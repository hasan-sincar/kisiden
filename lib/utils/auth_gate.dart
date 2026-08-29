import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../services/guest_session_service.dart';
import 'local_fonts.dart';

class AuthGate {
  static bool get isRegistered {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && !user.isAnonymous && !GuestSessionService.isGuest;
  }

  static Future<bool> requireRegisteredUser(
    BuildContext context, {
    String message = 'Bu işlemi gerçekleştirmek için giriş yapmalısınız.',
  }) async {
    if (isRegistered) return true;

    final goToLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Giriş Yapın',
          style: LocalFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: LocalFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Vazgeç', style: LocalFonts.poppins()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Giriş Yap', style: LocalFonts.poppins()),
          ),
        ],
      ),
    );

    if (goToLogin == true && context.mounted) {
      await GuestSessionService.end();
      final anonymousUser = FirebaseAuth.instance.currentUser;
      if (anonymousUser?.isAnonymous == true) {
        await FirebaseAuth.instance.signOut();
      }
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
    return false;
  }
}
