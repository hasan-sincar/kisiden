import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';
import '../utils/theme_colors.dart';
import '../utils/translations.dart';

class PhoneSetupScreen extends StatefulWidget {
  final bool isFirstTimeSetup;

  const PhoneSetupScreen({super.key, this.isFirstTimeSetup = false});

  @override
  State<PhoneSetupScreen> createState() => _PhoneSetupScreenState();
}

class _PhoneSetupScreenState extends State<PhoneSetupScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _otpSent = false;
  String _verificationId = '';
  DateTime? _lastOtpRequestAt;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    // Telefon ve Google girişinden elimizde olan verileri otomatik dolduruyoruz
    if (user != null) {
      if (user.email != null) _emailController.text = user.email!;
      if (user.phoneNumber != null) _phoneController.text = user.phoneNumber!;
      if (user.displayName != null && user.displayName != 'İsimsiz') {
        _nameController.text = user.displayName!;
      }
    }
  }

  String _friendlyAuthMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      final rawMessage = (error.message ?? '').toLowerCase();
      switch (error.code) {
        case 'invalid-phone-number':
          return tr('invalid_phone_format_with_country_code');
        case 'too-many-requests':
          return tr('too_many_attempts_try_later');
        case 'quota-exceeded':
          return tr('sms_quota_exceeded_try_later');
        case 'operation-not-allowed':
          return tr('phone_verification_not_enabled_firebase');
        case 'app-not-authorized':
          return tr('app_not_authorized_for_firebase');
        case 'missing-client-identifier':
          return tr('firebase_config_missing_check_credentials');
        case 'captcha-check-failed':
          return tr('security_verification_failed_retry');
        case 'network-request-failed':
          return tr('sms_send_failed_due_to_network');
        case 'credential-already-in-use':
        case 'phone-number-already-exists':
        case 'account-exists-with-different-credential':
        case 'provider-already-linked':
          return tr('phone_linked_to_another_account');
        case 'invalid-verification-code':
          return tr('verification_code_incorrect');
        case 'session-expired':
          return tr('verification_session_expired_request_sms_again');
        case 'internal-error':
          if (rawMessage.contains('17010') ||
              rawMessage.contains('blocked all requests') ||
              rawMessage.contains('unusual activity')) {
            return tr('device_temporarily_blocked_17010_wait_retry');
          }
          return tr(
            'verification_service_temporary_unavailable_17499_detailed',
          );
        default:
          if (error.code == '17010' ||
              rawMessage.contains('17010') ||
              rawMessage.contains('blocked all requests') ||
              rawMessage.contains('unusual activity')) {
            return tr('device_temporarily_blocked_17010_wait_15_30');
          }
          if (rawMessage.contains('17499') || rawMessage.contains('code:39')) {
            return tr('verification_service_temporary_error_17499_alt');
          }
          if ((error.message ?? '').isNotEmpty) {
            return error.message!;
          }
          return tr('generic_try_again_error');
      }
    }
    return tr('generic_try_again_error');
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (phoneNumber.isEmpty ||
        phoneNumber.length < 10 ||
        name.isEmpty ||
        email.isEmpty ||
        !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('enter_name_phone_valid_email'))),
      );
      return;
    }

    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('invalid_phone_format_with_country_code'))),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final hasPhoneProvider =
        currentUser?.providerData.any((p) => p.providerId == 'phone') ?? false;
    final currentPhone = normalizePhoneNumber(currentUser?.phoneNumber ?? '');

    // Phone-auth users are already verified. Do not start a second verification
    // flow, which can reopen iOS reCAPTCHA and recreate this screen.
    if (hasPhoneProvider && currentPhone == normalizedPhone) {
      setState(() => _isLoading = true);
      try {
        await _dbService.updatePhoneAndName(
          currentUser!.uid,
          normalizedPhone,
          name,
          email,
        );
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tr('operation_failed_with_reason').replaceFirst('%s', '$e'),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (_lastOtpRequestAt != null) {
      final elapsed = DateTime.now().difference(_lastOtpRequestAt!);
      if (elapsed.inSeconds < 60) {
        final remain = 60 - elapsed.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('wait_seconds_for_new_code').replaceFirst('%s', '$remain'),
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    _lastOtpRequestAt = DateTime.now();

    try {
      final isAlreadyRegistered = await _dbService.isPhoneNumberRegistered(
        normalizedPhone,
      );

      if (isAlreadyRegistered) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('phone_already_registered_try_another'))),
          );
        }
        return;
      }

      await _authService.verifyPhoneNumberForSignup(
        phoneNumber: normalizedPhone,
        codeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _otpSent = true;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('otp_sent_to_your_phone'))),
            );
          }
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr(
                    'sms_send_failed_with_reason',
                  ).replaceFirst('%s', _friendlyAuthMessage(e)),
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'sms_send_failed_with_reason',
              ).replaceFirst('%s', _friendlyAuthMessage(e)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _skipForNow() async {
    final shouldSkip = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('not_now')),
        content: Text(tr('add_phone_later_prompt')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('yes_continue')),
          ),
        ],
      ),
    );

    if (shouldSkip != true) return;

    setState(() => _isLoading = true);

    try {
      await _dbService.markProfileSetupSkipped();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('phone_info_can_be_completed_later'))),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr('operation_failed_with_reason').replaceFirst('%s', '$e'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _verifyOtpAndFinish() async {
    final otpCode = _otpController.text.trim();
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_enter_6_digit_code'))));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _verificationId.isEmpty) {
        throw Exception(tr('verification_not_started'));
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpCode,
      );

      await user.linkWithCredential(credential);
      await _dbService.updatePhoneAndName(
        user.uid,
        normalizePhoneNumber(_phoneController.text.trim()),
        _nameController.text.trim(),
        _emailController.text.trim(),
      );

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('phone_saved_successfully'))),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(
                'verification_failed_with_reason',
              ).replaceFirst('%s', _friendlyAuthMessage(e)),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: widget.isFirstTimeSetup
            ? []
            : [
                IconButton(
                  onPressed: _skipForNow,
                  icon: const Icon(Icons.close),
                  tooltip: tr('not_now'),
                ),
              ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  tr('profile_information'),
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('phone_setup_desc'),
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  style: LocalFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('full_name'),
                    hintText: tr('your_name_and_surname'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: LocalFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('email_address'),
                    hintText: tr('your_email_address'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: LocalFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: tr('your_phone_number'),
                    hintText: tr('phone_hint'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    prefixIcon: const Icon(Icons.phone),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: LocalFonts.poppins(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: tr('verification_code'),
                      hintText: tr('six_digit_code_hint'),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : Column(
                        children: [
                          ElevatedButton(
                            onPressed: _otpSent
                                ? _verifyOtpAndFinish
                                : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              _otpSent
                                  ? tr('verify_code_and_complete_signup')
                                  : tr('save_and_continue'),
                              style: LocalFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _skipForNow,
                            child: Text(
                              tr('not_now_complete_later'),
                              style: LocalFonts.poppins(
                                fontSize: 14,
                                color: AppColors.primary,
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
    );
  }
}
