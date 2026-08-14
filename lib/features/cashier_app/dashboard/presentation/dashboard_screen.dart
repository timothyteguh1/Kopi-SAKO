import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../logic/dashboard_provider.dart'; 
import '../../orders/presentation/pos_customer_screen.dart';
import '../../orders/presentation/pos_invoice_screen.dart';
import '../../orders/logic/orders_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool isExpanded = false;

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  void _showSettingsModal(BuildContext context) async {
    // 1. Amankan context dan navigator sebelum proses await dimulai!
    final currentContext = context;
    final navigator = Navigator.of(currentContext, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    
    // Tampilkan Loading
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      // Tunggu data dari Supabase
      final data = await Supabase.instance.client.from('global_settings').select('points_conversion_rate').eq('id', 1).single();
      
      // 2. Tutup loading dengan aman
      navigator.pop();

      if (!mounted) return;

      final rateCtrl = TextEditingController(text: data['points_conversion_rate'].toString());

      // 3. Tampilkan Modal Pengaturan Poin
      showDialog(
        context: currentContext,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Pengaturan Poin', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('1 Poin didapatkan setiap pembelian kelipatan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                final newRate = int.tryParse(rateCtrl.text);
                if (newRate != null && newRate > 0) {
                  Navigator.pop(ctx);
                  await Supabase.instance.client.from('global_settings').update({'points_conversion_rate': newRate}).eq('id', 1);
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Kelipatan poin berhasil diperbarui!')));
                }
              },
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      navigator.pop(); // Pastikan loading tertutup jika terjadi error
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('Gagal mengambil pengaturan: $e')));
      }
    }
  }

  void _showBranchSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: AppColors.surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pilih Cabang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                const SizedBox(height: 16),
                Consumer(
                  builder: (context, ref, child) {
                    final branchesAsync = ref.watch(branchesListProvider);
                    return branchesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                      error: (e, s) => Text('Gagal memuat cabang: $e'),
                      data: (branches) {
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: branches.length,
                          itemBuilder: (context, index) {
                            final branch = branches[index];
                            final isActive = ref.watch(activeBranchIdProvider) == branch['id'];

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.storefront, color: isActive ? AppColors.primaryOrange : Colors.grey),
                              title: Text(branch['name'], style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                              trailing: isActive ? const Icon(Icons.check_circle, color: AppColors.primaryOrange) : null,
                              onTap: () {
                                ref.read(activeBranchIdProvider.notifier).state = branch['id'];
                                ref.read(activeBranchNameProvider.notifier).state = branch['name'];
                                Navigator.pop(context);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar Aplikasi?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin logout dari sistem kasir ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx); 
              showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
              await Future.delayed(const Duration(milliseconds: 300));
              await Supabase.instance.client.auth.signOut();
            },
            child: const Text('Ya, Logout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(branchInitializationProvider);

    final salesDataAsync = ref.watch(todaySalesProvider);
    final liveOrdersAsync = ref.watch(liveOrdersProvider);
    final completedOrdersAsync = ref.watch(completedOrdersProvider); // DATA PESANAN SELESAI
    final branchName = ref.watch(activeBranchNameProvider);
    final userRole = ref.watch(userRoleProvider).value; 
    final isAdmin = userRole == 'super_admin';
    final currentUserName = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'Kasir';

    return Scaffold(
      backgroundColor: AppColors.background,
      
      drawer: Drawer(
        backgroundColor: AppColors.surfaceWhite,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primaryOrange),
              accountName: Text(currentUserName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text(isAdmin ? 'Super Admin' : 'Staf Kasir'),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: AppColors.primaryOrange, size: 40)),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.tune, color: AppColors.textDark),
                title: const Text('Pengaturan Poin', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsModal(context);
                },
              ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Keluar Aplikasi', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: GestureDetector(
          onTap: isAdmin ? () => _showBranchSwitcher(context, ref) : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: AppColors.primaryOrange),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cabang Aktif', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Row(
                    children: [
                      Text(branchName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      if (isAdmin) const Icon(Icons.arrow_drop_down, color: AppColors.textDark),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(cartProvider.notifier).clearCart();
          ref.read(selectedCustomerProvider.notifier).state = null;

          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              fullscreenDialog: true, 
              builder: (context) => const PosCustomerScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primaryOrange,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Buat Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: CustomScrollView(
        slivers: [
          // TOTAL PEMASUKAN HARI INI
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: salesDataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                error: (err, stack) => Text('Gagal memuat data: $err'),
                data: (sales) {
                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => isExpanded = !isExpanded),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20), border: Border.all(color: isExpanded ? AppColors.primaryOrange : Colors.transparent, width: 1.5)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Pemasukan Hari Ini', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(formatRupiah(sales.total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                            ],
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: isExpanded ? 110 : 0,
                        curve: Curves.easeInOut,
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Row(
                              children: [
                                _buildDetailCard('Tunai', formatRupiah(sales.cash), Icons.payments),
                                const SizedBox(width: 12),
                                _buildDetailCard('QRIS/Transfer', formatRupiah(sales.nonCash), Icons.qr_code_scanner),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ANTREAN AKTIF (LIVE)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Antrean Aktif', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Live', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
            ),
          ),

          liveOrdersAsync.when(
            loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)))),
            error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
            data: (orders) {
              if (orders.isEmpty) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32.0), child: Center(child: Text('Belum ada antrean pesanan di cabang ini.', style: TextStyle(color: Colors.grey.shade500)))));
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return LiveOrderCard(order: orders[index]);
                  },
                  childCount: orders.length,
                ),
              );
            },
          ),

          // PESANAN SELESAI HARI INI
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.0, 32.0, 16.0, 8.0),
              child: Text('Pesanan Selesai (Hari Ini)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ),
          ),

          completedOrdersAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
            data: (orders) {
              if (orders.isEmpty) {
                return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(32, 16, 32, 80), child: Center(child: Text('Belum ada pesanan yang selesai.', style: TextStyle(color: Colors.grey.shade500)))));
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Pakai komponen yang sama, tapi karena statusnya bukan 'preparing', otomatis tanpa timer dan berlabel "Selesai"
                    return LiveOrderCard(order: orders[index]);
                  },
                  childCount: orders.length,
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String amount, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryOrange, size: 20),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(amount, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET KHUSUS: KARTU PESANAN DENGAN AUTO-COMPLETE TIMER & NOTA AMAN
// ============================================================================
class LiveOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  const LiveOrderCard({super.key, required this.order});

  @override
  State<LiveOrderCard> createState() => _LiveOrderCardState();
}

