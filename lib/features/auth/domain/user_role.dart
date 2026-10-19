/// Available user roles in Maqyas as defined in Section 2
enum UserRole {
  owner('owner', 'المعلم (صاحب الورشة)'),
  supplier('supplier', 'المورد'),
  admin('admin', 'الأدمن');

  final String code;
  final String labelAr;

  const UserRole(this.code, this.labelAr);

  static UserRole fromCode(String? code) {
    switch (code) {
      case 'supplier':
        return UserRole.supplier;
      case 'admin':
        return UserRole.admin;
      case 'owner':
      default:
        return UserRole.owner;
    }
  }
}

/// Status of user account
enum UserStatus {
  active('active'),
  pending('pending'),
  disabled('disabled');

  final String code;
  const UserStatus(this.code);

  static UserStatus fromCode(String? code) {
    switch (code) {
      case 'pending':
        return UserStatus.pending;
      case 'disabled':
        return UserStatus.disabled;
      case 'active':
      default:
        return UserStatus.active;
    }
  }
}
