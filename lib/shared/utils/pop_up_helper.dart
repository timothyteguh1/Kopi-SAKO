import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ============================================================================
// FUNGSI GLOBAL: POP-UP SAKO CERDAS (BENTUK KOTAK / SQUARED)
// ============================================================================
Future<void> showSakoPopUp(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) async {
  if (!context.mounted) return;

  // OTAK PENERJEMAH ERROR QA[cite: 8]
  String finalMessage = message;
  if (isError) {
    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains('socketexception') ||
        lowerMsg.contains('failed host lookup') ||
        lowerMsg.contains('failed to fetch') ||
        lowerMsg.contains('clientexception')) {
      finalMessage = 'Gagal terhubung ke server. Silakan periksa koneksi internet Anda.';
    } else if (lowerMsg.contains('timeout')) {
      finalMessage = 'Waktu koneksi habis. Internet Anda terputus atau tidak stabil.';
    } else if (lowerMsg.contains('invalid login credentials')) {
      finalMessage = 'Nomor WhatsApp atau Password yang Anda masukkan salah.';
    } else if (lowerMsg.contains('already registered') || lowerMsg.contains('duplicate')) {
      finalMessage = 'Nomor WhatsApp atau Email ini sudah terdaftar sebelumnya.';
    } else if (lowerMsg.contains('weak password') || lowerMsg.contains('password should be')) {
      finalMessage = 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    } else if (lowerMsg.contains('rate limit')) {
      finalMessage = 'Terlalu banyak percobaan masuk. Silakan tunggu beberapa saat lagi.';
    } else if (lowerMsg.contains('database error saving new user') || lowerMsg.contains('unexpected_failure')) {
      finalMessage = 'Sistem Database menolak pendaftaran. Terdapat kesalahan pada Trigger atau struktur tabel (Error 500).';
    }
  }

  // TAMPILKAN POP-UP KOTAK
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surfaceWhite,
      // Radius diturunkan agar lebih tegas/boxy[cite: 8]
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
      // KUNCI KOTAK: Margin luar diperbesar agar pop-up terjepit dan tidak memanjang ke samping
      insetPadding: const EdgeInsets.symmetric(horizontal: 48), 
      child: Padding(
        padding: const EdgeInsets.all(24.0), // Jarak aman dalam (padding)
        child: Column(
          mainAxisSize: MainAxisSize.min, // Agar tinggi pop-up menyesuaikan isi
          children: [
            // Ikon dipindah ke tengah atas agar proporsional
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
              size: 56, 
            ),
            const SizedBox(height: 16),
            
            // Judul di tengah
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isError ? Colors.red : Colors.green,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 12),
            
            // Pesan error di tengah[cite: 8]
            Text(
              finalMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                height: 1.4, 
              ),
            ),
            const SizedBox(height: 24),
            
            // Tombol
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
      ),
    ),
  );
}