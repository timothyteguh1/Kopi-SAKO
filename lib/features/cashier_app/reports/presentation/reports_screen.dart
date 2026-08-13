import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Keuangan', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Laporan Penjualan & Uang Keluar'),
      ),
    );
  }
}