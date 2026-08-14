import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../logic/orders_provider.dart';
import 'widgets/pos_add_customer_modal.dart';
import 'pos_menu_screen.dart'; 

class PosCustomerScreen extends ConsumerStatefulWidget {
  const PosCustomerScreen({super.key});

  @override
  ConsumerState<PosCustomerScreen> createState() => _PosCustomerScreenState();
}

class _PosCustomerScreenState extends ConsumerState<PosCustomerScreen> {
  Timer? _debounce;
  final searchCtrl = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(posSearchQueryProvider.notifier).state = query;
    });
  }

  void _proceedToMenu(BuildContext context, Map<String, dynamic> customerData) {
    ref.read(selectedCustomerProvider.notifier).state = customerData;
    // Memastikan transisi menggunakan rootNavigator agar menimpa bottom bar
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const PosMenuScreen())
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(posCustomerResultsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('Identifikasi Pelanggan', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: AppColors.primaryOrange),
            tooltip: 'Tambah Pelanggan Baru',
            onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => const PosAddCustomerModal()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: TextField(
              controller: searchCtrl,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Cari Nama atau Nomor HP...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { searchCtrl.clear(); _onSearchChanged(''); }) : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: () => _proceedToMenu(context, {'is_guest': true, 'full_name': 'Pelanggan Umum (Guest)'}),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade200)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_walk, color: Colors.blue),
                    SizedBox(width: 8),
                    // KUNCI PERBAIKAN: Gunakan Flexible agar teks bisa membungkus ke bawah
                    Flexible(
                      child: Text(
                        'Gunakan Pelanggan Umum (Tanpa Poin)', 
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: () async {
                ref.invalidate(posCustomerResultsProvider);
                return await ref.read(posCustomerResultsProvider.future);
              },
              child: customersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                error: (err, stack) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(), 
                  children: [const SizedBox(height: 100), Center(child: Text('Error: $err'))]
                ),
                data: (customers) {
                  if (customers.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        Center(
                          child: Text(
                            searchCtrl.text.isNotEmpty 
                                ? 'Pelanggan tidak ditemukan. Tekan tombol (+) di atas.' 
                                : 'Belum ada data. Tarik ke bawah untuk memuat ulang.', 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(color: Colors.grey)
                          )
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: customers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = customers[index];
                      return ListTile(
                        onTap: () => _proceedToMenu(context, customer),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: AppColors.surfaceWhite,
                        leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: const Icon(Icons.person, color: AppColors.primaryOrange)),
                        title: Text(customer['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(customer['phone_number'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${customer['points'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange, fontSize: 16)),
                            const Text('Poin', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}