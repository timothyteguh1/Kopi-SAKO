import 'package:flutter_riverpod/flutter_riverpod.dart';
// TAMBAHAN WAJIB: Mengimpor legacy.dart untuk memperbaiki error StateProvider
import 'package:flutter_riverpod/legacy.dart'; 
import '../data/orders_repository.dart';

final ordersRepositoryProvider = Provider((ref) => OrdersRepository());

// --- STATE PELANGGAN ---
// StateProvider sekarang sudah dikenali berkat import legacy.dart di atas
final posSearchQueryProvider = StateProvider<String>((ref) => '');

final posCustomerResultsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(posSearchQueryProvider);
  return ref.watch(ordersRepositoryProvider).searchCustomers(query);
});

final selectedCustomerProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

// --- STATE KERANJANG ---
class CartNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  CartNotifier() : super([]);

  void addItem(Map<String, dynamic> product) {
    final existingIndex = state.indexWhere((item) => item['id'] == product['id']);
    if (existingIndex >= 0) {
      // Pastikan kasir tidak bisa menambah item melebihi stok yang ada
      if (state[existingIndex]['qty'] < product['current_stock']) {
        final newState = [...state];
        newState[existingIndex]['qty']++;
        state = newState;
      }
    } else {
      if (product['current_stock'] > 0) {
        state = [...state, {...product, 'qty': 1}];
      }
    }
  }

  void removeItem(String productId) {
    final existingIndex = state.indexWhere((item) => item['id'] == productId);
    if (existingIndex >= 0) {
      final newState = [...state];
      if (newState[existingIndex]['qty'] > 1) {
        newState[existingIndex]['qty']--;
      } else {
        newState.removeAt(existingIndex);
      }
      state = newState;
    }
  }

  void clearCart() => state = [];
  
  int get totalAmount => state.fold(0, (sum, item) => sum + ((item['price'] as int) * (item['qty'] as int)));
}

final cartProvider = StateNotifierProvider<CartNotifier, List<Map<String, dynamic>>>((ref) => CartNotifier());

final posMenuProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, branchId) async {
  return ref.watch(ordersRepositoryProvider).getActiveMenuWithStock(branchId);
});