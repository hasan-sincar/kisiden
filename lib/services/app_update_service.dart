import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppUpdateRequirement { none, soft, force }

class AppUpdateDecision {
  final AppUpdateRequirement requirement;
  final String latestVersion;
  final String currentVersion;
  final String title;
  final String message;
  final String storeUrl;
  final int remindIntervalHours;

  const AppUpdateDecision({
    required this.requirement,
    required this.latestVersion,
    required this.currentVersion,
    required this.title,
    required this.message,
    required this.storeUrl,
    required this.remindIntervalHours,
  });

  static const none = AppUpdateDecision(
    requirement: AppUpdateRequirement.none,
    latestVersion: '',
    currentVersion: '',
    title: '',
    message: '',
    storeUrl: '',
    remindIntervalHours: 24,
  );
}

class AppUpdateService {
  static const _dismissedVersionKey = 'update_dismissed_version';
  static const _dismissedAtKey = 'update_dismissed_at';

  final FirebaseFirestore _firestore;

  AppUpdateService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<AppUpdateDecision> checkForUpdate() async {
    try {
      if (kIsWeb) return AppUpdateDecision.none;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final doc = await _firestore
          .collection('settings')
          .doc('app_update')
          .get();
      if (!doc.exists || doc.data() == null) {
        return AppUpdateDecision.none;
      }

      final data = doc.data()!;
      final updateEnabled = data['updateEnabled'] != false;
      if (!updateEnabled) return AppUpdateDecision.none;

      final latestVersion = (data['latestVersion']?.toString() ?? '').trim();
      final minSupportedVersion =
          (data['minSupportedVersion']?.toString() ?? '').trim();
      final forceUpdate = data['forceUpdate'] == true;
      final remindIntervalHours = _toInt(
        data['remindIntervalHours'],
        fallback: 24,
      );

      if (latestVersion.isEmpty) return AppUpdateDecision.none;

      final isNewerAvailable =
          _compareVersions(currentVersion, latestVersion) < 0;
      final isBelowMinimum =
          minSupportedVersion.isNotEmpty &&
          _compareVersions(currentVersion, minSupportedVersion) < 0;

      if (!isNewerAvailable && !isBelowMinimum) {
        return AppUpdateDecision.none;
      }

      final selectedStoreUrl = _resolveStoreUrl(data);
      final title = (data['updateTitle']?.toString().trim().isNotEmpty ?? false)
          ? data['updateTitle'].toString().trim()
          : 'Yeni sürüm hazır';
      final message =
          (data['updateMessage']?.toString().trim().isNotEmpty ?? false)
          ? data['updateMessage'].toString().trim()
          : 'Daha güvenli ve stabil deneyim için uygulamayı güncelleyin.';

      final requirement = (isBelowMinimum || (forceUpdate && isNewerAvailable))
          ? AppUpdateRequirement.force
          : AppUpdateRequirement.soft;

      if (requirement == AppUpdateRequirement.soft) {
        final shouldSuppress = await _shouldSuppressSoftPrompt(
          latestVersion: latestVersion,
          remindIntervalHours: remindIntervalHours,
        );
        if (shouldSuppress) {
          return AppUpdateDecision.none;
        }
      }

      return AppUpdateDecision(
        requirement: requirement,
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        title: title,
        message: message,
        storeUrl: selectedStoreUrl,
        remindIntervalHours: remindIntervalHours,
      );
    } catch (e, stack) {
      debugPrint('App Update Check Error: $e');
      debugPrintStack(stackTrace: stack);
      return AppUpdateDecision.none;
    }
  }

  Future<void> markSoftDismissed(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, latestVersion);
    await prefs.setInt(_dismissedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> _shouldSuppressSoftPrompt({
    required String latestVersion,
    required int remindIntervalHours,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_dismissedVersionKey);
    final dismissedAtMs = prefs.getInt(_dismissedAtKey);
    if (dismissedVersion != latestVersion || dismissedAtMs == null) {
      return false;
    }

    final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedAtMs);
    final nextAllowed = dismissedAt.add(Duration(hours: remindIntervalHours));
    return DateTime.now().isBefore(nextAllowed);
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _resolveStoreUrl(Map<String, dynamic> data) {
    final androidUrl = (data['storeUrlAndroid']?.toString() ?? '').trim();
    final iosUrl = (data['storeUrlIos']?.toString() ?? '').trim();

    if (Platform.isAndroid) return androidUrl;
    if (Platform.isIOS) return iosUrl;
    return '';
  }

  int _compareVersions(String a, String b) {
    final aParts = _extractVersionParts(a);
    final bParts = _extractVersionParts(b);
    final maxLen = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < maxLen; i++) {
      final aVal = i < aParts.length ? aParts[i] : 0;
      final bVal = i < bParts.length ? bParts[i] : 0;
      if (aVal != bVal) return aVal.compareTo(bVal);
    }
    return 0;
  }

  List<int> _extractVersionParts(String version) {
    final cleaned = version.split('+').first;
    return cleaned
        .split('.')
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
  }
}
