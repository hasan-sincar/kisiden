import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/guest_session_service.dart';
import 'otp_screen.dart';
import '../main.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';
import 'legal_document_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  DateTime? _lastOtpRequestAt;
  DateTime? _otpBlockedUntil;
  static const int _otpCooldownSeconds = 60;

  bool _is17010Error(FirebaseAuthException error) {
    final rawMessage = (error.message ?? '').toLowerCase();
    return error.code == '17010' ||
        rawMessage.contains('17010') ||
        rawMessage.contains('blocked all requests') ||
        rawMessage.contains('unusual activity');
  }

  String _normalizePhoneForAuth(String input) {
    final raw = input.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return '';

    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      if (RegExp(r'^[1-9]\d{7,14}$').hasMatch(digits)) {
        return '+$digits';
      }
      return '';
    }

    final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '';

    // Local TR input: allow 5XXXXXXXXX and map to +90.
    if (RegExp(r'^5\d{9}$').hasMatch(digitsOnly)) {
      return '+90$digitsOnly';
    }

    // If user typed leading zero (05...), trim single leading zero.
    if (RegExp(r'^05\d{9}$').hasMatch(digitsOnly)) {
      return '+90${digitsOnly.substring(1)}';
    }

    // Generic fallback for international numbers typed without '+'.
    if (RegExp(r'^[1-9]\d{7,14}$').hasMatch(digitsOnly)) {
      return '+$digitsOnly';
    }

    return '';
  }

  void _onPhoneChanged(String value) {
    if (value.startsWith('05')) {
      final next = value.substring(1);
      _phoneController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _friendlyPhoneAuthError(FirebaseAuthException error) {
    final rawMessage = (error.message ?? '').toLowerCase();
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Telefon numarasi gecersiz.';
      case 'too-many-requests':
        return tr('too_many_attempts_try_later');
      case 'quota-exceeded':
        return tr('sms_quota_exceeded_try_later');
      case 'app-not-authorized':
      case 'operation-not-allowed':
      case 'missing-client-identifier':
        return tr('phone_auth_not_authorized_check_firebase');
      case 'internal-error':
        if (rawMessage.contains('17010') ||
            rawMessage.contains('blocked all requests') ||
            rawMessage.contains('unusual activity')) {
          return tr('device_temporarily_blocked_17010_wait_15_30');
        }
        return tr('verification_service_temporary_error_17499');
      default:
        if (error.code == '17010' || rawMessage.contains('17010')) {
          return tr('device_temporarily_blocked_17010_wait_15_30');
        }
        if (rawMessage.contains('17499') || rawMessage.contains('code:39')) {
          return tr('verification_service_temporary_error_17499');
        }
        return tr('generic_try_again_error');
    }
  }

  void _openLegalPage(String page) {
    String title;
    String assetPath;

    switch (page) {
      case 'about':
        title = tr('about_us');
        assetPath = 'assets/legal/about.html';
        break;
      case 'privacy':
        title = tr('privacy_policy');
        assetPath = 'assets/legal/privacy.html';
        break;
      case 'terms':
        title = tr('terms_of_use');
        assetPath = 'assets/legal/terms.html';
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LegalDocumentScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        await GuestSessionService.end();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RootScreen()),
          (route) => false,
        );
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? tr('generic_try_again_error'))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('generic_try_again_error')}: $error')),
      );
    }
  }

  // YENİ: Apple ile Giriş Yönlendirmesi
  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    var user = await _authService.signInWithApple();
    if (user != null && mounted) {
      await GuestSessionService.end();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueAsGuest() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    await GuestSessionService.start();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
      return;
    }
  }

  void _sendOtp() async {
    if (_isLoading) return;

    if (_otpBlockedUntil != null &&
        DateTime.now().isBefore(_otpBlockedUntil!)) {
      final left = _otpBlockedUntil!.difference(DateTime.now()).inSeconds;
      final safeLeft = left < 0 ? 0 : left;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('device_temporarily_blocked_17010_wait_15_30')}\n${tr('retry_after_seconds').replaceFirst('%s', '$safeLeft')}',
          ),
        ),
      );
      return;
    }

    if (_lastOtpRequestAt != null) {
      final elapsed = DateTime.now().difference(_lastOtpRequestAt!).inSeconds;
      if (elapsed < _otpCooldownSeconds) {
        final left = _otpCooldownSeconds - elapsed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('retry_after_seconds').replaceFirst('%s', '$left'),
            ),
          ),
        );
        return;
      }
    }

    final normalized = _normalizePhoneForAuth(_phoneController.text);
    if (normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_phone_format_with_country_code'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: normalized,
        verificationCompleted: (credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await GuestSessionService.end();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const RootScreen()),
              (route) => false,
            );
          } on FirebaseAuthException catch (error) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_friendlyPhoneAuthError(error))),
            );
          } catch (error) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${tr('generic_try_again_error')}: $error'),
              ),
            );
          }
        },
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          if (_is17010Error(error)) {
            setState(() {
              _otpBlockedUntil = DateTime.now().add(
                const Duration(minutes: 20),
              );
            });
          }
          final errorMessage = _friendlyPhoneAuthError(error);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        },
        codeSent: (verificationId, forceResendingToken) {
          if (!mounted) return;
          _lastOtpRequestAt = DateTime.now();
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: normalized,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {},
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('sms_send_failed_retry'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ŞIK ARKAPLAN (GRADIENT)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1976D2),
                  Color(0xFF4A148C),
                ],
              ),
            ),
          ),

          // DEKORATİF ARKAPLAN ŞEKİLLERİ
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/logo.png', height: 80),
                        const SizedBox(height: 16),
                        Text(
                          tr('app_name'),
                          style: LocalFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          tr('welcome_new_generation_marketplace'),
                          style: LocalFonts.poppins(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Telefon Numarası Giriş Alanı
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: TextField(
                            controller: _phoneController,
                            onChanged: _onPhoneChanged,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            style: LocalFonts.poppins(
                              color: const Color(0xFF6B7280),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.phone,
                                color: Colors.black,
                              ),
                              hintText: tr('phone_hint'),
                              hintStyle: LocalFonts.poppins(
                                color: const Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                              suffixIcon: _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: AppColors.primary,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8,
                                        top: 6,
                                        bottom: 6,
                                      ),
                                      child: Material(
                                        color: AppColors.primary,
                                        elevation: 3,
                                        borderRadius: BorderRadius.circular(12),
                                        child: InkWell(
                                          onTap: _sendOtp,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: const SizedBox(
                                            width: 42,
                                            height: 42,
                                            child: Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        TextButton.icon(
                          onPressed: _isLoading ? null : _continueAsGuest,
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(
                            tr('continue_as_guest'),
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                tr('or').toUpperCase(),
                                style: LocalFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.05,
                            ),
                          ),
                          onPressed: _isLoading ? null : _loginWithGoogle,
                          icon: Image.asset(
                            'assets/icon_google.png',
                            height: 24,
                          ),
                          label: Text(
                            tr('continue_with_google'),
                            style: LocalFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        // YENİ: Sadece iOS ve macOS cihazlarda Apple ile Giriş butonunu gösteriyoruz
                        if (defaultTargetPlatform == TargetPlatform.iOS ||
                            defaultTargetPlatform == TargetPlatform.macOS) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                            ),
                            onPressed: _isLoading ? null : _loginWithApple,
                            icon: const Icon(
                              Icons.apple,
                              color: Colors.white,
                              size: 28,
                            ),
                            label: Text(
                              tr('continue_with_apple'),
                              style: LocalFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => _openLegalPage('privacy'),
                              child: Text(
                                tr('privacy_policy'),
                                style: LocalFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Text(
                              "•",
                              style: TextStyle(color: Colors.white70),
                            ),
                            TextButton(
                              onPressed: () => _openLegalPage('terms'),
                              child: Text(
                                tr('terms_of_use'),
                                style: LocalFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
