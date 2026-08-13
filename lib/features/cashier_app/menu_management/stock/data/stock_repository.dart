import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProductsWithStock(
    String branchId,
  ) async {
    final productsResponse = await _supabase
        .from('products')
        .select('*')
        .eq('is_active', true)
        .order('name');
    final stocksResponse = await _supabase
        .from('branch_stocks')
        .select('product_id, quantity')
        .eq('branch_id', branchId);

    final List<Map<String, dynamic>> combinedList = [];
    for (var product in productsResponse) {
      final stockData = stocksResponse.firstWhere(
        (stock) => stock['product_id'] == product['id'],
        orElse: () => {'quantity': 0},
      );
      combinedList.add({...product, 'current_stock': stockData['quantity']});
    }
    return combinedList;
  }

  // UPLOAD GAMBAR (SUDAH DIPERBAIKI ANTI-ERROR INVALID KEY)
  Future<String?> uploadProductImage(String fileName, Uint8List fileBytes) async {
    try {
      // 1. Ambil ekstensinya saja (misal: "png" dari "gambar ku yang aneh.png")
      final String extension = fileName.split('.').last;
      
      // 2. Buat nama file baru yang 100% aman (Hanya angka dan titik)
      final String safePath = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      
      // 3. Upload menggunakan nama file yang sudah aman
      await _supabase.storage.from('menu_images').uploadBinary(safePath, fileBytes);
      
      return _supabase.storage.from('menu_images').getPublicUrl(safePath);
    } catch (e) {
      throw Exception('Gagal upload gambar: $e');
    }
  }

  Future<void> addProduct({
    required String name,
    required int price,
    required int costPrice,
    required bool isForSale,
    String? imageUrl,
  }) async {
    await _supabase.from('products').insert({
      'name': name,
      'price': price,
      'cost_price': costPrice,
      'is_for_sale': isForSale,
      'is_active': true,
      'image_url': imageUrl,
    });
  }

  Future<void> updateProductAndStock({
    required String productId,
    required String branchId,
    required String userId,
    required String name,
    required int price,
    required int costPrice,
    required int stockChange,
    required String movementType,
    required String reason,
    String? imageUrl, // Menerima URL gambar baru jika ada
  }) async {
    // 1. Update produk
    final Map<String, dynamic> updateData = {
      'name': name,
      'price': price,
      'cost_price': costPrice,
    };
    if (imageUrl != null)
      updateData['image_url'] =
          imageUrl; // Hanya update gambar jika Admin menggantinya

    await _supabase.from('products').update(updateData).eq('id', productId);

    // 2. Update Stok via RPC
    final qtyMagnitude = stockChange.abs();
    if (qtyMagnitude > 0) {
      try {
        await _supabase.rpc(
          'adjust_stock',
          params: {
            'p_branch_id': branchId,
            'p_product_id': productId,
            'p_user_id': userId,
            'p_quantity_changed': qtyMagnitude,
            'p_movement_type': movementType,
            'p_reason': reason,
          },
        );
      } on PostgrestException catch (e) {
        throw Exception(
          e.message.contains('Stok tidak mencukupi')
              ? e.message
              : 'Gagal update stok: ${e.message}',
        );
      }
    }
  }

  Future<void> deleteProduct(String productId) async {
    await _supabase
        .from('products')
        .update({'is_active': false})
        .eq('id', productId);
  }

  Future<List<Map<String, dynamic>>> getStockHistory(
    String branchId,
    String productId,
  ) async {
    return await _supabase
        .from('stock_movements')
        .select('*, profiles(full_name)')
        .eq('branch_id', branchId)
        .eq('product_id', productId)
        .order('created_at', ascending: false);
  }
}
