import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; // Untuk membuka WhatsApp

import '../../../../core/theme/app_colors.dart';
import '../../radar/logic/radar_provider.dart';
import '../logic/menu_provider.dart';

class BranchMenuSheet extends ConsumerWidget {
  final RadarBranch branch;
  const BranchMenuSheet({super.key, required this.branch});

  String formatRupiah(int number) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(number);
  }

  // Logika membuka WhatsApp
  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WA cabang ini belum tersedia.')));
      return;
    }
    
    // Ubah awalan '0' menjadi '62'
    String formattedPhone = phone;
    if (phone.startsWith('0')) {
      formattedPhone = '62${phone.substring(1)}';
    } else if (phone.startsWith('+62')) {
      formattedPhone = phone.substring(1); // Hilangkan '+'
    }

    final String message = "Halo SAKO ${branch.name}, saya ingin pesan kopi dari titik Radar saya!";
    final Uri url = Uri.parse('https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal membuka WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(branchMenuProvider(branch.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.6, 
      minChildSize: 0.5,
      maxChildSize: 0.95, 
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // --- HEADER GEROBAK DENGAN TOMBOL WA ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(branch.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.delivery_dining, size: 16, color: AppColors.primaryOrange),
                                  const SizedBox(width: 4),
                                  Text('Jarak: ${branch.distanceInMeters} m', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // TOMBOL WA KASIR
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Warna khas WA
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: () => _openWhatsApp(context, branch.phone),
                          icon: const Icon(Icons.chat, color: Colors.white, size: 18),
                          label: const Text('Chat Kasir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ],
                ),
              ),

              // --- DAFTAR MENU ---
              Expanded(
                child: menuAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                  error: (err, stack) => Center(child: Text('Gagal memuat menu:\n$err', textAlign: TextAlign.center)),
                  data: (menuItems) {
                    if (menuItems.isEmpty) return Center(child: Text('Stok gerobak ini sedang kosong.', style: TextStyle(color: Colors.grey.shade600)));

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      itemCount: menuItems.length,
                      separatorBuilder: (context, index) => const Divider(height: 32),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        final product = item['products'];
                        final stock = item['quantity'] ?? 0; 
                        final price = product['price'] ?? 0;
                        final imageUrl = product['image_url'];

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: imageUrl != null
                                  ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildFallbackImage())
                                  : _buildFallbackImage(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product['name'] ?? 'Kopi SAKO', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(formatRupiah(price), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryOrange)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text('Sisa $stock', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // TOMBOL PESAN DIHAPUS DARI SINI
                          ],
                        );
                      },
                    );
                  }
                )
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackImage() {
    return Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.local_cafe, color: Colors.grey, size: 32));
  }
}