import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_keys.dart';

void main() async {
  // Pastikan core Flutter sudah siap sebelum menjalankan fungsi berat
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Baca kunci rahasia dari .env
  await dotenv.load(fileName: ".env");

  // 2. Hubungkan aplikasi ke Supabase
  await Supabase.initialize(
    url: SupabaseKeys.url,
    anonKey: SupabaseKeys.anonKey,
  );

  // 3. Nyalakan mesin Riverpod dengan ProviderScope dan jalankan aplikasi
  runApp(const ProviderScope(child: CustomerApp()));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kopi SAKO',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
      ),
      // Layar sementara sebelum kita pasang GoRouter di tahap selanjutnya
      home: const Scaffold(
        body: Center(
          child: Text(
            'Kopi SAKO (Customer) - Mesin Menyala! 🚀',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}