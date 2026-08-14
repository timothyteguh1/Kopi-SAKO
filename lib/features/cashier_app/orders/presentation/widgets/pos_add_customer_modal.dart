import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kopi_sako/features/cashier_app/orders/presentation/pos_menu_screen.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../logic/orders_provider.dart';

class PosAddCustomerModal extends ConsumerStatefulWidget {
  const PosAddCustomerModal({super.key});

  @override
  ConsumerState<PosAddCustomerModal> createState() => _PosAddCustomerModalState();
}

class _PosAddCustomerModalState extends ConsumerState<PosAddCustomerModal> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  bool isLoading = false;

  // Cari fungsi _handleSave dan GANTI dengan yang ini:
  Future<void> _handleSave() async {
    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama dan Nomor HP wajib diisi!')));
      return;
    }

    setState(() => isLoading = true);
    try {
      // 1. Simpan dan tangkap datanya
      final newCustomer = await ref.read(ordersRepositoryProvider).registerNewCustomer(nameCtrl.text.trim(), phoneCtrl.text.trim());
      ref.invalidate(posCustomerResultsProvider); 
      
      if (context.mounted) {
        // 2. Tutup modal pendaftaran
        Navigator.pop(context); 
        
        // 3. Kunci pelanggan baru ke dalam State dan kosongkan keranjang
        ref.read(selectedCustomerProvider.notifier).state = newCustomer;
        ref.read(cartProvider.notifier).clearCart();
        
        // 4. OTOMATIS LEMPAR KE HALAMAN MENU!
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const PosMenuScreen())
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daftar Pelanggan Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 16),
              TextField(controller: nameCtrl, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Nama Lengkap', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Nomor WhatsApp', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isLoading ? null : _handleSave,
                  child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Simpan Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}