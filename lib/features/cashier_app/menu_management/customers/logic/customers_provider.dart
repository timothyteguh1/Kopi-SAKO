import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/customers_repository.dart';

class CustomersState {
  final List<Map<String, dynamic>> customers;
  final bool isLoading;
  final bool isSearching;
  final String searchQuery;

  CustomersState({
    this.customers = const [],
    this.isLoading = true,
    this.isSearching = false,
    this.searchQuery = '',
  });

  CustomersState copyWith({
    List<Map<String, dynamic>>? customers,
    bool? isLoading,
    bool? isSearching,
    String? searchQuery,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  final Ref ref;
  Timer? _debounceTimer;

  CustomersNotifier(this.ref) : super(CustomersState()) {
    fetchCustomers();
  }

  Future<void> fetchCustomers() async {
    // Memunculkan skeleton loading untuk pemuatan awal
    state = state.copyWith(isLoading: true, customers: []);
    await _fetchData();
  }

  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query, isSearching: true);
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _fetchData();
    });
  }

  // FUNGSI BARU: Tarik ke Bawah (Pull-to-Refresh)
  // Tidak memicu isLoading menjadi true, sehingga skeleton tidak muncul lagi
  Future<void> refreshManual() async {
    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final repo = ref.read(customersRepositoryProvider);
      final data = await repo.getCustomers(query: state.searchQuery);
      state = state.copyWith(customers: data, isLoading: false, isSearching: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, isSearching: false);
    }
  }

  void refreshData() {
    fetchCustomers();
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, CustomersState>((ref) {
  return CustomersNotifier(ref);
});