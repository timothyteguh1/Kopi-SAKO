import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_keys.dart';
import 'routes/app_router.dart';

void main() async {
  // 1. Pastikan engine Flutter sudah siap sebelum memanggil plugin eksternal
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Muat file .env yang berisi kunci rahasia
  await dotenv.load(fileName: ".env");

  // 3. Inisialisasi koneksi ke mesin Supabase
  await Supabase.initialize(
    url: SupabaseKeys.url,
    anonKey: SupabaseKeys.anonKey,
  );

  // 4. Jalankan aplikasi yang dibungkus ProviderScope agar Riverpod aktif
  runApp(const ProviderScope(child: CashierApp()));
}

// 5. Menggunakan ConsumerWidget sebagai antena untuk Riverpod
class CashierApp extends ConsumerWidget {
  const CashierApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) { // <-- Ada 'ref' di sini
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SAKO Cashier',
      theme: ThemeData(
        // Warna tema khusus kasir (Biru Keabu-abuan) agar mudah dibedakan
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      // 6. Menyuntikkan 'ref' ke dalam router agar Satpam Middleware aktif berkerja
      routerConfig: AppRouter.cashierRouter(ref), 
    );
  }
}