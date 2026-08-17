import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../dashboard/logic/dashboard_provider.dart';
import '../data/orders_repository.dart'; // MENGGUNAKAN ORDERS REPOSITORY

class OrdersHistoryState {
  final List<Map<String, dynamic>> orders;
  final bool isInitialLoad;
  final bool isSearching;
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
    state = state.copyWith(isInitialLoad: true, page: 0, hasMore: true, orders: []);
    await _fetchData();
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query, isSearching: true);
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
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
      // MENGGUNAKAN MESIN YANG BARU (ORDERS REPOSITORY)
      final repo = ref.read(ordersRepositoryProvider);
      final branchId = ref.read(activeBranchIdProvider);
      
      if (branchId == null) {
        state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
        return;
      }

      // Memanggil fungsi baru yang ada short_id nya
      final newOrders = await repo.getOrdersHistory(
        query: state.searchQuery,
        branchId: branchId,
      );

      state = state.copyWith(
        orders: isLoadMore ? [...state.orders, ...newOrders] : newOrders,
        hasMore: newOrders.length == 30, // Limit default dari fungsi getOrdersHistory
        isInitialLoad: false,
        isSearching: false,
        isFetchingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
    }
  }

  // Fungsi tambahan untuk menangani refresh (tarik ke bawah)
  Future<void> refreshManual() async {
    state = state.copyWith(page: 0, hasMore: true);
    await _fetchData();
  }

  void refreshAfterDelete() {
    if (state.searchQuery.isNotEmpty) {
      onSearchChanged(state.searchQuery);
    } else {
      fetchInitialOrders();
    }
  }
}

// Tambahkan inisiasi provider untuk OrdersRepository (karena sebelumnya ada di file terpisah)
final ordersRepositoryProvider = Provider((ref) => OrdersRepository());

final ordersHistoryProvider = StateNotifierProvider<OrdersHistoryNotifier, OrdersHistoryState>((ref) {
  return OrdersHistoryNotifier(ref);
});