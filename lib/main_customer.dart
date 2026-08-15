import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart'; // <-- IMPORT BARU DITAMBAHKAN
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_keys.dart';
import 'routes/app_router.dart'; // Panggil AppRouter

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // KUNCI PERBAIKAN: Nyalakan kamus format tanggal bahasa Indonesia
  await initializeDateFormatting('id_ID', null);

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: SupabaseKeys.url,
    anonKey: SupabaseKeys.anonKey,
  );

  runApp(const ProviderScope(child: CustomerApp()));
}

// 1. Ubah StatelessWidget menjadi ConsumerWidget
class CustomerApp extends ConsumerWidget {
  const CustomerApp({super.key});

  // 2. Tambahkan WidgetRef ref di dalam method build
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Kopi SAKO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      // 3. Masukkan ref ke dalam router agar sistem keamanan aktif
      routerConfig: AppRouter.customerRouter(ref), 
    );
  }
}