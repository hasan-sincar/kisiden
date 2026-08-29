import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/guest_session_service.dart';
import '../main.dart'; // RootScreen için yönlendirme bağlantısı
import '../utils/theme_colors.dart';
import '../utils/translations.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  static const int _maxAttempts = 5;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _friendlyOtpError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return tr('otp_invalid_code');
      case 'session-expired':
        return tr('otp_session_expired');
      case 'too-many-requests':
        return tr('otp_too_many_requests');
      default:
        return tr('otp_verification_failed');
    }
  }

  void _verifyCode() async {
    if (_isLoading) return;

    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) {
      final wait = _lockedUntil!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('otp_too_many_failed_attempts_wait').replaceFirst('%s', '$wait'),
          ),
        ),
      );
      return;
    }

    final code = _otpController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_enter_6_digit_code'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyOTP(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await GuestSessionService.end();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _failedAttempts += 1;
      if (_failedAttempts >= _maxAttempts) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyOtpError(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('otp_verification_process_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          tr('verification'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.mark_email_read,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'SMS Kodu Gönderildi',
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.phoneNumber} numarasına gönderilen 6 haneli kodu girin.',
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              // Gelen SMS'i klavye üzerinde otomatik gösterecek ipucu (Örn: "Mesajdan: 123456")
              autofillHints: const [AutofillHints.oneTimeCode],
              style: LocalFonts.poppins(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _verifyCode,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Doğrula',
                      style: LocalFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
