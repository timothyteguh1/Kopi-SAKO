import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../dashboard/logic/dashboard_provider.dart';
import '../data/purchases_repository.dart';

class PurchasesState {
  final List<Map<String, dynamic>> purchases;
  final bool isInitialLoad;
  final bool isSearching;
  final bool isFetchingMore;
  final bool hasMore;
  final String searchQuery;
  final int page;
  final DateTime startDate;
  final DateTime endDate;

  PurchasesState({
    this.purchases = const [],
    this.isInitialLoad = true,
    this.isSearching = false,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.searchQuery = '',
    this.page = 0,
    required this.startDate,
    required this.endDate,
  });

  PurchasesState copyWith({
    List<Map<String, dynamic>>? purchases,
    bool? isInitialLoad,
    bool? isSearching,
    bool? isFetchingMore,
    bool? hasMore,
    String? searchQuery,
    int? page,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return PurchasesState(
      purchases: purchases ?? this.purchases,
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

class PurchasesNotifier extends StateNotifier<PurchasesState> {
  final Ref ref;
  Timer? _debounceTimer;

  PurchasesNotifier(this.ref) : super(PurchasesState(
    startDate: DateTime.now().subtract(const Duration(days: 30)),
    endDate: DateTime.now(),
  )) {
    ref.listen<String?>(activeBranchIdProvider, (previous, next) {
      if (next != null && next != previous) fetchInitialPurchases();
    });

    if (ref.read(activeBranchIdProvider) != null) {
      fetchInitialPurchases();
    } else {
      state = state.copyWith(isInitialLoad: false);
    }
  }

  Future<void> fetchInitialPurchases() async {
    state = state.copyWith(isInitialLoad: true, page: 0, hasMore: true, purchases: []);
    await _fetchData();
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query, isSearching: true);
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      state = state.copyWith(page: 0, hasMore: true, purchases: []);
      await _fetchData();
    });
  }

  void onDateRangeChanged(DateTime start, DateTime end) {
    state = state.copyWith(startDate: start, endDate: end);
    fetchInitialPurchases();
  }

  Future<void> loadMore() async {
    if (state.isFetchingMore || !state.hasMore || state.isInitialLoad || state.isSearching) return;
    state = state.copyWith(isFetchingMore: true, page: state.page + 1);
    await _fetchData(isLoadMore: true);
  }

  Future<void> _fetchData({bool isLoadMore = false}) async {
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final branchId = ref.read(activeBranchIdProvider);
      
      if (branchId == null) {
        state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
        return;
      }

      final newPurchases = await repo.getPurchasesHistory(
        query: state.searchQuery,
        page: state.page,
        branchId: branchId,
        startDate: state.startDate,
        endDate: state.endDate,
      );

      state = state.copyWith(
        purchases: isLoadMore ? [...state.purchases, ...newPurchases] : newPurchases,
        hasMore: newPurchases.length == 15, 
        isInitialLoad: false,
        isSearching: false,
        isFetchingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isInitialLoad: false, isFetchingMore: false, isSearching: false);
    }
  }

  void refreshAfterDelete() {
    if (state.searchQuery.isNotEmpty) {
      onSearchChanged(state.searchQuery);
    } else {
      fetchInitialPurchases();
    }
  }
}

final purchasesProvider = StateNotifierProvider<PurchasesNotifier, PurchasesState>((ref) {
  return PurchasesNotifier(ref);
});