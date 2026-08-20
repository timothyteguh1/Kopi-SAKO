import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provider ini akan menerima parameter branchId (String) dari UI
final branchMenuProvider = FutureProvider.family<List<dynamic>, String>((ref, branchId) async {
  final supabase = Supabase.instance.client;
  
  // PERBAIKAN ERROR: Mengubah 'stock' menjadi 'quantity' 
  // (Pastikan nama kolom ini sesuai dengan yang ada di Supabase Anda)
  final response = await supabase
      .from('branch_stocks')
      .select('quantity, products(id, name, price, image_url)')
      .eq('branch_id', branchId)
      .gt('quantity', 0); // Hanya ambil yang quantity-nya lebih dari 0
      
  return response;
});