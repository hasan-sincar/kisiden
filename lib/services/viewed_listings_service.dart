import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewedListingsService {
  static const _storageKey = 'recently_viewed_listings';
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static Future<void> record({
    required String listingId,
    required Map<String, dynamic> data,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final entries = await _read(preferences, now);
    entries.removeWhere((entry) => entry['id'] == listingId);
    entries.insert(0, {
      'id': listingId,
      'viewedAt': now.toIso8601String(),
      'data': _listingPreview(data),
    });
    await preferences.setString(
      _storageKey,
      jsonEncode(entries.take(100).toList()),
    );
    revision.value++;
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final preferences = await SharedPreferences.getInstance();
    return _read(preferences, DateTime.now());
  }

  static Future<List<Map<String, dynamic>>> _read(
    SharedPreferences preferences,
    DateTime now,
  ) async {
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final valid = decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where((entry) {
          final viewedAt = DateTime.tryParse(entry['viewedAt']?.toString() ?? '');
          return viewedAt != null &&
              now.difference(viewedAt).inHours < 48 &&
              entry['id'] != null &&
              entry['data'] is Map;
        })
        .toList();

    if (valid.length != decoded.length) {
      await preferences.setString(_storageKey, jsonEncode(valid));
    }
    return valid;
  }

  static Map<String, dynamic> _listingPreview(Map<String, dynamic> data) {
    return {
      'title': data['title']?.toString() ?? '',
      'price': data['price'],
      'imageUrl': data['imageUrl']?.toString() ?? '',
      'additionalImages': data['additionalImages'] is List
          ? (data['additionalImages'] as List)
              .map((image) => image.toString())
              .toList()
          : <String>[],
      'city': data['city']?.toString() ?? '',
      'district': data['district']?.toString() ?? '',
      'status': data['status']?.toString() ?? '',
    };
  }
}
