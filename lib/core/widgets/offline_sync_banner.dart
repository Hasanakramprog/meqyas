import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/app_colors.dart';
import '../../features/auth/data/firebase_auth_repository.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/cut_optimization/data/cut_plan_repository.dart';
import '../../features/orders/data/orders_repository.dart';
import '../../features/projects/data/projects_repository.dart';
import '../../features/rules/data/rules_repository.dart';
import '../../features/suppliers/data/suppliers_repository.dart';
import '../firebase/offline_firestore_helper.dart';

/// Wraps the application's router child to provide:
/// 1. Real-time Offline / Pending-Sync banner at the top of the screen.
/// 2. Automatic Firestore cache warm-up for signed-in users (`rules`, `suppliers`, `workshops`, `projects`, `remnants`, `orders`).
/// 3. Lifecycle listener (`AppLifecycleState.resumed`) to immediately flush queued offline writes when connectivity returns.
/// 4. Single-Device Session Conflict alert when another device logs into the same account.
class OfflineSyncShell extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineSyncShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<OfflineSyncShell> createState() => _OfflineSyncShellState();
}

class _OfflineSyncShellState extends ConsumerState<OfflineSyncShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OfflineFirestoreHelper.startMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    OfflineFirestoreHelper.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OfflineFirestoreHelper.onAppResumed();
    }
  }

  /// Warms up Firestore local SQLite cache while online so all key collections
  /// are available if the user walks into an offline job site.
  void _warmUpCache(WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return;

    // Warm up global reference data
    ref.watch(suppliersListProvider);

    final activeWid = ref.watch(activeWorkshopIdProvider) ?? user.workshopId ?? '';
    if (user.uid.isNotEmpty) {
      ref.watch(ownerWorkshopsProvider(user.uid));
    }
    if (activeWid.isNotEmpty) {
      ref.watch(effectiveRulesProvider(activeWid));
      ref.watch(cuttingOptimizerProvider(activeWid));
      ref.watch(workshopProjectsProvider(activeWid));
      ref.watch(remnantsProvider(activeWid));
      ref.watch(workshopOrdersProvider(activeWid));
    }
    if (user.supplierId != null && user.supplierId!.isNotEmpty) {
      ref.watch(supplierOrdersProvider(user.supplierId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    _warmUpCache(ref);

    final statusAsync = ref.watch(offlineSyncStatusProvider);
    final status = statusAsync.value ?? OfflineFirestoreHelper.currentStatus;
    final conflictMsg = FirebaseAuthRepository.lastSessionConflictMessage;

    final showBanner = status.isOffline || conflictMsg != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: !showBanner
                ? const SizedBox.shrink()
                : Material(
                    color: conflictMsg != null
                        ? AppColors.error
                        : status.isOffline
                            ? const Color(0xFFD97706) // Amber/Orange warning
                            : AppColors.glassBlue,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              conflictMsg != null
                                  ? Icons.phonelink_lock_rounded
                                  : status.isOffline
                                      ? Icons.cloud_off_rounded
                                      : Icons.cloud_sync_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                conflictMsg ??
                                    (status.isOffline
                                        ? (status.pendingWritesCount > 0
                                            ? 'وضع عدم الاتصال — تم حفظ (${status.pendingWritesCount}) تعديل محلياً وسيتم المزامنة تلقائياً فور عودة الإنترنت'
                                            : 'وضع عدم الاتصال (Offline) — يمكنك العمل وحفظ المشاريع والقصات محلياً')
                                        : 'جاري مزامنة (${status.pendingWritesCount}) تعديل مع السحابة...'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            if (conflictMsg != null)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    FirebaseAuthRepository
                                        .lastSessionConflictMessage = null;
                                  });
                                },
                              )
                            else if (status.isOffline)
                              InkWell(
                                onTap: () =>
                                    OfflineFirestoreHelper.checkConnectivityNow(),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    'فحص الاتصال',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                      fontFamily: 'Cairo',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

/// Helper to guard user sign-out when the device is offline or has unsynced local writes.
class OfflineLogoutGuard {
  OfflineLogoutGuard._();

  static Future<void> confirmAndSignOut(BuildContext context) async {
    final status = OfflineFirestoreHelper.currentStatus;
    if (status.isOffline || status.hasPendingWrites) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(child: Text('تنبيه قبل تسجيل الخروج')),
              ],
            ),
            content: Text(
              status.hasPendingWrites
                  ? 'لديك (${status.pendingWritesCount}) تعديل محفوظ محلياً بانتظار الاتصال بالإنترنت للمزامنة.\n\nإذا قمت بتسجيل الخروج الآن بدون إنترنت، لن تتمكن من الدخول مرة أخرى حتى يتوفر اتصال بالإنترنت. هل تريد المتابعة؟'
                  : 'أنت غير متصل بالإنترنت حالياً.\nإذا قمت بتسجيل الخروج الآن، لن تتمكن من تسجيل الدخول مرة أخرى حتى يتوفر اتصال بالإنترنت. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('البقاء متصلاً بالحساب'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('تسجيل الخروج على أي حال'),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
    }

    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/auth/login');
    }
  }
}
