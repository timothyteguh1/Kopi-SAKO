import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/dashboard_repository.dart';
import '../../../auth/logic/auth_provider.dart'; 

// State Penyimpan ID Cabang Aktif & Nama Cabang Aktif
final activeBranchIdProvider = StateProvider<String?>((ref) => null);
final activeBranchNameProvider = StateProvider<String>((ref) => 'Memuat Cabang...');

// Provider Repository
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

// Provider Inisialisasi Cabang (Mendeteksi Admin vs Kasir)
final branchInitializationProvider = FutureProvider.autoDispose<void>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final userRole = ref.watch(userRoleProvider).value; 
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null || userRole == null) return;

  if (userRole == 'super_admin') {
    final branches = await repo.getAllBranches();
    if (branches.isNotEmpty && ref.read(activeBranchIdProvider) == null) {
      ref.read(activeBranchIdProvider.notifier).state = branches.first['id'];
      ref.read(activeBranchNameProvider.notifier).state = branches.first['name'];
    }
  } 
  else if (userRole == 'cashier') {
    final branchId = await repo.getCashierAssignedBranch(userId);
    if (branchId != null && ref.read(activeBranchIdProvider) == null) {
      ref.read(activeBranchIdProvider.notifier).state = branchId;
      ref.read(activeBranchNameProvider.notifier).state = 'Cabang Penugasan'; 
    }
  }
});

// Provider Daftar Cabang 
final branchesListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getAllBranches();
});

// =====================================================================
// PERBAIKAN: Provider Saldo Hari Ini (DIUBAH KE STREAM AGAR LIVE)
// =====================================================================
final todaySalesProvider = StreamProvider.autoDispose<DailySales>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final branchId = ref.watch(activeBranchIdProvider); 
  
  if (branchId == null) return Stream.value(DailySales(total: 0, cash: 0, nonCash: 0)); 
  return repo.getTodaySalesStream(branchId);
});

// Provider Antrean Live 
final liveOrdersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final branchId = ref.watch(activeBranchIdProvider); 
  
  if (branchId == null) return Stream.value([]); 
  return repo.getLiveOrdersStream(branchId);
});

// Provider Pesanan Selesai
final completedOrdersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final branchId = ref.watch(activeBranchIdProvider); 
  
  if (branchId == null) return Stream.value([]); 
  return repo.getCompletedOrdersStream(branchId);
});