import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/logic/auth_provider.dart';

import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_customer_screen.dart';
import '../features/auth/ui/register_cashier_screen.dart';

// Import Cashier App UI (Navigasi Bawah)
import '../features/cashier_app/dashboard/presentation/main_cashier_scaffold.dart';
import '../features/cashier_app/dashboard/presentation/dashboard_screen.dart';
import '../features/cashier_app/menu_management/presentation/management_screen.dart';
import '../features/cashier_app/reports/presentation/reports_screen.dart';

// Global Key untuk masing-masing router
final _rootNavigatorCustomer = GlobalKey<NavigatorState>();
final _rootNavigatorCashier = GlobalKey<NavigatorState>();

class AppRouter {
  
  // ==============================================================
  // 1. ROUTER APLIKASI CUSTOMER
  // ==============================================================
  static GoRouter customerRouter(WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value?.session;
    return GoRouter(
      navigatorKey: _rootNavigatorCustomer,
      initialLocation: '/login',
      redirect: (context, state) {
        final isLoggedIn = authState != null;
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';

        if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister) return '/login';
        if (isLoggedIn && (isGoingToLogin || isGoingToRegister)) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterCustomerScreen()),
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Kopi SAKO'), actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: () => AuthController.logout())
            ]),
            body: const Center(child: Text('Radar Peta Hadir di Sini!')),
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // 2. ROUTER APLIKASI KASIR
  // ==============================================================
  static GoRouter cashierRouter(WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value?.session;
    final userRole = ref.watch(userRoleProvider).value;
    
    return GoRouter(
      navigatorKey: _rootNavigatorCashier,
      initialLocation: '/cashier/dashboard', // Diarahkan langsung ke Dashboard baru
      redirect: (context, state) {
        final isLoggedIn = authState != null;
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';

        if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister) return '/login';
        
        if (isLoggedIn) {
          // Validasi ketat: Tendang keluar jika Customer mencoba masuk app Kasir
          if (userRole != null && userRole != 'cashier' && userRole != 'super_admin') {
            AuthController.logout();
            return '/login';
          }
          if (isGoingToLogin || isGoingToRegister) return '/cashier/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/login', 
          builder: (context, state) => const LoginScreen(isCashierApp: true)
        ),
        GoRoute(
          path: '/register', 
          builder: (context, state) => const RegisterCashierScreen()
        ),

        // --- SISTEM NAVIGASI BAWAH TANPA RELOAD ---
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainCashierScaffold(navigationShell: navigationShell);
          },
          branches: [
            // TAB 1: Beranda (Live)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/dashboard',
                  builder: (context, state) => const DashboardScreen(),
                ),
              ],
            ),
            
            // TAB 2: Pesanan (Riwayat & Search)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/orders',
                  builder: (context, state) => const Scaffold(body: Center(child: Text('Riwayat Pesanan'))), // Nanti kita buat file terpisah
                ),
              ],
            ),
            
            // TAB 3: Kelola
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/management',
                  builder: (context, state) => const ManagementScreen(),
                ),
              ],
            ),
            
            // TAB 4: Laporan
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}