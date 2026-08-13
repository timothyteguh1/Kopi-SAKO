import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../../dashboard/logic/dashboard_provider.dart';
import '../../logic/stock_provider.dart';

class EditStockModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> product;
  const EditStockModal({super.key, required this.product});

  @override
  ConsumerState<EditStockModal> createState() => _EditStockModalState();
}

class _EditStockModalState extends ConsumerState<EditStockModal> {
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController costCtrl;
  final stockChangeCtrl = TextEditingController();
  final reasonCtrl = TextEditingController();

  bool isLoading = false;
  bool isAddingStock = true;
  int currentStock = 0;

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.product['name']);
    priceCtrl = TextEditingController(text: widget.product['price'].toString());
    costCtrl = TextEditingController(text: widget.product['cost_price'].toString());
    currentStock = widget.product['current_stock'] as int;
  }

  int _calculatePreviewStock() {
    final int inputQty = int.tryParse(stockChangeCtrl.text) ?? 0;
    return isAddingStock ? (currentStock + inputQty) : (currentStock - inputQty);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
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

  void _showDeleteConfirmation(BuildContext context, String productId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Produk?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Produk ini akan disembunyikan. Riwayat lama tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isLoading = true);
              try {
                await ref.read(stockRepositoryProvider).deleteProduct(productId);
                ref.invalidate(branchStockProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                setState(() => isLoading = false);
              }
            },
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final branchId = ref.read(activeBranchIdProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final inputQty = int.tryParse(stockChangeCtrl.text) ?? 0;

    if (inputQty != 0 && reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan wajib diisi!')));
      setState(() => isLoading = false);
      return;
    }

    final int finalStockChange = isAddingStock ? inputQty : -inputQty;
    final String safeMovementType = isAddingStock ? 'add' : 'subtract';

    try {
      final repo = ref.read(stockRepositoryProvider);
      String? uploadedImageUrl;

      if (_selectedImageBytes != null && _selectedImageName != null) {
        uploadedImageUrl = await repo.uploadProductImage(_selectedImageName!, _selectedImageBytes!);
      }

      await repo.updateProductAndStock(
        productId: widget.product['id'], branchId: branchId!, userId: userId!,
        name: nameCtrl.text, price: int.parse(priceCtrl.text), costPrice: int.parse(costCtrl.text),
        stockChange: finalStockChange, movementType: safeMovementType, reason: reasonCtrl.text,
        imageUrl: uploadedImageUrl,
      );
      
      ref.invalidate(branchStockProvider);
      ref.invalidate(stockHistoryProvider(widget.product['id']));
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int previewStock = _calculatePreviewStock();
    final bool isInvalid = previewStock < 0;
    final existingImageUrl = widget.product['image_url'];

    // KUNCI RESPONSIVITAS: Align & ConstrainedBox
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600), // Ukuran Universal HP & Tablet
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Material(
            color: AppColors.surfaceWhite,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Hanya mengambil tinggi layar sesuai kontennya
              children: [
                // --- 1. DRAG HANDLE (Indikator tarik tutup modal) ---
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // --- 2. AREA FORM (Yang bisa di-scroll tanpa merusak drag Modal) ---
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(), // Tarik ke bawah untuk menutup
                    // SafeArea manual agar tombol tidak tertutup navigasi iPhone/Android
                    padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('Edit: ${widget.product['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark), overflow: TextOverflow.ellipsis)),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _showDeleteConfirmation(context, widget.product['id']))
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              height: 100, width: 100,
                              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300, strokeAlign: BorderSide.strokeAlignOutside)),
                              child: _selectedImageBytes != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover))
                                  : (existingImageUrl != null && existingImageUrl.toString().isNotEmpty)
                                      ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(existingImageUrl, fit: BoxFit.cover))
                                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo, color: Colors.grey), SizedBox(height: 4), Text('Ubah Foto', style: TextStyle(fontSize: 12, color: Colors.grey))]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Nama Produk', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga Modal', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga Jual', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                          ],
                        ),
                        const Divider(height: 32),

                        const Text('Penyesuaian Stok Fisik', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isAddingStock = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: isAddingStock ? Colors.green.shade50 : Colors.grey.shade100, border: Border.all(color: isAddingStock ? Colors.green : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text('Tambah (+)', style: TextStyle(fontWeight: FontWeight.bold, color: isAddingStock ? Colors.green : Colors.grey))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isAddingStock = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(color: !isAddingStock ? Colors.red.shade50 : Colors.grey.shade100, border: Border.all(color: !isAddingStock ? Colors.red : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text('Kurangi (-)', style: TextStyle(fontWeight: FontWeight.bold, color: !isAddingStock ? Colors.red : Colors.grey))),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(flex: 2, child: TextField(controller: stockChangeCtrl, keyboardType: TextInputType.number, onChanged: (val) => setState(() {}), decoration: InputDecoration(labelText: 'Jumlah', hintText: '0', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: TextField(controller: reasonCtrl, decoration: InputDecoration(labelText: 'Alasan (Wajib)', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: isInvalid ? Colors.red.shade50 : Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Stok Awal: $currentStock', style: TextStyle(color: Colors.grey.shade700)),
                                  Icon(Icons.arrow_forward, size: 16, color: isInvalid ? Colors.red : Colors.blue),
                                  Text('Menjadi: $previewStock', style: TextStyle(fontWeight: FontWeight.w900, color: isInvalid ? Colors.red : Colors.blue, fontSize: 16)),
                                ],
                              ),
                              if (isInvalid) ...[
                                const SizedBox(height: 6),
                                const Text('Stok tidak mencukupi!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: (isLoading || isInvalid) ? null : _handleSave,
                            child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : Text(isInvalid ? 'Stok Tidak Cukup' : 'Simpan Perubahan', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}