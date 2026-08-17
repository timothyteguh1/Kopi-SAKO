import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. AMBIL DAFTAR PELANGGAN (Beserta nama dari tabel profiles)
  Future<List<Map<String, dynamic>>> getCustomers({String query = ''}) async {
    var queryBuilder = _supabase.from('customers').select('''
      id,
      points,
      profiles (
        full_name,
        phone_number,
        recovery_email
      )
    ''');

    // Jika ada pencarian nama atau nomor HP
    if (query.isNotEmpty) {
      queryBuilder = queryBuilder.or('profiles.full_name.ilike.%$query%,profiles.phone_number.ilike.%$query%');
    }

    final response = await queryBuilder.order('points', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. AMBIL RIWAYAT POIN PELANGGAN
  Future<List<Map<String, dynamic>>> getPointHistory(String customerId) async {
    final response = await _supabase
        .from('point_history')
        .select('''
          points_changed, 
          reason, 
          created_at, 
          profiles!point_history_changed_by_fkey(full_name)
        ''')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response);
  }

  // 3. EDIT NAMA PELANGGAN (Menggunakan Fungsi SQL Sakti)
  Future<void> updateCustomerName(String customerId, String newName) async {
    await _supabase.rpc('admin_update_customer_name', params: {
      'p_customer_id': customerId,
      'p_new_name': newName,
    });
  }

  // 4. EDIT POIN PELANGGAN (Menggunakan Fungsi SQL Sakti)
  Future<void> updateCustomerPoints({
    required String customerId, 
    required int newPoints, 
    required String adminId,
  }) async {
    await _supabase.rpc('admin_adjust_customer_points', params: {
      'p_customer_id': customerId,
      'p_new_points': newPoints,
      'p_admin_id': adminId,
    });
  }

  // 5. KIRIM LINK RESET PASSWORD
  Future<void> sendResetPasswordEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // 6. HAPUS PELANGGAN SECARA TUNTAS
  Future<void> deleteCustomer(String customerId) async {
    await _supabase.rpc('delete_customer_completely', params: {'customer_uuid': customerId});
  }
}

final customersRepositoryProvider = Provider((ref) => CustomersRepository());