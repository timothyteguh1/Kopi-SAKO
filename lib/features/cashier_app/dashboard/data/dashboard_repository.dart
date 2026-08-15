import 'package:supabase_flutter/supabase_flutter.dart';

class DailySales {
  final int total;
  final int cash;
  final int nonCash;
  DailySales({required this.total, required this.cash, required this.nonCash});
}

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Helper untuk mendapatkan awal hari waktu lokal yang dikonversi ke format UTC ISO String
  String _getStartOfDayUtcIso() {
    final now = DateTime.now();
    // Jam 00:00:00 waktu lokal (WIB)
    final localStartOfDay = DateTime(now.year, now.month, now.day);
    // Dikonversi ke UTC string (contoh: 00:00 WIB -> 17:00 UTC hari sebelumnya)
    return localStartOfDay.toUtc().toIso8601String();
  }

  // 1. Ambil Penjualan (Live Stream)
  Stream<DailySales> getTodaySalesStream(String branchId) {
    final startOfDayUtc = _getStartOfDayUtcIso();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDayUtc)
        .map((events) {
          int cashTotal = 0;
          int nonCashTotal = 0;

          for (var row in events) {
            final status = row['status'];
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
    final startOfDayUtc = _getStartOfDayUtcIso();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDayUtc)
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
    final startOfDayUtc = _getStartOfDayUtcIso();

    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .gte('created_at', startOfDayUtc)
        .eq('status', 'completed') 
        .order('created_at', ascending: false); 
  }
  
  // ---------------------------------------------------------
  // TAMBAHAN UNTUK HALAMAN RIWAYAT PESANAN (SEARCH & PAGINATION & DATES)
  // ---------------------------------------------------------
  
  // Fungsi Tarik Riwayat (dengan Paginasi, Pencarian, & Filter Tanggal)
  Future<List<Map<String, dynamic>>> getOrdersHistory({
    String query = '', 
    int page = 0, 
    String branchId = '',
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final int limit = 15; // Tarik 15 data per halaman
    final int start = page * limit;
    final int end = start + limit - 1;

    // 1. Mulai dengan filter dasar cabang
    var queryBuilder = _supabase
        .from('orders')
        .select()
        .eq('branch_id', branchId);

    // 2. Terapkan filter pencarian atau tanggal
    // 2. Terapkan filter pencarian atau tanggal
    if (query.isNotEmpty) {
      // PERBAIKAN: Fokus mencari dari Nama Pelanggan saja untuk menghindari bentrok UUID.
      queryBuilder = queryBuilder.ilike('customer_name_snapshot', '%$query%');
    } else {
      // Jika tidak ada pencarian, gunakan rentang tanggal
      final startUtc = startDate.toUtc().toIso8601String();
      // Set end date ke jam 23:59:59 agar meng-cover seluruh hari terakhir pilihan
      final endUtc = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toUtc().toIso8601String();
      
      queryBuilder = queryBuilder.gte('created_at', startUtc).lte('created_at', endUtc);
    }

    // 3. Eksekusi pengurutan (.order) dan paginasi (.range) di tahap paling akhir!
    final response = await queryBuilder
        .order('created_at', ascending: false)
        .range(start, end);

    return List<Map<String, dynamic>>.from(response);
  }

  // Fungsi Super Admin: Hapus Pesanan Secara Paksa
  Future<void> deleteOrder(String orderId) async {
    // Karena kita sudah pasang ON DELETE CASCADE dan TRIGGER di Supabase,
    // kita hanya perlu menghapus induknya saja. Stok dan poin akan otomatis kembali!
    await _supabase.from('orders').delete().eq('id', orderId);
  }
}