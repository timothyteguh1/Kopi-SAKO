import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kopi_sako/features/auth/ui/forgot_password_screen.dart';
import '../features/auth/logic/auth_provider.dart';

import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_customer_screen.dart';
import '../features/auth/ui/register_cashier_screen.dart';
import '../features/auth/ui/splash_screen.dart'; // ---> TAMBAHAN: Import Splash Screen <---

// ==============================================================
// IMPORT CASHIER APP UI
// ==============================================================
import '../features/cashier_app/dashboard/presentation/main_cashier_scaffold.dart';
import '../features/cashier_app/dashboard/presentation/dashboard_screen.dart';
import '../features/cashier_app/menu_management/presentation/management_screen.dart';
import '../features/cashier_app/reports/presentation/reports_screen.dart';
import '../features/cashier_app/orders/presentation/orders_history_screen.dart';
import '../features/cashier_app/menu_management/stock/presentation/stock_screen.dart';
import '../features/cashier_app/purchases/presentation/purchases_screen.dart';
import '../features/cashier_app/menu_management/customers/presentation/customer_list_screen.dart';
import '../features/cashier_app/menu_management/admin/presentation/branches_admin_screen.dart';
import '../features/cashier_app/menu_management/admin/presentation/cashiers_admin_screen.dart';
import '../features/cashier_app/menu_management/presentation/printer_settings_screen.dart';

// ==============================================================
// IMPORT CUSTOMER APP UI
// ==============================================================
import '../features/customer_app/radar/presentation/radar_screen.dart';
import '../features/customer_app/presentation/main_customer_scaffold.dart';
import '../features/customer_app/order_checkout/presentation/customer_orders_screen.dart'; 
import '../features/customer_app/presentation/profile_screen.dart';


final _rootNavigatorCustomer = GlobalKey<NavigatorState>();
final _rootNavigatorCashier = GlobalKey<NavigatorState>();

class AppRouter {
  
  // ==============================================================
  // 1. ROUTER APLIKASI CUSTOMER
  // ==============================================================
  static GoRouter customerRouter(WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value?.session;
    final userRole = ref.watch(userRoleProvider).value; 

    return GoRouter(
      navigatorKey: _rootNavigatorCustomer,
      initialLocation: '/splash', // ---> TAMBAHAN: Rute awal kini adalah splash screen <---
      redirect: (context, state) {
        final isLoggedIn = authState != null;
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';
        final isGoingToForgotPass = state.matchedLocation == '/forgot-password';
        final isGoingToSplash = state.matchedLocation == '/splash'; // ---> TAMBAHAN <---

        // ---> TAMBAHAN: Izinkan Splash Screen berjalan bebas tanpa dicegat <---
        if (isGoingToSplash) return null; 

        if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister && !isGoingToForgotPass) return '/login';
        
        if (isLoggedIn) {
          // CEK ROLE: Jika bukan customer, tendang dan beri pesan
          if (userRole != null && userRole != 'customer') {
            AuthController.logout(); 

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_rootNavigatorCustomer.currentContext != null) {
                ScaffoldMessenger.of(_rootNavigatorCustomer.currentContext!).showSnackBar(
                  const SnackBar(
                    content: Text('Akses Ditolak: Aplikasi ini khusus untuk Pelanggan.'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
            
            return '/login'; 
          }

          if (isGoingToLogin || isGoingToRegister || isGoingToForgotPass) return '/customer/radar';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()), // ---> TAMBAHAN <---
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterCustomerScreen()),
        GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
        
        // --- SISTEM NAVIGASI BAWAH CUSTOMER ---
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainCustomerScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer/radar',
                  pageBuilder: (context, state) => const NoTransitionPage(child: RadarScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer/orders',
                  pageBuilder: (context, state) => const NoTransitionPage(child: CustomerOrdersScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer/profile',
                  pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
                ),
              ],
            ),
          ],
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
      initialLocation: '/splash', // ---> TAMBAHAN: Rute awal kini adalah splash screen <---
      redirect: (context, state) {
        final isLoggedIn = authState != null;
        final isGoingToLogin = state.matchedLocation == '/login';
        final isGoingToRegister = state.matchedLocation == '/register';
        final isGoingToForgotPass = state.matchedLocation == '/forgot-password';
        final isGoingToSplash = state.matchedLocation == '/splash'; // ---> TAMBAHAN <---

        // ---> TAMBAHAN: Izinkan Splash Screen berjalan bebas tanpa dicegat <---
        if (isGoingToSplash) return null;

        if (!isLoggedIn && !isGoingToLogin && !isGoingToRegister && !isGoingToForgotPass) return '/login';
        
        if (isLoggedIn) {
          if (userRole != null && userRole != 'cashier' && userRole != 'super_admin') {
            AuthController.logout();
            return '/login';
          }
          if (isGoingToLogin || isGoingToRegister || isGoingToForgotPass) return '/cashier/dashboard';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()), // ---> TAMBAHAN <---
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen(isCashierApp: true)),
        GoRoute(path: '/register', builder: (context, state) => const RegisterCashierScreen()),
        GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),

        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainCashierScaffold(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/dashboard',
                  pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/orders',
                  pageBuilder: (context, state) => const NoTransitionPage(child: OrdersHistoryScreen()),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/management',
                  pageBuilder: (context, state) => const NoTransitionPage(child: ManagementScreen()),
                  routes: [
                    GoRoute(path: 'stock', builder: (context, state) => const StockScreen()),
                    GoRoute(path: 'purchases', builder: (context, state) => const PurchasesScreen()),
                    GoRoute(path: 'customers', builder: (context, state) => const CustomerListScreen()),
                    GoRoute(path: 'printer', builder: (context, state) => const PrinterSettingsScreen()),
                    GoRoute(path: 'admin_branches', builder: (context, state) => const BranchesAdminScreen()),
                    GoRoute(path: 'admin_cashiers', builder: (context, state) => const CashiersAdminScreen()),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/cashier/reports',
                  pageBuilder: (context, state) => const NoTransitionPage(child: ReportsScreen()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}