class _LiveOrderCardState extends State<LiveOrderCard> {
  Timer? _timer;
  late DateTime _targetTime;
  String _timeRemaining = "--:--";
  bool _isOverdue = false;
  bool _isAutoUpdating = false;

  @override
  void initState() {
    super.initState();
    // Hanya hitung timer jika statusnya masih diproses (preparing)
    if (widget.order['status'] == 'preparing') {
      _calculateTargetTime();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateTime();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTargetTime() {
    final createdAt = DateTime.parse(widget.order['created_at']).toLocal();
    final int prepTimeMinutes = widget.order['estimated_prep_time'] ?? 15;
    _targetTime = createdAt.add(Duration(minutes: prepTimeMinutes));
    _updateTime();
  }

  Future<void> _autoCompleteOrder() async {
    if (_isAutoUpdating) return;
    _isAutoUpdating = true;
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': 'completed'})
          .eq('id', widget.order['id']);
    } catch (e) {
      debugPrint('Gagal auto-update status: $e');
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final difference = _targetTime.difference(now);

    if (difference.isNegative) {
      if (!_isOverdue && mounted) {
        setState(() {
          _isOverdue = true;
          _timeRemaining = "Selesai"; 
        });
        _autoCompleteOrder();
      }
    } else {
      final minutes = difference.inMinutes.toString().padLeft(2, '0');
      final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');
      if (mounted) {
        setState(() {
          _timeRemaining = "$minutes:$seconds";
          _isOverdue = false;
        });
      }
    }
  }

 Future<void> _showInvoiceModal() async {
    // 1. Simpan context ke variabel lokal agar aman
    final currentContext = context;
    
    // Tampilkan Loading
    showDialog(
      context: currentContext,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
    );

    try {
      final orderId = widget.order['id'];
      final response = await Supabase.instance.client
          .from('order_items')
          .select('quantity, price_at_time, products(name)')
          .eq('order_id', orderId);

      // 2. TUTUP DIALOG LOADING DULUAN (Gunakan rootNavigator = true agar sangat aman)
      Navigator.of(currentContext, rootNavigator: true).pop();

      // 3. Cek apakah widget masih ada di layar sebelum pindah halaman
      if (!mounted) return; 

      final cartItems = (response as List<dynamic>).map<Map<String, dynamic>>((item) {
        final qty = item['quantity'] ?? 0;
        final price = item['price_at_time'] ?? 0;
        String productName = 'Produk Tidak Diketahui';
        if (item['products'] != null) {
          if (item['products'] is Map) {
            productName = item['products']['name'] ?? productName;
          } else if (item['products'] is List && item['products'].isNotEmpty) {
            productName = item['products'][0]['name'] ?? productName;
          }
        }
        return {'qty': qty, 'price': price, 'name': productName};
      }).toList();

      // Buka Layar Nota
      Navigator.push(
        currentContext,
        MaterialPageRoute(
          builder: (context) => PosInvoiceScreen(
            cartItems: cartItems,
            total: widget.order['total_amount'] as int,
            paymentMethod: widget.order['payment_method'] ?? 'cash',
            customerName: widget.order['customer_name_snapshot'] ?? 'Umum',
          ),
        ),
      );
    } catch (e) {
      // Jika terjadi error (misal internet putus), tutup loading-nya juga
      Navigator.of(currentContext, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(content: Text('Gagal memuat rincian nota: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String orderId = '#${widget.order['id'].toString().substring(0, 6).toUpperCase()}';
    final String customerName = widget.order['customer_name_snapshot'] ?? 'Pelanggan';
    final String amount = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(widget.order['total_amount'] as int);
    
    // Status pengecekan
    final bool isProcessing = widget.order['status'] == 'preparing';
    final bool isCompleted = widget.order['status'] == 'completed';

    return GestureDetector(
      onTap: _showInvoiceModal,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20), 
        decoration: BoxDecoration(
          color: isCompleted ? Colors.grey.shade50 : AppColors.surfaceWhite, // Warna beda jika selesai
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(orderId, style: TextStyle(fontWeight: FontWeight.w900, color: isCompleted ? Colors.grey.shade600 : AppColors.textDark, fontSize: 16)),
                Row(
                  children: [
                    // TIMER (Hanya untuk yang sedang diproses)
                    if (isProcessing)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _isOverdue ? Colors.green.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Icon(_isOverdue ? Icons.check_circle : Icons.timer_outlined, size: 14, color: _isOverdue ? Colors.green : Colors.blue),
                            const SizedBox(width: 4),
                            Text(_timeRemaining, style: TextStyle(color: _isOverdue ? Colors.green : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    
                    // LENCANA STATUS (Selesai menggunakan lencana Abu-abu)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.grey.shade200 : (isProcessing ? Colors.blue.shade50 : Colors.orange.shade50), 
                        borderRadius: BorderRadius.circular(12)
                      ), 
                      child: Text(
                        isCompleted ? 'Selesai' : (isProcessing ? 'Diproses' : 'Menunggu'), 
                        style: TextStyle(
                          color: isCompleted ? Colors.grey.shade600 : (isProcessing ? Colors.blue : Colors.orange), 
                          fontSize: 12, fontWeight: FontWeight.bold
                        )
                      )
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text(customerName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isCompleted ? Colors.grey.shade600 : AppColors.textDark)), 
                Text(amount, style: TextStyle(fontWeight: FontWeight.w900, color: isCompleted ? Colors.grey.shade500 : AppColors.primaryOrange))
              ]
            ),
          ],
        ),
      ),
    );
  }
}