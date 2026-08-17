import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/utils/pop_up_helper.dart';
import '../data/branches_admin_repository.dart';

// KUNCI PERBAIKAN: Import provider dashboard agar kita bisa me-reset memorinya
import '../../../dashboard/logic/dashboard_provider.dart';

final branchesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(branchesAdminRepoProvider).getBranches();
});

class BranchesAdminScreen extends ConsumerWidget {
  const BranchesAdminScreen({super.key});

  void _showBranchDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existingBranch}) {
    final nameCtrl = TextEditingController(text: existingBranch?['name'] ?? '');
    final addressCtrl = TextEditingController(text: existingBranch?['address'] ?? '');
    final waCtrl = TextEditingController(text: existingBranch?['whatsapp_number'] ?? ''); 
    final isEdit = existingBranch != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Cabang' : 'Tambah Cabang Baru', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Cabang', 
                  filled: true, 
                  fillColor: Colors.grey.shade100, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor WhatsApp', 
                  hintText: 'Contoh: 081234567890',
                  filled: true, 
                  fillColor: Colors.grey.shade100, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alamat Lengkap', 
                  filled: true, 
                  fillColor: Colors.grey.shade100, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () async {
              final String finalName = nameCtrl.text.trim();
              final String finalAddress = addressCtrl.text.trim().isEmpty ? '-' : addressCtrl.text.trim();
              final String finalWa = waCtrl.text.trim().isEmpty ? '-' : waCtrl.text.trim();

              if (finalName.isEmpty) {
                 showSakoPopUp(ctx, title: 'Validasi', message: 'Nama cabang tidak boleh kosong.', isError: true);
                 return;
              }
              
              showDialog(context: ctx, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
              
              try {
                if (isEdit) {
                  await ref.read(branchesAdminRepoProvider).updateBranch(existingBranch['id'], finalName, finalAddress, finalWa);
                } else {
                  await ref.read(branchesAdminRepoProvider).addBranch(finalName, finalAddress, finalWa);
                }
                
                if (ctx.mounted) {
                  Navigator.pop(ctx); 
                  Navigator.pop(ctx); 
                  ref.invalidate(branchesProvider); 
                  // Refresh daftar dropdown di dashboard jika ada penambahan/perubahan nama
                  ref.invalidate(branchesListProvider); 
                  showSakoPopUp(context, title: 'Berhasil', message: isEdit ? 'Cabang diperbarui.' : 'Cabang baru ditambahkan.', isError: false);
                }
              } catch (e) {
                if (ctx.mounted) {
                  Navigator.pop(ctx); 
                  showSakoPopUp(ctx, title: 'Gagal Menyimpan', message: e.toString(), isError: true);
                }
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmToggleActive(BuildContext context, WidgetRef ref, Map<String, dynamic> branch) {
    final String branchName = branch['name'] ?? 'Cabang ini';
    final bool isActive = branch['is_active'] ?? true;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Nonaktifkan Cabang?' : 'Aktifkan Cabang?', style: TextStyle(color: isActive ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
        content: Text(isActive 
          ? 'Apakah Anda yakin ingin menonaktifkan $branchName?\n\nCabang akan disembunyikan dari aplikasi operasional kasir.'
          : 'Apakah Anda yakin ingin mengaktifkan kembali $branchName?\n\nCabang ini akan kembali beroperasi normal di aplikasi kasir.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.red : Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(branchesAdminRepoProvider).toggleBranchActive(branch['id'], isActive);
                
                // KUNCI PERBAIKAN: Hapus memori Dashboard jika cabang yang sedang Anda buka barusan dinonaktifkan!
                if (isActive && ref.read(activeBranchIdProvider) == branch['id']) {
                  ref.read(activeBranchIdProvider.notifier).state = null;
                  ref.read(activeBranchNameProvider.notifier).state = 'Memuat...';
                }

                ref.invalidate(branchesProvider); // Refresh list di admin
                ref.invalidate(branchesListProvider); // Refresh dropdown di beranda
                ref.invalidate(branchInitializationProvider); // Paksa dashboard milih cabang baru
                
                if (context.mounted) {
                  showSakoPopUp(context, title: 'Berhasil', message: isActive ? 'Cabang dinonaktifkan.' : 'Cabang diaktifkan kembali.', isError: false);
                }
              } catch (e) {
                if (context.mounted) showSakoPopUp(context, title: 'Gagal', message: e.toString(), isError: true);
              }
            },
            child: Text(isActive ? 'Ya, Nonaktifkan' : 'Ya, Aktifkan', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('Kelola Cabang', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryOrange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Cabang Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showBranchDialog(context, ref),
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
        error: (e, s) => Center(child: Text('Gagal memuat cabang: $e')),
        data: (branches) {
          return RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: () async {
              ref.invalidate(branchesProvider);
            },
            child: branches.isEmpty 
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Belum ada cabang. Silakan tambah cabang baru.', style: TextStyle(color: Colors.grey))),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: branches.length,
                  itemBuilder: (context, index) {
                    final branch = branches[index];
                    
                    final String branchName = branch['name'] ?? 'Cabang Tanpa Nama';
                    final String branchAddress = branch['address'] ?? '-';
                    final String branchWa = branch['whatsapp_number'] ?? '-';
                    final bool isActive = branch['is_active'] ?? true; 

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.surfaceWhite : Colors.grey.shade200, 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primaryOrange.withOpacity(0.1) : Colors.grey.shade300, 
                            shape: BoxShape.circle
                          ),
                          child: Icon(Icons.storefront, color: isActive ? AppColors.primaryOrange : Colors.grey.shade600),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(branchName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isActive ? AppColors.textDark : Colors.grey.shade600))),
                            if (!isActive) 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8)), 
                                child: const Text('NONAKTIF', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                              )
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.phone_android, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(branchWa, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(branchAddress, style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                ],
                              ),
                            ],
                          )
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'edit') _showBranchDialog(context, ref, existingBranch: branch);
                            if (val == 'toggle_active') _confirmToggleActive(context, ref, branch);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit Cabang')),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: 'toggle_active', 
                              child: Text(
                                isActive ? 'Nonaktifkan Cabang' : 'Aktifkan Cabang', 
                                style: TextStyle(color: isActive ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                              )
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          );
        },
      ),
    );
  }
}