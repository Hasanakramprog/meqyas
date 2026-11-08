import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';

final adminAllUsersProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  return FirebaseFirestore.instance.collection('users').snapshots().map((snap) {
    final list = snap.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
    // Put users needing activation first, then sort by name/email
    list.sort((a, b) {
      final aNeedsActivation = !a.isEmailVerified || a.status != UserStatus.active;
      final bNeedsActivation = !b.isEmailVerified || b.status != UserStatus.active;
      if (aNeedsActivation != bNeedsActivation) {
        return aNeedsActivation ? -1 : 1;
      }
      return a.fullName.compareTo(b.fullName);
    });
    return list;
  });
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _filter = 'all'; // 'all' | 'needs_activation' | 'owner' | 'supplier' | 'disabled'
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _activateUser(AppUser user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'isEmailVerified': true,
      'status': 'active',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(
            'تم تفعيل حساب "${user.fullName.isNotEmpty ? user.fullName : user.email}" بنجاح ✅',
          ),
        ),
      );
    }
  }

  Future<void> _activateAllPending(List<AppUser> pendingUsers) async {
    if (pendingUsers.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    final now = FieldValue.serverTimestamp();
    for (final u in pendingUsers) {
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(u.uid),
        {
          'isEmailVerified': true,
          'status': 'active',
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('تم تفعيل ${pendingUsers.length} حساب بنجاح ✅'),
        ),
      );
    }
  }

  Future<void> _toggleUserDisabled(AppUser user) async {
    final newStatus =
        user.status == UserStatus.disabled ? 'active' : 'disabled';
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'status': newStatus,
      if (newStatus == 'active') 'isEmailVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'active'
                ? 'تمت إعادة تنشيط الحساب ✅'
                : 'تم تعطيل الحساب ⛔',
          ),
        ),
      );
    }
  }

  Future<void> _changeUserRole(AppUser user, UserRole newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'role': newRole.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث الدور إلى: ${newRole.labelAr}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final usersAsync = ref.watch(adminAllUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة وتفعيل المستخدمين'),
        centerTitle: false,
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('خطأ في تحميل المستخدمين: $err')),
        data: (allUsers) {
          final needsActivationList = allUsers
              .where(
                (u) => !u.isEmailVerified || u.status == UserStatus.pending,
              )
              .toList();

          final filtered = allUsers.where((u) {
            if (_filter == 'needs_activation') {
              if (u.isEmailVerified && u.status == UserStatus.active) {
                return false;
              }
            } else if (_filter == 'owner' && u.role != UserRole.owner) {
              return false;
            } else if (_filter == 'supplier' && u.role != UserRole.supplier) {
              return false;
            } else if (_filter == 'disabled' &&
                u.status != UserStatus.disabled) {
              return false;
            }

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchName = u.fullName.toLowerCase().contains(q);
              final matchEmail = u.email.toLowerCase().contains(q);
              final matchPhone = u.phone.toLowerCase().contains(q);
              if (!matchName && !matchEmail && !matchPhone) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // ── Top Banner for Pending Activations ──────────────────
              if (needsActivationList.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberPrimary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.amberPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.amberPrimary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'يوجد ${needsActivationList.length} حساب بانتظار التفعيل',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () =>
                            _activateAllPending(needsActivationList),
                        icon: const Icon(Icons.done_all_rounded, size: 18),
                        label: const Text('تفعيل الجميع بضغطة واحدة'),
                      ),
                    ],
                  ),
                ),

              // ── Search + Filter Chips ───────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو البريد الإلكتروني أو الجوال...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'الكل (${allUsers.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'needs_activation',
                            'بانتظار التفعيل (${needsActivationList.length})',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'owner',
                            'أصحاب الورش (${allUsers.where((u) => u.isOwner).length})',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'supplier',
                            'الموردين (${allUsers.where((u) => u.isSupplier).length})',
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'disabled',
                            'معطل (${allUsers.where((u) => u.status == UserStatus.disabled).length})',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Users List ──────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('لا يوجد مستخدمون مطابقون للبحث'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final u = filtered[index];
                          return _buildUserCard(context, u, theme, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filter == key;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      selectedColor: AppColors.amberPrimary.withValues(alpha: 0.22),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    AppUser user,
    ThemeData theme,
    bool isDark,
  ) {
    final needsActivation =
        !user.isEmailVerified || user.status == UserStatus.pending;
    final isDisabled = user.status == UserStatus.disabled;

    Color roleColor;
    switch (user.role) {
      case UserRole.admin:
        roleColor = AppColors.error;
      case UserRole.supplier:
        roleColor = AppColors.glassBlueLight;
      case UserRole.owner:
        roleColor = AppColors.amberPrimary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: needsActivation
              ? AppColors.amberPrimary.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: needsActivation ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: roleColor.withValues(alpha: 0.15),
                  child: Icon(
                    user.isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : (user.isSupplier
                              ? Icons.local_shipping_outlined
                              : Icons.precision_manufacturing_outlined),
                    color: roleColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty
                            ? user.fullName
                            : 'مستخدم بدون اسم',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.slate300
                              : AppColors.slate600,
                        ),
                      ),
                      if (user.phone.isNotEmpty)
                        Text(
                          'الجوال: ${user.phone}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.slate400
                                : AppColors.slate500,
                          ),
                        ),
                    ],
                  ),
                ),

                // Role selector menu
                PopupMenuButton<UserRole>(
                  tooltip: 'تغيير الدور',
                  onSelected: (newRole) => _changeUserRole(user, newRole),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: UserRole.owner,
                      child: Text('صاحب ورشة (Owner)'),
                    ),
                    PopupMenuItem(
                      value: UserRole.supplier,
                      child: Text('مورد (Supplier)'),
                    ),
                    PopupMenuItem(
                      value: UserRole.admin,
                      child: Text('مدير النظام (Admin)'),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: roleColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.role.labelAr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: roleColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status Badges + 1-Tap Action Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Email verification status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: user.isEmailVerified
                            ? AppColors.success.withValues(alpha: 0.14)
                            : AppColors.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.isEmailVerified
                            ? 'البريد مفعّل ✅'
                            : 'بانتظار تفعيل البريد ⏳',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: user.isEmailVerified
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ),

                    // Account status chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? AppColors.error.withValues(alpha: 0.14)
                            : AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isDisabled
                            ? 'الحساب معطّل ⛔'
                            : (user.status == UserStatus.pending
                                  ? 'بانتظار الموافقة'
                                  : 'الحساب نشط'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? AppColors.error
                              : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),

                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (needsActivation)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _activateUser(user),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'تفعيل الحساب الآن',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (!user.isAdmin)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDisabled
                              ? AppColors.success
                              : AppColors.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _toggleUserDisabled(user),
                        icon: Icon(
                          isDisabled
                              ? Icons.lock_open_rounded
                              : Icons.block_rounded,
                          size: 15,
                        ),
                        label: Text(
                          isDisabled ? 'إعادة تنشيط' : 'تعطيل الحساب',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
