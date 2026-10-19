import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/supplier_dashboard_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
