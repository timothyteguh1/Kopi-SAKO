import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// IMPORT RIVERPOD & PROVIDER KITA
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kopi_sako/features/cashier_app/dashboard/logic/dashboard_provider.dart';
import 'package:kopi_sako/features/cashier_app/dashboard/logic/printer_provider.dart';

// KUNCI PERBAIKAN: Ubah StatefulWidget menjadi ConsumerStatefulWidget
class PosInvoiceScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int total;
  final String paymentMethod;
  final String customerName;

  final String? orderId;
  final bool isAdmin;
  final VoidCallback? onOrderDeleted;

  const PosInvoiceScreen({
    super.key,
    required this.cartItems,
    required this.total,
    required this.paymentMethod,
    required this.customerName,
    this.orderId,
    this.isAdmin = false,
    this.onOrderDeleted,
  });

  @override
  ConsumerState<PosInvoiceScreen> createState() => _PosInvoiceScreenState();
}

// KUNCI PERBAIKAN: Ubah State menjadi ConsumerState
class _PosInvoiceScreenState extends ConsumerState<PosInvoiceScreen> {
  int _earnedPoints = 0;
  bool _isFetchingPoints = true;

  @override
  void initState() {
    super.initState();
    _calculatePoints();
  }

  Future<void> _calculatePoints() async {
    final isWalkIn = widget.customerName.toLowerCase().contains('umum');
    if (isWalkIn) {
      if (mounted) {
        setState(() {
          _earnedPoints = 0;
          _isFetchingPoints = false;
        });
      }
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('global_settings')
          .select('points_conversion_rate')
          .eq('id', 1)
          .single();

      final rate = data['points_conversion_rate'] as int;

      if (mounted) {
        setState(() {
          _earnedPoints = widget.total ~/ rate;
          _isFetchingPoints = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingPoints = false);
    }
  }

  void _showPopUp(
    BuildContext context,
    String title,
    String message, {
    bool isError = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF4A3B32), fontSize: 14),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65C00), 
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Mengerti',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAdminDelete() async {
    final currentContext = context;

    final bool? confirm = await showDialog<bool>(
      context: currentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Hapus Transaksi?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Tindakan ini tidak bisa dibatalkan. Stok barang akan otomatis dikembalikan ke cabang dan poin pelanggan akan dipotong. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ya, Hapus',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || widget.orderId == null || !mounted) return;

    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.red)),
    );

    try {
      await Supabase.instance.client
          .from('orders')
          .delete()
          .eq('id', widget.orderId!);

      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading

      await showDialog(
        context: currentContext,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Berhasil',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            'Transaksi terhapus. Stok & Poin telah disesuaikan otomatis.',
            style: TextStyle(color: Color(0xFF4A3B32)),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65C00),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Mengerti',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      if (mounted) {
        if (widget.onOrderDeleted != null) widget.onOrderDeleted!();
        Navigator.of(currentContext).pop();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(currentContext, rootNavigator: true).pop(); // Tutup loading
      _showPopUp(currentContext, 'Gagal', 'Gagal menghapus: $e', isError: true);
    }
  }

  String formatRupiah(int number) => NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(number);
  
  String get _todayDate =>
      DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    const colorJagoGreen = Color(0xFF007A4D);
    const colorCreamBg = Color(0xFFFDFBF7);
    const colorTextBrown = Color(0xFF4A3B32);
    const colorDivider = Color(0xFFEBE6D9);

    String methodLabel = 'Tunai';
    if (widget.paymentMethod == 'qris') methodLabel = 'QRIS';
    if (widget.paymentMethod == 'transfer') methodLabel = 'Transfer Bank';

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
                    decoration: BoxDecoration(
                      color: colorJagoGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: colorJagoGreen,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Pesanan Berhasil!',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: colorTextBrown,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Antrean sedang dipersiapkan',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),

                  if (!_isFetchingPoints && _earnedPoints > 0)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade100,
                                  Colors.orange.shade50,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.orange.shade300,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+$_earnedPoints Poin Didapatkan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.orange.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorDivider, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _todayDate,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              methodLabel,
                              style: const TextStyle(
                                color: colorJagoGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pelanggan: ${widget.customerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorTextBrown,
                            fontSize: 14,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(color: colorDivider, thickness: 1.5),
                        ),

                        ...widget.cartItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item['qty']}x',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorTextBrown,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['name'],
                                    style: const TextStyle(
                                      color: colorTextBrown,
                                    ),
                                  ),
                                ),
                                Text(
                                  formatRupiah(item['price'] * item['qty']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: colorTextBrown,
                                  ),
                                ),
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
                            const Text(
                              'Total Bayar',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorTextBrown,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              formatRupiah(widget.total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: colorTextBrown,
                                fontSize: 18,
                              ),
                            ),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: colorDivider,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.print,
                                  color: colorTextBrown,
                                ),
                                label: const Text(
                                  'Cetak Struk',
                                  style: TextStyle(
                                    color: colorTextBrown,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                // FUNGSI CETAK PRINTER SUDAH TERHUBUNG KE REF
                                onPressed: () async {
                                  final printerState = ref.read(printerProvider);
                                  final branchName = ref.read(activeBranchNameProvider);

                                  if (!printerState.isConnected) {
                                    _showPopUp(
                                      context,
                                      'Printer Putus',
                                      'Silakan sambungkan printer Bluetooth Anda melalui menu pengaturan terlebih dahulu.',
                                      isError: true,
                                    );
                                    return;
                                  }

                                  try {
                                    await ref.read(printerProvider.notifier).printReceipt(
                                          branchName: branchName, 
                                          cartItems: widget.cartItems,
                                          total: widget.total,
                                          paymentMethod: widget.paymentMethod,
                                          customerName: widget.customerName,
                                          orderId: widget.orderId ?? 'Selesai',
                                        );
                                    _showPopUp(
                                      context,
                                      'Berhasil',
                                      'Struk sedang dicetak...',
                                      isError: false,
                                    );
                                  } catch (e) {
                                    _showPopUp(
                                      context,
                                      'Gagal Cetak',
                                      'Pastikan printer menyala dan kertas tersedia.',
                                      isError: true,
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorJagoGreen,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(
                                  Icons.home,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Ke Beranda',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                },
                              ),
                            ),
                          ],
                        ),

                        if (widget.isAdmin && widget.orderId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  backgroundColor: Colors.red.shade50,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Hapus Transaksi (Admin)',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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