import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../logic/stock_provider.dart';

class StockHistoryModal extends ConsumerWidget {
  final String productId;
  final String productName;

  const StockHistoryModal({super.key, required this.productId, required this.productName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(stockHistoryProvider(productId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 16),
                Text('Riwayat Stok: $productName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (movements) {
                if (movements.isEmpty) return const Center(child: Text('Belum ada riwayat pergerakan stok.'));

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: movements.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final move = movements[index];
                    final date = DateTime.parse(move['created_at']).toLocal();
                    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
                    final type = move['type'];
                    final userName = move['profiles']?['full_name'] ?? 'Sistem';

                    final stockBefore = move['stock_before'] ?? 0;
                    final stockAfter = move['stock_after'] ?? 0;
                    final qtyChanged = move['quantity_changed'] ?? 0;

                    final isAdding = type == 'add';
                    final isSelling = type == 'sold';

                    Color iconColor = Colors.grey;
                    IconData iconData = Icons.swap_horiz;
                    String actionText = 'Penyesuaian';

                    if (isAdding) {
                      iconColor = Colors.green; iconData = Icons.add_circle; actionText = 'Stok Masuk';
                    } else if (isSelling) {
                      iconColor = Colors.orange; iconData = Icons.shopping_cart; actionText = 'Terjual';
                    } else if (type == 'subtract') {
                      iconColor = Colors.red; iconData = Icons.remove_circle; actionText = 'Stok Keluar';
                    } else if (type == 'correction') {
                      iconColor = Colors.blue; iconData = Icons.build_circle; actionText = 'Koreksi';
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(iconData, color: iconColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(move['description'] ?? actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Oleh: $userName', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              Text(formattedDate, style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),

                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$stockBefore', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey)),
                                    Text('$stockAfter', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                                    const SizedBox(width: 12),
                                    Text('(${isAdding ? '+' : '-'}$qtyChanged)', style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}