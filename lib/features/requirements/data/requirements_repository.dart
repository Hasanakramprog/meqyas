import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/firebase/offline_firestore_helper.dart';
import '../domain/requirement_line.dart';
import 'requirements_service.dart';

class RequirementsRepository {
  final FirebaseFirestore _firestore;

  RequirementsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _projectDoc(
    String workshopId,
    String projectId,
  ) =>
      _firestore
          .collection('workshops')
          .doc(workshopId)
          .collection('projects')
          .doc(projectId);

  CollectionReference<Map<String, dynamic>> _reqCol(
    String workshopId,
    String projectId,
  ) =>
      _projectDoc(workshopId, projectId).collection('requirements');

  Stream<List<RequirementLine>> watchRequirements(
    String workshopId,
    String projectId,
  ) {
    if (workshopId.isEmpty || projectId.isEmpty) {
      return Stream.value(const []);
    }
    return _reqCol(workshopId, projectId).snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => RequirementLine.fromMap(doc.data(), docId: doc.id))
          .toList();
      return RequirementsService.sortLines(list);
    });
  }

  Future<List<RequirementLine>> getRequirements(
    String workshopId,
    String projectId,
  ) async {
    if (workshopId.isEmpty || projectId.isEmpty) return const [];
    final snap = await OfflineFirestoreHelper.getQueryOfflineSafe(
      _reqCol(workshopId, projectId),
    );
    final list = snap.docs
        .map((doc) => RequirementLine.fromMap(doc.data(), docId: doc.id))
        .toList();
    return RequirementsService.sortLines(list);
  }

  String _deterministicAutoId(RequirementLine line) {
    final safeCode = line.engineItemCode
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\u0600-\u06FF]'), '_');
    return 'auto_${line.category}_${safeCode.isEmpty ? line.nameArabic.hashCode.abs() : safeCode}';
  }

  /// Writes the initial auto-generated snapshot if no lines exist yet,
  /// and records `requirementsGeneratedAt` on the project document.
  /// Never modifies supplier stock (Spec §0.4 & §11).
  Future<void> saveSnapshot({
    required String workshopId,
    required String projectId,
    required List<RequirementLine> lines,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty) return;

    final col = _reqCol(workshopId, projectId);
    final existingSnap = await OfflineFirestoreHelper.getQueryOfflineSafe(col);
    final resolvedLines = lines.map((l) {
      if (l.id.isNotEmpty) return l;
      if (l.isAuto) return l.copyWith(id: _deterministicAutoId(l));
      return l;
    }).toList();
    final incomingIds = resolvedLines
        .map((l) => l.id)
        .where((id) => id.isNotEmpty)
        .toSet();

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    // Remove auto lines that are no longer in the merged snapshot
    for (final doc in existingSnap.docs) {
      if (!incomingIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (final line in resolvedLines) {
      final docRef = line.id.isNotEmpty ? col.doc(line.id) : col.doc();
      final data = line.copyWith(id: docRef.id).toMap();
      data['updatedAt'] = now;
      batch.set(docRef, data, SetOptions(merge: true));
    }

    batch.set(
      _projectDoc(workshopId, projectId),
      {'requirementsGeneratedAt': now},
      SetOptions(merge: true),
    );

    await OfflineFirestoreHelper.commitBatchOfflineSafe(batch);
  }

  Future<void> upsertLine({
    required String workshopId,
    required String projectId,
    required RequirementLine line,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty) return;
    final col = _reqCol(workshopId, projectId);
    final docRef = line.id.isNotEmpty ? col.doc(line.id) : col.doc();
    final now = FieldValue.serverTimestamp();
    final data = line.copyWith(id: docRef.id).toMap();
    data['updatedAt'] = now;
    if (line.id.isEmpty) {
      data['createdAt'] = now;
    }
    await OfflineFirestoreHelper.writeOfflineSafe(
      docRef.set(data, SetOptions(merge: true)),
    );
  }

  /// Deletes a manual line or marks an auto line as `dismissed = true` so
  /// regeneration does not bring it back unless the owner restores dismissed lines.
  Future<void> dismissOrDeleteLine({
    required String workshopId,
    required String projectId,
    required RequirementLine line,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty || line.id.isEmpty) return;
    final docRef = _reqCol(workshopId, projectId).doc(line.id);
    if (line.isAuto) {
      await OfflineFirestoreHelper.writeOfflineSafe(
        docRef.update({
          'dismissed': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
    } else {
      await OfflineFirestoreHelper.writeOfflineSafe(docRef.delete());
    }
  }

  /// Restores a single dismissed auto line or re-creates a deleted manual line (for Undo snackbar).
  Future<void> undoDeleteLine({
    required String workshopId,
    required String projectId,
    required RequirementLine previousLine,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty) return;
    await upsertLine(
      workshopId: workshopId,
      projectId: projectId,
      line: previousLine.copyWith(
        dismissed: false,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Restores all dismissed auto lines in the project.
  Future<int> restoreAllDismissed({
    required String workshopId,
    required String projectId,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty) return 0;
    final col = _reqCol(workshopId, projectId);
    final snap = await OfflineFirestoreHelper.getQueryOfflineSafe(
      col.where('dismissed', isEqualTo: true),
    );
    if (snap.docs.isEmpty) return 0;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'dismissed': false,
        'updatedAt': now,
      });
    }
    await OfflineFirestoreHelper.commitBatchOfflineSafe(batch);
    return snap.docs.length;
  }

  /// Resets a manual override on `toBuyQty` back to `max(requiredQty - inStockQty, 0)`.
  Future<void> resetToBuyOverride({
    required String workshopId,
    required String projectId,
    required RequirementLine line,
  }) async {
    if (workshopId.isEmpty || projectId.isEmpty || line.id.isEmpty) return;
    final defaultToBuy = RequirementLine.computeDefaultToBuy(
      line.requiredQty,
      line.inStockQty,
    );
    await OfflineFirestoreHelper.writeOfflineSafe(
      _reqCol(workshopId, projectId).doc(line.id).update({
        'toBuyQty': defaultToBuy,
        'isToBuyOverridden': false,
        'needsReviewAfterRegen': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }
}

final requirementsRepositoryProvider = Provider<RequirementsRepository>((ref) {
  return RequirementsRepository();
});

final projectRequirementsProvider = StreamProvider.autoDispose.family<
    List<RequirementLine>, ({String workshopId, String projectId})>((ref, arg) {
  final repo = ref.watch(requirementsRepositoryProvider);
  return repo.watchRequirements(arg.workshopId, arg.projectId);
});

