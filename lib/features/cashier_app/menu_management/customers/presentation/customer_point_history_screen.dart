import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kopi_sako/core/theme/app_colors.dart';
import '../data/customers_repository.dart';

final pointHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, customerId) async {
  return ref.read(customersRepositoryProvider).getPointHistory(customerId);
});

class CustomerPointHistoryScreen extends ConsumerWidget {
  final String customerId;
  final String customerName;
  final int currentPoints;

  const CustomerPointHistoryScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentPoints,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(pointHistoryProvider(customerId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Riwayat Poin', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900, fontSize: 18)),
            Text(customerName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Text('Total Poin Aktif', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Text('$currentPoints Pts', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Aktivitas Terbaru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
              error: (e, s) => Center(child: Text('Gagal memuat riwayat: $e', style: const TextStyle(color: Colors.red))),
              data: (history) {
                if (history.isEmpty) {
                  return Center(child: Text('Belum ada pergerakan poin.', style: TextStyle(color: Colors.grey.shade500)));
                }

                // KUNCI PERBAIKAN: Gunakan RefreshIndicator
                return RefreshIndicator(
                  color: AppColors.primaryOrange,
                  onRefresh: () async {
                    // Memaksa provider untuk mengambil data ulang dari Supabase
                    return ref.refresh(pointHistoryProvider(customerId).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final int pointsChanged = item['points_changed'] ?? 0;
                      final bool isAddition = pointsChanged > 0;
                      final String reason = item['reason'] ?? 'Transaksi';
                      final DateTime date = DateTime.parse(item['created_at']).toLocal();
                      final String strDate = DateFormat('dd MMM yyyy, HH:mm', 'id').format(date);
                      
                      String adminName = 'Sistem';
                      if (item['profiles'] != null && item['profiles']['full_name'] != null) {
                        adminName = item['profiles']['full_name'];
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAddition ? Colors.green.shade50 : Colors.red.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAddition ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                                color: isAddition ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                                  const SizedBox(height: 4),
                                  Text('$strDate • Oleh: $adminName', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              '${isAddition ? '+' : ''}$pointsChanged',
                              style: TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 16, 
                                color: isAddition ? Colors.green : Colors.red
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}