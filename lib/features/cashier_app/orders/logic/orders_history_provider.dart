import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../dashboard/logic/dashboard_provider.dart';

// State untuk menyimpan kondisi layar riwayat
class OrdersHistoryState {
  final List<Map<String, dynamic>> orders;
  final bool isInitialLoad;
  final bool isSearching; // <-- TAMBAHAN BARU: Status khusus untuk pencarian
  final bool isFetchingMore;
  final bool hasMore;
  final String searchQuery;
  final int page;
  final DateTime startDate;
  final DateTime endDate;

  OrdersHistoryState({
    this.orders = const [],
    this.isInitialLoad = true,
    this.isSearching = false,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.searchQuery = '',
    this.page = 0,
    required this.startDate,
    required this.endDate,
  });

  OrdersHistoryState copyWith({
    List<Map<String, dynamic>>? orders,
    bool? isInitialLoad,
    bool? isSearching,
    bool? isFetchingMore,
    bool? hasMore,
    String? searchQuery,
    int? page,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return OrdersHistoryState(
      orders: orders ?? this.orders,
      isInitialLoad: isInitialLoad ?? this.isInitialLoad,
      isSearching: isSearching ?? this.isSearching,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: searchQuery ?? this.searchQuery,
      page: page ?? this.page,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

class OrdersHistoryNotifier extends StateNotifier<OrdersHistoryState> {
  final Ref ref;
  Timer? _debounceTimer;

  OrdersHistoryNotifier(this.ref) : super(OrdersHistoryState(
    startDate: DateTime.now().subtract(const Duration(days: 30)),
    endDate: DateTime.now(),
  )) {
    ref.listen<String?>(activeBranchIdProvider, (previous, next) {
      if (next != null && next != previous) {
        fetchInitialOrders();
      }
    });

    final initialBranch = ref.read(activeBranchIdProvider);
    if (initialBranch != null) {
      fetchInitialOrders();
    } else {
      state = state.copyWith(isInitialLoad: false);
    }
  }

  Future<void> fetchInitialOrders() async {
    // Kosongkan orders agar UI tahu harus menampilkan skeleton (hanya saat awal)
    state = state.copyWith(isInitialLoad: true, page: 0, hasMore: true, orders: []);
    await _fetchData();
  }

  // Fungsi Ketik Pencarian
  void onSearchChanged(String query) {
    // 1. Catat apa yang diketik dan nyalakan status "sedang mencari"
    state = state.copyWith(searchQuery: query, isSearching: true);
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      // 2. Kosongkan data, reset halaman, tapi biarkan status isSearching menyala
      state = state.copyWith(page: 0, hasMore: true, orders: []);
      await _fetchData();
    });
  }

  void onDateRangeChanged(DateTime start, DateTime end) {
    state = state.copyWith(startDate: start, endDate: end);
    fetchInitialOrders();
  }

  Future<void> loadMore() async {
    if (state.isFetchingMore || !state.hasMore || state.isInitialLoad || state.isSearching) return;
    
    state = state.copyWith(isFetchingMore: true, page: state.page + 1);
    await _fetchData(isLoadMore: true);
  }

  Future<void> _fetchData({bool isLoadMore = false}) async {
    try {
      final repo = ref.read(dashboardRepositoryProvider);
      final branchId = ref.read(activeBranchIdProvider);
      
      if (branchId == null) {
        state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
        return;
      }

      final newOrders = await repo.getOrdersHistory(
        query: state.searchQuery,
        page: state.page,
        branchId: branchId,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        orders: isLoadMore ? [...state.orders, ...newOrders] : newOrders,
        hasMore: newOrders.length == 15, 
        isInitialLoad: false, // Matikan skeleton
        isSearching: false,   // Matikan spinner di search bar
        isFetchingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
    }
  }

  void refreshAfterDelete() {
    // Jika sedang mencari sesuatu, ulangi proses pencariannya
    if (state.searchQuery.isNotEmpty) {
      onSearchChanged(state.searchQuery);
    } else {
      fetchInitialOrders();
    }
  }
}

// Pastikan deklarasi ini TIDAK menggunakan .autoDispose
final ordersHistoryProvider = StateNotifierProvider<OrdersHistoryNotifier, OrdersHistoryState>((ref) {
  return OrdersHistoryNotifier(ref);
});