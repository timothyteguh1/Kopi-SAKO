import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/pop_up_helper.dart';
import '../../dashboard/logic/dashboard_provider.dart';
import '../../menu_management/stock/logic/stock_provider.dart';
import '../data/purchases_repository.dart';
import '../logic/purchases_provider.dart';

class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final TextEditingController _supplierCtrl = TextEditingController();
  bool _isLoading = false;

  // Struktur penyimpanan item sementara sebelum di-submit
  List<Map<String, dynamic>> _purchaseItems = [];

  void _addNewItemRow() {
    setState(() {
      _purchaseItems.add({
        'product_id': null,
        'qty': 1,
        'cost': 0,
      });
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      _purchaseItems.removeAt(index);
    });
  }

  int _calculateTotal() {
    int total = 0;
    for (var item in _purchaseItems) {
      final int qty = item['qty'] as int;
      final int cost = item['cost'] as int;
      total += (qty * cost);
    }
    return total;
  }

  Future<void> _submitPurchase() async {
    if (_supplierCtrl.text.isEmpty) {
      showSakoPopUp(context, title: 'Validasi', message: 'Nama Supplier wajib diisi.', isError: true);
      return;
    }

    if (_purchaseItems.isEmpty) {
      showSakoPopUp(context, title: 'Validasi', message: 'Masukkan minimal satu barang belanjaan.', isError: true);
      return;
    }

    // Validasi apakah ada item yang belum dipilih atau harganya nol
    for (var i = 0; i < _purchaseItems.length; i++) {
      final item = _purchaseItems[i];
      if (item['product_id'] == null) {
        showSakoPopUp(context, title: 'Validasi', message: 'Ada baris barang yang belum dipilih pada urutan ke-${i + 1}.', isError: true);
        return;
      }
      if (item['qty'] <= 0 || item['cost'] <= 0) {
        showSakoPopUp(context, title: 'Validasi', message: 'Jumlah dan Harga Modal harus lebih dari 0 pada baris ke-${i + 1}.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      final branchId = ref.read(activeBranchIdProvider);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final totalAmount = _calculateTotal();

      await ref.read(purchasesRepositoryProvider).addPurchase(
        branchId: branchId!,
        userId: userId!,
        supplierName: _supplierCtrl.text.trim(),
        totalAmount: totalAmount,
        items: _purchaseItems,
      );

      // Refresh data riwayat pembelian & stok barang agar UI terbaru
      ref.read(purchasesProvider.notifier).refreshAfterDelete();
      ref.invalidate(branchStockProvider);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading

      await showSakoPopUp(
        context, 
        title: 'Pembelian Berhasil', 
        message: 'Pengeluaran telah dicatat dan stok fisik otomatis bertambah!', 
        isError: false,
      );

      if (mounted) Navigator.pop(context); // Kembali ke halaman sebelumnya

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading
      showSakoPopUp(context, title: 'Gagal Menyimpan', message: e.toString(), isError: true);
      setState(() => _isLoading = false);
    }
  }

  String formatRupiah(int number) => NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(branchStockProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('Catat Pengeluaran Belanja', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900, fontSize: 18)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Informasi Supplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _supplierCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cth: Indogrosir, Pasar, atau Toko Kopi',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    const Text('Daftar Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),

                    // LIST BARANG YANG DITAMBAHKAN
                    ...List.generate(_purchaseItems.length, (index) {
                      final currentItem = _purchaseItems[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Barang #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () => _removeItemRow(index),
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // DROPDOWN PRODUK
                            stockAsync.when(
                              loading: () => const Center(child: LinearProgressIndicator(color: AppColors.primaryOrange)),
                              error: (e, s) => Text('Gagal memuat produk: $e'),
                              data: (products) {
                                return DropdownButtonFormField<String>(
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  hint: const Text('Pilih Produk / Bahan'),
                                  value: currentItem['product_id'],
                                  isExpanded: true,
                                  items: products.map((prod) {
                                    return DropdownMenuItem<String>(
                                      value: prod['id'],
                                      child: Text('${prod['name']} (Stok: ${prod['current_stock']})'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    // 1. KUNCI PERBAIKAN: Tarik Harga Modal saat produk dipilih
                                    final selectedProduct = products.firstWhere((p) => p['id'] == val);
                                    final int costPrice = selectedProduct['cost_price'] ?? 0;

                                    setState(() {
                                      _purchaseItems[index]['product_id'] = val;
                                      _purchaseItems[index]['cost'] = costPrice; // Autofill harga beli
                                    });
                                  },
                                );
                              }
                            ),
                            const SizedBox(height: 12),

                            // QUANTITY & COST PER UNIT
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: currentItem['qty'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Jumlah',
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                    onChanged: (val) => setState(() => _purchaseItems[index]['qty'] = int.tryParse(val) ?? 0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    // 2. KUNCI PERBAIKAN: Gunakan ValueKey agar TextField sadar produknya berubah
                                    key: ValueKey('cost_${index}_${currentItem['product_id']}'),
                                    initialValue: currentItem['cost'] == 0 ? '' : currentItem['cost'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Harga Beli Satuan (Rp)',
                                      filled: true,
                                      fillColor: Colors.grey.shade100,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                    onChanged: (val) => setState(() => _purchaseItems[index]['cost'] = int.tryParse(val) ?? 0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Subtotal: ${formatRupiah((currentItem['qty'] as int) * (currentItem['cost'] as int))}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            )
                          ],
                        ),
                      );
                    }),

                    // TOMBOL TAMBAH BARANG
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppColors.primaryOrange, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.add, color: AppColors.primaryOrange),
                        label: const Text('Tambah Barang Lain', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
                        onPressed: _addNewItemRow,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // AREA TOTAL DAN SIMPAN
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Pengeluaran', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                      Text(formatRupiah(_calculateTotal()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textDark, // Warna hitam untuk menandakan aksi penting
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _submitPurchase,
                      child: const Text('Simpan Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}