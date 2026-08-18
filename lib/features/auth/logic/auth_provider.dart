import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

final userRoleProvider = FutureProvider<String?>((ref) async {
  final session = ref.watch(authStateProvider).value?.session;
  if (session == null) return null;

  try {
    final response = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .single();
    return response['role'] as String;
  } catch (e) {
    return null;
  }
});

class AuthController {

  // ==========================================
  // 2. LOGIKA MINTA OTP (PANGGIL EDGE FUNCTION)
  // ==========================================
  static Future<String?> sendRegisterOtp(String realEmail, String password, String name, String phone) async {
    try {
      // Memanggil Edge Function Supabase 'send-otp' yang telah dideploy
      final response = await supabase.functions.invoke(
        'send-otp',
        body: {
          'email': realEmail,
          'phone': phone,
        },
      );

      if (response.status != 200) {
        return 'Gagal mengirim OTP. Silakan periksa kembali email Anda.';
      }
      
      return null; // Sukses tanpa error
    } catch (e) {
      return 'Terjadi kesalahan jaringan atau sistem: $e';
    }
  }

  // ==========================================
  // 3. VERIFIKASI OTP & BOOKING AUTH DI TEMPAT
  // ==========================================
  // 1. VERIFIKASI OTP: Hanya cek kecocokan angka, JANGAN daftar user di sini!
  static Future<String?> verifyOtpAndFinalize(String realEmail, String otp, String phone) async {
    try {
      final otpData = await supabase.from('otp_requests').select().eq('email', realEmail).eq('otp_code', otp).maybeSingle();

      if (otpData == null) return 'Kode OTP salah atau tidak valid.';

      final expiresAt = DateTime.parse(otpData['expires_at']);
      if (DateTime.now().toUtc().isAfter(expiresAt)) return 'Kode OTP telah kedaluwarsa.';

      await supabase.from('otp_requests').delete().eq('email', realEmail);
      
      return null; // Sukses verifikasi! User belum didaftarkan.
    } catch (e) {
      return 'Gagal melakukan verifikasi: $e';
    }
  }

  // ==========================================
  // REGISTRASI PELANGGAN & KASIR (ANTI-JEBOL)
  // ==========================================
  static Future<String?> registerCustomer(String phone, String password, String name, String realEmail) async {
    try {
      final String fakeEmail = '$phone@sako.id';
      final response = await supabase.auth.signUp(
        email: fakeEmail,
        password: password,
        data: {
          'full_name': name,
          'role': 'customer',
          'phone_number': phone,
          'recovery_email': realEmail,
        },
      );
      // Validasi ekstra: Jika user null, berarti ada error di server Supabase
      if (response.user == null) return 'Database error saving new user';
      return null;
    } on AuthException catch (e) {
      return e.message; // Tangkap pesan asli dari Supabase
    } catch (e) {
      return 'Error tidak terduga: $e';
    }
  }

  static Future<String?> registerCashier(String phone, String password, String name, String realEmail) async {
    try {
      final String fakeEmail = '$phone@sako.id';
      final response = await supabase.auth.signUp(
        email: fakeEmail,
        password: password,
        data: {
          'full_name': name,
          'role': 'cashier',
          'phone_number': phone,
          'recovery_email': realEmail,
        },
      );
      if (response.user == null) return 'Database error saving new user';
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error tidak terduga: $e';
    }
  }

  // ==========================================
  // 4. LOGIKA LOGIN GLOBAL (WITH PRE-LOGIN CHECK)
  // ==========================================
  static Future<String?> login(String phone, String password) async {
    try {
      // 1. Tarik data profil berdasarkan nomor HP untuk validasi awal
      final profile = await supabase.from('profiles').select('recovery_email, role, branch_id').eq('phone_number', phone).maybeSingle();
      
      String emailToLogin = '$phone@sako.id';
      String? userRole;
      String? branchId;

      if (profile != null) {
        userRole = profile['role'];
        branchId = profile['branch_id'];
      }

      // 2. Validasi Pra-Login: Cegah kasir tanpa cabang atau cabang nonaktif masuk ke sistem
      if (userRole == 'cashier') {
        if (branchId == null) {
          return 'Akses ditolak. Anda belum ditugaskan ke cabang mana pun oleh Super Admin.';
        }

        // Cek status keaktifan cabang tempat kasir bertugas
        final branchDetails = await supabase.from('branches').select('is_active, name').eq('id', branchId).maybeSingle();

        if (branchDetails != null && branchDetails['is_active'] == false) {
          final branchName = branchDetails['name'] ?? 'Cabang Anda';
          return 'Akses ditolak. $branchName sedang dinonaktifkan oleh Super Admin.';
        }
      }

      // 3. Jalankan otentikasi jika semua syarat keamanan di atas terpenuhi
      await supabase.auth.signInWithPassword(email: emailToLogin, password: password);
      return null;

    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) return 'Nomor WhatsApp atau password salah.';
      if (e.message.contains('Email not confirmed')) return 'Akun Anda belum diverifikasi OTP.';
      return e.message;
    } catch (e) {
      return 'Gagal masuk. Silakan coba lagi.';
    }
  }

  // ==========================================
  // 5. LOGOUT
  // ==========================================
  static Future<void> logout() async {
    await supabase.auth.signOut();
  }
}