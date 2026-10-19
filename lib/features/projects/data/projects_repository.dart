import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/project.dart';
import '../domain/models/project_unit.dart';

abstract class ProjectsRepository {
  Stream<List<Project>> watchProjects(String workshopId);
  Future<Project?> getProject(String workshopId, String projectId);
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
  Future<Project?> getProject(String workshopId, String projectId) async {
    final doc = await _projectsCol(workshopId).doc(projectId).get();
    if (!doc.exists) return null;
    return Project.fromFirestore(doc);
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
    // Delete subcollection units first
    final units = await _unitsCol(workshopId, projectId).get();
    final batch = _firestore.batch();
    for (final u in units.docs) {
      batch.delete(u.reference);
    }
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
      batch.update(projectRef, {
        'unitCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return docRef.id;
    } else {
      // Existing unit update
      final docRef = col.doc(unit.id);
      final batch = _firestore.batch();
      batch.set(docRef, unit.toMap(), SetOptions(merge: true));
      batch.update(projectRef, {
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return unit.id;
    }
  }

  @override
  Future<void> deleteUnit(String workshopId, String projectId, String unitId) async {
    final batch = _firestore.batch();
    batch.delete(_unitsCol(workshopId, projectId).doc(unitId));
    batch.update(_projectsCol(workshopId).doc(projectId), {
      'unitCount': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return FirestoreProjectsRepository();
});
