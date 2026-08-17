import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../logic/orders_history_provider.dart';
import 'pos_invoice_screen.dart'; 

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSearch = ref.read(ordersHistoryProvider).searchQuery;
      if (currentSearch.isNotEmpty) {
        _searchController.text = currentSearch;
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(ordersHistoryProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context, OrdersHistoryState state) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: state.startDate, end: state.endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryOrange, 
              onPrimary: Colors.white, 
              onSurface: AppColors.textDark, 
            ),
            dialogBackgroundColor: AppColors.surfaceWhite,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(ordersHistoryProvider.notifier).onDateRangeChanged(picked.start, picked.end);
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> order, bool isAdmin) async {
    final currentContext = context;
    showDialog(context: currentContext, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));

    try {
      final response = await Supabase.instance.client.from('order_items').select('quantity, price_at_time, products(name)').eq('order_id', order['id']);
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop();

      final cartItems = (response as List<dynamic>).map<Map<String, dynamic>>((item) {
        String productName = 'Produk Tidak Diketahui';
        if (item['products'] != null) {
          if (item['products'] is Map) productName = item['products']['name'] ?? productName;
          else if (item['products'] is List && item['products'].isNotEmpty) productName = item['products'][0]['name'] ?? productName;
        }
        return {'qty': item['quantity'] ?? 0, 'price': item['price_at_time'] ?? 0, 'name': productName};
      }).toList();

      Navigator.of(currentContext, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => PosInvoiceScreen(
            cartItems: cartItems,
            total: order['total_amount'] as int,
            paymentMethod: order['payment_method'] ?? 'cash',
            customerName: order['customer_name_snapshot'] ?? 'Umum',
            orderId: order['id'], 
            isAdmin: isAdmin,
            onOrderDeleted: () => ref.read(ordersHistoryProvider.notifier).refreshAfterDelete(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading
      
      showDialog(
        context: currentContext,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Gagal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18))),
            ],
          ),
          content: Text('Gagal memuat rincian nota: $e', style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersHistoryProvider);
    final userRole = ref.watch(userRoleProvider).value; 
    final isAdmin = userRole == 'super_admin';

    final strStartDate = DateFormat('dd MMM', 'id').format(state.startDate);
    final strEndDate = DateFormat('dd MMM', 'id').format(state.endDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: const Text('Riwayat Pesanan', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => ref.read(ordersHistoryProvider.notifier).onSearchChanged(val),
                    decoration: InputDecoration(
                      hintText: 'Cari Nota / Pelanggan...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: state.isSearching
                          ? const Padding(padding: EdgeInsets.all(14.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange)))
                          : null,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                if (_searchController.text.isEmpty)
                  InkWell(
                    onTap: () => _pickDateRange(context, state),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.primaryOrange, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '$strStartDate - $strEndDate',
                            style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: state.isInitialLoad && state.orders.isEmpty
          ? _buildSkeletonLoading() 
          : state.orders.isEmpty
              ? Center(child: Text(state.searchQuery.isEmpty ? 'Tidak ada pesanan di tanggal ini.' : 'Tidak ada pesanan ditemukan.', style: TextStyle(color: Colors.grey.shade500)))
              // PERBAIKAN: RefreshIndicator untuk loading saat drag ke bawah
              : RefreshIndicator(
                  color: AppColors.primaryOrange,
                  onRefresh: () async {
                    await ref.read(ordersHistoryProvider.notifier).refreshManual();
                  },
                  child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(), // Pastikan list selalu bisa di-scroll agar RefreshIndicator menyala
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: state.orders.length + (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == state.orders.length) {
                          return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
                        }

                        final order = state.orders[index];
                        final DateTime currentOrderDate = DateTime.parse(order['created_at']).toLocal();
                        
                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true; 
                        } else {
                          final previousOrder = state.orders[index - 1];
                          final DateTime previousOrderDate = DateTime.parse(previousOrder['created_at']).toLocal();
                          
                          if (currentOrderDate.day != previousOrderDate.day || currentOrderDate.month != previousOrderDate.month || currentOrderDate.year != previousOrderDate.year) {
                            showDateHeader = true;
                          }
                        }

                        final Widget orderCard = _buildOrderCard(order, isAdmin);

                        if (showDateHeader) {
                          String formattedDateHeader = DateFormat('EEEE, dd MMMM yyyy', 'id').format(currentOrderDate);
                          if (currentOrderDate.day == DateTime.now().day && currentOrderDate.month == DateTime.now().month && currentOrderDate.year == DateTime.now().year) {
                            formattedDateHeader = "Hari Ini";
                          }
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.history_toggle_off, color: Colors.grey, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      formattedDateHeader, 
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textDark)
                                    ),
                                  ],
                                ),
                              ),
                              orderCard,
                            ],
                          );
                        }

                        return orderCard;
                      },
                    ),
                ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isAdmin) {
    // KUNCI PENCARIAN NOTA: Menampilkan short_id jika ada, jika tidak fallback ke potongan ID panjang
    final String rawShortId = order['short_id'] ?? order['id'].toString().substring(0, 6);
    final String orderId = '#${rawShortId.toUpperCase()}';
    
    final String time = DateFormat('HH:mm').format(DateTime.parse(order['created_at']).toLocal()); 
    final String customerName = order['customer_name_snapshot'] ?? 'Pelanggan Umum';
    final String amount = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(order['total_amount'] as int);
    
    Color statusColor = Colors.grey;
    String statusText = 'Unknown';
    if (order['status'] == 'completed') { statusColor = Colors.green; statusText = 'Selesai'; } 
    else if (order['status'] == 'preparing') { statusColor = Colors.blue; statusText = 'Diproses'; }

    return GestureDetector(
      onTap: () => _openInvoice(order, isAdmin),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(orderId, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold))
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pukul $time', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange))
              ]
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 80, height: 20),
                  _shimmerBox(width: 60, height: 24, radius: 12),
                ],
              ),
              const SizedBox(height: 12),
              _shimmerBox(width: 120, height: 14),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _shimmerBox(width: 100, height: 16),
                  _shimmerBox(width: 80, height: 18),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({required double width, required double height, double radius = 4}) {
    return Container(width: width, height: height, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(radius)));
  }
}