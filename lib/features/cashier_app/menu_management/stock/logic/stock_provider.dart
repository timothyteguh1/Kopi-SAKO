import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/stock_repository.dart';

import 'package:kopi_sako/features/cashier_app/dashboard/logic/dashboard_provider.dart';

final stockRepositoryProvider = Provider((ref) => StockRepository());
final stockSearchQueryProvider = StateProvider<String>((ref) => '');

final branchStockProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) return [];

  final repo = ref.watch(stockRepositoryProvider);
  final allProducts = await repo.getProductsWithStock(branchId);
  
  final query = ref.watch(stockSearchQueryProvider).toLowerCase();
  if (query.isEmpty) return allProducts;

  return allProducts.where((product) {
    final name = (product['name'] ?? '').toString().toLowerCase();
    return name.contains(query);
  }).toList();
});

final stockHistoryProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, productId) async {
  final branchId = ref.watch(activeBranchIdProvider);
  if (branchId == null) return [];
  
  final repo = ref.watch(stockRepositoryProvider);
  return repo.getStockHistory(branchId, productId);
});