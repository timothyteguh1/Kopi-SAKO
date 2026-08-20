import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/sako_text_field.dart';
import '../../../shared/widgets/sako_button.dart';
import '../../../shared/utils/pop_up_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  
  // Variabel untuk menyimpan ID pengguna jika WA & Email cocok (Digunakan di Tahap 3)
  String? _userId; 

  final _supabase = Supabase.instance.client;

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ====================================================================
  // TAHAP 1: Validasi Keamanan Data (WA + Email) & Panggil 'send-otp'
  // ====================================================================
  Future<void> _verifyDataAndSendOtp() async {
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (phone.isEmpty || email.isEmpty) {
      showSakoPopUp(context, title: 'Validasi', message: 'Nomor WhatsApp dan Email wajib diisi.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Cek kecocokan data di tabel profiles
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('phone_number', phone)
          .eq('recovery_email', email)
          .maybeSingle();

      if (profile == null) {
        throw Exception('Data tidak cocok. Pastikan Nomor WA dan Email sesuai dengan yang Anda daftarkan.');
      }

      // Simpan User ID secara diam-diam untuk keperluan mereset sandi di Tahap 3 nanti
      _userId = profile['id'];

      // 2. Minta Edge Function kirim OTP
      await _supabase.functions.invoke(
        'send-otp',
        body: {
          'email': email,
          'phone': phone,
          'type': 'forgot_password', // <--- Parameter penentu format email
        },
      );

      if (mounted) {
        setState(() {
          _currentStep = 2; 
          _isLoading = false;
        });
        showSakoPopUp(context, title: 'OTP Terkirim', message: 'Kode OTP telah dikirim ke email $email', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSakoPopUp(context, title: 'Gagal', message: e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  // ====================================================================
  // TAHAP 2: Verifikasi Kode OTP dari Tabel Buatan Sendiri (otp_requests)
  // ====================================================================
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();

    if (otp.length != 6) {
      showSakoPopUp(context, title: 'Validasi', message: 'Kode OTP harus berjumlah 6 digit.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Cek apakah kode OTP ada di database dan belum kedaluwarsa
      final response = await _supabase
          .from('otp_requests')
          .select('id')
          .eq('email', email)
          .eq('otp_code', otp)
          .gte('expires_at', DateTime.now().toUtc().toIso8601String())
          .maybeSingle();

      if (response == null) {
        throw Exception('Kode OTP salah atau sudah kedaluwarsa.');
      }

      if (mounted) {
        setState(() {
          _currentStep = 3; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSakoPopUp(context, title: 'Verifikasi Gagal', message: e.toString().replaceAll('Exception: ', ''), isError: true);
      }
    }
  }

  // ====================================================================
  // TAHAP 3: Timpa Sandi Baru Menggunakan Edge Function 'reset-password-custom'
  // ====================================================================
  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.length < 6) {
      showSakoPopUp(context, title: 'Validasi', message: 'Sandi minimal 6 karakter.', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      showSakoPopUp(context, title: 'Validasi', message: 'Kata sandi tidak cocok.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Panggil Edge Function admin untuk menimpa sandi berdasarkan ID yang disimpan
      await _supabase.functions.invoke(
        'reset-password-custom',
        body: {
          'user_id': _userId,
          'new_password': newPass,
        },
      );

      if (mounted) {
        setState(() => _isLoading = false);
        await showSakoPopUp(context, title: 'Berhasil', message: 'Kata sandi Anda berhasil dipulihkan! Silakan login menggunakan kata sandi baru.', isError: false);
        if (mounted) context.pop(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showSakoPopUp(context, title: 'Gagal Memperbarui', message: 'Terjadi kesalahan sistem. Silakan coba lagi.', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_reset, color: AppColors.primaryOrange, size: 16), SizedBox(width: 6), Text('PEMULIHAN AKUN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight))]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Lupa\nSandi', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textDark, height: 1.0, letterSpacing: -1.5)),
                  const SizedBox(height: 24),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
                        child: child,
                      );
                    },
                    child: _buildCurrentStepWidget(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      default: return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Container(
      key: const ValueKey(1),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Verifikasi Identitas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Masukkan nomor WhatsApp dan email terdaftar untuk memastikan ini benar Anda.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3)),
          const SizedBox(height: 24),
          SakoTextField(controller: _phoneController, label: 'Nomor WhatsApp', hint: '081234567890', prefixIcon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          SakoTextField(controller: _emailController, label: 'Email Pemulihan', hint: 'nama@email.com', prefixIcon: Icons.mail_outline, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 32),
          SakoButton(text: 'Kirim OTP', isLoading: _isLoading, onPressed: _verifyDataAndSendOtp),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Container(
      key: const ValueKey(2),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Verifikasi OTP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Masukkan 6 digit kode yang telah kami kirimkan ke email ${_emailController.text}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3)),
          const SizedBox(height: 24),
          SakoTextField(controller: _otpController, label: 'Kode OTP', hint: '123456', prefixIcon: Icons.lock_clock_outlined, keyboardType: TextInputType.number),
          const SizedBox(height: 32),
          SakoButton(text: 'Verifikasi Kode', isLoading: _isLoading, onPressed: _verifyOtp),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Container(
      key: const ValueKey(3),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Buat Sandi Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text('OTP berhasil diverifikasi! Silakan buat kata sandi baru untuk akun Anda.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.3)),
          const SizedBox(height: 24),
          SakoTextField(controller: _newPasswordController, label: 'Kata Sandi Baru', hint: '••••••••', prefixIcon: Icons.lock_outline, isPassword: true),
          const SizedBox(height: 20),
          SakoTextField(controller: _confirmPasswordController, label: 'Ulangi Kata Sandi', hint: '••••••••', prefixIcon: Icons.lock_reset, isPassword: true),
          const SizedBox(height: 32),
          SakoButton(text: 'Simpan Sandi', isLoading: _isLoading, onPressed: _resetPassword),
        ],
      ),
    );
  }
}