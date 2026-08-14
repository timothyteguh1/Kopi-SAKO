import 'package:supabase_flutter/supabase_flutter.dart';

class DailySales {
  final int total;
  final int cash;
  final int nonCash;
  DailySales({required this.total, required this.cash, required this.nonCash});
}

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Ambil Penjualan (DIUBAH KE STREAM AGAR LIVE SECARA OTOMATIS)
  Stream<DailySales> getTodaySalesStream(String branchId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDay)
        .map((events) {
          int cashTotal = 0;
          int nonCashTotal = 0;

          for (var row in events) {
            final status = row['status'];
            // Jangan hitung pesanan yang batal atau belum dibayar
            if (status == 'waiting_payment' || status == 'cancelled') continue; 

            final amount = row['total_amount'] as int;
            final method = row['payment_method'] as String?;

            if (method == 'cash') {
              cashTotal += amount;
            } else if (method == 'qris' || method == 'transfer') {
              nonCashTotal += amount;
            }
          }
          return DailySales(total: cashTotal + nonCashTotal, cash: cashTotal, nonCash: nonCashTotal);
        });
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
            return status == 'waiting_payment' || status == 'preparing';
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

  // 5. Ambil Daftar Pesanan Selesai Hari Ini
  Stream<List<Map<String, dynamic>>> getCompletedOrdersStream(String branchId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDay)
        .eq('status', 'completed') 
        .order('created_at', ascending: false); 
  }
}