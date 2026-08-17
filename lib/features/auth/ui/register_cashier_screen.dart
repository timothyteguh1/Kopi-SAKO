import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../logic/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/sako_text_field.dart';
import '../../../shared/widgets/sako_button.dart';
import '../../../shared/utils/pop_up_helper.dart'; // IMPORT POP-UP GLOBAL

class RegisterCashierScreen extends StatefulWidget {
  const RegisterCashierScreen({super.key});

  @override
  State<RegisterCashierScreen> createState() => _RegisterCashierScreenState();
}

class _RegisterCashierScreenState extends State<RegisterCashierScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(); 
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || 
        _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Semua kolom wajib diisi.');
      return;
    }
    setState(() => _isLoading = true);
    
    final realEmail = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    final errorMsg = await AuthController.sendRegisterOtp(realEmail, password, name, phone);

    if (mounted) {
      setState(() => _isLoading = false);
      if (errorMsg != null) {
        _showError(errorMsg);
      } else {
        _showOtpDialog(realEmail, phone);
      }
    }
  }

  void _showOtpDialog(String email, String phone) {
    final otpController = TextEditingController();
    bool isVerifying = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Masukkan Kode OTP', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Kode 6 digit telah dikirim ke:\n$email', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actions: [
              if (!isVerifying)
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: const Text('Batal', style: TextStyle(color: Colors.grey))
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                onPressed: isVerifying ? null : () async {
                  if (otpController.text.length != 6) return;
                  setStateDialog(() => isVerifying = true);
                  
                  final error = await AuthController.verifyOtpAndFinalize(email, otpController.text, phone);
                  
                  if (ctx.mounted) {
                    setStateDialog(() => isVerifying = false);
                    if (error != null) {
                      showSakoPopUp(ctx, title: 'Gagal', message: error, isError: true);
                    } else {
                      Navigator.pop(ctx); // Tutup dialog OTP
                      await showSakoPopUp(context, title: 'Akun Diajukan!', message: 'Pendaftaran sukses! Silakan hubungi Super Admin untuk penempatan Cabang sebelum Anda bisa Login.', isError: false);
                      if (context.mounted) context.pop(); // Kembali ke halaman Login
                    }
                  }
                },
                child: isVerifying 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Verifikasi & Buat Akun', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showError(String message) {
    // MENGGUNAKAN POP-UP SAKO
    showSakoPopUp(context, title: 'Pendaftaran Gagal', message: message, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => context.pop())),
      body: SafeArea(
        child: IgnorePointer(
          ignoring: _isLoading,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading ? 0.6 : 1.0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(tag: 'sako_logo', child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/logo_sako.png', height: 64, width: 64, fit: BoxFit.cover))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.assignment_ind_outlined, color: AppColors.textDark, size: 16), SizedBox(width: 6), Text('REKRUTMEN STAF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight))]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Akses\nKasir', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textDark, height: 1.0, letterSpacing: -1.5)),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SakoTextField(controller: _nameController, label: 'Nama Lengkap (KTP)', hint: 'Sesuai identitas asli', prefixIcon: Icons.badge_outlined),
                        const SizedBox(height: 20),
                        SakoTextField(controller: _phoneController, label: 'Nomor WhatsApp', hint: '081234567890', prefixIcon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        SakoTextField(controller: _emailController, label: 'Email Pribadi', hint: 'nama@email.com', prefixIcon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 20),
                        SakoTextField(controller: _passwordController, label: 'Password', hint: '••••••••', prefixIcon: Icons.lock_outline, isPassword: true),
                        const SizedBox(height: 32),
                        
                        SakoButton(
                          text: 'Ajukan Akses',
                          isLoading: _isLoading,
                          backgroundColor: AppColors.textDark, 
                          onPressed: _handleRegister,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}