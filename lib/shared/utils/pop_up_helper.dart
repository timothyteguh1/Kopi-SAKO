import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ============================================================================
// FUNGSI GLOBAL: POP-UP SAKO CERDAS (BENTUK KOTAK TENGAH)
// ============================================================================
Future<void> showSakoPopUp(
  BuildContext context, {
  required String title,
  required String message,
  bool isError = false,
}) async {
  if (!context.mounted) return;

  // OTAK PENERJEMAH ERROR QA (Dipertahankan dari sistem Anda)[cite: 2]
  String finalMessage = message;
  if (isError) {
    final lowerMsg = message.toLowerCase();

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
    } else if (lowerMsg.contains('database error saving new user') ||
        lowerMsg.contains('unexpected_failure')) {
      finalMessage =
          'Sistem Database menolak pendaftaran. Terdapat kesalahan pada Trigger atau struktur tabel (Error 500).';
    }
  }

  // TAMPILKAN POP-UP KOTAK DENGAN UI BERSIH
  await showDialog(
    context: context,
    barrierDismissible: true, // Bisa ditutup dengan mengetuk area luar layar
    builder: (BuildContext ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 40,
        ), // Agar lebar pop-up pas di tengah[cite: 2]
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize
                .min, // Agar tinggi pop-up menyesuaikan isi teks[cite: 2]
            children: [
              // Ikon Animasi/Warna dengan Latar Belakang Lingkaran Halus
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isError
                      ? Colors.red.withOpacity(0.1)
                      : AppColors.primaryOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: isError ? Colors.red : AppColors.primaryOrange,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Judul Pop-up
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),

              // Pesan Detail (Sudah melewati penerjemah bahasa)
              Text(
                finalMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Tombol Aksi Bawah
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError
                        ? Colors.red
                        : AppColors.primaryOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () =>
                      Navigator.of(ctx).pop(), // Perintah menutup pop-up
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
