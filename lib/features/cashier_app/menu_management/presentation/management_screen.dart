import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Operasional', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Menu Kelola Stok, Pelanggan, & Reward'),
      ),
    );
  }
}