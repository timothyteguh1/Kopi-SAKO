import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../auth/logic/auth_provider.dart';

// Wadah untuk menyimpan hasil tarikan data laporan
class ReportState {
  final int totalIncome;
  final int totalExpense;
  final int netProfit;
  final List<dynamic> topProducts;
  final List<dynamic> expenseHistory;
  final bool isLoading;

  ReportState({
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.netProfit = 0,
    this.topProducts = const [],
    this.expenseHistory = const [],
    this.isLoading = false,
  });
}

class ReportNotifier extends StateNotifier<ReportState> {
  ReportNotifier() : super(ReportState());

  Future<void> loadReport(DateTime start, DateTime end, String? branchId) async {
    state = ReportState(isLoading: true); // Munculkan loading
    
    try {
      // Format tanggal ISO agar dipahami oleh Supabase
      // Untuk tanggal akhir (end), kita paksa hingga jam 23:59:59 agar rekap 1 hari penuh ditarik
      final startIso = start.toIso8601String();
      final endIso = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

      // Panggil 3 fungsi RPC di Supabase secara bersamaan (paralel) agar aplikasi tidak lemot
      final results = await Future.wait([
        supabase.rpc('get_financial_summary', params: {'p_start_date': startIso, 'p_end_date': endIso, 'p_branch_id': branchId}),
        supabase.rpc('get_top_selling_products', params: {'p_start_date': startIso, 'p_end_date': endIso, 'p_branch_id': branchId}),
        supabase.rpc('get_expense_history', params: {'p_start_date': startIso, 'p_end_date': endIso, 'p_branch_id': branchId}),
      ]);

      // Ekstrak datanya
      final summaryData = (results[0] as List).firstOrNull ?? {};
      final productsData = results[1] as List;
      final expenseData = results[2] as List;

      // Simpan ke wadah dan matikan loading
      state = ReportState(
        isLoading: false,
        totalIncome: summaryData['total_income'] ?? 0,
        totalExpense: summaryData['total_expense'] ?? 0,
        netProfit: summaryData['net_profit'] ?? 0,
        topProducts: productsData,
        expenseHistory: expenseData,
      );

    } catch (e) {
      state = ReportState(isLoading: false);
      print("Gagal memuat laporan: $e");
    }
  }
}

// Inilah Provider yang akan dipanggil oleh UI
final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) => ReportNotifier());