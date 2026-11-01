import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/project.dart';
import '../domain/models/project_unit.dart';

abstract class ProjectsRepository {
  Stream<List<Project>> watchProjects(String workshopId);
  Stream<Project?> watchProject(String workshopId, String projectId);
  Future<Project?> getProject(String workshopId, String projectId);
  Future<String?> findProjectWorkshop(List<String> workshopIds, String projectId);
  Future<String> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String workshopId, String projectId);

  Stream<List<ProjectUnit>> watchUnits(String workshopId, String projectId);
  Future<ProjectUnit?> getUnit(String workshopId, String projectId, String unitId);
  Future<String> saveUnit(String workshopId, ProjectUnit unit);
  Future<void> deleteUnit(String workshopId, String projectId, String unitId);
}

class FirestoreProjectsRepository implements ProjectsRepository {
  final FirebaseFirestore _firestore;

  FirestoreProjectsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _projectsCol(String workshopId) =>
      _firestore.collection('workshops').doc(workshopId).collection('projects');

  CollectionReference<Map<String, dynamic>> _unitsCol(String workshopId, String projectId) =>
      _projectsCol(workshopId).doc(projectId).collection('units');

  @override
  Stream<List<Project>> watchProjects(String workshopId) {
    if (workshopId.isEmpty) return Stream.value(const []);
    return _projectsCol(workshopId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Project.fromFirestore).toList());
  }

  @override
  Stream<Project?> watchProject(String workshopId, String projectId) {
    if (workshopId.isEmpty || projectId.isEmpty) return Stream.value(null);
    return _projectsCol(workshopId).doc(projectId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Project.fromFirestore(doc);
    });
  }

  @override
  Future<Project?> getProject(String workshopId, String projectId) async {
    final doc = await _projectsCol(workshopId).doc(projectId).get();
    if (!doc.exists) return null;
    return Project.fromFirestore(doc);
  }

  @override
  Future<String?> findProjectWorkshop(List<String> workshopIds, String projectId) async {
    for (final wid in workshopIds) {
      final doc = await _projectsCol(wid).doc(projectId).get();
      if (doc.exists) return wid;
    }
    return null;
  }

  @override
  Future<String> createProject(Project project) async {
    final ref = _projectsCol(project.workshopId).doc();
    final newProject = project.copyWith(
      id: ref.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.set(newProject.toMap());
    return ref.id;
  }

  @override
  Future<void> updateProject(Project project) async {
    await _projectsCol(project.workshopId).doc(project.id).update({
      'name': project.name,
      'clientName': project.clientName,
      'clientPhone': project.clientPhone,
      'location': project.location,
      'status': project.status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteProject(String workshopId, String projectId) async {
    final batch = _firestore.batch();

    // 1. Delete subcollection units
    final units = await _unitsCol(workshopId, projectId).get();
    for (final u in units.docs) {
      batch.delete(u.reference);
    }

    // 2. Delete subcollection requirements (Project Materials Requirements table)
    final reqs = await _projectsCol(workshopId)
        .doc(projectId)
        .collection('requirements')
        .get();
    for (final req in reqs.docs) {
      batch.delete(req.reference);
    }

    // 3. Delete cut plans for this project & collect planIds + consumedRemnantIds
    final plans = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('cutPlans')
        .where('projectId', isEqualTo: projectId)
        .get();

    final planIds = <String>[];
    final consumedRemnantIdsFromPlans = <String>{};
    for (final p in plans.docs) {
      planIds.add(p.id);
      final data = p.data();
      final resultMap = data['result'] as Map<String, dynamic>?;
      final consumedList =
          (resultMap?['consumedRemnantIds'] as List<dynamic>?) ??
              (data['consumedRemnantIds'] as List<dynamic>?);
      if (consumedList != null) {
        for (final id in consumedList) {
          if (id is String && id.isNotEmpty) {
            consumedRemnantIdsFromPlans.add(id);
          }
        }
      }
      batch.delete(p.reference);
    }

    // 4. Delete remnants originating from this project
    final remnants = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .where('sourceProjectId', isEqualTo: projectId)
        .get();

    final deletedOriginRemnantIds = <String>{};
    for (final r in remnants.docs) {
      deletedOriginRemnantIds.add(r.id);
      batch.delete(r.reference);
    }

    // 5. Restore shelf remnants that were consumed by this project's plans
    final remnantsToRestore = <DocumentReference<Map<String, dynamic>>>{};
    for (var i = 0; i < planIds.length; i += 10) {
      final chunk = planIds.sublist(
        i,
        i + 10 > planIds.length ? planIds.length : i + 10,
      );
      final consumedSnap = await _firestore
          .collection('workshops')
          .doc(workshopId)
          .collection('remnants')
          .where('usedInPlanId', whereIn: chunk)
          .get();
      for (final rDoc in consumedSnap.docs) {
        if (!deletedOriginRemnantIds.contains(rDoc.id)) {
          remnantsToRestore.add(rDoc.reference);
        }
      }
    }

    for (final remId in consumedRemnantIdsFromPlans) {
      if (!deletedOriginRemnantIds.contains(remId)) {
        final remRef = _firestore
            .collection('workshops')
            .doc(workshopId)
            .collection('remnants')
            .doc(remId);
        final remSnap = await remRef.get();
        if (remSnap.exists) {
          remnantsToRestore.add(remRef);
        }
      }
    }

    for (final remRef in remnantsToRestore) {
      batch.update(remRef, {
        'state': 'available',
        'usedAt': FieldValue.delete(),
        'usedInPlanId': FieldValue.delete(),
      });
    }

    // 6. Delete workshop cart items originating from this project
    final cartItems = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('cart')
        .where('sourceProjectId', isEqualTo: projectId)
        .get();
    for (final c in cartItems.docs) {
      batch.delete(c.reference);
    }

    // 7. Clean up draft orders in `orders` collection related to this project
    try {
      final draftOrders = await _firestore
          .collection('orders')
          .where('workshopId', isEqualTo: workshopId)
          .where('status', isEqualTo: 'draft')
          .get();
      for (final ordDoc in draftOrders.docs) {
        final data = ordDoc.data();
        final rawItems = (data['items'] as List<dynamic>?) ?? const [];
        final hasProjectItems = rawItems.any(
          (item) =>
              item is Map<String, dynamic> && item['projectId'] == projectId,
        );
        if (!hasProjectItems) continue;

        final remainingItems = rawItems
            .where(
              (item) =>
                  !(item is Map<String, dynamic> &&
                      item['projectId'] == projectId),
            )
            .toList();
        if (remainingItems.isEmpty) {
          batch.delete(ordDoc.reference);
        } else {
          var newTotal = 0.0;
          for (final item in remainingItems) {
            if (item is Map<String, dynamic>) {
              final q = (item['qty'] as num?)?.toDouble() ?? 0.0;
              final p = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
              newTotal += q * p;
            }
          }
          batch.update(ordDoc.reference, {
            'items': remainingItems,
            'totalAmount': newTotal,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {
      // Ignore if offline or index not ready for orders cleanup
    }

    // 8. Delete the project document itself
    batch.delete(_projectsCol(workshopId).doc(projectId));

    await batch.commit();

    // 9. Best-effort cleanup of cut plan PDFs in Firebase Storage
    for (final planId in planIds) {
      try {
        await FirebaseStorage.instance
            .ref('workshops/$workshopId/cut-plans/$planId/cut_plan.pdf')
            .delete();
      } catch (_) {}
    }
  }

  @override
  Stream<List<ProjectUnit>> watchUnits(String workshopId, String projectId) {
    if (workshopId.isEmpty || projectId.isEmpty) return Stream.value(const []);
    return _unitsCol(workshopId, projectId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(ProjectUnit.fromFirestore).toList());
  }

  @override
  Future<ProjectUnit?> getUnit(String workshopId, String projectId, String unitId) async {
    final doc = await _unitsCol(workshopId, projectId).doc(unitId).get();
    if (!doc.exists) return null;
    return ProjectUnit.fromFirestore(doc);
  }

  @override
  Future<String> saveUnit(String workshopId, ProjectUnit unit) async {
    final col = _unitsCol(workshopId, unit.projectId);
    final projectRef = _projectsCol(workshopId).doc(unit.projectId);

    if (unit.id.isEmpty) {
      // New unit
      final docRef = col.doc();
      final newUnit = unit.copyWith(
        id: docRef.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final batch = _firestore.batch();
      batch.set(docRef, newUnit.toMap());
      batch.set(projectRef, {
        'unitCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      return docRef.id;
    } else {
      // Existing unit update
      final docRef = col.doc(unit.id);
      final batch = _firestore.batch();
      batch.set(docRef, unit.toMap(), SetOptions(merge: true));
      batch.set(projectRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      return unit.id;
    }
  }

  @override
  Future<void> deleteUnit(String workshopId, String projectId, String unitId) async {
    final batch = _firestore.batch();
    batch.delete(_unitsCol(workshopId, projectId).doc(unitId));
    batch.set(_projectsCol(workshopId).doc(projectId), {
      'unitCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return FirestoreProjectsRepository();
});

final workshopProjectsProvider = StreamProvider.autoDispose.family<List<Project>, String>((ref, workshopId) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchProjects(workshopId);
});
