import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  static Future<List<Map<String, dynamic>>> loadActivePreview({
    int limit = 5,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final entries = await _read(preferences, DateTime.now());
    if (entries.isEmpty || limit <= 0) return [];

    const batchSize = 30;
    final activeEntries = <Map<String, dynamic>>[];
    final inactiveIds = <String>{};

    for (var offset = 0; offset < entries.length; offset += batchSize) {
      final batch = entries.skip(offset).take(batchSize).toList();
      final ids = batch.map((entry) => entry['id'].toString()).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('listings')
          .where(FieldPath.documentId, whereIn: ids)
          .get();
      final activeIds = snapshot.docs
          .where((doc) => doc.data()['status'] == 'active')
          .map((doc) => doc.id)
          .toSet();

      for (final entry in batch) {
        final id = entry['id'].toString();
        if (activeIds.contains(id)) {
          activeEntries.add(entry);
          if (activeEntries.length == limit) break;
        } else {
          inactiveIds.add(id);
        }
      }

      if (activeEntries.length == limit) break;
    }

    if (inactiveIds.isNotEmpty) {
      final remaining = entries
          .where((entry) => !inactiveIds.contains(entry['id'].toString()))
          .toList();
      await preferences.setString(_storageKey, jsonEncode(remaining));
    }

    return activeEntries;
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
