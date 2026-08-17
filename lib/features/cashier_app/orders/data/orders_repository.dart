import 'package:supabase_flutter/supabase_flutter.dart';

class OrdersRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    var request = _supabase.from('profiles').select('*, customers(points)').eq('role', 'customer');
    if (query.isNotEmpty) {
      request = request.or('full_name.ilike.%$query%,phone_number.ilike.%$query%');
    }
    final response = await request.limit(20).order('full_name');
    return response.map((e) {
      final points = (e['customers'] != null) ? e['customers']['points'] ?? 0 : 0;
      return {...e, 'points': points};
    }).toList();
  }

  Future<Map<String, dynamic>> registerNewCustomer(String name, String phone) async {
    try {
      final newUserId = await _supabase.rpc('register_customer_by_cashier', params: {
        'p_full_name': name, 'p_phone_number': phone,
      });
      return {
        'id': newUserId,
        'full_name': name,
        'phone_number': phone,
        'points': 0,
        'is_guest': false,
      };
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Nomor HP ini sudah terdaftar.');
      throw Exception('Gagal mendaftarkan pelanggan: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> getBranchInfo(String branchId) async {
    return await _supabase.from('branches').select().eq('id', branchId).single();
  }

  Future<List<Map<String, dynamic>>> getActiveMenuWithStock(String branchId) async {
    final products = await _supabase.from('products').select('*').eq('is_active', true).eq('is_for_sale', true).order('name');
    final stocks = await _supabase.from('branch_stocks').select('product_id, quantity').eq('branch_id', branchId);

    final List<Map<String, dynamic>> menuList = [];
    for (var product in products) {
      final stockData = stocks.firstWhere((s) => s['product_id'] == product['id'], orElse: () => {'quantity': 0});
      menuList.add({...product, 'current_stock': stockData['quantity']});
    }
    return menuList;
  }

  Future<Map<String, dynamic>> checkoutOrder({
    required String branchId, required String cashierId, required Map<String, dynamic>? selectedCustomer,
    required String paymentMethod, required int estimatedTime, required List<Map<String, dynamic>> cartItems, required int totalAmount,
  }) async {
    final customerId = selectedCustomer?['id'];
    final customerName = selectedCustomer?['full_name'] ?? 'Pelanggan Umum';
    final customerPhone = selectedCustomer?['phone_number'] ?? '-';

    final order = await _supabase.from('orders').insert({
      'branch_id': branchId, 'customer_id': customerId, 'customer_name_snapshot': customerName,
      'customer_phone_snapshot': customerPhone, 'total_amount': totalAmount,
      'payment_method': paymentMethod, 'estimated_prep_time': estimatedTime, 'status': 'preparing',
    }).select().single();

    final orderId = order['id'];

    for (var item in cartItems) {
      final qty = item['qty'] as int;
      await _supabase.from('order_items').insert({'order_id': orderId, 'product_id': item['id'], 'quantity': qty, 'price_at_time': item['price']});
      await _supabase.rpc('adjust_stock', params: {'p_branch_id': branchId, 'p_product_id': item['id'], 'p_user_id': cashierId, 'p_quantity_changed': qty, 'p_movement_type': 'sold', 'p_reason': 'Penjualan POS: $orderId'});
    }

    if (customerId != null) {
      final int pointsEarned = (totalAmount / 10000).floor();
      if (pointsEarned > 0) {
        await _supabase.from('point_history').insert({'customer_id': customerId, 'changed_by': cashierId, 'points_changed': pointsEarned, 'reason': 'Pembelian POS'});
      }
    }
    return order; 
  }

  Future<void> processPayment({
    required String? customerId,
    required String branchId,
    required int totalAmount,
    required String paymentMethod,
    required int estimatedTime,
    required List<Map<String, dynamic>> cartItems,
  }) async {
    try {
      final String cashierId = _supabase.auth.currentUser!.id;

      final List<Map<String, dynamic>> itemsPayload = cartItems.map((item) {
        return {
          'product_id': item['id'],
          'quantity': item['qty'],
          'price_at_time': item['price'],
        };
      }).toList();

      await _supabase.rpc('process_pos_transaction', params: {
        'p_customer_id': customerId,
        'p_branch_id': branchId,
        'p_cashier_id': cashierId,
        'p_total_amount': totalAmount,
        'p_payment_method': paymentMethod,
        'p_estimated_prep_time': estimatedTime,
        'p_items': itemsPayload,
      });

    } catch (e) {
      throw Exception('Gagal memproses pembayaran: $e');
    }
  }

  // =====================================================================
  // FUNGSI BARU: Tarik Riwayat Pesanan dengan Pencarian Resi/Nama (short_id)
  // =====================================================================
  Future<List<Map<String, dynamic>>> getOrdersHistory({
    String query = '', 
    required String branchId,
  }) async {
    var queryBuilder = _supabase.from('orders').select('''
      *,
      order_items (
        quantity,
        price_at_time,
        products (name)
      )
    ''').eq('branch_id', branchId);

    // KUNCI PERBAIKAN PENCARIAN NOMOR NOTA: Mencari di short_id atau nama snapshot
    if (query.isNotEmpty) {
      queryBuilder = queryBuilder.or('short_id.ilike.%$query%,customer_name_snapshot.ilike.%$query%');
    }

    final response = await queryBuilder.order('created_at', ascending: false).limit(30);
    return List<Map<String, dynamic>>.from(response);
  }
}