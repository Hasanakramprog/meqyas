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
import '../../features/projects/domain/models/project_unit.dart';
import '../../features/projects/presentation/screens/project_detail_screen.dart';
import '../../features/projects/presentation/screens/projects_list_screen.dart';
import '../../features/projects/presentation/screens/unit_editor_screen.dart';
import '../../features/rules/presentation/admin_rules_screen.dart';
import '../../features/rules/presentation/workshop_rules_screen.dart';
import '../../features/cut_optimization/presentation/screens/cut_plan_screen.dart';
import '../../features/cut_optimization/presentation/screens/remnants_screen.dart';
import '../../features/cut_scanner/presentation/screens/qr_piece_scanner_screen.dart';

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
        routes: [
          GoRoute(
            path: 'rules',
            name: 'owner_rules',
            builder: (context, state) {
              final wid = state.uri.queryParameters['workshopId'];
              return WorkshopRulesScreen(initialWorkshopId: wid);
            },
          ),
          GoRoute(
            path: 'projects',
            name: 'owner_projects',
            builder: (context, state) => const ProjectsListScreen(),
            routes: [
              GoRoute(
                path: ':projectId',
                name: 'project_detail',
                builder: (context, state) {
                  final projectId = state.pathParameters['projectId']!;
                  final workshopId = state.uri.queryParameters['workshopId'];
                  return ProjectDetailScreen(
                    projectId: projectId,
                    initialWorkshopId: workshopId,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'units/new',
                    name: 'new_unit',
                    builder: (context, state) {
                      final projectId = state.pathParameters['projectId']!;
                      final workshopId = state.uri.queryParameters['workshopId'];
                      return UnitEditorScreen(
                        projectId: projectId,
                        initialWorkshopId: workshopId,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'units/:unitId',
                    name: 'edit_unit',
                    builder: (context, state) {
                      final projectId = state.pathParameters['projectId']!;
                      final workshopId = state.uri.queryParameters['workshopId'];
                      final unit = state.extra as ProjectUnit?;
                      return UnitEditorScreen(
                        projectId: projectId,
                        initialUnit: unit,
                        initialWorkshopId: workshopId,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: 'cut-plan',
            name: 'cut_plan',
            builder: (context, state) {
              final projectId = state.uri.queryParameters['projectId']!;
              final workshopId = state.uri.queryParameters['workshopId'] ?? '';
              return CutPlanScreen(
                workshopId: workshopId,
                projectId: projectId,
              );
            },
          ),
          GoRoute(
            path: 'remnants',
            name: 'workshop_remnants',
            builder: (context, state) {
              final workshopId = state.uri.queryParameters['workshopId'] ?? '';
              return RemnantsScreen(workshopId: workshopId);
            },
          ),
          GoRoute(
            path: 'scanner',
            name: 'qr_scanner',
            builder: (context, state) => const QrPieceScannerScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/scanner',
        name: 'quick_scanner',
        builder: (context, state) => const QrPieceScannerScreen(),
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
        routes: [
          GoRoute(
            path: 'rules',
            name: 'admin_rules',
            builder: (context, state) => const AdminRulesScreen(),
          ),
        ],
      ),
    ],
  );
});
