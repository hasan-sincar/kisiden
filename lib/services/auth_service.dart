import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // YENİ: Web kontrolü için eklendi
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

String normalizePhoneNumber(String input) {
  final normalized = input.trim().replaceAll(RegExp(r'\s+'), '');
  if (normalized.isEmpty) return '';

  if (normalized.startsWith('+')) {
    return normalized;
  }

  String digits = normalized.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('90') && digits.length > 10) {
    return '+$digits';
  }
  if (digits.length == 10 && digits.startsWith('5')) {
    return '+90$digits';
  }
  if (digits.length == 11 && digits.startsWith('05')) {
    return '+90${digits.substring(1)}';
  }
  // Keep behavior strict for Turkish phone flow: +90 and 10-digit GSM numbers.
  return '';
}

bool isValidTurkishPhone(String phoneNumber) {
  return RegExp(r'^\+90\d{10}$').hasMatch(phoneNumber);
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Google ile Giriş Yapma Fonksiyonu
  Future<UserCredential?> signInWithGoogle() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return null;
    }
    try {
      if (kIsWeb) {
        // ÇÖZÜM: Web için Popup tabanlı doğrudan Firebase Auth kullanımı
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        return await _auth.signInWithPopup(authProvider);
      } else {
        // Mobil (Android/iOS) için Google giriş penceresini tetikliyoruz
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // Kullanıcı pencereyi kapatırsa

        // Google'dan kimlik doğrulama bilgilerini alıyoruz
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Firebase için yeni bir kimlik oluşturuyoruz
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Firebase'e giriş yapıyoruz
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      print("Google Giriş Hatası: $e");
      return null;
    }
  }

  // --- YENİ: Apple ile Giriş Yapma Fonksiyonu ---
  Future<UserCredential?> signInWithApple() async {
    try {
      if (kIsWeb) {
        return await _auth.signInWithPopup(AppleAuthProvider());
      } else {
        final rawNonce = _generateNonce();
        final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

        final appleIdCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );
        final identityToken = appleIdCredential.identityToken;
        if (identityToken == null || identityToken.isEmpty) {
          throw FirebaseAuthException(
            code: 'apple-missing-identity-token',
            message: 'Apple kimlik doğrulama belirteci alınamadı.',
          );
        }

        final oauthCredential = OAuthProvider(
          'apple.com',
        ).credential(idToken: identityToken, rawNonce: rawNonce);

        return await _auth.signInWithCredential(oauthCredential);
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      final message = e.toString();
      if (message.contains('AuthorizationError') &&
          message.contains('error 1000')) {
        throw FirebaseAuthException(
          code: 'apple-authorization-error-1000',
          message:
              'Apple ile giriş yetkilendirilemedi. Sign in with Apple capability, '
              'Bundle ID ve TestFlight imzasını kontrol edin.',
        );
      }
      throw FirebaseAuthException(
        code: 'apple-sign-in-failed',
        message: 'Apple ile giriş yapılamadı: $message',
      );
    }
  }

  // Apple Sign-In için güvenli ve rastgele bir nonce (şifreleme dizesi) oluşturur
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  // Çıkış Yapma Fonksiyonu
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Telefon Numarası ile Giriş/Kayıt için SMS Gönderme
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      // Android'de SMS kodunu otomatik yakalarsa tetiklenir (Kullanıcı kod girmeden giriş yapar)
      verificationCompleted: verificationCompleted,
      // Hata oluşursa (Geçersiz numara, çok fazla istek vb.) tetiklenir
      verificationFailed: verificationFailed,
      // SMS başarıyla gönderildiğinde tetiklenir (OTP ekranına geçiş için kullanacağız)
      codeSent: codeSent,
      timeout: const Duration(seconds: 60),
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // Gelen SMS Kodunu Doğrulama
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final code = smsCode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Lütfen 6 haneli doğrulama kodunu girin.',
      );
    }

    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: code,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> verifyPhoneNumberForSignup({
    required String phoneNumber,
    required Function(String, int?) codeSent,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Geçersiz telefon numarası',
      );
    }

    await _auth.verifyPhoneNumber(
      phoneNumber: normalizedPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await currentUser.linkWithCredential(credential);
        } else {
          await _auth.signInWithCredential(credential);
        }
      },
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      timeout: const Duration(seconds: 60),
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }
}
