import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/utils/pop_up_helper.dart';
import '../data/cashiers_admin_repository.dart';
import '../data/branches_admin_repository.dart';

final cashiersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(cashiersAdminRepoProvider).getCashiers();
});

class CashiersAdminScreen extends ConsumerWidget {
  const CashiersAdminScreen({super.key});

  void _showAssignBranchDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> cashier) async {
    final branchRepo = ref.read(branchesAdminRepoProvider);
    final cashierRepo = ref.read(cashiersAdminRepoProvider);

    // Tampilkan loading awal
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
    
    try {
      final branches = await branchRepo.getBranches();
      if (!context.mounted) return;
      // KUNCI PERBAIKAN: Gunakan rootNavigator
      Navigator.of(context, rootNavigator: true).pop(); // Tutup loading awal

      String? selectedBranchId = cashier['branch_id'];
      bool isSaving = false;

      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (ctx) => StatefulBuilder(
          builder: (contextDialog, setStateDialog) {
            return AlertDialog(
              title: const Text('Tugaskan Kasir', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pilih cabang untuk ${cashier['full_name']}:'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBranchId,
                    decoration: InputDecoration(filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    hint: const Text('Pilih Cabang'),
                    items: branches.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['name']))).toList(),
                    onChanged: isSaving ? null : (val) => setStateDialog(() => selectedBranchId = val),
                  ),
                ],
              ),
              actions: [
                if (!isSaving) // Sembunyikan Batal saat proses simpan berjalan
                  TextButton(
                    // KUNCI PERBAIKAN: Gunakan rootNavigator untuk batal
                    onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), 
                    child: const Text('Batal', style: TextStyle(color: Colors.grey))
                  ),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: isSaving ? null : () async {
                    if (selectedBranchId == null) return;
                    
                    setStateDialog(() => isSaving = true);

                    try {
                      await cashierRepo.assignBranch(cashier['id'], selectedBranchId);
                      
                      if (ctx.mounted) {
                        // KUNCI PERBAIKAN: Gunakan rootNavigator saat berhasil
                        Navigator.of(ctx, rootNavigator: true).pop(); 
                      }

                      if (context.mounted) {
                        ref.invalidate(cashiersProvider); 
                        showSakoPopUp(context, title: 'Berhasil', message: 'Kasir berhasil ditugaskan ke cabang.', isError: false);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setStateDialog(() => isSaving = false); 
                        showSakoPopUp(ctx, title: 'Gagal', message: e.toString(), isError: true);
                      }
                    }
                  },
                  child: isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      // KUNCI PERBAIKAN: Gunakan rootNavigator saat error awal
      Navigator.of(context, rootNavigator: true).pop(); 
      showSakoPopUp(context, title: 'Gagal', message: 'Gagal memuat daftar cabang: $e', isError: true);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> cashier) {
    final cashierRepo = ref.read(cashiersAdminRepoProvider);
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (contextDialog, setStateDialog) {
          return AlertDialog(
            title: const Text('Cabut Akses Kasir?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: Text('Apakah Anda yakin ingin menghapus akses login ${cashier['full_name']}?\n\nNama kasir pada nota riwayat transaksi akan tetap dipertahankan.'),
            actions: [
              if (!isDeleting)
                TextButton(
                  // KUNCI PERBAIKAN: Gunakan rootNavigator untuk batal
                  onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), 
                  child: const Text('Batal', style: TextStyle(color: Colors.grey))
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isDeleting ? null : () async {
                  setStateDialog(() => isDeleting = true);
                  try {
                    await cashierRepo.deleteCashier(cashier['id']);
                    // KUNCI PERBAIKAN: Gunakan rootNavigator
                    if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop(); 
                    if (context.mounted) {
                      ref.invalidate(cashiersProvider);
                      showSakoPopUp(context, title: 'Terhapus', message: 'Akses login kasir berhasil dicabut.', isError: false);
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      setStateDialog(() => isDeleting = false);
                      showSakoPopUp(ctx, title: 'Gagal', message: e.toString(), isError: true);
                    }
                  }
                },
                child: isDeleting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Ya, Hapus Akses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _resetPassword(BuildContext context, WidgetRef ref, Map<String, dynamic> cashier) async {
    final email = cashier['recovery_email'];
    if (email == null) return;
    final cashierRepo = ref.read(cashiersAdminRepoProvider);

    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)));
    try {
      await cashierRepo.resetPassword(email);
      if (context.mounted) {
        // KUNCI PERBAIKAN: Gunakan rootNavigator
        Navigator.of(context, rootNavigator: true).pop();
        showSakoPopUp(context, title: 'Terkirim', message: 'Link reset sandi telah dikirim ke $email', isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        // KUNCI PERBAIKAN: Gunakan rootNavigator
        Navigator.of(context, rootNavigator: true).pop();
        showSakoPopUp(context, title: 'Gagal', message: e.toString(), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiersAsync = ref.watch(cashiersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
        title: const Text('Kelola Kasir', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900)),
      ),
      body: cashiersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
        error: (e, s) => Center(child: Text('Gagal memuat kasir: $e')),
        data: (cashiers) {
          return RefreshIndicator(
            color: AppColors.primaryOrange,
            onRefresh: () async => ref.invalidate(cashiersProvider),
            child: cashiers.isEmpty 
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('Belum ada kasir yang terdaftar.', style: TextStyle(color: Colors.grey))),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: cashiers.length,
                  itemBuilder: (context, index) {
                    final cashier = cashiers[index];
                    final isAssigned = cashier['branch_id'] != null;
                    final branchName = cashier['branches'] != null ? cashier['branches']['name'] : 'Belum Ditugaskan';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite, 
                        borderRadius: BorderRadius.circular(16), 
                        border: Border.all(color: isAssigned ? Colors.grey.shade200 : AppColors.primaryOrange.withOpacity(0.5))
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: isAssigned ? Colors.blue.shade50 : AppColors.primaryOrange.withOpacity(0.1),
                          child: Icon(Icons.person, color: isAssigned ? Colors.blue : AppColors.primaryOrange),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(cashier['full_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                            if (!isAssigned) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(8)), child: const Text('Menunggu ACC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. HP: ${cashier['phone_number'] ?? '-'}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.storefront, size: 14, color: isAssigned ? Colors.green : Colors.red),
                                  const SizedBox(width: 4),
                                  Text(branchName, style: TextStyle(color: isAssigned ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'assign') _showAssignBranchDialog(context, ref, cashier);
                            if (val == 'reset') _resetPassword(context, ref, cashier);
                            if (val == 'delete') _confirmDelete(context, ref, cashier);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'assign', child: Text(isAssigned ? 'Pindah Cabang' : 'Tugaskan (ACC)')),
                            const PopupMenuItem(value: 'reset', child: Text('Reset Kata Sandi')),
                            const PopupMenuDivider(),
                            const PopupMenuItem(value: 'delete', child: Text('Cabut Akses', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
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