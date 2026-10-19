import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final DateTime? phoneVerifiedAt;
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
      'role': role.code,
      'status': status.code,
      'workshopId': workshopId,
      'supplierId': supplierId,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      phoneVerifiedAt: map['phoneVerifiedAt'] != null
          ? DateTime.tryParse(map['phoneVerifiedAt'] as String)
          : null,
      role: UserRole.fromCode(map['role'] as String?),
      status: UserStatus.fromCode(map['status'] as String?),
      workshopId: map['workshopId'] as String?,
      supplierId: map['supplierId'] as String?,
    );
  }
}
