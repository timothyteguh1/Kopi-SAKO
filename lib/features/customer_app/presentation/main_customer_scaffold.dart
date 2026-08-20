import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainCustomerScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainCustomerScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    // Warna khas SAKO
    final Color colorJagoGreen = const Color(0xFF007A4D);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          backgroundColor: Colors.white,
          indicatorColor: colorJagoGreen.withOpacity(0.15),
          elevation: 0,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore, color: colorJagoGreen),
              label: 'Radar',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long, color: colorJagoGreen),
              label: 'Pesanan',
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: colorJagoGreen),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}