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
  // Ditambahkan parameter opsional requestedRole (defaultnya customer)
  static Future<String?> register(String phone, String password, String fullName, String realEmail, {String requestedRole = 'customer'}) async {
    try {
      final dummyEmail = '$phone@sako.id'; 

      await supabase.auth.signUp(
        email: dummyEmail, 
        password: password,
        data: {
          'full_name': fullName, 
          'phone_number': phone,
          'recovery_email': realEmail,
          'requested_role': requestedRole, // <-- Mengirim bendera peran ke SQL
        } 
      );
      return null; 
    } on AuthException catch (e) {
      if (e.message.contains('already registered')) return 'Nomor WhatsApp ini sudah terdaftar.';
      return e.message; 
    } catch (e) {
      return 'Terjadi kesalahan sistem. Pastikan internet Anda stabil.';
    }
  }

  static Future<String?> login(String phone, String password) async {
    try {
      final dummyEmail = '$phone@sako.id'; 
      await supabase.auth.signInWithPassword(email: dummyEmail, password: password);
      return null;
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        return 'Nomor WhatsApp atau password salah.';
      }
      return e.message;
    } catch (e) {
      return 'Gagal masuk. Silakan coba lagi.';
    }
  }

  static Future<void> logout() async {
    await supabase.auth.signOut();
  }
}