import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../logic/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/sako_text_field.dart';
import '../../../shared/widgets/sako_button.dart';
import '../../../shared/utils/pop_up_helper.dart';

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  State<RegisterCustomerScreen> createState() => _RegisterCustomerScreenState();
}

class _RegisterCustomerScreenState extends State<RegisterCustomerScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  
  // State khusus alur OTP langsung di tempat (Inline)
  bool _isSendingOtp = false;
  bool _isOtpSent = false;
  bool _isVerifyingOtp = false;
  bool _isEmailVerified = false;

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showSakoPopUp(context, title: 'Validasi', message: 'Silakan masukkan email pribadi yang valid terlebih dahulu.', isError: true);
      return;
    }

    setState(() => _isSendingOtp = true);
    
    // Menggunakan fungsi kirim pendaftaran bawaan Anda
    final errorMsg = await AuthController.sendRegisterOtp(
      email, 
      _passwordController.text.isEmpty ? 'dummy123' : _passwordController.text,
      _nameController.text.trim().isEmpty ? 'Pelanggan SAKO' : _nameController.text.trim(),
      _phoneController.text.trim()
    );

    if (mounted) {
      setState(() => _isSendingOtp = false);
      if (errorMsg != null && !errorMsg.contains('OTP')) {
        showSakoPopUp(context, title: 'Gagal', message: errorMsg, isError: true);
      } else {
        setState(() => _isOtpSent = true);
        showSakoPopUp(context, title: 'OTP Terkirim', message: 'Kode verifikasi 6-digit berhasil dikirim ke $email', isError: false);
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (otp.length != 6) {
      showSakoPopUp(context, title: 'Validasi', message: 'Kode OTP harus berjumlah 6 digit.', isError: true);
      return;
    }

    setState(() => _isVerifyingOtp = true);
    final error = await AuthController.verifyOtpAndFinalize(email, otp, phone);

    if (mounted) {
      setState(() => _isVerifyingOtp = false);
      if (error != null) {
        showSakoPopUp(context, title: 'Verifikasi Gagal', message: error, isError: true);
      } else {
        setState(() {
          _isEmailVerified = true;
          _isOtpSent = false;
        });
        showSakoPopUp(context, title: 'Sukses', message: 'Email Anda berhasil diverifikasi!', isError: false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty ||
        _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      showSakoPopUp(context, title: 'Validasi', message: 'Semua kolom wajib diisi.', isError: true);
      return;
    }

    if (!_isEmailVerified) {
      showSakoPopUp(context, title: 'Verifikasi Wajib', message: 'Silakan lakukan verifikasi OTP pada kolom email Anda terlebih dahulu.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Finalisasi pembuatan akun Pelanggan SAKO seutuhnya
    final errorMsg = await AuthController.registerCustomer(
      _phoneController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      _emailController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (errorMsg != null) {
        showSakoPopUp(context, title: 'Pendaftaran Gagal', message: errorMsg, isError: true);
      } else {
        await showSakoPopUp(context, title: 'Berhasil', message: 'Akun Pelanggan SAKO berhasil dibuat! Silakan masuk.', isError: false);
        if (mounted) context.pop(); 
      }
    }
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_add_alt, color: AppColors.primaryOrange, size: 16), SizedBox(width: 6), Text('DAFTAR PELANGGAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight))]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Buat\nAkun', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textDark, height: 1.0, letterSpacing: -1.5)),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SakoTextField(controller: _nameController, label: 'Nama Lengkap', hint: 'Budi Santoso', prefixIcon: Icons.badge_outlined),
                        const SizedBox(height: 20),
                        SakoTextField(controller: _phoneController, label: 'Nomor WhatsApp', hint: '081234567890', prefixIcon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        
                        // KUNCI UTAMA: Row Input Email + Tombol Minta OTP Berdampingan
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: SakoTextField(
                                controller: _emailController,
                                label: 'Email (Untuk Pemulihan)',
                                hint: 'nama@email.com',
                                prefixIcon: Icons.mail_outline,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_isEmailVerified,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!_isEmailVerified)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isOtpSent ? Colors.grey : AppColors.primaryOrange,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  onPressed: _isSendingOtp ? null : _handleSendOtp,
                                  child: _isSendingOtp
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(_isOtpSent ? 'Resend' : 'Minta OTP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),

                        // Indikator Hijau Sukses Verifikasi Email
                        if (_isEmailVerified)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                const SizedBox(width: 4),
                                const Text('Email Berhasil Terverifikasi', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),

                        // Input Pengisian OTP Secara Langsung di Bawah Email
                        if (_isOtpSent && !_isEmailVerified) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: SakoTextField(
                                  controller: _otpController,
                                  label: 'Masukkan 6 Digit OTP',
                                  hint: '123456',
                                  prefixIcon: Icons.lock_clock_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                                  child: _isVerifyingOtp
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Verifikasi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 20),
                        SakoTextField(controller: _passwordController, label: 'Password', hint: '••••••••', prefixIcon: Icons.lock_outline, isPassword: true),
                        const SizedBox(height: 32),

                        SakoButton(
                          text: 'Daftar Sekarang',
                          isLoading: _isLoading,
                          backgroundColor: _isEmailVerified ? AppColors.primaryOrange : Colors.grey.shade400,
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