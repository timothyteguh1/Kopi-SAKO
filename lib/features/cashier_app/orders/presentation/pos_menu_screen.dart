import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:kopi_sako/features/cashier_app/dashboard/logic/dashboard_provider.dart';
import 'package:kopi_sako/features/cashier_app/orders/presentation/pos_payment_screen.dart';
import '../logic/orders_provider.dart';

class PosMenuScreen extends ConsumerStatefulWidget {
  const PosMenuScreen({super.key});

  @override
  ConsumerState<PosMenuScreen> createState() => _PosMenuScreenState();
}

class _PosMenuScreenState extends ConsumerState<PosMenuScreen> {
  String formatRupiah(int number) => NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(number);

  void _editQtyManual(
    BuildContext context,
    Map<String, dynamic> item,
    CartNotifier cartNotifier,
  ) {
    final ctrl = TextEditingController(text: item['qty'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Atur Jumlah',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF4A3B32),
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007A4D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              int newQty = int.tryParse(ctrl.text) ?? item['qty'];
              int currentQty = item['qty'];
              int diff = newQty - currentQty;

              if (diff > 0) {
                for (int i = 0; i < diff; i++) {
                  cartNotifier.addItem(item);
                }
              } else if (diff < 0) {
                for (int i = 0; i < diff.abs(); i++) {
                  cartNotifier.removeItem(item['id']);
                }
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchId = ref.watch(activeBranchIdProvider);
    final customer = ref.watch(selectedCustomerProvider);
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    if (customer == null) return const Scaffold();

    const colorJagoGreen = Color(0xFF007A4D);
    const colorCreamBg = Color(0xFFFDFBF7);
    const colorTextBrown = Color(0xFF4A3B32);
    const colorDivider = Color(0xFFEBE6D9);

    return Scaffold(
      backgroundColor: colorCreamBg,
      appBar: AppBar(
        backgroundColor: colorCreamBg,
        elevation: 0,
        iconTheme: const IconThemeData(color: colorTextBrown),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Point of Sale',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: colorTextBrown,
                fontSize: 18,
              ),
            ),
            Text(
              'Pelanggan: ${customer['is_guest'] == true ? 'Walk-in (Umum)' : customer['full_name']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(
              Icons.swap_horiz,
              color: Colors.redAccent,
              size: 18,
            ),
            label: const Text(
              'Ganti',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 700;

          Widget buildCartSection() {
            return Container(
              width: isTablet ? 380 : double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: isTablet
                    ? const Border(
                        left: BorderSide(color: colorDivider, width: 1.5),
                      )
                    : const Border(
                        top: BorderSide(color: colorDivider, width: 1.5),
                      ),
                boxShadow: [
                  if (!isTablet)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Order',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: colorTextBrown,
                          ),
                        ),
                        Text(
                          '${customer['is_guest'] == true ? 'Walk-in' : customer['full_name']} • Cash',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: colorDivider, thickness: 1.5),

                  Expanded(
                    child: cart.isEmpty
                        ? const Center(
                            child: Text(
                              'Keranjang Kosong',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(24),
                            itemCount: cart.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 24),
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return _AnimatedCartItemRow(
                                key: ValueKey(item['id']),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: colorTextBrown,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatRupiah(item['price']),
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: colorDivider,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.remove,
                                              size: 20,
                                            ),
                                            color: colorTextBrown,
                                            onPressed: () => cartNotifier
                                                .removeItem(item['id']),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            constraints: const BoxConstraints(),
                                          ),
                                          GestureDetector(
                                            onTap: () => _editQtyManual(
                                              context,
                                              item,
                                              cartNotifier,
                                            ),
                                            child: Container(
                                              color: Colors.transparent,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 8,
                                                  ),
                                              child: Text(
                                                '${item['qty']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 18,
                                                  color: colorTextBrown,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.add,
                                              size: 20,
                                            ),
                                            color: colorJagoGreen,
                                            onPressed: () =>
                                                cartNotifier.addItem(item),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // AREA TOTAL
                  if (cart.isNotEmpty)
                    // KUNCI PERBAIKAN: SafeArea agar tombol tidak nabrak ujung bawah layar HP / Home bar
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          24,
                          16,
                          24,
                          16,
                        ), // Padding atas & bawah dikurangi agar padat
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: colorDivider, width: 1.5),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize
                              .min, // Memastikan bungkus ini hanya mengambil ruang seperlunya
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  formatRupiah(cartNotifier.totalAmount),
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6), // Spasi diperkecil
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: colorTextBrown,
                                  ),
                                ),
                                Text(
                                  formatRupiah(cartNotifier.totalAmount),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: colorTextBrown,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 16,
                            ), // Jarak ke tombol dioptimalkan
                            // TOMBOL CHARGE CASH (Dilangsingkan jadi 50px)
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorJagoGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PosPaymentScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Charge Cash • ${formatRupiah(cartNotifier.totalAmount)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // TOMBOL CLEAR ORDER (Garis diperhalus, dilangsingkan jadi 48px)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ), // Garis dibuat lebih soft & tipis
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                                label: Text(
                                  'Clear order',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                onPressed: () => cartNotifier.clearCart(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          Widget buildMenuGrid() {
            return RefreshIndicator(
              color: colorJagoGreen,
              onRefresh: () async {
                ref.invalidate(posMenuProvider(branchId!));
                return await ref.read(posMenuProvider(branchId).future);
              },
              child: branchId == null
                  ? const Center(child: Text('Cabang tidak valid'))
                  : ref
                        .watch(posMenuProvider(branchId))
                        .when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: colorJagoGreen,
                            ),
                          ),
                          error: (e, s) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 100),
                              Center(child: Text('Error: $e')),
                            ],
                          ),
                          data: (menu) {
                            if (menu.isEmpty)
                              return ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 200),
                                  Center(child: Text('Belum ada menu.')),
                                ],
                              );

                            return GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(24),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isTablet ? 3 : 2,
                                    childAspectRatio:
                                        0.75, // KUNCI PERBAIKAN: Diubah jadi 0.75 agar lebih tinggi ke bawah
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                  ),
                              itemCount: menu.length,
                              itemBuilder: (context, index) {
                                final item = menu[index];
                                final stock = item['current_stock'] as int;
                                final isOutOfStock = stock <= 0;

                                return _AnimatedProductCard(
                                  item: item,
                                  isOutOfStock: isOutOfStock,
                                  onTap: isOutOfStock
                                      ? null
                                      : () => cartNotifier.addItem(item),
                                );
                              },
                            );
                          },
                        ),
            );
          }

          // RENDER UI FINAL (Tablet vs HP)
          if (isTablet) {
            return Row(
              children: [
                Expanded(child: buildMenuGrid()),
                buildCartSection(),
              ],
            );
          } else {
            return Column(
              children: [
                Expanded(flex: 5, child: buildMenuGrid()),

                // PERBAIKAN: Gunakan Expanded biasa agar list pesanan punya ruang untuk di-scroll
                if (cart.isNotEmpty)
                  Expanded(
                    flex:
                        6, // Memberikan porsi ruang yang lebih lega untuk keranjang di HP
                    child: buildCartSection(),
                  ),
              ],
            );
          }
        },
      ),
    );
  }
}

