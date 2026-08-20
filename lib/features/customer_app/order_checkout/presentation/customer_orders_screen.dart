import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CustomerOrdersScreen extends StatelessWidget {
  const CustomerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Riwayat Pesanan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              const Text(
                'Belum Ada Pesanan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              Text(
                'Fitur status pesanan langsung di dalam aplikasi sedang disiapkan.\n\nSaat ini, silakan gunakan tombol Chat WA di menu Radar untuk memesan langsung ke Kasir.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}