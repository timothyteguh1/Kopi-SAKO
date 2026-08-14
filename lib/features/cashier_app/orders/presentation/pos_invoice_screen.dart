import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PosInvoiceScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final int total;
  final String paymentMethod;
  final String customerName;

  const PosInvoiceScreen({
    super.key,
    required this.cartItems,
    required this.total,
    required this.paymentMethod,
    required this.customerName,
  });

  @override
  State<PosInvoiceScreen> createState() => _PosInvoiceScreenState();
}

class _PosInvoiceScreenState extends State<PosInvoiceScreen> {
  int _earnedPoints = 0;
  bool _isFetchingPoints = true;

  @override
  void initState() {
    super.initState();
    _calculatePoints();
  }

  // FUNGSI PINTAR: Menghitung poin otomatis berdasarkan pengaturan terbaru di Supabase
  Future<void> _calculatePoints() async {
    // Jika pelanggan umum (Walk-in), tidak dapat poin. Langsung hentikan loading.
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
      // Ambil kelipatan poin dari tabel global_settings
      final data = await Supabase.instance.client
          .from('global_settings')
          .select('points_conversion_rate')
          .eq('id', 1)
          .single();
      
      final rate = data['points_conversion_rate'] as int;
      
      if (mounted) {
        setState(() {
          _earnedPoints = widget.total ~/ rate; // Pembagian bulat (contoh: 180.000 / 10.000 = 18 poin)
          _isFetchingPoints = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingPoints = false);
    }
  }

  String formatRupiah(int number) => NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  String get _todayDate => DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now());

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
            child: SingleChildScrollView( // Ditambahkan agar aman jika struk sangat panjang
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. IKON SUKSES
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: colorJagoGreen.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: colorJagoGreen, size: 80),
                  ),
                  const SizedBox(height: 24),
                  const Text('Pesanan Berhasil!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: colorTextBrown)),
                  const SizedBox(height: 8),
                  Text('Antrean sedang dipersiapkan', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  
                  // 2. LENCANA POIN REWARD (Tampil menawan dengan animasi)
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
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade100, Colors.orange.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.orange.shade300, width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: Colors.orange, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  '+$_earnedPoints Poin Didapatkan',
                                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade800, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    ),
                  
                  const SizedBox(height: 32),

                  // 3. KARTU NOTA (STRUK KERTAS)
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
                            Text(methodLabel, style: const TextStyle(color: colorJagoGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Pelanggan: ${widget.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, color: colorTextBrown, fontSize: 14)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: colorDivider, thickness: 1.5)),
                        
                        // DAFTAR ITEM DI NOTA
                        ...widget.cartItems.map((item) => Padding(
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
                        )),
                        
                        const Padding(padding: EdgeInsets.only(top: 4, bottom: 16), child: Divider(color: colorDivider, thickness: 1.5)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Bayar', style: TextStyle(fontWeight: FontWeight.bold, color: colorTextBrown, fontSize: 16)),
                            Text(formatRupiah(widget.total), style: const TextStyle(fontWeight: FontWeight.w900, color: colorTextBrown, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 4. TOMBOL NAVIGASI
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: colorDivider, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                            ),
                            icon: const Icon(Icons.print, color: colorTextBrown),
                            label: const Text('Cetak Struk', style: TextStyle(color: colorTextBrown, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur cetak printer bluetooth sedang dikembangkan')));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorJagoGreen,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0
                            ),
                            icon: const Icon(Icons.home, color: Colors.white),
                            label: const Text('Ke Beranda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              // Kembali ke Dashboard
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}