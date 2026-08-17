import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PurchasesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getPurchasesHistory({
    String query = '', 
    int page = 0, 
    String branchId = '',
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final int limit = 15;
    final int start = page * limit;
    final int end = start + limit - 1;

    var queryBuilder = _supabase.from('purchases').select().eq('branch_id', branchId);

    if (query.isNotEmpty) {
      queryBuilder = queryBuilder.ilike('supplier_name', '%$query%');
    } else {
      final startUtc = startDate.toUtc().toIso8601String();
      final endUtc = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toUtc().toIso8601String();
      queryBuilder = queryBuilder.gte('created_at', startUtc).lte('created_at', endUtc);
    }

    final response = await queryBuilder.order('created_at', ascending: false).range(start, end);
    return List<Map<String, dynamic>>.from(response);
  }

  // ==========================================================================
  // FUNGSI PERBAIKAN: Hapus Pembelian (Admin)
  // ==========================================================================
  Future<void> deletePurchase(String purchaseId) async {
    // 1. Hapus rincian barangnya terlebih dahulu secara eksplisit.
    // Ini memberi kesempatan pada Trigger Supabase untuk membaca data 
    // cabang (branch_id) di tabel induk sebelum induknya dilenyapkan.
    await _supabase.from('purchase_items').delete().eq('purchase_id', purchaseId);

    // 2. Setelah rincian terhapus dan stok cabang sukses dikurangi oleh Trigger,
    // barulah kita hancurkan nota induknya.
    await _supabase.from('purchases').delete().eq('id', purchaseId);
  }

  // ==========================================================================
  // FUNGSI BARU: Tambah Pembelian (Kulakan)
  // ==========================================================================
  Future<void> addPurchase({
    required String branchId,
    required String userId,
    required String supplierName,
    required int totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    // 1. Buat Nota Induk
    final purchaseResponse = await _supabase.from('purchases').insert({
      'branch_id': branchId,
      'user_id': userId,
      'supplier_name': supplierName,
      'total_amount': totalAmount,
    }).select('id').single();

    final String newPurchaseId = purchaseResponse['id'];

    // 2. Siapkan data rincian barang untuk dimasukkan secara massal (bulk insert)
    final List<Map<String, dynamic>> itemsToInsert = items.map((item) {
      return {
        'purchase_id': newPurchaseId,
        'product_id': item['product_id'],
        'quantity': item['qty'],
        'cost_per_unit': item['cost'],
      };
    }).toList();

    // 3. Masukkan rincian barang.
    // SETELAH INI BERHASIL, TRIGGER SUPABASE AKAN OTOMATIS MENAMBAH STOK FISIK!
    await _supabase.from('purchase_items').insert(itemsToInsert);
  }
}

final purchasesRepositoryProvider = Provider((ref) => PurchasesRepository());