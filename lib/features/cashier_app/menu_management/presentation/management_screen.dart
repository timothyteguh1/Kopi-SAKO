import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; 

import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';

class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRole = ref.watch(userRoleProvider).value;
    final isAdmin = userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: const Text(
          'Kelola Operasional',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Menu Utama',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),

          // MENU 1: STOK
          _buildMenuCard(
            context,
            title: 'Stok Bahan & Menu',
            subtitle: isAdmin
                ? 'Kelola semua stok dan harga jual'
                : 'Lihat sisa stok di cabang ini',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              context.go('/cashier/management/stock');
            },
          ),

          // MENU 2: PEMBELIAN
          _buildMenuCard(
            context,
            title: 'Catat Pembelian',
            subtitle: 'Input pengeluaran belanja cabang',
            icon: Icons.receipt_long_outlined,
            onTap: () {
              context.go('/cashier/management/purchases');
            },
          ),

          // MENU 3: KELOLA PELANGGAN
          _buildMenuCard(
            context,
            title: 'Daftar Pelanggan',
            subtitle: isAdmin
                ? 'Kelola poin, edit nama, reset sandi, & hapus'
                : 'Lihat daftar pelanggan & sisa poin',
            icon: Icons.group_outlined,
            onTap: () {
              context.go('/cashier/management/customers');
            },
          ),

          // MENU 4: REWARD / PROMO
          _buildMenuCard(
            context,
            title: 'Reward & Promo',
            subtitle: isAdmin
                ? 'Buat dan atur promo pelanggan'
                : 'Lihat daftar promo aktif',
            icon: Icons.card_giftcard_outlined,
            onTap: () {
              // TODO: context.go('/cashier/management/promo');
            },
          ),

          // MENU 5: PENGATURAN PRINTER (BARU)
          _buildMenuCard(
            context,
            title: 'Pengaturan Printer',
            subtitle: 'Sambungkan ke printer thermal bluetooth',
            icon: Icons.print_outlined,
            onTap: () {
              context.go('/cashier/management/printer');
            },
          ),

          // --- PEMBATAS KHUSUS SUPER ADMIN ---
          if (isAdmin) ...[
            const SizedBox(height: 24),
            const Text(
              'Khusus Super Admin',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // MENU 6: KELOLA KASIR
            _buildMenuCard(
              context,
              title: 'Kelola Kasir',
              subtitle: 'Tugaskan kasir ke cabang tertentu',
              icon: Icons.people_outline,
              onTap: () {
                context.go('/cashier/management/admin_cashiers');
              },
            ),

            // MENU 7: KELOLA CABANG
            _buildMenuCard(
              context,
              title: 'Kelola Cabang',
              subtitle: 'Tambah, edit, atau tutup cabang',
              icon: Icons.storefront_outlined,
              onTap: () {
                context.go('/cashier/management/admin_branches');
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primaryOrange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}