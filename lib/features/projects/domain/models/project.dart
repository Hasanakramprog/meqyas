import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String workshopId;
  final String name;
  final String clientName;
  final String clientPhone;
  final String location;
  final String status; // 'draft', 'in_progress', 'completed'
  final int unitCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.workshopId,
    required this.name,
    this.clientName = '',
    this.clientPhone = '',
    this.location = '',
    this.status = 'draft',
    this.unitCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'workshopId': workshopId,
      'name': name,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'location': location,
      'status': status,
      'unitCount': unitCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Project.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Project(
      id: doc.id,
      workshopId: data['workshopId'] as String? ?? '',
      name: data['name'] as String? ?? 'مشروع بدون اسم',
      clientName: data['clientName'] as String? ?? '',
      clientPhone: data['clientPhone'] as String? ?? '',
      location: data['location'] as String? ?? '',
      status: data['status'] as String? ?? 'draft',
      unitCount: (data['unitCount'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(data['createdAt']),
      updatedAt: _parseDate(data['updatedAt']),
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  Project copyWith({
    String? id,
    String? workshopId,
    String? name,
    String? clientName,
    String? clientPhone,
    String? location,
    String? status,
    int? unitCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      workshopId: workshopId ?? this.workshopId,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      location: location ?? this.location,
      status: status ?? this.status,
      unitCount: unitCount ?? this.unitCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
