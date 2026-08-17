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

// Provider Daftar Cabang (KUNCI PERBAIKAN: HANYA TAMPILKAN YANG AKTIF)
final branchesListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await Supabase.instance.client
      .from('branches')
      .select('id, name')
      .eq('is_active', true) // <-- Hanya ambil yang nyawanya masih ada
      .order('name');
  return List<Map<String, dynamic>>.from(res);
});

// Provider Inisialisasi Cabang & Penjaga Status
final branchInitializationProvider = FutureProvider.autoDispose<void>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  final userRole = ref.watch(userRoleProvider).value; 
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null || userRole == null) return;

  if (userRole == 'super_admin') {
    // Ambil daftar cabang yang MASIH AKTIF saja
    final res = await Supabase.instance.client.from('branches').select('id, name').eq('is_active', true).order('name');
    final activeBranches = List<Map<String, dynamic>>.from(res);

    final currentBranchId = ref.read(activeBranchIdProvider);
    final isCurrentBranchStillActive = activeBranches.any((b) => b['id'] == currentBranchId);

    if (activeBranches.isNotEmpty) {
      // Jika Admin belum milih cabang, ATAU cabang yang sedang dibuka barusan di-NONAKTIF-kan
      if (currentBranchId == null || !isCurrentBranchStillActive) {
        // Otomatis lempar / pindahkan Admin ke cabang pertama yang aktif di daftar
        ref.read(activeBranchIdProvider.notifier).state = activeBranches.first['id'];
        ref.read(activeBranchNameProvider.notifier).state = activeBranches.first['name'];
      }
    } else {
      // Jika SEMUA cabang ditutup
      ref.read(activeBranchIdProvider.notifier).state = null;
      ref.read(activeBranchNameProvider.notifier).state = 'Tidak ada cabang aktif';
    }
  } 
  else if (userRole == 'cashier') {
    // Kasir: Terikat pada satu cabang
    final branchId = await repo.getCashierAssignedBranch(userId);
    
    if (branchId == null) {
      await AuthController.logout();
      return;
    }

    // Cek apakah cabang tempat kasir ditugaskan masih hidup (is_active)
    final branchDetails = await Supabase.instance.client
        .from('branches')
        .select('is_active')
        .eq('id', branchId)
        .maybeSingle();

    if (branchDetails == null || branchDetails['is_active'] == false) {
      // Kasir langsung ditendang ke halaman login jika cabangnya dinonaktifkan
      await AuthController.logout();
      return;
    }

    if (ref.read(activeBranchIdProvider) == null) {
      ref.read(activeBranchIdProvider.notifier).state = branchId;
      ref.read(activeBranchNameProvider.notifier).state = 'Cabang Penugasan'; 
    }
  }
});

// =====================================================================
// Provider Saldo Hari Ini (DIUBAH KE STREAM AGAR LIVE)
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