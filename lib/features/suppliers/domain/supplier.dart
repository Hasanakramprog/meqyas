import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String name;
  final String phone;
  final List<String> whatsappPhones;
  final String address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.whatsappPhones = const [],
    this.address = '',
    this.createdAt,
    this.updatedAt,
  });

  List<String> get allWhatsappNumbers {
    final numbers = <String>[
      ...whatsappPhones.where((p) => p.trim().isNotEmpty),
      if (phone.trim().isNotEmpty) phone.trim(),
    ];
    return numbers.toSet().toList();
  }

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    List<String>? whatsappPhones,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsappPhones: whatsappPhones ?? this.whatsappPhones,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'whatsappPhones': whatsappPhones.map((p) => p.trim()).where((p) => p.isNotEmpty).toList(),
      'address': address.trim(),
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map, {String? docId}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawWhatsapp = map['whatsappPhones'];
    final whatsappList = rawWhatsapp is Iterable
        ? rawWhatsapp.map((e) => e.toString()).toList()
        : <String>[];

    return Supplier(
      id: docId ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? 'مورد بدون اسم',
      phone: map['phone'] as String? ?? '',
      whatsappPhones: whatsappList,
      address: map['address'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}

class SeedSuppliers {
  static List<Supplier> getDefaultSuppliers() {
    return const [
      Supplier(
        id: 'sup_national_aluminum',
        name: 'شركة التوريدات الوطنية للألمنيوم والملحقات',
        phone: '966500000001',
        whatsappPhones: ['966500000001', '966500000002'],
        address: 'المنطقة الصناعية — الرياض',
      ),
      Supplier(
        id: 'sup_gulf_glass',
        name: 'مصنع الخليج للزجاج والإكسسوارات',
        phone: '966500000003',
        whatsappPhones: ['966500000003'],
        address: 'الصناعية الثانية — الدمام',
      ),
    ];
  }
}

