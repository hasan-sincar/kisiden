import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/guest_session_service.dart';
import '../services/web_qr_login_service.dart';
import 'otp_screen.dart';
import '../main.dart';
import '../utils/translations.dart';
import 'legal_document_screen.dart';
import 'contact_us_screen.dart';
import '../widgets/web_qr_login_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const MethodChannel _phoneNumberHintChannel = MethodChannel(
    'appim/widget',
  );
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _phoneAuthCompleted = false;
  DateTime? _lastOtpRequestAt;
  DateTime? _otpBlockedUntil;
  static const int _otpCooldownSeconds = 60;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectPhoneNumberFromDevice();
      });
    }
  }

  Future<void> _selectPhoneNumberFromDevice() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final phoneNumber = await _phoneNumberHintChannel.invokeMethod<String>(
        'pickPhoneNumber',
      );
      if (!mounted || phoneNumber == null || phoneNumber.trim().isEmpty) return;

      final normalized = _normalizePhoneForAuth(phoneNumber);
      final input = normalized.startsWith('+90')
          ? normalized.substring(3)
          : phoneNumber.trim();
      _phoneController.value = TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      );
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('phone_hint_unavailable'))));
    }
  }

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
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithApple();
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAppleAuthError(error))));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('generic_try_again_error')}: $error')),
      );
    }
  }

  String _friendlyAppleAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'canceled':
      case 'web-context-canceled':
        return 'Apple ile giriş iptal edildi.';
      case 'operation-not-allowed':
        return 'Apple ile giriş Firebase Authentication içinde etkin değil.';
      case 'invalid-credential':
        return 'Apple kimlik doğrulaması geçersiz. Lütfen tekrar deneyin.';
      case 'apple-authorization-error-1000':
        return 'Apple ile giriş bu TestFlight build\'inde yetkili değil. '
            'Apple Developer\'da com.kisidencom.appim için Sign in with Apple '
            'capability ve provisioning profilini yenileyin.';
      default:
        return error.message ?? 'Apple ile giriş yapılamadı.';
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

  Future<void> _loginWithQr() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final session = await WebQrLoginService().createWebSession();
      if (!mounted) return;
      final customToken = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => WebQrLoginDialog(session: session),
      );
      if (customToken == null) return;

      final credential = await FirebaseAuth.instance.signInWithCustomToken(
        customToken,
      );
      if (credential.user == null) {
        throw StateError('Web oturumu acilamadi.');
      }
      await GuestSessionService.end();
      if (!mounted) return;
      try {
        await WebQrLoginService().acknowledgeWebSession(session);
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('qr_login_cleanup_failed')}: $error'),
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RootScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? tr('generic_try_again_error'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('generic_try_again_error')}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    _phoneAuthCompleted = false;
    setState(() => _isLoading = true);

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: normalized,
        verificationCompleted: (credential) async {
          if (_phoneAuthCompleted) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            await GuestSessionService.end();
            _phoneAuthCompleted = true;
            navigatorKey.currentState?.pushAndRemoveUntil(
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
          if (!mounted || _phoneAuthCompleted) return;
          _lastOtpRequestAt = DateTime.now();
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
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
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final verticalPadding = constraints.maxHeight < 700 ? 12.0 : 22.0;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 380 ? 20 : 26,
                vertical: verticalPadding,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Image.asset(
                        'assets/logo.png',
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        tr('app_name'),
                        style: LocalFonts.poppins(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF17191D),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr('welcome_new_generation_marketplace'),
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF858994),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: _LoginBenefit(
                              icon: Icons.sell_outlined,
                              title: tr('login_benefit_trade_title'),
                              subtitle: tr('login_benefit_trade_subtitle'),
                            ),
                          ),
                          const _LoginBenefitDivider(),
                          Expanded(
                            child: _LoginBenefit(
                              icon: Icons.shield_outlined,
                              title: tr('login_benefit_trust_title'),
                              subtitle: tr('login_benefit_trust_subtitle'),
                            ),
                          ),
                          const _LoginBenefitDivider(),
                          Expanded(
                            child: _LoginBenefit(
                              icon: Icons.people_outline_rounded,
                              title: tr('login_benefit_listings_title'),
                              subtitle: tr('login_benefit_listings_subtitle'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 78,
                        child: TextField(
                          controller: _phoneController,
                          onChanged: _onPhoneChanged,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          textAlignVertical: TextAlignVertical.center,
                          style: LocalFonts.poppins(
                            color: const Color(0xFF17191D),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            labelText: tr('login_phone_label'),
                            labelStyle: LocalFonts.poppins(
                              color: const Color(0xFF858994),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                            hintText: tr('phone_hint'),
                            hintStyle: LocalFonts.poppins(
                              color: const Color(0xFF858994),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            prefixIcon: const Icon(
                              Icons.phone_iphone_outlined,
                              color: Color(0xFF17191D),
                              size: 21,
                            ),
                            suffixIcon:
                                !kIsWeb &&
                                    defaultTargetPlatform ==
                                        TargetPlatform.android
                                ? IconButton(
                                    tooltip: tr('choose_phone_from_device'),
                                    onPressed: _isLoading
                                        ? null
                                        : _selectPhoneNumberFromDevice,
                                    icon: const Icon(Icons.contact_phone),
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFFE1E3E8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: Color(0xFF17191D),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tr('phone_auth_sms_notice'),
                          style: LocalFonts.poppins(
                            color: const Color(0xFF858994),
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 62,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _sendOtp,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF17191D),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF777A80),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SizedBox(width: 24),
                                    Text(
                                      tr('login_continue'),
                                      style: LocalFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: 21,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _loginWithQr,
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text(tr('web_qr_login')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF17191D),
                              side: const BorderSide(
                                color: Color(0xFFE1E3E8),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (defaultTargetPlatform == TargetPlatform.android ||
                          defaultTargetPlatform == TargetPlatform.macOS) ...[
                        const SizedBox(height: 21),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE1E3E8),
                                height: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                tr('or').toUpperCase(),
                                style: LocalFonts.poppins(
                                  color: const Color(0xFF858994),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(
                                color: Color(0xFFE1E3E8),
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (defaultTargetPlatform == TargetPlatform.android) ...[
                        const SizedBox(height: 17),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF17191D),
                              side: const BorderSide(color: Color(0xFFE1E3E8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 1,
                              shadowColor: Colors.black.withValues(alpha: 0.08),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/icon_google.png',
                                  height: 22,
                                ),
                                const SizedBox(width: 11),
                                Text(
                                  tr('continue_with_google'),
                                  style: LocalFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (defaultTargetPlatform == TargetPlatform.macOS) ...[
                        const SizedBox(height: 17),
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _loginWithApple,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF17191D),
                              side: const BorderSide(color: Color(0xFFE1E3E8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.apple, size: 23),
                            label: Text(
                              tr('continue_with_apple'),
                              style: LocalFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _continueAsGuest,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF17191D),
                            side: const BorderSide(color: Color(0xFFE1E3E8)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                color: Color(0xFF17191D),
                                size: 21,
                              ),
                              Expanded(
                                child: Text(
                                  tr('continue_as_guest'),
                                  textAlign: TextAlign.center,
                                  style: LocalFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Color(0xFFAAADB5),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LoginLegalLink(
                            label: tr('privacy_policy'),
                            onPressed: () => _openLegalPage('privacy'),
                          ),
                          _LoginLegalLink(
                            label: tr('contact_us'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ContactUsScreen(),
                              ),
                            ),
                          ),
                          _LoginLegalLink(
                            label: tr('terms_of_use'),
                            onPressed: () => _openLegalPage('terms'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LoginBenefit extends StatelessWidget {
  const _LoginBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF17191D)),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: LocalFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF17191D),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: LocalFonts.poppins(
            fontSize: 9,
            color: const Color(0xFF858994),
          ),
        ),
      ],
    );
  }
}

class _LoginBenefitDivider extends StatelessWidget {
  const _LoginBenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFE1E3E8),
    );
  }
}

class _LoginLegalLink extends StatelessWidget {
  const _LoginLegalLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF858994),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: LocalFonts.poppins(fontSize: 11)),
    );
  }
}
