import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/logic/auth_provider.dart';
import '../logic/report_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State Filter UI
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  
  String? _selectedBranchId; // Jika null, berarti "Semua Cabang"
  String _selectedBranchName = 'Semua Cabang (Global)';
  List<Map<String, dynamic>> _branchesList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Tarik data saat pertama kali layar dibuka (delay sedikit agar widget build dulu)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final userRole = ref.read(userRoleProvider).value;
    
    // Jika Kasir, otomatis set cabangnya dan tidak bisa ubah cabang
    if (userRole == 'cashier') {
      final session = supabase.auth.currentSession;
      if (session != null) {
        final profile = await supabase.from('profiles').select('branch_id').eq('id', session.user.id).single();
        _selectedBranchId = profile['branch_id'];
        _selectedBranchName = 'Cabang Anda';
      }
    } else {
      // Jika Admin, tarik daftar cabang untuk dropdown
      final branches = await supabase.from('branches').select('id, name').order('name');
      setState(() {
        _branchesList = List<Map<String, dynamic>>.from(branches);
      });
    }

    _fetchReportData();
  }

  void _fetchReportData() {
    ref.read(reportProvider.notifier).loadReport(
      _selectedDateRange.start, 
      _selectedDateRange.end, 
      _selectedBranchId
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryOrange, onPrimary: Colors.white, onSurface: AppColors.textDark),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _fetchReportData(); // Reload data jika tanggal berubah
    }
  }

  void _showBranchPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Pilih Cabang Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                title: const Text('Semua Cabang (Global)', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: _selectedBranchId == null ? const Icon(Icons.check, color: AppColors.primaryOrange) : null,
                onTap: () {
                  setState(() {
                    _selectedBranchId = null;
                    _selectedBranchName = 'Semua Cabang (Global)';
                  });
                  Navigator.pop(context);
                  _fetchReportData();
                },
              ),
              const Divider(),
              ..._branchesList.map((branch) => ListTile(
                title: Text(branch['name']),
                trailing: _selectedBranchId == branch['id'] ? const Icon(Icons.check, color: AppColors.primaryOrange) : null,
                onTap: () {
                  setState(() {
                    _selectedBranchId = branch['id'];
                    _selectedBranchName = branch['name'];
                  });
                  Navigator.pop(context);
                  _fetchReportData();
                },
              ))
            ],
          ),
        );
      }
    );
  }

  String _formatDateRange() {
    final start = DateFormat('d MMM yyyy', 'id_ID').format(_selectedDateRange.start);
    final end = DateFormat('d MMM yyyy', 'id_ID').format(_selectedDateRange.end);
    if (start == end) return start; 
    return '$start - $end';
  }

  String _formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final userRole = ref.watch(userRoleProvider).value;
    final isSuperAdmin = userRole == 'super_admin';
    final reportState = ref.watch(reportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Keuangan', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        centerTitle: true,
      ),
      // KUNCI FIX 2: Gunakan Stack agar tidak berkedip (UI kerangka tetap dirender di bawah loading overlay)
      body: Stack(
        children: [
          Column(
            children: [
              // 1. AREA FILTER
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surfaceWhite,
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Rentang Waktu', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryOrange),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(_formatDateRange(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: isSuperAdmin ? _showBranchPicker : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300), 
                            borderRadius: BorderRadius.circular(8),
                            color: isSuperAdmin ? Colors.transparent : Colors.grey.shade100,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cabang', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.storefront, size: 14, color: AppColors.textDark),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(_selectedBranchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  if (isSuperAdmin) const Icon(Icons.arrow_drop_down, size: 16),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. KARTU RINGKASAN
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildSummaryCard('Pemasukan', _formatCurrency(reportState.totalIncome), Colors.green.shade600, Icons.arrow_upward),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Pengeluaran', _formatCurrency(reportState.totalExpense), AppColors.error, Icons.arrow_downward),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Laba Bersih', _formatCurrency(reportState.netProfit), Colors.blue.shade700, Icons.analytics),
                  ],
                ),
              ),

              // 3. TAB MENU
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 48, 
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab, 
                  dividerColor: Colors.transparent, 
                  indicator: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(12)),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textLight,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Produk Terlaris'),
                    Tab(text: 'Riwayat Keluar'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 4. ISI TAB
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // TAB 1: PRODUK TERLARIS
                    reportState.topProducts.isEmpty && !reportState.isLoading
                        ? const Center(child: Text('Belum ada penjualan di rentang waktu ini.', style: TextStyle(color: AppColors.textLight)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: reportState.topProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final product = reportState.topProducts[index];
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Text('${index + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textLight)),
                                    const SizedBox(width: 16),
                                    Container(
                                      height: 48, width: 48,
                                      decoration: BoxDecoration(color: AppColors.fieldBackground, borderRadius: BorderRadius.circular(12)),
                                      child: const Icon(Icons.local_cafe, color: AppColors.primaryOrange),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(product['product_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textDark)),
                                          const SizedBox(height: 4),
                                          Text('Terjual: ${product['total_qty']} Item', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                    Text(_formatCurrency(product['total_revenue']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green)),
                                  ],
                                ),
                              );
                            },
                          ),

                    // TAB 2: RIWAYAT PENGELUARAN
                    reportState.expenseHistory.isEmpty && !reportState.isLoading
                        ? const Center(child: Text('Belum ada pengeluaran di rentang waktu ini.', style: TextStyle(color: AppColors.textLight)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: reportState.expenseHistory.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final expense = reportState.expenseHistory[index];
                              final date = DateTime.parse(expense['expense_date']).toLocal();
                              final isOps = expense['type'] == 'Operasional';
                              
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Icon(isOps ? Icons.build_circle : Icons.inventory, color: isOps ? Colors.purple : Colors.orange, size: 32),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(expense['description'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                                          const SizedBox(height: 4),
                                          Text(DateFormat('d MMM yyyy, HH:mm').format(date), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ),
                                    Text(_formatCurrency(expense['amount']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.error)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
          
          // OVERLAY LOADING TRANSPARAN
          if (reportState.isLoading)
            Container(
              color: AppColors.surfaceWhite.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 12),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}