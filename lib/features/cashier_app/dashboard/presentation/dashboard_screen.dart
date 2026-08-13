import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../logic/dashboard_provider.dart'; 

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

  String formatOrderId(String uuid) {
    return '#${uuid.substring(0, 6).toUpperCase()}';
  }

  // FUNGSI MEMUNCULKAN BOTTOM SHEET SWITCH BRANCH (Admin)
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

  // FUNGSI KERTAS/POP-UP POS KASIR (TEMPAT BUAT PESANAN)
  void _showCreateOrderModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Agar bisa menyesuaikan tinggi keyboard/konten
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75, // Mengambil 75% layar
          decoration: const BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5, 
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                ),
              ),
              const SizedBox(height: 16),
              const Text('Buat Pesanan Baru (POS)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const Text('Pilih produk dari database cabang aktif', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 32),
              
              // Tempat form produk & keranjang belanja kasir nanti
              const Expanded(
                child: Center(
                  child: Text(
                    'Form POS Kasir akan dirakit di sini\n(Terhubung ke tabel products & branch_stocks)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(branchInitializationProvider);

    final salesDataAsync = ref.watch(todaySalesProvider);
    final liveOrdersAsync = ref.watch(liveOrdersProvider);
    final branchName = ref.watch(activeBranchNameProvider);
    final userRole = ref.watch(userRoleProvider).value; 
    final isAdmin = userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: GestureDetector(
          onTap: isAdmin ? () => _showBranchSwitcher(context, ref) : null,
          child: Row(
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
      
      // TOMBOL MELAYANG POS (HANYA MUNCUL DI BERANDA)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderModal(context),
        backgroundColor: AppColors.primaryOrange,
        elevation: 4,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Buat Pesanan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      body: CustomScrollView(
        slivers: [
          // KARTU SALDO
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
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWhite,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isExpanded ? AppColors.primaryOrange : Colors.transparent, width: 1.5),
                          ),
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
                              Text(
                                formatRupiah(sales.total), 
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark)
                              ),
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

          // JUDUL ANTREAN
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

          // DAFTAR ANTREAN
          liveOrdersAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox()),
            error: (err, stack) => SliverToBoxAdapter(child: Center(child: Text('Error: $err'))),
            data: (orders) {
              if (orders.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 80), // Padding bawah ditambah agar tidak tertutup tombol melayang
                    child: Center(child: Text('Belum ada antrean pesanan di cabang ini.', style: TextStyle(color: Colors.grey.shade500))),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final order = orders[index];
                    final orderId = order['id'] as String;
                    final customerName = order['customer_name_snapshot'] ?? 'Pelanggan';
                    final totalAmount = order['total_amount'] as int;
                    final status = order['status'] as String;
                    
                    return _buildLiveOrderCard(
                      orderId: formatOrderId(orderId),
                      customerName: customerName,
                      amount: formatRupiah(totalAmount),
                      status: status,
                    );
                  },
                  childCount: orders.length,
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)), // Ruang kosong untuk tombol melayang
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String amount, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
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

  Widget _buildLiveOrderCard({required String orderId, required String customerName, required String amount, required String status}) {
    final isProcessing = status == 'processing';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              Text(orderId, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isProcessing ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isProcessing ? 'Diproses' : 'Menunggu Bayar', 
                  style: TextStyle(color: isProcessing ? Colors.blue : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
            ],
          ),
        ],
      ),
    );
  }
}