class _AnimatedProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isOutOfStock;
  final VoidCallback? onTap;

  const _AnimatedProductCard({
    required this.item,
    required this.isOutOfStock,
    this.onTap,
  });

  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard> {
  double _scale = 1.0;

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) setState(() => _scale = 0.95);
  }

  // PERBAIKAN: Ubah menjadi TapUpDetails
  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _scale = 1.0);
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final formatRupiah = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isOutOfStock ? 0.4 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFEBE6D9), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // KUNCI PERBAIKAN: Expanded memastikan gambar bisa melebar dan tidak overflow
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      0,
                    ), // Memberi sedikit jarak margin dari tepi
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2EFE8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: (widget.item['image_url'] != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.item['image_url'],
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.coffee,
                            color: Color(0xFF4A3B32),
                            size: 40,
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    widget.item['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: Color(0xFF4A3B32),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 16.0,
                  ), // Padding bawah agar angka tidak terlalu nempel
                  child: Text(
                    widget.isOutOfStock
                        ? 'Sold Out'
                        : formatRupiah.format(widget.item['price']),
                    style: TextStyle(
                      color: widget.isOutOfStock
                          ? Colors.grey
                          : Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCartItemRow extends StatefulWidget {
  final Widget child;
  const _AnimatedCartItemRow({required super.key, required this.child});

  @override
  State<_AnimatedCartItemRow> createState() => _AnimatedCartItemRowState();
}

class _AnimatedCartItemRowState extends State<_AnimatedCartItemRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
