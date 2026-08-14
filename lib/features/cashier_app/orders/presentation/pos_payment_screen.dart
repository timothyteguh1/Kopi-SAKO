import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'pos_invoice_screen.dart';
import 'package:kopi_sako/features/cashier_app/dashboard/logic/dashboard_provider.dart';
import '../logic/orders_provider.dart';

class PosPaymentScreen extends ConsumerStatefulWidget {
  const PosPaymentScreen({super.key});

  @override
  ConsumerState<PosPaymentScreen> createState() => _PosPaymentScreenState();
}

class _PosPaymentScreenState extends ConsumerState<PosPaymentScreen> {
  String _selectedPaymentMethod = 'cash'; 
  bool _isLoading = false;

  String formatRupiah(int number) => NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  String get _todayDate => DateFormat('dd MMM yyyy').format(DateTime.now());

  // FUNGSI UTAMA: Menampilkan Modal Timer & Eksekusi Database
  void _showTimerModalAndProcess() {
    final timerCtrl = TextEditingController(text: "1"); // Default 15 Menit

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Estimasi Waktu', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4A3B32)), textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Berapa menit waktu persiapan pesanan ini?', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: timerCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF007A4D)),
              decoration: InputDecoration(
                suffixText: ' Menit',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007A4D),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              int minutes = int.tryParse(timerCtrl.text) ?? 15;
              Navigator.pop(ctx); // Tutup modal timer
              _executePaymentToDatabase(minutes); // Mulai tembak ke Database!
            },
            child: const Text('Proses Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // FUNGSI LOGIKA DATABASE
  Future<void> _executePaymentToDatabase(int estimatedTime) async {
    setState(() => _isLoading = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    try {
      final customer = ref.read(selectedCustomerProvider);
      final branchId = ref.read(activeBranchIdProvider);
      final cart = ref.read(cartProvider);
      final total = ref.read(cartProvider.notifier).totalAmount;

      // 1. Simpan salinan data untuk ditampilkan di Nota
      // (Karena setelah ini data keranjang di Provider akan kita hapus)
      final savedCart = List<Map<String, dynamic>>.from(cart);
      final savedTotal = total;
      final savedCustomerName = customer?['is_guest'] == true ? 'Walk-in (Umum)' : (customer?['full_name'] ?? 'Walk-in (Umum)');
      final savedPaymentMethod = _selectedPaymentMethod;

      // 2. Eksekusi Logika ke Supabase
      await ref.read(ordersRepositoryProvider).processPayment(
        customerId: customer?['is_guest'] == true ? null : customer?['id'], 
        branchId: branchId!,
        totalAmount: total,
        paymentMethod: _selectedPaymentMethod, 
        estimatedTime: estimatedTime,
        cartItems: cart,
      );

      // 3. Bersihkan Keranjang setelah sukses
      ref.read(cartProvider.notifier).clearCart();
      ref.read(selectedCustomerProvider.notifier).state = null;

      // 4. MENGARAHKAN KE HALAMAN NOTA (BUKAN LANGSUNG KE DASHBOARD)
      // Hapus riwayat layar sebelumnya, sisakan Dashboard sebagai rute terbawah, lalu tumpuk dengan Nota.
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => PosInvoiceScreen(
            cartItems: savedCart,
            total: savedTotal,
            paymentMethod: savedPaymentMethod,
            customerName: savedCustomerName,
          ),
        ),
        (route) => route.isFirst,
      );

    } catch (e) {
      setState(() => _isLoading = false);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(selectedCustomerProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    
    if (customer == null) return const Scaffold();

    const colorJagoGreen = Color(0xFF007A4D);
    const colorCreamBg = Color(0xFFFDFBF7);
    const colorTextBrown = Color(0xFF4A3B32);
    const colorDivider = Color(0xFFEBE6D9);

    final String customerName = customer['is_guest'] == true ? 'Walk-in (Umum)' : customer['full_name'];

    return Scaffold(
      backgroundColor: colorCreamBg,
      appBar: AppBar(
        backgroundColor: colorCreamBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextBrown),
        title: const Text('Pembayaran', style: TextStyle(fontWeight: FontWeight.w900, color: colorTextBrown, fontSize: 18)),
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
                    // 1. INFO TRANSAKSI
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: colorDivider, width: 1.5)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tanggal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)), Text(_todayDate, style: const TextStyle(fontWeight: FontWeight.w900, color: colorTextBrown))]),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: colorDivider, height: 1)),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Pelanggan', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                            Row(children: [const Icon(Icons.person, size: 16, color: colorJagoGreen), const SizedBox(width: 6), Text(customerName, style: const TextStyle(fontWeight: FontWeight.w900, color: colorTextBrown))]),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 2. TOMBOL PROMO
                    const Text('Promo & Diskon', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorTextBrown)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur Promo masih dalam pengembangan (On Progress)'))),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
                        child: Row(children: [Icon(Icons.local_offer, color: Colors.grey.shade400), const SizedBox(width: 12), Text('Gunakan Promo / Poin (Coming Soon)', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade500)), const Spacer(), Icon(Icons.chevron_right, color: Colors.grey.shade400)]),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 3. METODE PEMBAYARAN
                    const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorTextBrown)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPaymentMethodCard(id: 'cash', icon: Icons.payments, label: 'Tunai'),
                        const SizedBox(width: 12),
                        _buildPaymentMethodCard(id: 'qris', icon: Icons.qr_code_scanner, label: 'QRIS (Non-Tunai)'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildPaymentMethodCard(id: 'transfer', icon: Icons.account_balance, label: 'Transfer (Non-Tunai)'),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()), 
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. BOTTOM BAR
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: colorDivider, width: 1.5))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), Text(formatRupiah(cartNotifier.totalAmount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorTextBrown))]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 60, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: colorJagoGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 0),
                      onPressed: _isLoading ? null : _showTimerModalAndProcess, // PANGGIL MODAL TIMER
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : const Text('Selesaikan Pembayaran', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({required String id, required IconData icon, required String label}) {
    final bool isSelected = _selectedPaymentMethod == id;
    const colorJagoGreen = Color(0xFF007A4D);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? colorJagoGreen.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? colorJagoGreen : const Color(0xFFEBE6D9), width: isSelected ? 2 : 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? colorJagoGreen : Colors.grey, size: 32),
              const SizedBox(height: 12),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600, color: isSelected ? colorJagoGreen : Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}