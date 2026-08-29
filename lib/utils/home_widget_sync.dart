import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeWidgetSync {
  static const MethodChannel _channel = MethodChannel('appim/widget');
  static int? _lastSyncedUnreadCount;

  static Future<void> syncUnreadNotifications(int count) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final safeCount = count < 0 ? 0 : count;
    if (_lastSyncedUnreadCount == safeCount) return;

    _lastSyncedUnreadCount = safeCount;
    try {
      await _channel.invokeMethod('setUnreadNotificationCount', {
        'count': safeCount,
      });
    } catch (_) {
      // Native badge/widget sync is best-effort; never break UI flow.
    }
  }
}
