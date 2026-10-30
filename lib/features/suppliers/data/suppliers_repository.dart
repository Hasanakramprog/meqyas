import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/supplier.dart';

class SuppliersRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  SuppliersRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('suppliers');

  Stream<List<Supplier>> watchSuppliers() {
    return _col.snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return SeedSuppliers.getDefaultSuppliers();
      }
      final list = snap.docs
          .map((doc) => Supplier.fromMap(doc.data(), docId: doc.id))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Stream<Supplier?> watchSupplierById(String supplierId) {
    if (supplierId.isEmpty) return Stream.value(null);
    return _col.doc(supplierId).snapshots().map((doc) {
      if (!doc.exists) {
        for (final seed in SeedSuppliers.getDefaultSuppliers()) {
          if (seed.id == supplierId) return seed;
        }
        return null;
      }
      return Supplier.fromMap(doc.data()!, docId: doc.id);
    });
  }

  /// Creates a supplier with a Firebase Auth account via `createSupplierUser` Cloud Function (Admin only).
  Future<String> createSupplierAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    required List<String> whatsappPhones,
    required String address,
  }) async {
    final callable = _functions.httpsCallable('createSupplierUser');
    final res = await callable.call({
      'email': email.trim(),
      'password': password,
      'name': name.trim(),
      'phone': phone.trim(),
      'whatsappPhones': whatsappPhones,
      'address': address.trim(),
    });
    return res.data['supplierId'] as String;
  }

  /// Saves or updates a supplier document directly (Admin or own Supplier).
  Future<String> saveSupplier(Supplier supplier) async {
    final docRef = supplier.id.isNotEmpty ? _col.doc(supplier.id) : _col.doc();
    final now = FieldValue.serverTimestamp();
    final data = supplier.toMap();
    data['updatedAt'] = now;
    if (supplier.id.isEmpty) {
      data['createdAt'] = now;
    }
    await docRef.set(data, SetOptions(merge: true));
    return docRef.id;
  }

  Future<int> seedDefaultSuppliersToFirestore() async {
    final existing = await _col.get();
    final existingIds = existing.docs.map((d) => d.id).toSet();
    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();
    var added = 0;

    for (final s in SeedSuppliers.getDefaultSuppliers()) {
      if (existingIds.contains(s.id)) continue;
      batch.set(_col.doc(s.id), {
        ...s.toMap(),
        'createdAt': now,
        'updatedAt': now,
      });
      added++;
    }
    if (added > 0) await batch.commit();
    return added;
  }
}

final suppliersRepositoryProvider = Provider<SuppliersRepository>((ref) {
  return SuppliersRepository();
});

final suppliersListProvider = StreamProvider.autoDispose<List<Supplier>>((ref) {
  final repo = ref.watch(suppliersRepositoryProvider);
  return repo.watchSuppliers();
});

final supplierByIdProvider = StreamProvider.autoDispose
    .family<Supplier?, String>((ref, supplierId) {
      final repo = ref.watch(suppliersRepositoryProvider);
      return repo.watchSupplierById(supplierId);
    });
