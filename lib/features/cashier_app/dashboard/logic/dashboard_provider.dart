import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/dashboard_repository.dart';
// Asumsi: Anda sudah punya userRoleProvider di auth_provider.dart seperti di app_router
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
  final userRole = ref.watch(userRoleProvider).value; // Tarik role dari auth_provider
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null || userRole == null) return;

  // JIKA SUPER ADMIN: Ambil semua cabang, dan set default ke cabang pertama
  if (userRole == 'super_admin') {
    final branches = await repo.getAllBranches();
    if (branches.isNotEmpty && ref.read(activeBranchIdProvider) == null) {
      ref.read(activeBranchIdProvider.notifier).state = branches.first['id'];
      ref.read(activeBranchNameProvider.notifier).state = branches.first['name'];
    }
  } 
  // JIKA KASIR: Tarik ID cabang dari database
  else if (userRole == 'cashier') {
    final branchId = await repo.getCashierAssignedBranch(userId);
    if (branchId != null && ref.read(activeBranchIdProvider) == null) {
      ref.read(activeBranchIdProvider.notifier).state = branchId;
      // Nanti bisa diextract namanya juga, untuk MVP kita set manual jika kasir
      ref.read(activeBranchNameProvider.notifier).state = 'Cabang Penugasan'; 
    }
  }
});

// Provider Daftar Cabang (Untuk UI Bottom Sheet Switcher Admin)
final branchesListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getAllBranches();
});

// Provider Saldo Hari Ini
final todaySalesProvider = FutureProvider.autoDispose<DailySales>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final branchId = ref.watch(activeBranchIdProvider); 
  
  if (branchId == null) return DailySales(total: 0, cash: 0, nonCash: 0); 
  return repo.getTodaySales(branchId);
});

// Provider Antrean Live 
final liveOrdersProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  final branchId = ref.watch(activeBranchIdProvider); 
  
  // SOLUSI LOADING ABADI: Gunakan Stream.value([]) agar tampil teks kosong
  if (branchId == null) return Stream.value([]); 
  
  return repo.getLiveOrdersStream(branchId);
});