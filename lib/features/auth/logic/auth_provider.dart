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
  // 1. ALUR PENDAFTARAN CUSTOMER (Langsung Login)
  // ==========================================
  static Future<String?> registerCustomer(String phone, String password, String fullName, String realEmail) async {
    try {
      // Customer langsung didaftarkan menggunakan email asli
      final response = await supabase.auth.signUp(
        email: realEmail,
        password: password,
        data: {
          'full_name': fullName, 
          'phone_number': phone,
          'recovery_email': realEmail,
          'requested_role': 'customer', 
        } 
      );
      
      if (response.session != null) {
        // Karena Customer tidak butuh OTP, kita langsung SULAP emailnya saat itu juga
        final dummyEmail = '$phone@sako.id';
        await supabase.auth.updateUser(UserAttributes(email: dummyEmail));
        // Customer tidak di-logout, biarkan mereka langsung masuk ke aplikasi
      }

      return null; 
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) return 'Email atau Nomor WhatsApp ini sudah terdaftar.';
      return e.message; 
    } catch (e) {
      return 'Terjadi kesalahan sistem. Pastikan internet Anda stabil.';
    }
  }

  // ==========================================
  // 2. ALUR PENDAFTARAN KASIR (Butuh OTP & ACC)
  // ==========================================
  static Future<String?> sendRegisterOtp(String realEmail, String password, String fullName, String phone) async {
    try {
      await supabase.auth.signUp(
        email: realEmail,
        password: password,
        data: {
          'full_name': fullName, 
          'phone_number': phone,
          'recovery_email': realEmail,
          'requested_role': 'cashier', 
        } 
      );
      return null; 
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) return 'Email atau Nomor WhatsApp ini sudah terdaftar.';
      return e.message; 
    } catch (e) {
      return 'Terjadi kesalahan sistem. Pastikan internet Anda stabil.';
    }
  }

  static Future<String?> verifyOtpAndFinalize(String realEmail, String otp, String phone) async {
    try {
      final response = await supabase.auth.verifyOTP(type: OtpType.signup, email: realEmail, token: otp);
      
      if (response.session != null) {
        // SULAP IDENTITAS: Tukar email menjadi nomor HP
        final dummyEmail = '$phone@sako.id';
        await supabase.auth.updateUser(UserAttributes(email: dummyEmail));
        
        // Logout paksa agar kasir nunggu ACC
        await supabase.auth.signOut();
        return null;
      }
      return 'Gagal memverifikasi sesi.';
    } on AuthException catch (_) {
      return 'Kode OTP salah atau sudah kedaluwarsa.';
    } catch (e) {
      return 'Terjadi kesalahan sistem saat verifikasi.';
    }
  }

  // ==========================================
  // 3. LOGIKA LOGIN GLOBAL
  // ==========================================
  static Future<String?> login(String phone, String password) async {
    try {
      // 1. Tarik data profil berdasarkan nomor HP
      final profile = await supabase.from('profiles').select('recovery_email, role, branch_id').eq('phone_number', phone).maybeSingle();
      
      String emailToLogin = '$phone@sako.id'; 
      String? userRole;
      String? branchId;

      if (profile != null) {
        if (profile['recovery_email'] != null) emailToLogin = profile['recovery_email'];
        userRole = profile['role'];
        branchId = profile['branch_id'];
      }

      // 2. KUNCI PERBAIKAN: Validasi Pra-Login untuk Kasir
      // Kita tolak aksesnya di pintu depan agar layar tidak berkedip ke Dashboard
      if (userRole == 'cashier') {
        if (branchId == null) {
          return 'Akses ditolak. Anda belum ditugaskan ke cabang mana pun oleh Super Admin.';
        }

        // Cek nyawa cabang tempat kasir bertugas
        final branchDetails = await supabase.from('branches').select('is_active, name').eq('id', branchId).maybeSingle();

        if (branchDetails != null && branchDetails['is_active'] == false) {
          final branchName = branchDetails['name'] ?? 'Cabang Anda';
          return 'Akses ditolak. $branchName sedang dinonaktifkan oleh Super Admin.';
        }
      }

      // 3. Jika semua validasi lolos, barulah eksekusi autentikasi sesungguhnya
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

  static Future<void> logout() async {
    await supabase.auth.signOut();
  }
}