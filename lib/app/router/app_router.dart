import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/pending_approval_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/supplier_dashboard_screen.dart';
import '../../features/home/presentation/home_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AppUser?>>(
      currentUserProvider,
      (_, _) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(currentUserProvider);

    // If auth state is still loading, stay on current location
    if (authState.isLoading) return null;

    final user = authState.value;
    final loc = state.matchedLocation;

    final isAuthRoute = loc == '/auth/login' || loc == '/auth/register';
    final isHomeRoute = loc == '/';
    final isVerifyRoute = loc == '/auth/verify-email';
    final isPendingRoute = loc == '/auth/pending-approval';

    // 1. Not signed in
    if (user == null) {
      if (isAuthRoute || isHomeRoute) return null;
      return '/auth/login';
    }

    // 2. Disabled account
    if (user.status == UserStatus.disabled) {
      return '/auth/login';
    }

    // 3. Email not verified
    if (!user.isEmailVerified) {
      if (isVerifyRoute) return null;
      return '/auth/verify-email';
    }

    // 4. Pending approval
    if (user.status == UserStatus.pending) {
      if (isPendingRoute) return null;
      return '/auth/pending-approval';
    }

    // 5. Signed in & active trying to access login/register/verify/pending
    if (isAuthRoute || isVerifyRoute || isPendingRoute) {
      return _dashboardForRole(user.role);
    }

    // 6. Role-based route guard on /dashboard/...
    if (loc.startsWith('/dashboard/')) {
      if (user.isOwner && !loc.startsWith('/dashboard/owner')) {
        return '/dashboard/owner';
      }
      if (user.isSupplier && !loc.startsWith('/dashboard/supplier')) {
        return '/dashboard/supplier';
      }
      if (user.isAdmin) {
        // Admin can view all dashboards
        return null;
      }
    }

    return null;
  }

  String _dashboardForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return '/dashboard/admin';
      case UserRole.supplier:
        return '/dashboard/supplier';
      case UserRole.owner:
        return '/dashboard/owner';
    }
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/verify-email',
        name: 'verify_email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: '/auth/pending-approval',
        name: 'pending_approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),
      GoRoute(
        path: '/dashboard/owner',
        name: 'owner_dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/supplier',
        name: 'supplier_dashboard',
        builder: (context, state) => const SupplierDashboardScreen(),
      ),
      GoRoute(
        path: '/dashboard/admin',
        name: 'admin_dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});
