import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // IMPORT BARU
import '../../../../../../core/theme/app_colors.dart';
import '../../logic/stock_provider.dart';

class AddProductModal extends ConsumerStatefulWidget {
  const AddProductModal({super.key});

  @override
  ConsumerState<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends ConsumerState<AddProductModal> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: '0');
  final costCtrl = TextEditingController(text: '0');
  bool isForSale = true;
  bool isLoading = false;

  // Variabel untuk menyimpan gambar
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  // Fungsi pilih dan kompres gambar
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    // KUNCI OPTIMASI: Batasi lebar/tinggi 500px dan kualitas 60%
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      maxWidth: 500, 
      maxHeight: 500, 
      imageQuality: 60,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = image.name;
      });
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
              const Text('Tambah Produk Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark)),
              const SizedBox(height: 16),
              
              // AREA PILIH GAMBAR
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300, strokeAlign: BorderSide.strokeAlignOutside)),
                    child: _selectedImageBytes != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover))
                        : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), SizedBox(height: 4), Text('Foto', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Nama Barang/Menu', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga Modal (Rp)', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga Jual (Rp)', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(title: const Text('Menu untuk Dijual?'), subtitle: const Text('Matikan jika ini hanya bahan baku internal.'), value: isForSale, activeColor: AppColors.primaryOrange, onChanged: (val) => setState(() => isForSale = val)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: isLoading ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    setState(() => isLoading = true);
                    try {
                      final repo = ref.read(stockRepositoryProvider);
                      String? uploadedImageUrl;

                      // Jika ada gambar, upload dulu sebelum simpan data
                      if (_selectedImageBytes != null && _selectedImageName != null) {
                        uploadedImageUrl = await repo.uploadProductImage(_selectedImageName!, _selectedImageBytes!);
                      }

                      await repo.addProduct(
                        name: nameCtrl.text,
                        price: int.parse(priceCtrl.text.isEmpty ? '0' : priceCtrl.text),
                        costPrice: int.parse(costCtrl.text.isEmpty ? '0' : costCtrl.text),
                        isForSale: isForSale,
                        imageUrl: uploadedImageUrl, // Simpan link gambar ke Supabase
                      );
                      ref.invalidate(branchStockProvider);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      setState(() => isLoading = false);
                    }
                  },
                  child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Simpan Produk', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}