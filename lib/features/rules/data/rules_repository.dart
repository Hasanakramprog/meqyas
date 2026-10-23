import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maqyas_engine/maqyas_engine.dart';

class RulesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  RulesRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  // -------------------------------------------------------------
  // Stream Approved Rules (Global)
  // -------------------------------------------------------------
  Stream<List<CalculationRule>> watchApprovedRules() {
    return _firestore
        .collection('calculationRules')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        // Fallback to built-in seed rules if database is empty/fresh
        return SeedRules.getSystem2000BeadedRules();
      }
      return snap.docs
          .map((doc) => CalculationRule.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  // -------------------------------------------------------------
  // Stream All Rules (Admin)
  // -------------------------------------------------------------
  Stream<List<CalculationRule>> watchAllRules() {
    return _firestore.collection('calculationRules').snapshots().map((snap) {
      return snap.docs
          .map((doc) => CalculationRule.fromMap(doc.data(), docId: doc.id))
          .toList();
    });
  }

  // -------------------------------------------------------------
  // Workshop Overrides
  // -------------------------------------------------------------
  Stream<Map<String, Map<String, dynamic>>> watchWorkshopOverrides(String workshopId) {
    if (workshopId.isEmpty) return Stream.value(const {});
    return _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('ruleOverrides')
        .snapshots()
        .map((snap) {
      final map = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        map[doc.id] = doc.data();
      }
      return map;
    });
  }

  /// Merges global approved rules with workshop-specific custom overrides
  Stream<List<CalculationRule>> watchEffectiveRules(String workshopId) {
    if (workshopId.isEmpty) {
      return watchApprovedRules();
    }

    // Combine both streams
    final approvedStream = watchApprovedRules();
    final overridesStream = watchWorkshopOverrides(workshopId);

    return StreamZip2(approvedStream, overridesStream, (
      List<CalculationRule> approved,
      Map<String, Map<String, dynamic>> overrides,
    ) {
      if (overrides.isEmpty) return approved;

      return approved.map((baseRule) {
        final override = overrides[baseRule.ruleKey];
        if (override != null) {
          return baseRule.copyWith(
            lengthFormula: override['lengthFormula'] as String? ?? baseRule.lengthFormula,
            quantityFormula: override['quantityFormula'] as String? ?? baseRule.quantityFormula,
            notes: '[مخصص للورشة] ${baseRule.notes ?? ""}'.trim(),
          );
        }
        return baseRule;
      }).toList();
    });
  }

  Future<void> saveWorkshopRuleOverride({
    required String workshopId,
    required String ruleKey,
    required String lengthFormula,
    required String quantityFormula,
    required String baseRuleVersionId,
    String? updatedBy,
    List<String>? allWorkshopIds,
  }) async {
    final targetWorkshopIds = (allWorkshopIds != null && allWorkshopIds.isNotEmpty)
        ? allWorkshopIds
        : [workshopId];

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final wid in targetWorkshopIds) {
      final ref = _firestore
          .collection('workshops')
          .doc(wid)
          .collection('ruleOverrides')
          .doc(ruleKey);

      batch.set(ref, {
        'ruleKey': ruleKey,
        'baseRuleVersionId': baseRuleVersionId,
        'lengthFormula': lengthFormula,
        'quantityFormula': quantityFormula,
        'updatedAt': now,
        'updatedBy': ?updatedBy,
      });
    }

    await batch.commit();
  }

  Future<void> deleteWorkshopRuleOverride({
    required String workshopId,
    required String ruleKey,
    List<String>? allWorkshopIds,
  }) async {
    final targetWorkshopIds = (allWorkshopIds != null && allWorkshopIds.isNotEmpty)
        ? allWorkshopIds
        : [workshopId];

    final batch = _firestore.batch();
    for (final wid in targetWorkshopIds) {
      final ref = _firestore
          .collection('workshops')
          .doc(wid)
          .collection('ruleOverrides')
          .doc(ruleKey);
      batch.delete(ref);
    }
    await batch.commit();
  }

  // -------------------------------------------------------------
  // Cutting Optimizer Settings (Workshop & System)
  // -------------------------------------------------------------
  Stream<CutOptimizer> watchCuttingOptimizer(String workshopId) {
    if (workshopId.isEmpty) {
      return watchSystemCuttingOptimizer();
    }

    final workshopRef = _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('settings')
        .doc('cutting');

    return workshopRef.snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data()?['isCustomized'] == true) {
        final d = doc.data()!;
        return CutOptimizer(
          barLengthCm: (d['barLengthCm'] as num?)?.toDouble() ?? 660.0,
          trimLossCm: (d['trimLossCm'] as num?)?.toDouble() ?? 4.0,
          kerfPerCutCm: (d['kerfPerCutCm'] as num?)?.toDouble() ?? 0.5,
          minRemnantCm: (d['minRemnantCm'] as num?)?.toDouble() ?? 50.0,
        );
      }
      // Fallback to system configs
      return await getSystemCuttingOptimizer();
    });
  }

  Stream<CutOptimizer> watchSystemCuttingOptimizer() {
    return _firestore
        .collection('systemConfigs')
        .doc('cuttingOptimizer')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final d = doc.data()!;
        return CutOptimizer(
          barLengthCm: (d['barLengthCm'] as num?)?.toDouble() ?? 660.0,
          trimLossCm: (d['trimLossCm'] as num?)?.toDouble() ?? 4.0,
          kerfPerCutCm: (d['kerfPerCutCm'] as num?)?.toDouble() ?? 0.5,
          minRemnantCm: (d['minRemnantCm'] as num?)?.toDouble() ?? 50.0,
        );
      }
      return const CutOptimizer();
    });
  }

  Future<CutOptimizer> getSystemCuttingOptimizer() async {
    try {
      final doc = await _firestore.collection('systemConfigs').doc('cuttingOptimizer').get();
      if (doc.exists) {
        final d = doc.data()!;
        return CutOptimizer(
          barLengthCm: (d['barLengthCm'] as num?)?.toDouble() ?? 660.0,
          trimLossCm: (d['trimLossCm'] as num?)?.toDouble() ?? 4.0,
          kerfPerCutCm: (d['kerfPerCutCm'] as num?)?.toDouble() ?? 0.5,
          minRemnantCm: (d['minRemnantCm'] as num?)?.toDouble() ?? 50.0,
        );
      }
    } catch (_) {}
    return const CutOptimizer();
  }

  Future<void> saveWorkshopCuttingSettings({
    required String workshopId,
    required double barLengthCm,
    required double trimLossCm,
    required double kerfPerCutCm,
    required double minRemnantCm,
    List<String>? allWorkshopIds,
  }) async {
    final targets = (allWorkshopIds != null && allWorkshopIds.isNotEmpty)
        ? allWorkshopIds
        : [workshopId];

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final wid in targets) {
      final ref = _firestore
          .collection('workshops')
          .doc(wid)
          .collection('settings')
          .doc('cutting');

      batch.set(ref, {
        'barLengthCm': barLengthCm,
        'trimLossCm': trimLossCm,
        'kerfPerCutCm': kerfPerCutCm,
        'minRemnantCm': minRemnantCm,
        'isCustomized': true,
        'updatedAt': now,
      });
    }
    await batch.commit();
  }

  Future<void> resetWorkshopCuttingSettings({
    required String workshopId,
    List<String>? allWorkshopIds,
  }) async {
    final targets = (allWorkshopIds != null && allWorkshopIds.isNotEmpty)
        ? allWorkshopIds
        : [workshopId];

    final batch = _firestore.batch();
    for (final wid in targets) {
      final ref = _firestore
          .collection('workshops')
          .doc(wid)
          .collection('settings')
          .doc('cutting');
      batch.delete(ref);
    }
    await batch.commit();
  }

  Future<void> saveSystemCuttingSettings({
    required double barLengthCm,
    required double trimLossCm,
    required double kerfPerCutCm,
    required double minRemnantCm,
    required String adminUid,
  }) async {
    final ref = _firestore.collection('systemConfigs').doc('cuttingOptimizer');
    await ref.set({
      'barLengthCm': barLengthCm,
      'trimLossCm': trimLossCm,
      'kerfPerCutCm': kerfPerCutCm,
      'minRemnantCm': minRemnantCm,
      'updatedBy': adminUid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -------------------------------------------------------------
  // Pinned Rule Versions (For old projects)
  // -------------------------------------------------------------
  Future<List<CalculationRule>> getRulesByIds(List<String> versionIds) async {
    if (versionIds.isEmpty) return const [];

    final cleanIds = versionIds.map((v) => v.split('_v').first).toSet().toList();
    final rules = <CalculationRule>[];

    for (final id in cleanIds) {
      try {
        final doc = await _firestore.collection('calculationRules').doc(id).get();
        if (doc.exists) {
          rules.add(CalculationRule.fromMap(doc.data()!, docId: doc.id));
        }
      } catch (_) {}
    }

    return rules.isNotEmpty ? rules : SeedRules.getSystem2000BeadedRules();
  }

  // -------------------------------------------------------------
  // Admin Rule Operations
  // -------------------------------------------------------------
  Future<String> saveDraftRule(CalculationRule rule, {String? adminUid}) async {
    final col = _firestore.collection('calculationRules');
    final docRef = rule.id.isNotEmpty ? col.doc(rule.id) : col.doc();
    final now = FieldValue.serverTimestamp();

    final data = rule.toMap();
    data['id'] = docRef.id;
    data['status'] = 'draft';
    data['updatedAt'] = now;
    if (rule.id.isEmpty) {
      data['createdAt'] = now;
      if (adminUid != null) data['createdBy'] = adminUid;
    }

    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> deleteDraftRule(String ruleId) async {
    await _firestore.collection('calculationRules').doc(ruleId).delete();
  }

  Future<void> approveRule(String ruleId) async {
    final callable = _functions.httpsCallable('approveRule');
    await callable.call({'ruleId': ruleId});
  }

  Future<void> archiveRule(String ruleId) async {
    final callable = _functions.httpsCallable('archiveRule');
    await callable.call({'ruleId': ruleId});
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs() {
    return _firestore
        .collection('auditLogs')
        .orderBy('at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Stream<List<WorkshopInfo>> watchOwnerWorkshops(String ownerUid) {
    if (ownerUid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('workshops')
        .where('ownerUid', isEqualTo: ownerUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => WorkshopInfo(
                  id: doc.id,
                  name: (doc.data()['name'] as String?) ?? 'ورشة بدون اسم',
                  location: (doc.data()['location'] as String?) ?? '',
                  phone: (doc.data()['phone'] as String?) ?? '',
                ))
            .toList());
  }

  Future<String> createWorkshop({
    required String name,
    required String location,
    String phone = '',
  }) async {
    final callable = _functions.httpsCallable('createWorkshop');
    final res = await callable.call({
      'name': name,
      'location': location,
      'phone': phone,
    });
    return res.data['workshopId'] as String;
  }
}

class WorkshopInfo {
  final String id;
  final String name;
  final String location;
  final String phone;

  const WorkshopInfo({
    required this.id,
    required this.name,
    this.location = '',
    this.phone = '',
  });
}

// -------------------------------------------------------------
// Stream Helper (Zip 2 Streams)
// -------------------------------------------------------------
class StreamZip2<A, B, R> extends Stream<R> {
  final Stream<A> _a;
  final Stream<B> _b;
  final R Function(A, B) _combiner;

  StreamZip2(this._a, this._b, this._combiner);

  @override
  StreamSubscription<R> listen(
    void Function(R event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    A? lastA;
    B? lastB;
    var hasA = false;
    var hasB = false;

    final controller = StreamController<R>();

    void checkEmit() {
      if (hasA && hasB && onData != null) {
        controller.add(_combiner(lastA as A, lastB as B));
      }
    }

    final subA = _a.listen((a) {
      lastA = a;
      hasA = true;
      checkEmit();
    }, onError: controller.addError);

    final subB = _b.listen((b) {
      lastB = b;
      hasB = true;
      checkEmit();
    }, onError: controller.addError);

    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// -------------------------------------------------------------
// Riverpod Providers
// -------------------------------------------------------------
final rulesRepositoryProvider = Provider<RulesRepository>((ref) {
  return RulesRepository();
});

final ownerWorkshopsProvider = StreamProvider.autoDispose.family<List<WorkshopInfo>, String>((ref, ownerUid) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchOwnerWorkshops(ownerUid);
});

class ActiveWorkshopNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setWorkshopId(String? id) => state = id;
}

final activeWorkshopIdProvider = NotifierProvider<ActiveWorkshopNotifier, String?>(
  ActiveWorkshopNotifier.new,
);

final effectiveRulesProvider = StreamProvider.autoDispose.family<List<CalculationRule>, String>((ref, workshopId) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchEffectiveRules(workshopId);
});

final workshopOverridesProvider = StreamProvider.autoDispose.family<Map<String, Map<String, dynamic>>, String>((ref, workshopId) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchWorkshopOverrides(workshopId);
});

final allAdminRulesProvider = StreamProvider.autoDispose<List<CalculationRule>>((ref) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchAllRules();
});

final auditLogsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchAuditLogs();
});

final calculatorEngineProvider = Provider.autoDispose.family<CalculatorEngine, String>((ref, workshopId) {
  final rulesAsync = ref.watch(effectiveRulesProvider(workshopId));
  final rules = rulesAsync.value ?? SeedRules.getSystem2000BeadedRules();
  return CalculatorEngine(rules: rules);
});

final cuttingOptimizerProvider = StreamProvider.autoDispose.family<CutOptimizer, String>((ref, workshopId) {
  final repo = ref.watch(rulesRepositoryProvider);
  return repo.watchCuttingOptimizer(workshopId);
});
