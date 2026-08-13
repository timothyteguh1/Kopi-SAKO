import 'package:supabase_flutter/supabase_flutter.dart';

class DailySales {
  final int total;
  final int cash;
  final int nonCash;
  DailySales({required this.total, required this.cash, required this.nonCash});
}

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Ambil Penjualan (Hanya untuk Cabang yang Aktif)
  Future<DailySales> getTodaySales(String branchId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final response = await _supabase
        .from('orders')
        .select('total_amount, payment_method, status')
        .eq('branch_id', branchId)
        .gte('created_at', startOfDay)
        .neq('status', 'waiting_payment'); 

    int cashTotal = 0;
    int nonCashTotal = 0;

    for (var row in response) {
      final amount = row['total_amount'] as int;
      final method = row['payment_method'] as String?;
      if (method == 'cash') {
        cashTotal += amount;
      } else if (method == 'qris' || method == 'transfer') {
        nonCashTotal += amount;
      }
    }
    return DailySales(total: cashTotal + nonCashTotal, cash: cashTotal, nonCash: nonCashTotal);
  }

  // 2. Ambil Antrean LIVE 
  Stream<List<Map<String, dynamic>>> getLiveOrdersStream(String branchId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDay)
        .order('created_at', ascending: true)
        .map((events) {
          return events.where((order) {
            final status = order['status'];
            return status == 'waiting_payment' || status == 'processing';
          }).toList();
        });
  }

  // 3. Ambil Daftar Semua Cabang (Khusus Super Admin)
  Future<List<Map<String, dynamic>>> getAllBranches() async {
    return await _supabase
        .from('branches')
        .select('id, name')
        .eq('status', 'open')
        .order('name');
  }

  // 4. Ambil ID Cabang Khusus Kasir dari tabel cashiers
  Future<String?> getCashierAssignedBranch(String userId) async {
    final response = await _supabase
        .from('cashiers')
        .select('assigned_branch_id')
        .eq('id', userId)
        .maybeSingle();
    return response?['assigned_branch_id'] as String?;
  }
}