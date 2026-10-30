import 'package:cloud_firestore/cloud_firestore.dart';

class BannerAdSettings {
  const BannerAdSettings({
    required this.isActive,
    required this.androidId,
    required this.iosId,
  });

  static const _defaultAndroidId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _defaultIosId = 'ca-app-pub-3940256099942544/2934735716';
  static const _cacheDuration = Duration(minutes: 5);

  static BannerAdSettings? _cachedSettings;
  static DateTime? _cachedAt;
  static Future<BannerAdSettings>? _pendingRequest;

  final bool isActive;
  final String androidId;
  final String iosId;

  static Future<BannerAdSettings> load() async {
    final cachedAt = _cachedAt;
    final cachedSettings = _cachedSettings;
    if (cachedAt != null &&
        cachedSettings != null &&
        DateTime.now().difference(cachedAt) < _cacheDuration) {
      return cachedSettings;
    }

    final pendingRequest = _pendingRequest;
    if (pendingRequest != null) return pendingRequest;

    final request = _fetch();
    _pendingRequest = request;
    try {
      final settings = await request;
      _cachedSettings = settings;
      _cachedAt = DateTime.now();
      return settings;
    } finally {
      _pendingRequest = null;
    }
  }

  static Future<BannerAdSettings> _fetch() async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('ads')
        .get();
    final data = doc.data();
    final activeValue = data?['isActive'];

    return BannerAdSettings(
      isActive: activeValue is bool ? activeValue : true,
      androidId: _configuredId(data?['androidId'], _defaultAndroidId),
      iosId: _configuredId(data?['iosId'], _defaultIosId),
    );
  }

  static String _configuredId(dynamic value, String fallback) {
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? fallback : id;
  }
}
