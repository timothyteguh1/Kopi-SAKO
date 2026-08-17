import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CashiersAdminRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getCashiers() async {
    // Mengambil semua staf (role cashier) beserta nama cabang tempat mereka ditugaskan
    final res = await _supabase.from('profiles')
        .select('id, full_name, phone_number, recovery_email, branch_id, branches(name)')
        .eq('role', 'cashier')
        .order('full_name');
    return List<Map<String, dynamic>>.from(res);
  }

  // FUNGSI ACC / ASSIGN CABANG
  Future<void> assignBranch(String cashierId, String? branchId) async {
    await _supabase.from('profiles').update({'branch_id': branchId}).eq('id', cashierId);
  }

  Future<void> resetPassword(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> deleteCashier(String cashierId) async {
    // Menggunakan fungsi RPC yang sama dengan Hapus Pelanggan untuk menghapus akses Auth-nya
    await _supabase.rpc('delete_customer_completely', params: {'customer_uuid': cashierId});
  }
}

final cashiersAdminRepoProvider = Provider((ref) => CashiersAdminRepository());