import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BranchesAdminRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBranches() async {
    final res = await _supabase.from('branches').select().order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addBranch(String name, String address, String whatsapp) async {
    await _supabase.from('branches').insert({
      'name': name, 
      'address': address,
      'whatsapp_number': whatsapp,
      'status': 'open',
      'is_active': true,
    });
  }

  Future<void> updateBranch(String id, String name, String address, String whatsapp) async {
    await _supabase.from('branches').update({
      'name': name, 
      'address': address,
      'whatsapp_number': whatsapp, 
    }).eq('id', id);
  }

  // KUNCI PERBAIKAN: Fungsi Toggle Dinamis
  Future<void> toggleBranchActive(String id, bool currentStatus) async {
    final bool newActiveStatus = !currentStatus;
    
    // Siapkan data dasar yang akan di-update (is_active)
    final Map<String, dynamic> updateData = {
      'is_active': newActiveStatus,
    };

    // Jika Super Admin menonaktifkan cabang (newActiveStatus == false), 
    // paksa juga status operasionalnya menjadi 'closed'
    if (!newActiveStatus) {
      updateData['status'] = 'closed';
    }

    await _supabase.from('branches').update(updateData).eq('id', id);
  }
}

final branchesAdminRepoProvider = Provider((ref) => BranchesAdminRepository());