import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../dashboard/logic/printer_provider.dart';

class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerProvider);
    final printerNotifier = ref.read(printerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        title: const Text('Pengaturan Printer', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          // KOTAK STATUS KONEKSI
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: printerState.isConnected ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: printerState.isConnected ? Colors.green : Colors.red),
            ),
            child: Row(
              children: [
                Icon(
                  printerState.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: printerState.isConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printerState.isConnected ? 'Terhubung' : 'Terputus',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: printerState.isConnected ? Colors.green : Colors.red),
                      ),
                      if (printerState.selectedDevice != null)
                        Text(
                          printerState.selectedDevice!.name ?? 'Printer Kasir',
                          style: TextStyle(fontSize: 14, color: printerState.isConnected ? Colors.green.shade700 : Colors.red.shade700),
                        )
                    ],
                  ),
                ),
                if (printerState.isConnected)
                  TextButton(
                    onPressed: () => printerNotifier.disconnect(),
                    child: const Text('Putuskan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Perangkat Bluetooth Tersedia', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark, fontSize: 14)),
            ),
          ),
          
          // DAFTAR PERANGKAT BLUETOOTH
          Expanded(
            child: printerState.devices.isEmpty
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('Tidak ada perangkat Bluetooth ditemukan.\n\nPastikan Bluetooth HP menyala dan printer sudah di-pairing (disandingkan) di pengaturan HP Anda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ))
                : ListView.builder(
                    itemCount: printerState.devices.length,
                    itemBuilder: (context, index) {
                      final device = printerState.devices[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200)
                        ),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.fieldBackground,
                            child: Icon(Icons.print, color: AppColors.primaryOrange),
                          ),
                          title: Text(device.name ?? 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(device.address ?? ''),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () async {
                            // Munculkan Loading
                            showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
                            
                            // Eksekusi Sambung
                            final success = await printerNotifier.connect(device);
                            
                            // Tutup Loading
                            if (context.mounted) Navigator.pop(context); 
                            
                            // Munculkan Hasil
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Berhasil terhubung ke ${device.name}' : 'Gagal menghubungkan ke ${device.name}. Pastikan printer menyala.'),
                                  backgroundColor: success ? Colors.green : Colors.red,
                                )
                              );
                            }
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