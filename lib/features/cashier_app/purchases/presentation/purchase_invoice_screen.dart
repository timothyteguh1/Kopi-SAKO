import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/pop_up_helper.dart';
import '../data/purchases_repository.dart';

// 1. PERBAIKAN: Ubah menjadi ConsumerStatefulWidget agar bisa mengakses Repository
class PurchaseInvoiceScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> items;
  final int total;
  final String supplierName;
  final String? purchaseId;
  final bool isAdmin;
  final VoidCallback? onDeleted;

  const PurchaseInvoiceScreen({
    super.key,
    required this.items,
    required this.total,
    required this.supplierName,
    this.purchaseId,
    this.isAdmin = false,
    this.onDeleted,
  });

  @override
  ConsumerState<PurchaseInvoiceScreen> createState() => _PurchaseInvoiceScreenState();
}

class _PurchaseInvoiceScreenState extends ConsumerState<PurchaseInvoiceScreen> {
  Future<void> _executeAdminDelete() async {
    final currentContext = context;
    
    // Konfirmasi penghapusan
    final bool? confirm = await showDialog<bool>(
      context: currentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Pembelian?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text('Tindakan ini tidak bisa dibatalkan. Stok barang yang masuk dari nota ini akan otomatis dikurangi kembali. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || widget.purchaseId == null || !mounted) return;

    // Loading overlay
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      // 2. KUNCI PERBAIKAN FINAL: Gunakan Repository yang sudah dilengkapi logika "Hapus Anak Dulu, Baru Induk"
      await ref.read(purchasesRepositoryProvider).deletePurchase(widget.purchaseId!);

      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading

      await showSakoPopUp(
        currentContext, 
        title: 'Berhasil', 
        message: 'Nota pembelian terhapus. Stok barang telah dikurangi otomatis.', 
        isError: false
      );

      if (mounted) {
        if (widget.onDeleted != null) widget.onDeleted!();
        Navigator.of(currentContext).pop(); 
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading
      showSakoPopUp(currentContext, title: 'Gagal', message: e.toString(), isError: true);
    }
  }

  String formatRupiah(int number) => NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  String get _todayDate => DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    const colorRedExpense = Color(0xFFD32F2F); 
    const colorCreamBg = Color(0xFFFDFBF7);
    const colorTextBrown = Color(0xFF4A3B32);
    const colorDivider = Color(0xFFEBE6D9);

    return Scaffold(
      backgroundColor: colorCreamBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: colorRedExpense.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long, color: colorRedExpense, size: 80),
                  ),
                  const SizedBox(height: 24),
                  const Text('Nota Pembelian', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: colorTextBrown)),
                  const SizedBox(height: 8),
                  Text('Rincian pengeluaran kas cabang', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 32),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorDivider, width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 10))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_todayDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            const Text('LUNAS', style: TextStyle(color: colorRedExpense, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Supplier: ${widget.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold, color: colorTextBrown, fontSize: 14)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: colorDivider, thickness: 1.5),
                        ),

                        // DAFTAR ITEM BELANJA
                        ...widget.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['qty']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: colorTextBrown)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(item['name'], style: const TextStyle(color: colorTextBrown))),
                                Text(formatRupiah(item['price'] * item['qty']), style: const TextStyle(fontWeight: FontWeight.w600, color: colorTextBrown)),
                              ],
                            ),
                          ),
                        ),

                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 16),
                          child: Divider(color: colorDivider, thickness: 1.5),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Keluar', style: TextStyle(fontWeight: FontWeight.bold, color: colorTextBrown, fontSize: 16)),
                            Text('- ${formatRupiah(widget.total)}', style: const TextStyle(fontWeight: FontWeight.w900, color: colorRedExpense, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.textDark, // Warna netral gelap
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            label: const Text('Tutup Nota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        
                        if (widget.isAdmin && widget.purchaseId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.red.shade50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                label: const Text('Hapus Pembelian (Admin)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                onPressed: _executeAdminDelete,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}