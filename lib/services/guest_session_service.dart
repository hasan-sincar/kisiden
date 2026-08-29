import 'package:shared_preferences/shared_preferences.dart';

/// Misafir modu yalnızca bu cihazda tutulur; Firebase Authentication'a kullanıcı
/// eklemez ve Firestore'da profil belgesi oluşturmaz.
class GuestSessionService {
  static const _guestModeKey = 'guest_mode';
  static bool _isGuest = false;

  static bool get isGuest => _isGuest;

  static Future<bool> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _isGuest = preferences.getBool(_guestModeKey) ?? false;
    return _isGuest;
  }

  static Future<void> start() async {
    _isGuest = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_guestModeKey, true);
  }

  static Future<void> end() async {
    _isGuest = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_guestModeKey);
  }
}
