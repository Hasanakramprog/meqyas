import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final DateTime? phoneVerifiedAt;
  final bool isEmailVerified;
  final UserRole role;
  final UserStatus status;
  final String? workshopId;
  final String? supplierId;

  const AppUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    this.phoneVerifiedAt,
    this.isEmailVerified = false,
    required this.role,
    this.status = UserStatus.active,
    this.workshopId,
    this.supplierId,
  });

  bool get isActive => status == UserStatus.active;
  bool get isOwner => role == UserRole.owner;
  bool get isSupplier => role == UserRole.supplier;
  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'phoneVerifiedAt': phoneVerifiedAt?.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'role': role.code,
      'status': status.code,
      'workshopId': workshopId,
      'supplierId': supplierId,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid, {bool isEmailVerified = false}) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      phoneVerifiedAt: _parseDateTime(map['phoneVerifiedAt']),
      isEmailVerified: isEmailVerified || (map['isEmailVerified'] as bool? ?? false),
      role: UserRole.fromCode(map['role'] as String?),
      status: UserStatus.fromCode(map['status'] as String?),
      workshopId: map['workshopId'] as String?,
      supplierId: map['supplierId'] as String?,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic dyn = value;
      final result = dyn.toDate();
      if (result is DateTime) return result;
    } catch (_) {}
    return null;
  }
}
