import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ============================================================================
// FUNGSI GLOBAL: POP-UP SAKO CERDAS (PENGGANTI SNACKBAR)
// ============================================================================
Future<void> showSakoPopUp(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) async {
  if (!context.mounted) return;

  // OTAK PENERJEMAH ERROR QA
  String finalMessage = message;
  if (isError) {
    final lowerMsg = message.toLowerCase();

    // PERBAIKAN: Menambahkan 'failed to fetch' dan 'clientexception' untuk menangkap error internet di Web/Emulator
    if (lowerMsg.contains('socketexception') ||
        lowerMsg.contains('failed host lookup') ||
        lowerMsg.contains('failed to fetch') ||
        lowerMsg.contains('clientexception')) {
      finalMessage =
          'Gagal terhubung ke server. Silakan periksa koneksi internet Anda.';
    } else if (lowerMsg.contains('timeout')) {
      finalMessage =
          'Waktu koneksi habis. Internet Anda terputus atau tidak stabil.';
    } else if (lowerMsg.contains('invalid login credentials')) {
      finalMessage = 'Nomor WhatsApp atau Password yang Anda masukkan salah.';
    } else if (lowerMsg.contains('already registered') ||
        lowerMsg.contains('duplicate')) {
      finalMessage =
          'Nomor WhatsApp atau Email ini sudah terdaftar sebelumnya.';
    } else if (lowerMsg.contains('weak password') ||
        lowerMsg.contains('password should be')) {
      finalMessage = 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    } else if (lowerMsg.contains('rate limit')) {
      finalMessage =
          'Terlalu banyak percobaan masuk. Silakan tunggu beberapa saat lagi.';
    }
  }

  // TAMPILKAN POP-UP
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      // Contoh perbaikan struktur teks di dalam pop_up_helper.dart
      content: Text(
        message,
        textAlign: TextAlign
            .center, // KUNCI RAPI: Letakkan teks di tengah agar seimbang
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 14,
          height: 1.4, // Memberikan jarak antar baris agar tidak dempet
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
