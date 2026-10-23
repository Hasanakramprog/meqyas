import 'package:cloud_firestore/cloud_firestore.dart';
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

    // 2. Delete cut plans for this project
    final plans = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('cutPlans')
        .where('projectId', isEqualTo: projectId)
        .get();

    final planIds = plans.docs.map((d) => d.id).toList();
    for (final p in plans.docs) {
      batch.delete(p.reference);
    }

    // 3. Delete remnants originating from this project
    final remnants = await _firestore
        .collection('workshops')
        .doc(workshopId)
        .collection('remnants')
        .where('sourceProjectId', isEqualTo: projectId)
        .get();

    for (final r in remnants.docs) {
      batch.delete(r.reference);
    }

    // 4. Restore shelf remnants that were consumed by this project's plans
    if (planIds.isNotEmpty) {
      final consumedRemnants = await _firestore
          .collection('workshops')
          .doc(workshopId)
          .collection('remnants')
          .where('usedInPlanId', whereIn: planIds.take(10).toList())
          .get();

      for (final rDoc in consumedRemnants.docs) {
        batch.update(rDoc.reference, {
          'state': 'available',
          'usedAt': FieldValue.delete(),
          'usedInPlanId': FieldValue.delete(),
        });
      }
    }

    // 5. Delete the project document
    batch.delete(_projectsCol(workshopId).doc(projectId));

    await batch.commit();
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
