import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../logic/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Memberikan waktu minimal 2.5 detik agar animasi kopinya selesai diputar 
    // (Inilah efek 'Perceived Performance' yang kita bicarakan!)
    await Future.delayed(const Duration(milliseconds: 2500));
    
    if (!mounted) return;

    // Sistem mengecek secara diam-diam apakah user sudah login
    final session = ref.read(authStateProvider).value?.session;
    final role = ref.read(userRoleProvider).value;

    if (session != null) {
      if (role == 'cashier' || role == 'super_admin') {
        context.go('/cashier/dashboard');
      } else {
        context.go('/customer/radar');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Menampilkan animasi cangkir kopi yang sudah Anda unduh
            Lottie.asset(
              'assets/animations/coffee_loading.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Kopi SAKO',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Menyeduh data...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primaryOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}