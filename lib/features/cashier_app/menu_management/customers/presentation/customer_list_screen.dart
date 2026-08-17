import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// MUNDUR 5 TINGKAT KE FOLDER LIB
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/utils/pop_up_helper.dart';

// MUNDUR 4 TINGKAT KE FOLDER FEATURES
import '../../../../auth/logic/auth_provider.dart';

import '../data/customers_repository.dart';
import '../logic/customers_provider.dart';
import 'customer_point_history_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- AKSI ADMIN: EDIT NAMA ---
  Future<void> _editName(
    Map<String, dynamic> customer,
    String currentName,
  ) async {
    final TextEditingController nameCtrl = TextEditingController(
      text: currentName,
    );

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Edit Nama Pelanggan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Nama Baru',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && nameCtrl.text.trim().isNotEmpty) {
      _showLoading();
      try {
        await ref
            .read(customersRepositoryProvider)
            .updateCustomerName(customer['id'], nameCtrl.text.trim());
        _hideLoading();
        await ref
            .read(customersProvider.notifier)
            .refreshManual(); 
        showSakoPopUp(
          context,
          title: 'Berhasil',
          message: 'Nama pelanggan telah diperbarui.',
          isError: false,
        );
      } catch (e) {
        _hideLoading();
        showSakoPopUp(
          context,
          title: 'Gagal',
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  // --- AKSI ADMIN: EDIT POIN ---
  Future<void> _editPoints(
    Map<String, dynamic> customer,
    int currentPoints,
  ) async {
    final TextEditingController pointsCtrl = TextEditingController(
      text: currentPoints.toString(),
    );

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Ubah Poin Pelanggan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: pointsCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total Poin Baru',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final int newPoints = int.tryParse(pointsCtrl.text) ?? currentPoints;
      if (newPoints == currentPoints) return;

      _showLoading();
      try {
        final adminId = Supabase.instance.client.auth.currentUser?.id;
        await ref
            .read(customersRepositoryProvider)
            .updateCustomerPoints(
              customerId: customer['id'],
              newPoints: newPoints,
              adminId: adminId!,
            );
        _hideLoading();
        await ref
            .read(customersProvider.notifier)
            .refreshManual(); 
        showSakoPopUp(
          context,
          title: 'Berhasil',
          message: 'Poin pelanggan disesuaikan dan tercatat di riwayat.',
          isError: false,
        );
      } catch (e) {
        _hideLoading();
        showSakoPopUp(
          context,
          title: 'Gagal',
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  // --- AKSI ADMIN: RESET SANDI ---
  Future<void> _resetPassword(String? email) async {
    if (email == null || email.isEmpty) {
      showSakoPopUp(
        context,
        title: 'Tidak Bisa Reset',
        message:
            'Pelanggan ini belum mendaftarkan Email Pemulihan. Mereka tidak bisa menerima link reset sandi.',
        isError: true,
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Kirim Link Reset?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Link untuk membuat kata sandi baru akan dikirimkan ke email:\n\n$email',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Kirim Email',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoading();
      try {
        await ref
            .read(customersRepositoryProvider)
            .sendResetPasswordEmail(email);
        _hideLoading();
        showSakoPopUp(
          context,
          title: 'Berhasil Terkirim',
          message: 'Link reset sandi telah dikirim ke email pelanggan.',
          isError: false,
        );
      } catch (e) {
        _hideLoading();
        showSakoPopUp(
          context,
          title: 'Gagal Mengirim',
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  // --- AKSI ADMIN: HAPUS TUNTAS ---
  Future<void> _deleteCustomer(
    Map<String, dynamic> customer,
    String currentName,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Hapus Permanen?',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $currentName?\n\nAkses login mereka akan dicabut, namun nota transaksi mereka akan tetap aman tersimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ya, Hapus Tuntas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoading();
      try {
        await ref
            .read(customersRepositoryProvider)
            .deleteCustomer(customer['id']);
        _hideLoading();
        await ref
            .read(customersProvider.notifier)
            .refreshManual(); 
        showSakoPopUp(
          context,
          title: 'Terhapus',
          message:
              'Pelanggan dan akses login-nya telah dihapus tuntas dari sistem.',
          isError: false,
        );
      } catch (e) {
        _hideLoading();
        showSakoPopUp(
          context,
          title: 'Gagal Menghapus',
          message: e.toString(),
          isError: true,
        );
      }
    }
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryOrange),
      ),
    );
  }

  void _hideLoading() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final userRole = ref.watch(userRoleProvider).value;
    final isAdmin = userRole == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelola Pelanggan',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  ref.read(customersProvider.notifier).onSearchChanged(val),
              decoration: InputDecoration(
                hintText: 'Cari Nama atau Nomor HP...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: state.isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: state.isLoading
          ? _buildSkeletonLoading()
          : state.customers.isEmpty
          ? Center(
              child: Text(
                'Tidak ada pelanggan ditemukan.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primaryOrange,
              onRefresh: () async {
                await ref.read(customersProvider.notifier).refreshManual();
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: state.customers.length,
                itemBuilder: (context, index) {
                  final customer = state.customers[index];
                  final profile = customer['profiles'] ?? {};

                  final String name = profile['full_name'] ?? 'Pelanggan';
                  final String phone = profile['phone_number'] ?? '-';
                  final String? email = profile['recovery_email'];
                  final int points = customer['points'] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Material(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CustomerPointHistoryScreen(
                                customerId: customer['id'],
                                customerName: name,
                                currentPoints: points,
                              ),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryOrange.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            name[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        subtitle: Text(
                          phone,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$points Pts',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            if (isAdmin)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.grey,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'edit_name')
                                    _editName(customer, name);
                                  if (value == 'edit_points')
                                    _editPoints(customer, points);
                                  if (value == 'reset_pass')
                                    _resetPassword(email);
                                  if (value == 'delete')
                                    _deleteCustomer(customer, name);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit_name',
                                    child: Text('Ubah Nama'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit_points',
                                    child: Text('Sesuaikan Poin'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reset_pass',
                                    child: Text('Reset Kata Sandi'),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text(
                                      'Hapus Permanen',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}