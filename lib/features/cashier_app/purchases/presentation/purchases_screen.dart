import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../../../../shared/utils/pop_up_helper.dart';
import '../logic/purchases_provider.dart';
import 'purchase_invoice_screen.dart';
import 'add_purchase_screen.dart'; // Import layar tambah pengeluaran

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sinkronisasi teks pencarian jika kembali dari tab/layar lain
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentSearch = ref.read(purchasesProvider).searchQuery;
      if (currentSearch.isNotEmpty) {
        _searchController.text = currentSearch;
      }
    });

    // Sensor scroll untuk memuat data tambahan (Infinite Scroll)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(purchasesProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange(BuildContext context, PurchasesState state) async {
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
      ref.read(purchasesProvider.notifier).onDateRangeChanged(picked.start, picked.end);
    }
  }

  Future<void> _openInvoice(Map<String, dynamic> purchase, bool isAdmin) async {
    final currentContext = context;
    showDialog(
      context: currentContext, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
    );

    try {
      // Ambil rincian barang dari tabel purchase_items
      final response = await Supabase.instance.client
          .from('purchase_items')
          .select('quantity, cost_per_unit, products(name)')
          .eq('purchase_id', purchase['id']);
          
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading

      final items = (response as List<dynamic>).map<Map<String, dynamic>>((item) {
        String productName = 'Produk Tidak Diketahui';
        if (item['products'] != null) {
          if (item['products'] is Map) productName = item['products']['name'] ?? productName;
        }
        return {'qty': item['quantity'] ?? 0, 'price': item['cost_per_unit'] ?? 0, 'name': productName};
      }).toList();

      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => PurchaseInvoiceScreen(
            items: items,
            total: purchase['total_amount'] as int,
            supplierName: purchase['supplier_name'] ?? 'Toko/Supplier',
            purchaseId: purchase['id'], 
            isAdmin: isAdmin,
            onDeleted: () => ref.read(purchasesProvider.notifier).refreshAfterDelete(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading
      showSakoPopUp(currentContext, title: 'Gagal Membuka Nota', message: e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(purchasesProvider);
    final userRole = ref.watch(userRoleProvider).value; 
    final isAdmin = userRole == 'super_admin';

    final strStartDate = DateFormat('dd MMM', 'id').format(state.startDate);
    final strEndDate = DateFormat('dd MMM', 'id').format(state.endDate);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Riwayat Pembelian', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => ref.read(purchasesProvider.notifier).onSearchChanged(val),
                    decoration: InputDecoration(
                      hintText: 'Cari Nama Supplier...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      // Tampilkan spinner cerdas saat mencari
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
      
      // TOMBOL MENGAMBANG: CATAT PENGELUARAN
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPurchaseScreen()),
          );
        },
        backgroundColor: AppColors.textDark, // Warna hitam elegan
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Catat Belanja', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      // TAMPILAN KONTEN UTAMA
      body: state.isInitialLoad && state.purchases.isEmpty
          ? _buildSkeletonLoading() // Tampilkan skeleton saat muat awal (belum ada data)
          : state.purchases.isEmpty
              ? Center(child: Text(state.searchQuery.isEmpty ? 'Tidak ada pengeluaran di tanggal ini.' : 'Tidak ada supplier ditemukan.', style: TextStyle(color: Colors.grey.shade500)))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Padding bawah dilebihkan agar tidak tertutup tombol mengambang
                  itemCount: state.purchases.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Indikator loading tambahan di bawah saat scroll mentok
                    if (index == state.purchases.length) {
                      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
                    }

                    final purchase = state.purchases[index];
                    final DateTime currentPurchaseDate = DateTime.parse(purchase['created_at']).toLocal();
                    
                    // Logika pengelompokan hari
                    bool showDateHeader = false;
                    if (index == 0) {
                      showDateHeader = true; 
                    } else {
                      final previousPurchase = state.purchases[index - 1];
                      final DateTime previousPurchaseDate = DateTime.parse(previousPurchase['created_at']).toLocal();
                      
                      if (currentPurchaseDate.day != previousPurchaseDate.day || currentPurchaseDate.month != previousPurchaseDate.month || currentPurchaseDate.year != previousPurchaseDate.year) {
                        showDateHeader = true;
                      }
                    }

                    final Widget purchaseCard = _buildPurchaseCard(purchase, isAdmin);

                    // Menyisipkan header tanggal di antara daftar kartu
                    if (showDateHeader) {
                      String formattedDateHeader = DateFormat('EEEE, dd MMMM yyyy', 'id').format(currentPurchaseDate);
                      if (currentPurchaseDate.day == DateTime.now().day && currentPurchaseDate.month == DateTime.now().month && currentPurchaseDate.year == DateTime.now().year) {
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
                          purchaseCard,
                        ],
                      );
                    }

                    return purchaseCard;
                  },
                ),
    );
  }

  // Desain Kartu Riwayat Pembelian (Aksen Merah)
  Widget _buildPurchaseCard(Map<String, dynamic> purchase, bool isAdmin) {
    final String purchaseId = '#${purchase['id'].toString().substring(0, 6).toUpperCase()}';
    final String time = DateFormat('HH:mm').format(DateTime.parse(purchase['created_at']).toLocal()); 
    final String supplierName = purchase['supplier_name'] ?? 'Supplier';
    final String amount = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(purchase['total_amount'] as int);

    return GestureDetector(
      onTap: () => _openInvoice(purchase, isAdmin),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(purchaseId, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), 
                  child: const Text('Keluar', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Pukul $time', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                Text('- $amount', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red))
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
    return Container(
      width: width, 
      height: height, 
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(radius))
    );
  }
}