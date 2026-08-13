import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/logic/auth_provider.dart';
import '../logic/stock_provider.dart';

import 'widgets/add_product_modal.dart';
import 'widgets/edit_stock_modal.dart';
import 'widgets/stock_history_modal.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(branchStockProvider);
    final userRole = ref.watch(userRoleProvider).value;
    final isAdmin = userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () {
            ref.read(stockSearchQueryProvider.notifier).state = '';
            Navigator.pop(context);
          },
        ),
        title: const Text('Stok Bahan & Menu', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.primaryOrange),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => const AddProductModal(),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) => ref.read(stockSearchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: 'Cari nama barang atau menu...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primaryOrange,
        onRefresh: () async {
          ref.invalidate(branchStockProvider);
          return ref.read(branchStockProvider.future);
        },
        child: stockAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (products) {
            if (products.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('Belum ada data barang.')),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final isForSale = product['is_for_sale'] == true;
                final currentStock = product['current_stock'] as int;
                final isLowStock = currentStock <= 10;
                
                // Ambil URL gambar dari database
                final imageUrl = product['image_url'];

                return GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => StockHistoryModal(productId: product['id'], productName: product['name']),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isLowStock ? Colors.red.shade200 : Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        // --- AREA GAMBAR / IKON (Sudah Diperbarui) ---
                        Container(
                          height: 56, // Dibuat ukuran pasti agar rapi
                          width: 56,
                          decoration: BoxDecoration(
                            color: isForSale ? AppColors.primaryOrange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    // errorBuilder: Jika gambar gagal dimuat, kembali ke ikon bawaan
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      isForSale ? Icons.coffee : Icons.kitchen,
                                      color: isForSale ? AppColors.primaryOrange : Colors.blue,
                                    ),
                                  ),
                                )
                              : Icon(
                                  isForSale ? Icons.coffee : Icons.kitchen,
                                  color: isForSale ? AppColors.primaryOrange : Colors.blue,
                                ),
                        ),
                        // ---------------------------------------------
                        
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(isForSale ? 'Harga Jual: ${formatRupiah(product['price'])}' : 'Harga Modal: ${formatRupiah(product['cost_price'])}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$currentStock', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isLowStock ? Colors.red : AppColors.textDark)),
                            Text('Tersedia', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                          ],
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.edit_square, color: Colors.grey, size: 20),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => EditStockModal(product: product),
                              );
                            },
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}