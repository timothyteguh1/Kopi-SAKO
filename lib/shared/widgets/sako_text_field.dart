import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SakoTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final bool isPassword;
  final IconData prefixIcon;
  final bool enabled; // KUNCI PERBAIKAN: Tambahkan parameter enabled

  const SakoTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.enabled = true, // Nilai default true, jadi layar login aman!
  });

  @override
  State<SakoTextField> createState() => _SakoTextFieldState();
}

class _SakoTextFieldState extends State<SakoTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword ? _obscureText : false,
          enabled: widget.enabled, // KUNCI PERBAIKAN: Terapkan ke TextField bawaan
          
          // Ubah warna teks menjadi abu-abu jika sedang dikunci (disabled)
          style: TextStyle(
            color: widget.enabled ? AppColors.textDark : Colors.grey.shade600, 
            fontSize: 16
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.black38),
            filled: true,
            
            // Ubah warna latar menjadi sedikit lebih gelap jika dikunci
            fillColor: widget.enabled ? AppColors.fieldBackground : Colors.grey.shade200, 
            contentPadding: const EdgeInsets.symmetric(vertical: 20),
            prefixIcon: Icon(
              widget.prefixIcon, 
              color: widget.enabled ? Colors.black54 : Colors.grey, 
              size: 22
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: widget.enabled ? Colors.black54 : Colors.grey,
                      size: 22,
                    ),
                    onPressed: widget.enabled 
                        ? () => setState(() => _obscureText = !_obscureText)
                        : null,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
            ),
            
            // Tambahkan border khusus saat state disabled agar terlihat rapi
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}