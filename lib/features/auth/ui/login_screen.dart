import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../logic/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/sako_text_field.dart';
import '../../../shared/widgets/sako_button.dart'; // <-- Tombol baru diimpor

class LoginScreen extends StatefulWidget {
  final bool isCashierApp; 
  const LoginScreen({super.key, this.isCashierApp = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(); 
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Nomor WhatsApp dan Password wajib diisi.');
      return;
    }
    setState(() => _isLoading = true);
    final errorMsg = await AuthController.login(_phoneController.text.trim(), _passwordController.text);
    if (mounted) {
      setState(() => _isLoading = false);
      if (errorMsg != null) _showError(errorMsg);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Kunci layar dan redupkan otomatis saat loading
        child: IgnorePointer(
          ignoring: _isLoading,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading ? 0.6 : 1.0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  
                  _FadeSlideTransition(
                    delay: 0,
                    child: Hero(
                      tag: 'sako_logo',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16), 
                        child: Image.asset('assets/images/logo_sako.png', height: 64, width: 64, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24), 

                  _FadeSlideTransition(
                    delay: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(widget.isCashierApp ? Icons.admin_panel_settings_outlined : Icons.person_outline, color: AppColors.primaryOrange, size: 16),
                              const SizedBox(width: 6),
                              Text(widget.isCashierApp ? 'STAF INTERNAL' : 'PELANGGAN SAKO', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.isCashierApp ? 'SAKO\nCashier' : 'Kopi\nSAKO',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.textDark, height: 1.0, letterSpacing: -1.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.isCashierApp ? 'Masuk untuk mulai mengelola transaksi kasir hari ini.' : 'Masuk dan pesan kopi segar langsung ke lokasimu.',
                          style: const TextStyle(fontSize: 16, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _FadeSlideTransition(
                    delay: 200,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SakoTextField(controller: _phoneController, label: 'Nomor WhatsApp', hint: '081234567890', prefixIcon: Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                          const SizedBox(height: 20),
                          SakoTextField(controller: _passwordController, label: 'Password', hint: '••••••••', prefixIcon: Icons.lock_outline, isPassword: true),
                          const SizedBox(height: 12),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: () {}, child: const Text('Lupa password?', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(height: 12),

                          // Menggunakan tombol pantul baru
                          SakoButton(
                            text: 'Masuk',
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  _FadeSlideTransition(
                    delay: 300,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => context.push('/register'),
                        child: RichText(
                          text: TextSpan(
                            text: 'Belum punya akun? ', style: const TextStyle(color: AppColors.textLight, fontSize: 15),
                            children: [TextSpan(text: widget.isCashierApp ? 'Ajukan pendaftaran' : 'Daftar sekarang', style: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold))],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget transisi animasi untuk tampilan meluncur
class _FadeSlideTransition extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeSlideTransition({required this.child, required this.delay});

  @override
  State<_FadeSlideTransition> createState() => _FadeSlideTransitionState();
}

class _FadeSlideTransitionState extends State<_FadeSlideTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnimation, child: SlideTransition(position: _slideAnimation, child: widget.child));
  }
}