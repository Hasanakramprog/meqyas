import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class RemnantDoc {
  final String id;
  final String itemCode;
  final String nameArabic;
  final String color;
  final double lengthCm;
  final String sourceProjectId;
  final String sourceProjectName;
  final String sourcePlanId;
  final String state; // 'available' | 'used'
  final DateTime createdAt;
  final DateTime? usedAt;

  const RemnantDoc({
    required this.id,
    required this.itemCode,
    required this.nameArabic,
    required this.color,
    required this.lengthCm,
    required this.sourceProjectId,
    required this.sourceProjectName,
    required this.sourcePlanId,
    required this.state,
    required this.createdAt,
    this.usedAt,
  });

  bool get isAvailable => state == 'available';

  RemnantStock toRemnantStock() => RemnantStock(
        id: id,
        itemCode: itemCode,
        nameArabic: nameArabic,
        color: color,
        lengthCm: lengthCm,
        sourceProjectName: sourceProjectName,
      );

  factory RemnantDoc.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return RemnantDoc(
      id: docId,
      itemCode: map['itemCode'] as String? ?? '',
      nameArabic: map['nameArabic'] as String? ?? '',
      color: map['color'] as String? ?? 'white',
      lengthCm: (map['lengthCm'] as num?)?.toDouble() ?? 0,
      sourceProjectId: map['sourceProjectId'] as String? ?? '',
      sourceProjectName: map['sourceProjectName'] as String? ?? '',
      sourcePlanId: map['sourcePlanId'] as String? ?? '',
      state: map['state'] as String? ?? 'available',
      createdAt: parseTs(map['createdAt']),
      usedAt: map['usedAt'] != null ? parseTs(map['usedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'itemCode': itemCode,
        'nameArabic': nameArabic,
        'color': color,
        'lengthCm': lengthCm,
        'sourceProjectId': sourceProjectId,
        'sourceProjectName': sourceProjectName,
        'sourcePlanId': sourcePlanId,
        'state': state,
        'createdAt': Timestamp.fromDate(createdAt),
        if (usedAt != null) 'usedAt': Timestamp.fromDate(usedAt!),
      };
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class CutPlanRepository {
  final FirebaseFirestore _firestore;

  CutPlanRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // -------------------------------------------------------------------------
  // Remnants — Stream & Read
  // -------------------------------------------------------------------------

  /// Streams all remnants for a workshop, ordered by creation date descending.
  Stream<List<RemnantDoc>> watchRemnants(String workshopId) {
    return _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RemnantDoc.fromMap(d.data(), d.id))
            .toList());
  }

  /// Loads only available remnants for the optimizer (one-shot, called at plan generation time).
  Future<List<RemnantDoc>> getAvailableRemnants(String workshopId) async {
    final snap = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .where('state', isEqualTo: 'available')
        .get();
    return snap.docs.map((d) => RemnantDoc.fromMap(d.data(), d.id)).toList();
  }

  // -------------------------------------------------------------------------
  // Save Cut Plan + Remnants (atomic batch)
  // -------------------------------------------------------------------------

  /// Saves the optimization result to Firestore:
  /// 1. Writes a `cutPlans/{planId}` document.
  /// 2. Writes a `remnants/{id}` document for every new reusable remnant.
  /// 3. Marks consumed remnant IDs as `state: used`.
  Future<String> saveCutPlan({
    required String workshopId,
    required String projectId,
    required String projectName,
    required String generatedByUid,
    required OptimizationResult result,
    required double minRemnantCm,
  }) async {
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    // 1. Delete previous cut plans for this project
    final existingPlans = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('cutPlans')
        .where('projectId', isEqualTo: projectId)
        .get();

    final oldPlanIds = existingPlans.docs.map((d) => d.id).toSet();
    for (final doc in existingPlans.docs) {
      batch.delete(doc.reference);
    }

    // 2. Delete existing AVAILABLE remnants originating from this project
    // (they are superseded by the new cut plan calculation)
    final existingRemnants = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .where('sourceProjectId', isEqualTo: projectId)
        .get();

    for (final doc in existingRemnants.docs) {
      final state = doc.data()['state'];
      if (state == 'available') {
        batch.delete(doc.reference);
      }
    }

    // 3. If an old plan consumed shelf remnants that are NOT consumed by the new plan,
    // restore them back to 'available'
    if (oldPlanIds.isNotEmpty) {
      final consumedByOldPlans = await _firestore
          .collection('workshops')
          .doc(workshopId)
          .collection('remnants')
          .where('usedInPlanId', whereIn: oldPlanIds.toList().take(10).toList())
          .get();

      final newlyConsumed = result.consumedRemnantIds.toSet();
      for (final rDoc in consumedByOldPlans.docs) {
        if (!newlyConsumed.contains(rDoc.id)) {
          batch.update(rDoc.reference, {
            'state': 'available',
            'usedAt': FieldValue.delete(),
            'usedInPlanId': FieldValue.delete(),
          });
        }
      }
    }

    // 4. Create new cut plan document
    final planRef = _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('cutPlans')
        .doc();
    final planId = planRef.id;

    // Build itemGroups from barPlans
    final itemGroupsMap = <String, Map<String, dynamic>>{};
    for (final bar in result.barPlans) {
      itemGroupsMap.putIfAbsent(bar.itemCode, () => {
            'itemCode': bar.itemCode,
            'nameArabic': bar.cuts.isNotEmpty ? bar.cuts.first.nameArabic : bar.itemCode,
            'color': bar.color,
            'bars': <Map<String, dynamic>>[],
          });

      (itemGroupsMap[bar.itemCode]!['bars'] as List).add({
        'barNumber': bar.barNumber,
        'sourceKind': bar.isFromRemnant ? 'remnant' : 'full_bar',
        if (bar.sourceRemnantId != null) 'sourceRemnantId': bar.sourceRemnantId,
        if (bar.sourceRemnantLengthCm != null)
          'sourceRemnantLengthCm': bar.sourceRemnantLengthCm,
        if (bar.sourceRemnantProjectName != null)
          'sourceRemnantProjectName': bar.sourceRemnantProjectName,
        'totalBarLengthCm': bar.totalBarLengthCm,
        'totalCutsLengthCm': bar.totalCutsLengthCm,
        'kerfLossCm': bar.totalKerfLossCm,
        'remainingLengthCm': bar.remainingLengthCm,
        'isRemnantUseful': bar.isRemnantUseful,
        'cuts': bar.cuts
            .map((c) => {
                  'nameArabic': c.nameArabic,
                  'lengthCm': c.lengthCm,
                  'pieceIndex': c.pieceIndex,
                  'unitTag': c.unitTag ?? '',
                  if (c.fromRemnantId != null) 'fromRemnantId': c.fromRemnantId,
                })
            .toList(),
      });
    }

    // Write cut plan document
    batch.set(planRef, {
      'projectId': projectId,
      'projectName': projectName,
      'generatedAt': now,
      'generatedBy': generatedByUid,
      'pdfUrl': null,
      'summary': {
        'totalBarsNeeded': result.summary.totalBarsNeeded,
        'remnantsReused': result.summary.remnantsReused,
        'totalCutLengthCm': result.summary.totalCutLengthCm,
        'totalTrimLossCm': result.summary.totalTrimLossCm,
        'totalKerfLossCm': result.summary.totalKerfLossCm,
        'totalScrapCm': result.summary.totalScrapCm,
        'totalReusableRemnantsCm': result.summary.totalReusableRemnantsCm,
        'scrapPercentage': result.summary.scrapPercentage,
        'barsSavedByRemnants': result.summary.barsSavedByRemnants,
      },
      'itemGroups': itemGroupsMap.values.toList(),
      'oversizedCuts': result.oversizedCuts
          .map((c) => {
                'nameArabic': c.nameArabic,
                'lengthCm': c.lengthCm,
                'unitTag': c.unitTag ?? '',
              })
          .toList(),
    });

    // Write new remnants (useful leftovers from this plan: both from new full bars and consumed remnants)
    for (final bar in result.barPlans) {
      if (bar.isRemnantUseful) {
        final remnantRef = _firestore
            .collection('workshops')
            .doc(workshopId)
            .collection('remnants')
            .doc();
        batch.set(remnantRef, {
          'itemCode': bar.itemCode,
          'nameArabic': bar.cuts.isNotEmpty ? bar.cuts.first.nameArabic : bar.itemCode,
          'color': bar.color,
          'lengthCm': (bar.remainingLengthCm * 10).round() / 10,
          'sourceProjectId': projectId,
          'sourceProjectName': projectName,
          'sourcePlanId': planId,
          'state': 'available',
          'createdAt': now,
          if (bar.sourceRemnantId != null) 'parentRemnantId': bar.sourceRemnantId,
        });
      }
    }

    // Mark consumed remnants as 'used'
    for (final remnantId in result.consumedRemnantIds) {
      final remnantRef = _firestore
          .collection('workshops')
          .doc(workshopId)
          .collection('remnants')
          .doc(remnantId);
      batch.update(remnantRef, {
        'state': 'used',
        'usedAt': now,
        'usedInPlanId': planId,
      });
    }

    await batch.commit();
    return planId;
  }

  // -------------------------------------------------------------------------
  // Mark Remnant as Used / Available (manual, from RemnantsScreen)
  // -------------------------------------------------------------------------

  Future<void> markRemnantUsed(String workshopId, String remnantId) async {
    await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .doc(remnantId)
        .update({
      'state': 'used',
      'usedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markRemnantAvailable(String workshopId, String remnantId) async {
    await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .doc(remnantId)
        .update({
      'state': 'available',
      'usedAt': FieldValue.delete(),
      'usedInPlanId': FieldValue.delete(),
    });
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final cutPlanRepositoryProvider = Provider<CutPlanRepository>((ref) {
  return CutPlanRepository();
});

final remnantsProvider =
    StreamProvider.autoDispose.family<List<RemnantDoc>, String>(
  (ref, workshopId) {
    if (workshopId.isEmpty) return const Stream.empty();
    return ref.watch(cutPlanRepositoryProvider).watchRemnants(workshopId);
  },
);

final availableRemnantsProvider =
    StreamProvider.autoDispose.family<List<RemnantDoc>, String>(
  (ref, workshopId) {
    if (workshopId.isEmpty) return const Stream.empty();
    return ref
        .watch(cutPlanRepositoryProvider)
        .watchRemnants(workshopId)
        .map((list) => list.where((r) => r.isAvailable).toList());
  },
);
