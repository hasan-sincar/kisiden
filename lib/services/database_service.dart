import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../main.dart';
import '../utils/translations.dart';
import 'auth_service.dart';

part 'database_service_account.dart';
part 'database_service_community.dart';

class DatabaseService {
  static const List<String> _adminEmails = ['hasanmardinn@gmail.com'];

  DatabaseService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseMessaging? messaging,
    FirebaseAnalytics? analytics,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageOverride = storage,
       _auth = auth ?? FirebaseAuth.instance,
       _messagingOverride = messaging,
       _analyticsOverride = analytics;

  static Map<String, dynamic> buildTradeOfferPayload({
    required String senderId,
    required String receiverId,
    required String senderListingId,
    required String receiverListingId,
    required String senderListingTitle,
    required String receiverListingTitle,
    required String senderListingImage,
    required String receiverListingImage,
    required String senderName,
    required String receiverName,
    required double senderPrice,
    required double receiverPrice,
    required double estimatedPriceDiff,
    required String message,
  }) {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'senderListingId': senderListingId,
      'receiverListingId': receiverListingId,
      'senderListingTitle': senderListingTitle,
      'receiverListingTitle': receiverListingTitle,
      'senderListingImage': senderListingImage,
      'receiverListingImage': receiverListingImage,
      'senderName': senderName,
      'receiverName': receiverName,
      'senderPrice': senderPrice,
      'receiverPrice': receiverPrice,
      'estimatedPriceDiff': estimatedPriceDiff,
      'message': message,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storageOverride;
  final FirebaseAuth _auth;
  final FirebaseMessaging? _messagingOverride;
  final FirebaseAnalytics? _analyticsOverride;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;
  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseAnalytics get _analytics =>
      _analyticsOverride ?? FirebaseAnalytics.instance;

  Future<DateTime> _readServerNow() async {
    try {
      final ref = _firestore.collection('_app_meta').doc('server_clock');
      await ref.set({
        'now': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final snap = await ref.get();
      final value = snap.data()?['now'];
      if (value is Timestamp) {
        return value.toDate();
      }
    } catch (_) {}
    return DateTime.now();
  }

  bool _matchesCategoryHierarchy({
    required String listingPath,
    required String alarmPath,
  }) {
    final listing = listingPath.trim();
    final alarm = alarmPath.trim();
    if (alarm.isEmpty) return true;
    if (listing == alarm) return true;
    return listing.startsWith('$alarm > ');
  }

  List<String> _buildCategoryAncestors(String categoryPath) {
    final normalized = categoryPath
        .split('>')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final result = <String>[];
    for (var i = 1; i <= normalized.length; i++) {
      result.add(normalized.take(i).join(' > '));
    }
    return result;
  }

  Future<List<String>> _getAdminUserIds() async {
    final adminIds = <String>{};

    for (final email in _adminEmails) {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) {
        continue;
      }

      final snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .get();

      for (final doc in snap.docs) {
        adminIds.add(doc.id);
      }
    }

    return adminIds.toList();
  }

  Future<void> _notifyAdmins({
    required String titleKey,
    required String messageKey,
    List<String>? titleArgs,
    List<String>? messageArgs,
    String type = 'general',
    String targetId = '',
    String? reason,
  }) async {
    final adminIds = await _getAdminUserIds();
    for (final adminId in adminIds) {
      await sendNotification(
        adminId,
        titleKey,
        messageKey,
        titleArgs: titleArgs,
        messageArgs: messageArgs,
        type: type,
        targetId: targetId,
        reason: reason,
        source: 'admin_alert',
      );
    }
  }

  Future<void> notifyAdminsForNewReport({
    required String listingId,
    required String listingTitle,
    required String reporterName,
    required String reason,
  }) async {
    await _notifyAdmins(
      titleKey: 'admin_alert_new_report_title',
      messageKey: 'admin_alert_new_report_message',
      messageArgs: [reporterName, listingTitle],
      type: 'listing',
      targetId: listingId,
      reason: reason,
    );
  }

  Future<void> notifyAdminsForNewTicket({
    required String ticketId,
    required String subject,
    required String userName,
  }) async {
    await _notifyAdmins(
      titleKey: 'admin_alert_new_ticket_title',
      messageKey: 'admin_alert_new_ticket_message',
      messageArgs: [userName, subject],
      type: 'ticket',
      targetId: ticketId,
    );
  }

  Future<void> notifyAdminsForUpdatedListing({
    required String listingId,
    required String listingTitle,
    required String sellerName,
  }) async {
    await _notifyAdmins(
      titleKey: 'admin_alert_updated_listing_title',
      messageKey: 'admin_alert_updated_listing_message',
      messageArgs: [listingTitle, sellerName],
      type: 'listing',
      targetId: listingId,
    );
  }

  Future<bool> addListing({
    required String title,
    required String description,
    required double price,
    required String imageUrl,
    required List<String> additionalImages,
    required String category,
    required String categoryPath,
    required Map<String, String> featuresMap,
    required User user,
    double? lat,
    double? lng,
    required String city,
    required String district,
    bool isDiscountedForAlarms = false,
    bool isOfferEnabled = true,
    bool autoRenew = false,
    bool isUrgent = false,
    bool tradeEnabled = false,
    Map<String, dynamic>? tradePreferences,
  }) async {
    try {
      if (await _containsProfanity([title, description])) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null)
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(tr('profanity_error')),
              backgroundColor: Colors.red,
            ),
          );
        return false;
      }
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      bool isPro = false;
      String sellerName = user.displayName ?? 'İsimsiz';
      Map<String, dynamic> uData = {};
      int extraRightsBalance = 0;
      if (userDoc.exists) {
        uData = userDoc.data() as Map<String, dynamic>;
        isPro =
            uData['proUntil'] != null &&
            (uData['proUntil'] as Timestamp).toDate().isAfter(DateTime.now());
        final profileName = (uData['name'] ?? '').toString().trim();
        if (profileName.isNotEmpty) {
          sellerName = profileName;
        }
        extraRightsBalance =
            (uData['adminExtraListingLimit'] as num?)?.toInt() ?? 0;
      }
      String listingNo = (Random().nextInt(90000000) + 10000000).toString();
      final now = DateTime.now();
      final bool usesExtraListingRight = extraRightsBalance > 0;
      final Timestamp? listingRightExpiresAt = usesExtraListingRight
          ? Timestamp.fromDate(now.add(const Duration(days: 30)))
          : null;

      if (usesExtraListingRight) {
        await _firestore.runTransaction((transaction) async {
          final userRef = _firestore.collection('users').doc(user.uid);
          final freshUserSnap = await transaction.get(userRef);
          if (!freshUserSnap.exists) return;
          final freshUser = freshUserSnap.data() as Map<String, dynamic>? ?? {};
          final freshExtraRights =
              (freshUser['adminExtraListingLimit'] as num?)?.toInt() ?? 0;
          if (freshExtraRights <= 0) return;

          final proUntil = freshUser['proUntil'];
          final hasActivePro =
              proUntil is Timestamp &&
              proUntil.toDate().isAfter(DateTime.now());
          final proLimit =
              (freshUser['proListingLimit'] as num?)?.toInt() ?? 10;
          final baseLimit = hasActivePro ? max(10, proLimit) : 10;
          final currentAdminLimit = (freshUser['adminListingLimit'] as num?)
              ?.toInt();
          final currentTotalLimit =
              currentAdminLimit ?? (baseLimit + freshExtraRights);
          final nextExtraBalance = freshExtraRights - 1;
          final nextTotalLimit = max(baseLimit, currentTotalLimit - 1);

          transaction.update(userRef, {
            'adminExtraListingLimit': nextExtraBalance,
            'adminListingLimit': nextTotalLimit,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });
      }

      final listingRef = await _firestore.collection('listings').add({
        'listingNo': listingNo,
        'title': title,
        'description': description,
        'price': price,
        'imageUrl': imageUrl,
        'additionalImages': additionalImages,
        'features': featuresMap,
        'isOfferEnabled': isOfferEnabled,
        'category': category,
        'categoryPath': categoryPath,
        'sellerId': user.uid,
        'sellerName': sellerName,
        'sellerPhone': userDoc.data()?['phoneNumber'] ?? '',
        'isPro': isPro,
        'proUntil': isPro ? uData['proUntil'] : null,
        'isDiscountedForAlarms': isDiscountedForAlarms,
        'isUrgent': isUrgent,
        'createdAt': FieldValue.serverTimestamp(),
        'showcaseUntil': null,
        'status': 'pending',
        'lat': lat,
        'lng': lng,
        'city': city,
        'district': district,
        'favoritedBy': [],
        'autoRenew': autoRenew,
        'tradeEnabled': tradeEnabled,
        'tradePreferences': tradePreferences ?? <String, dynamic>{},
        'listingRightExpiresAt': listingRightExpiresAt,
        'listingRightSource': usesExtraListingRight ? 'extra' : null,
      });

      await _notifyAdmins(
        titleKey: 'admin_alert_new_listing_title',
        messageKey: 'admin_alert_new_listing_message',
        messageArgs: [title, sellerName],
        type: 'listing',
        targetId: listingRef.id,
      );

      return true;
    } catch (e) {
      throw Exception("Veritabanına kayıt hatası: $e");
    }
  }

  Future<void> updateListing({
    required String listingId,
    required String title,
    required String description,
    required double price,
    String? newImageUrl,
    List<String>? additionalImages,
    bool? autoRenew,
    String? category,
    String? categoryPath,
    Map<String, String>? featuresMap,
    String? city,
    String? district,
    bool? tradeEnabled,
    Map<String, dynamic>? tradePreferences,
    bool? isUrgent,
    bool isAdmin = false,
  }) async {
    if (!isAdmin && await _containsProfanity([title, description])) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null)
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('profanity_error')),
            backgroundColor: Colors.red,
          ),
        );
      return;
    }
    var listingDoc = await _firestore
        .collection('listings')
        .doc(listingId)
        .get();
    double oldPrice = 0;
    bool isOnlyPriceChanged = false;
    String currentStatus = 'pending';
    Map<String, dynamic> oldData = {};

    if (listingDoc.exists) {
      oldData = listingDoc.data() as Map<String, dynamic>;
      // Eğer daha önce kaydedilmiş bir eski fiyat varsa (henüz onaylanmamışsa) onu koru
      if (oldData.containsKey('oldPrice')) {
        oldPrice = double.tryParse(oldData['oldPrice'].toString()) ?? 0;
      } else {
        oldPrice = double.tryParse(oldData['price'].toString()) ?? 0;
      }

      currentStatus = oldData['status'] ?? 'pending';

      // YENİ: Başka hiçbir şey değişmediyse (Sadece fiyat değiştiyse) tespit et
      bool titleSame =
          (oldData['title'] ?? '').toString().trim() == title.trim();
      bool descSame =
          (oldData['description'] ?? '').toString().trim() ==
          description.trim();
      bool imageSame =
          newImageUrl == null ||
          newImageUrl.trim().isEmpty ||
          newImageUrl == oldData['imageUrl'];

      bool categorySame = category == null || category == oldData['category'];
      bool citySame = city == null || city == oldData['city'];
      bool districtSame = district == null || district == oldData['district'];

      bool addImagesSame = true;
      if (additionalImages != null) {
        List<dynamic> oldAddImages = oldData['additionalImages'] ?? [];
        if (additionalImages.length != oldAddImages.length) {
          addImagesSame = false;
        } else {
          for (int i = 0; i < additionalImages.length; i++) {
            if (additionalImages[i] != oldAddImages[i]) {
              addImagesSame = false;
              break;
            }
          }
        }
      }

      if (titleSame &&
          descSame &&
          imageSame &&
          addImagesSame &&
          categorySame &&
          citySame &&
          districtSame) {
        isOnlyPriceChanged = true;
      }
    }

    Map<String, dynamic> data = {
      'title': title,
      'description': description,
      'price': price,
      // YENİ: Sadece fiyat değiştiyse ilanı onaydan düşürme, eski durumunu koru
      'status': (isAdmin || isOnlyPriceChanged) ? currentStatus : 'pending',
    };

    String _normalize(dynamic value) {
      if (value == null) return '';
      return value.toString().trim();
    }

    String _listKey(List<dynamic> list) =>
        list.map((e) => _normalize(e)).where((e) => e.isNotEmpty).join('||');

    String _mapKey(Map<dynamic, dynamic> map) {
      final entries =
          map.entries
              .map((e) => MapEntry(_normalize(e.key), _normalize(e.value)))
              .where((e) => e.key.isNotEmpty)
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      return entries.map((e) => '${e.key}:${e.value}').join('|');
    }

    final changes = <String, Map<String, String>>{};
    void _addChange(String label, dynamic before, dynamic after) {
      final b = _normalize(before);
      final a = _normalize(after);
      if (b == a) return;
      changes[label] = {
        'before': b.isEmpty ? '-' : b,
        'after': a.isEmpty ? '-' : a,
      };
    }

    _addChange('Başlık', oldData['title'], title);
    _addChange('Açıklama', oldData['description'], description);
    _addChange('Fiyat', oldData['price'], price);
    _addChange(
      'Kategori',
      oldData['categoryPath'] ?? oldData['category'],
      categoryPath ??
          category ??
          oldData['categoryPath'] ??
          oldData['category'],
    );
    _addChange('İl', oldData['city'], city ?? oldData['city']);
    _addChange('İlçe', oldData['district'], district ?? oldData['district']);
    _addChange('Acil', oldData['isUrgent'], isUrgent ?? oldData['isUrgent']);
    _addChange(
      'Otomatik Yenile',
      oldData['autoRenew'],
      autoRenew ?? oldData['autoRenew'],
    );

    if (newImageUrl != null && _normalize(newImageUrl).isNotEmpty) {
      _addChange('Kapak Fotoğrafı', oldData['imageUrl'], newImageUrl);
    }
    if (additionalImages != null) {
      final oldAdditional = List<dynamic>.from(
        oldData['additionalImages'] ?? [],
      );
      if (_listKey(oldAdditional) != _listKey(additionalImages)) {
        changes['Ek Fotoğraflar'] = {
          'before': '${oldAdditional.length} adet',
          'after': '${additionalImages.length} adet',
        };
      }
    }
    if (featuresMap != null) {
      final oldFeatures = Map<String, dynamic>.from(oldData['features'] ?? {});
      if (_mapKey(oldFeatures) != _mapKey(featuresMap)) {
        changes['Özellikler'] = {
          'before': '${oldFeatures.length} alan',
          'after': '${featuresMap.length} alan',
        };
      }
    }

    if (newImageUrl != null) data['imageUrl'] = newImageUrl;
    if (additionalImages != null) data['additionalImages'] = additionalImages;
    if (oldPrice > 0 && oldPrice != price) {
      data['oldPrice'] = oldPrice;
    } else {
      data['oldPrice'] = FieldValue.delete();
    }
    if (autoRenew != null) data['autoRenew'] = autoRenew;
    if (category != null) data['category'] = category;
    if (categoryPath != null) data['categoryPath'] = categoryPath;
    if (featuresMap != null) data['features'] = featuresMap;
    if (city != null) data['city'] = city;
    if (district != null) data['district'] = district;
    if (tradeEnabled != null) data['tradeEnabled'] = tradeEnabled;
    if (tradePreferences != null) data['tradePreferences'] = tradePreferences;
    if (isUrgent != null) data['isUrgent'] = isUrgent;

    // YENI: Vitrin alanlarını koruyun - anasayfa ve kategori vitrini süresi devam etsin
    if (oldData.containsKey('showcaseUntil') &&
        oldData['showcaseUntil'] != null) {
      data['showcaseUntil'] = oldData['showcaseUntil'];
    }
    if (oldData.containsKey('showcasedAt') && oldData['showcasedAt'] != null) {
      data['showcasedAt'] = oldData['showcasedAt'];
    }
    if (oldData.containsKey('categoryShowcaseUntil') &&
        oldData['categoryShowcaseUntil'] != null) {
      data['categoryShowcaseUntil'] = oldData['categoryShowcaseUntil'];
    }
    if (oldData.containsKey('categoryShowcasedAt') &&
        oldData['categoryShowcasedAt'] != null) {
      data['categoryShowcasedAt'] = oldData['categoryShowcasedAt'];
    }

    if (!isAdmin && !isOnlyPriceChanged && changes.isNotEmpty) {
      data['lastEditChangeSummary'] = {
        'updatedAt': FieldValue.serverTimestamp(),
        'changedFields': changes.keys.toList(),
        'changes': changes,
      };
    }

    await _firestore.collection('listings').doc(listingId).update(data);

    if (!isAdmin && !isOnlyPriceChanged && changes.isNotEmpty) {
      final sellerName = _normalize(oldData['sellerName']).isNotEmpty
          ? _normalize(oldData['sellerName'])
          : (_auth.currentUser?.displayName?.trim().isNotEmpty == true
                ? _auth.currentUser!.displayName!.trim()
                : 'Kullanıcı');
      await notifyAdminsForUpdatedListing(
        listingId: listingId,
        listingTitle: title.trim(),
        sellerName: sellerName,
      );
    }

    // YENİ: Sadece fiyat değiştiyse ve fiyat düştüyse anında favorileyenlere bildirim yolla
    if (isOnlyPriceChanged &&
        currentStatus == 'active' &&
        oldPrice > price &&
        listingDoc.exists) {
      List<dynamic> favoritedBy =
          (listingDoc.data() as Map<String, dynamic>)['favoritedBy'] ?? [];
      if (favoritedBy.isNotEmpty) {
        for (String uId in favoritedBy) {
          await sendNotification(
            uId,
            'notif_title_price_change',
            'notif_msg_price_change',
            messageArgs: [
              title,
              oldPrice.toString(),
              price.toString(),
              'dir_down',
            ],
            type: 'listing',
            targetId: listingId,
          );
        }
        await _firestore.collection('listings').doc(listingId).update({
          'oldPrice': FieldValue.delete(),
        });
      }
    }
  }

  Future<void> deleteListing(String listingId) async {
    Map<String, dynamic>? listingData;
    try {
      var doc = await _firestore.collection('listings').doc(listingId).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        listingData = data;
        List<dynamic> favoritedBy = data['favoritedBy'] ?? [];
        String title = data['title'] ?? 'İlan';
        for (String uid in favoritedBy) {
          await sendNotification(
            uid,
            'notif_title_fav_removed',
            'notif_msg_fav_removed',
            messageArgs: [title],
          );
        }
      }
    } catch (e) {
      print("İlan silinirken favori bildirimi hatası: $e");
    }

    // YENI: Silinen ilan active/pending ise once ek (reklam/satin alma) hak havuzunu erit.
    // Boylece ek haklar, ana hak (10 / aktif pro limiti) seviyesine inene kadar geri donmez.
    try {
      final sellerId = (listingData?['sellerId'] ?? '').toString().trim();
      final status = (listingData?['status'] ?? '').toString().trim();
      final consumesSlot = status == 'active' || status == 'pending';

      if (sellerId.isNotEmpty && consumesSlot) {
        final userRef = _firestore.collection('users').doc(sellerId);
        await _firestore.runTransaction((transaction) async {
          final userSnap = await transaction.get(userRef);
          if (!userSnap.exists) return;

          final user = userSnap.data() as Map<String, dynamic>;
          int readLimit(dynamic value, {int fallback = 0}) {
            if (value is num) return value.toInt();
            return int.tryParse(value?.toString() ?? '') ?? fallback;
          }

          final proUntil = user['proUntil'];
          final hasActivePro =
              proUntil is Timestamp &&
              proUntil.toDate().isAfter(DateTime.now());
          final proLimit = readLimit(user['proListingLimit'], fallback: 10);
          final baseLimit = hasActivePro ? max(10, proLimit) : 10;

          final rawAdminLimit = user['adminListingLimit'];
          final currentAdminLimit = rawAdminLimit == null
              ? null
              : readLimit(rawAdminLimit, fallback: baseLimit);
          final storedExtra = readLimit(user['adminExtraListingLimit']);
          final derivedExtraFromLimit = currentAdminLimit == null
              ? 0
              : max(0, currentAdminLimit - baseLimit);
          final currentExtraBalance = max(storedExtra, derivedExtraFromLimit);

          if (currentExtraBalance <= 0) return;

          final nextExtraBalance = currentExtraBalance - 1;
          final nextTotalLimit = baseLimit + nextExtraBalance;
          transaction.set(userRef, {
            'adminExtraListingLimit': nextExtraBalance,
            'adminListingLimit': nextTotalLimit,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
      }
    } catch (e) {
      print('Silinen ilanda hak havuzu guncellenemedi: $e');
    }

    await _firestore.collection('listings').doc(listingId).delete();
  }

  Future<void> republishListing(String listingId) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final listingDoc = await listingRef.get();
    if (!listingDoc.exists) return;

    final data = listingDoc.data() as Map<String, dynamic>? ?? {};
    final hasExtraRightExpiry = data['listingRightExpiresAt'] != null;

    // YENI: Vitrin alanlarını koru
    Map<String, dynamic> showcaseData = {};
    if (data.containsKey('showcaseUntil') && data['showcaseUntil'] != null) {
      showcaseData['showcaseUntil'] = data['showcaseUntil'];
    }
    if (data.containsKey('showcasedAt') && data['showcasedAt'] != null) {
      showcaseData['showcasedAt'] = data['showcasedAt'];
    }
    if (data.containsKey('categoryShowcaseUntil') &&
        data['categoryShowcaseUntil'] != null) {
      showcaseData['categoryShowcaseUntil'] = data['categoryShowcaseUntil'];
    }
    if (data.containsKey('categoryShowcasedAt') &&
        data['categoryShowcasedAt'] != null) {
      showcaseData['categoryShowcasedAt'] = data['categoryShowcasedAt'];
    }

    if (hasExtraRightExpiry) {
      final sellerId = (data['sellerId'] ?? '').toString().trim();
      if (sellerId.isEmpty) {
        throw Exception('İlan sahibi bulunamadı.');
      }

      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(sellerId);
        final userSnap = await transaction.get(userRef);
        if (!userSnap.exists) {
          throw Exception('Kullanıcı bulunamadı.');
        }

        final userData = userSnap.data() as Map<String, dynamic>? ?? {};
        final extraRightsBalance =
            (userData['adminExtraListingLimit'] as num?)?.toInt() ?? 0;
        if (extraRightsBalance <= 0) {
          throw Exception(
            'Bu ilanı tekrar yayınlamak için yeni ilan hakkı satın almanız gerekir.',
          );
        }

        final proUntil = userData['proUntil'];
        final hasActivePro =
            proUntil is Timestamp && proUntil.toDate().isAfter(DateTime.now());
        final proLimit = (userData['proListingLimit'] as num?)?.toInt() ?? 10;
        final baseLimit = hasActivePro ? max(10, proLimit) : 10;
        final currentAdminLimit = (userData['adminListingLimit'] as num?)
            ?.toInt();
        final currentTotalLimit =
            currentAdminLimit ?? (baseLimit + extraRightsBalance);
        final nextExtraBalance = extraRightsBalance - 1;
        final nextTotalLimit = max(baseLimit, currentTotalLimit - 1);

        transaction.update(userRef, {
          'adminExtraListingLimit': nextExtraBalance,
          'adminListingLimit': nextTotalLimit,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        Map<String, dynamic> listingUpdate = {
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'listingRightExpiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'listingRightSource': 'extra',
        };
        listingUpdate.addAll(showcaseData);

        transaction.update(listingRef, listingUpdate);
      });
      return;
    }

    Map<String, dynamic> updateData = {
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
    updateData.addAll(showcaseData);

    await listingRef.update(updateData);
  }

  Future<void> approveListing(
    String listingId,
    String sellerId,
    String title,
  ) async {
    try {
      // İlan bilgilerini çek
      DocumentSnapshot listingSnap = await _firestore
          .collection('listings')
          .doc(listingId)
          .get();
      if (!listingSnap.exists) return; // İlan yoksa çık
      var listingData = listingSnap.data() as Map<String, dynamic>;

      Map<String, dynamic> updateData = {'status': 'active'};
      double price = double.tryParse(listingData['price'].toString()) ?? 0;
      double oldPrice =
          double.tryParse(listingData['oldPrice']?.toString() ?? '0') ?? 0;
      List<dynamic> favoritedBy = listingData['favoritedBy'] ?? [];

      // Onay sırasında fiyat değişmişse ve favorileyen varsa bildirimi şimdi at
      if (oldPrice > 0 && oldPrice != price && favoritedBy.isNotEmpty) {
        String dirKey = price > oldPrice ? 'dir_up' : 'dir_down';
        for (String uId in favoritedBy) {
          await sendNotification(
            uId,
            'notif_title_price_change',
            'notif_msg_price_change',
            messageArgs: [title, oldPrice.toString(), price.toString(), dirKey],
            type: 'listing',
            targetId: listingId,
          );
        }
        updateData['oldPrice'] = FieldValue.delete();
      }
      updateData['lastEditChangeSummary'] = FieldValue.delete();

      // İlanı aktif et ve gerekiyorsa oldPrice bilgisini temizle
      await _firestore.collection('listings').doc(listingId).update(updateData);

      // Satıcıya bildirim gönder
      await sendNotification(
        sellerId,
        'notif_title_approved',
        'notif_msg_approved',
        messageArgs: [title],
        type: 'listing',
        targetId: listingId,
      );

      // --- YENİ: ARAMA ALARMI TETİKLEYİCİSİ (ONAY SONRASI) ---
      String categoryPath = listingData['categoryPath'];
      bool isDiscounted = listingData['isDiscountedForAlarms'] ?? false;

      // Alarmları kontrol et (hiyerarşik: üst kategori alarmları alt kategorileri de yakalar)
      final alarmDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final seenIds = <String>{};
      final categoryCandidates = _buildCategoryAncestors(categoryPath);
      for (var start = 0; start < categoryCandidates.length; start += 10) {
        final end = (start + 10).clamp(0, categoryCandidates.length);
        final chunk = categoryCandidates.sublist(start, end);
        final alarmsSnap = await _firestore
            .collection('search_alarms')
            .where('categoryPath', whereIn: chunk)
            .get();
        for (final doc in alarmsSnap.docs) {
          if (seenIds.add(doc.id)) {
            alarmDocs.add(doc);
          }
        }
      }

      for (var doc in alarmDocs) {
        var alarmData = doc.data();
        if (alarmData['userId'] == sellerId)
          continue; // Kendisinin girdiği ilanda kendine bildirim gitmesin
        final alarmCategoryPath = (alarmData['categoryPath'] ?? '')
            .toString()
            .trim();
        if (!_matchesCategoryHierarchy(
          listingPath: categoryPath,
          alarmPath: alarmCategoryPath,
        )) {
          continue;
        }
        double minP = (alarmData['minPrice'] ?? 0).toDouble();
        double maxP = (alarmData['maxPrice'] ?? double.infinity).toDouble();
        if (maxP == 0) maxP = double.infinity;

        bool match = true;
        if (price < minP || price > maxP) match = false;
        if (alarmData['city'] != null &&
            alarmData['city'] != listingData['city'])
          match = false;
        if (alarmData['district'] != null &&
            alarmData['district'] != listingData['district'])
          match = false;

        Map<String, dynamic> alarmFeatures = alarmData['features'] ?? {};
        Map<String, dynamic> listingFeatures = listingData['features'] ?? {};
        if (alarmFeatures.isNotEmpty) {
          alarmFeatures.forEach((key, value) {
            if (listingFeatures[key] != value) match = false;
          });
        }

        if (match) {
          String notifTitle = isDiscounted
              ? 'notif_title_alarm_discount'
              : 'notif_title_alarm';
          String notifBody = isDiscounted
              ? 'notif_msg_alarm_discount'
              : 'notif_msg_alarm';
          await sendNotification(
            alarmData['userId'],
            notifTitle,
            notifBody,
            messageArgs: [categoryPath, title],
            type: 'listing',
            targetId: listingId,
          );
        }
      }

      // --- YENİ: TAKİPÇİLERE BİLDİRİM GÖNDERME ---
      var followersSnap = await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('followers')
          .get();
      String sellerName = listingData['sellerName'] ?? 'Satıcı';
      for (var doc in followersSnap.docs) {
        await sendNotification(
          doc.id,
          'notif_title_new_listing_from_followed',
          'notif_msg_new_listing_from_followed',
          messageArgs: [sellerName, title],
          type: 'listing',
          targetId: listingId,
        );
      }
    } catch (e) {
      print("İlan onaylama ve alarm hatası: $e");
    }
  }

  Future<void> rejectListing(
    String listingId,
    String sellerId,
    String title, {
    String? reason,
  }) async {
    await deleteListing(listingId);
    if (reason != null && reason.isNotEmpty) {
      await sendNotification(
        sellerId,
        'notif_title_rejected',
        'notif_msg_rejected_reason',
        messageArgs: [title, reason],
        reason: reason,
      );
    } else {
      await sendNotification(
        sellerId,
        'notif_title_rejected',
        'notif_msg_rejected',
        messageArgs: [title],
      );
    }
  }

  // --- YENİ: İLANI REDDETMEK YERİNE DÜZENLEME İSTEMEK İÇİN ---
  Future<void> requestEditListing(
    String listingId,
    String sellerId,
    String title,
    String reason,
  ) async {
    await _firestore.collection('listings').doc(listingId).update({
      'status': 'passive',
    });
    await sendNotification(
      sellerId,
      'notif_title_needs_edit',
      'notif_msg_needs_edit',
      messageArgs: [title, reason],
      reason: reason,
      type: 'listing',
      targetId: listingId,
    );
  }

  Future<void> upgradeListingToShowcase(
    String listingId,
    int days, {
    String? packageId,
    String? price,
  }) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final user = FirebaseAuth.instance.currentUser!;
    final serverNow = await _readServerNow();

    await _firestore.runTransaction((transaction) async {
      final listingSnap = await transaction.get(listingRef);
      if (!listingSnap.exists) return;

      DateTime baseDate = serverNow;
      Timestamp? currentShowcaseUntil =
          (listingSnap.data() as Map<String, dynamic>)['showcaseUntil'];
      if (currentShowcaseUntil != null &&
          currentShowcaseUntil.toDate().isAfter(baseDate)) {
        baseDate = currentShowcaseUntil.toDate();
      }

      final newShowcaseUntil = baseDate.add(Duration(days: days));
      transaction.update(listingRef, {
        'showcaseUntil': Timestamp.fromDate(newShowcaseUntil),
        'showcasedAt': FieldValue.serverTimestamp(),
      });

      if (packageId != null && price != null) {
        var purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': user.uid,
          'userName': user.displayName ?? 'İsimsiz',
          'userEmail': user.email ?? '',
          'packageId': packageId,
          'price': price,
          'days': days,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'Anasayfa Vitrin',
        });
      }
    });
  }

  Future<void> upgradeListingToCategoryShowcase(
    String listingId,
    int days, {
    String? packageId,
    String? price,
  }) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final user = FirebaseAuth.instance.currentUser!;
    final serverNow = await _readServerNow();

    await _firestore.runTransaction((transaction) async {
      final listingSnap = await transaction.get(listingRef);
      if (!listingSnap.exists) return;

      DateTime baseDate = serverNow;
      Timestamp? currentShowcaseUntil =
          (listingSnap.data() as Map<String, dynamic>)['categoryShowcaseUntil'];
      if (currentShowcaseUntil != null &&
          currentShowcaseUntil.toDate().isAfter(baseDate)) {
        baseDate = currentShowcaseUntil.toDate();
      }

      final newShowcaseUntil = baseDate.add(Duration(days: days));
      transaction.update(listingRef, {
        'categoryShowcaseUntil': Timestamp.fromDate(newShowcaseUntil),
        'categoryShowcasedAt': FieldValue.serverTimestamp(),
      });

      if (packageId != null && price != null) {
        var purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': user.uid,
          'userName': user.displayName ?? 'İsimsiz',
          'userEmail': user.email ?? '',
          'packageId': packageId,
          'price': price,
          'days': days,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'Kategori Vitrin',
        });
      }
    });
  }

  Future<void> upgradeListingToUrgent(
    String listingId,
    int days, {
    String? packageId,
    String? price,
  }) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final user = FirebaseAuth.instance.currentUser!;
    final serverNow = await _readServerNow();

    await _firestore.runTransaction((transaction) async {
      final listingSnap = await transaction.get(listingRef);
      if (!listingSnap.exists) return;

      DateTime baseDate = serverNow;
      final data = listingSnap.data() as Map<String, dynamic>;
      final Timestamp? currentUrgentUntil = data['urgentUntil'] as Timestamp?;
      if (currentUrgentUntil != null &&
          currentUrgentUntil.toDate().isAfter(baseDate)) {
        baseDate = currentUrgentUntil.toDate();
      }

      final newUrgentUntil = baseDate.add(Duration(days: days));
      transaction.update(listingRef, {
        'isUrgent': true,
        'urgentUntil': Timestamp.fromDate(newUrgentUntil),
        'urgentActivatedAt': FieldValue.serverTimestamp(),
      });

      if (packageId != null && price != null) {
        var purchaseRef = _firestore.collection('purchases').doc();
        transaction.set(purchaseRef, {
          'userId': user.uid,
          'userName': user.displayName ?? 'İsimsiz',
          'userEmail': user.email ?? '',
          'packageId': packageId,
          'price': price,
          'days': days,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'Acil İlan',
        });
      }
    });
  }

  Future<void> addCategory(
    String nameTr,
    String nameEn,
    String nameAr,
    String parentId, {
    int order = 0,
    String attributeType = "",
  }) async {
    await _firestore.collection('categories').add({
      'name': nameTr,
      'name_en': nameEn,
      'name_ar': nameAr,
      'parentId': parentId,
      'features': [],
      'order': order,
      'attributeType': attributeType,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- YENİ: ÇOKLU (TOPLU) KATEGORİ EKLEME ---
  Future<void> addMultipleCategories(
    String parentId,
    List<String> categoryNames, {
    int startOrder = 0,
    String attributeType = "",
  }) async {
    if (categoryNames.isEmpty) return;
    WriteBatch batch = _firestore.batch();

    for (int i = 0; i < categoryNames.length; i++) {
      String name = categoryNames[i].trim();
      if (name.isEmpty) continue;

      DocumentReference docRef = _firestore.collection('categories').doc();
      batch.set(docRef, {
        'name': name,
        'name_en':
            name, // Çeviriler varsayılan olarak Türkçe ile aynı bırakılır, gerekirse panelden düzenlenir
        'name_ar': name,
        'parentId': parentId,
        'features': [],
        'order': startOrder + i,
        'attributeType': attributeType,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> addCategoryFeature(
    String categoryId,
    String nameTr,
    String nameEn,
    String nameAr,
    List<String> optTr,
    List<String> optEn,
    List<String> optAr,
  ) async {
    await _firestore.collection('categories').doc(categoryId).set({
      'features': FieldValue.arrayUnion([
        {
          'name': nameTr,
          'name_en': nameEn,
          'name_ar': nameAr,
          'options': optTr,
          'options_en': optEn,
          'options_ar': optAr,
        },
      ]),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCategoryFeature(String categoryId, dynamic feature) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'features': FieldValue.arrayRemove([feature]),
    });
  }

  Future<void> updateCategoryFeature(
    String categoryId,
    dynamic oldFeature,
    String nameTr,
    String nameEn,
    String nameAr,
    List<String> optTr,
    List<String> optEn,
    List<String> optAr,
  ) async {
    final trimmedTr = nameTr.trim();
    final trimmedEn = nameEn.trim().isNotEmpty ? nameEn.trim() : trimmedTr;
    final trimmedAr = nameAr.trim().isNotEmpty ? nameAr.trim() : trimmedTr;

    dynamic newFeature;
    if (oldFeature is String &&
        optTr.isEmpty &&
        optEn.isEmpty &&
        optAr.isEmpty &&
        trimmedEn == trimmedTr &&
        trimmedAr == trimmedTr) {
      newFeature = trimmedTr;
    } else {
      newFeature = {
        'name': trimmedTr,
        'name_en': trimmedEn,
        'name_ar': trimmedAr,
        'options': optTr,
        'options_en': optEn,
        'options_ar': optAr,
      };
    }

    final docRef = _firestore.collection('categories').doc(categoryId);
    final batch = _firestore.batch();
    batch.update(docRef, {
      'features': FieldValue.arrayRemove([oldFeature]),
    });
    batch.set(docRef, {
      'features': FieldValue.arrayUnion([newFeature]),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> deleteCategory(String categoryId) async {
    var subCats = await _firestore
        .collection('categories')
        .where('parentId', isEqualTo: categoryId)
        .get();
    for (var doc in subCats.docs) {
      await deleteCategory(doc.id);
    }
    await _firestore.collection('categories').doc(categoryId).delete();
  }

  Future<void> updateCategoryName(
    String categoryId,
    String newNameTr,
    String newNameEn,
    String newNameAr,
    String attributeType,
  ) async {
    await _firestore.collection('categories').doc(categoryId).update({
      'name': newNameTr,
      'name_en': newNameEn,
      'name_ar': newNameAr,
      'attributeType': attributeType,
    });
  }

  Future<Map<String, int>> backfillCategoryFeatureTranslations({
    bool overwriteExisting = false,
  }) async {
    final categoriesSnap = await _firestore.collection('categories').get();
    final translator = GoogleTranslator();
    final Map<String, String> translationCache = <String, String>{};

    Future<String> translateFromTr(String value, String targetLang) async {
      final input = value.trim();
      if (input.isEmpty) return '';

      final cacheKey = '$targetLang::$input';
      final cached = translationCache[cacheKey];
      if (cached != null) return cached;

      try {
        final translated = await translator.translate(
          input,
          from: 'tr',
          to: targetLang,
        );
        final text = translated.text.trim();
        if (text.isNotEmpty) {
          translationCache[cacheKey] = text;
          return text;
        }
      } catch (_) {}

      translationCache[cacheKey] = input;
      return input;
    }

    bool listEqualsShallow(List<String> a, List<String> b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    Future<List<String>> translateOptions(
      List<String> options,
      String targetLang,
    ) async {
      final result = <String>[];
      for (final option in options) {
        final translated = await translateFromTr(option, targetLang);
        result.add(translated);
      }
      return result;
    }

    int categoriesUpdated = 0;
    int featuresUpdated = 0;
    int translatedNameFields = 0;
    int translatedOptionItems = 0;

    WriteBatch batch = _firestore.batch();
    int pendingWrites = 0;

    for (final doc in categoriesSnap.docs) {
      final data = doc.data();
      final rawFeatures = data['features'];
      if (rawFeatures is! List) continue;

      bool categoryChanged = false;
      final updatedFeatures = <dynamic>[];

      for (final rawFeature in rawFeatures) {
        if (rawFeature is String) {
          final trName = rawFeature.trim();
          if (trName.isEmpty) {
            updatedFeatures.add(rawFeature);
            continue;
          }

          final enName = await translateFromTr(trName, 'en');
          final arName = await translateFromTr(trName, 'ar');

          translatedNameFields += 2;
          featuresUpdated++;
          categoryChanged = true;

          updatedFeatures.add({
            'name': trName,
            'name_en': enName,
            'name_ar': arName,
            'options': <String>[],
            'options_en': <String>[],
            'options_ar': <String>[],
          });
          continue;
        }

        if (rawFeature is Map) {
          final featureMap = Map<String, dynamic>.from(rawFeature);
          final updatedMap = Map<String, dynamic>.from(featureMap);

          final trName = (featureMap['name'] ?? '').toString().trim();
          if (trName.isEmpty) {
            updatedFeatures.add(rawFeature);
            continue;
          }

          final oldEnName = (featureMap['name_en'] ?? '').toString().trim();
          final oldArName = (featureMap['name_ar'] ?? '').toString().trim();

          String nextEnName = oldEnName;
          if (overwriteExisting || oldEnName.isEmpty) {
            nextEnName = await translateFromTr(trName, 'en');
            if (nextEnName != oldEnName) {
              translatedNameFields++;
            }
          }

          String nextArName = oldArName;
          if (overwriteExisting || oldArName.isEmpty) {
            nextArName = await translateFromTr(trName, 'ar');
            if (nextArName != oldArName) {
              translatedNameFields++;
            }
          }

          final trOptions = featureMap['options'] is List
              ? List<String>.from(
                  (featureMap['options'] as List)
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty),
                )
              : <String>[];

          final oldEnOptions = featureMap['options_en'] is List
              ? List<String>.from(
                  (featureMap['options_en'] as List)
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty),
                )
              : <String>[];
          final oldArOptions = featureMap['options_ar'] is List
              ? List<String>.from(
                  (featureMap['options_ar'] as List)
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty),
                )
              : <String>[];

          List<String> nextEnOptions = oldEnOptions;
          if (overwriteExisting || oldEnOptions.isEmpty) {
            nextEnOptions = await translateOptions(trOptions, 'en');
            if (!listEqualsShallow(nextEnOptions, oldEnOptions)) {
              translatedOptionItems += nextEnOptions.length;
            }
          }

          List<String> nextArOptions = oldArOptions;
          if (overwriteExisting || oldArOptions.isEmpty) {
            nextArOptions = await translateOptions(trOptions, 'ar');
            if (!listEqualsShallow(nextArOptions, oldArOptions)) {
              translatedOptionItems += nextArOptions.length;
            }
          }

          final featureChanged =
              nextEnName != oldEnName ||
              nextArName != oldArName ||
              !listEqualsShallow(nextEnOptions, oldEnOptions) ||
              !listEqualsShallow(nextArOptions, oldArOptions);

          if (featureChanged) {
            featuresUpdated++;
            categoryChanged = true;
          }

          updatedMap['name'] = trName;
          updatedMap['name_en'] = nextEnName.isNotEmpty ? nextEnName : trName;
          updatedMap['name_ar'] = nextArName.isNotEmpty ? nextArName : trName;
          updatedMap['options'] = trOptions;
          updatedMap['options_en'] = nextEnOptions;
          updatedMap['options_ar'] = nextArOptions;

          updatedFeatures.add(updatedMap);
          continue;
        }

        updatedFeatures.add(rawFeature);
      }

      if (!categoryChanged) continue;

      batch.update(doc.reference, {'features': updatedFeatures});
      pendingWrites++;
      categoriesUpdated++;

      if (pendingWrites >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        pendingWrites = 0;
      }
    }

    if (pendingWrites > 0) {
      await batch.commit();
    }

    return {
      'categoriesScanned': categoriesSnap.docs.length,
      'categoriesUpdated': categoriesUpdated,
      'featuresUpdated': featuresUpdated,
      'translatedNameFields': translatedNameFields,
      'translatedOptionItems': translatedOptionItems,
    };
  }

  Future<void> updateCategoriesOrder(
    List<Map<String, dynamic>> categoryOrders,
  ) async {
    WriteBatch batch = _firestore.batch();
    for (var item in categoryOrders) {
      batch.update(_firestore.collection('categories').doc(item['id']), {
        'order': item['order'],
      });
    }
    await batch.commit();
  }

  Stream<QuerySnapshot> getCategoriesStream(String parentId) => _firestore
      .collection('categories')
      .where('parentId', isEqualTo: parentId)
      .snapshots();

  // --- YENİ: REKLAM AYARLARINI KAYDETME VE OKUMA FONKSİYONLARI ---
  Future<void> updateAdSettings(
    bool isActive,
    String androidId,
    String iosId,
  ) async {
    await _firestore.collection('settings').doc('ads').set({
      'isActive': isActive,
      'androidId': androidId,
      'iosId': iosId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateAppUpdateSettings({
    required bool updateEnabled,
    required String latestVersion,
    required String minSupportedVersion,
    required bool forceUpdate,
    required String updateTitle,
    required String updateMessage,
    required String storeUrlAndroid,
    required String storeUrlIos,
    required int remindIntervalHours,
  }) async {
    await _firestore.collection('settings').doc('app_update').set({
      'updateEnabled': updateEnabled,
      'latestVersion': latestVersion,
      'minSupportedVersion': minSupportedVersion,
      'forceUpdate': forceUpdate,
      'updateTitle': updateTitle,
      'updateMessage': updateMessage,
      'storeUrlAndroid': storeUrlAndroid,
      'storeUrlIos': storeUrlIos,
      'remindIntervalHours': remindIntervalHours,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateListingRightsSettings({
    required String rewardedAndroidAdUnitId,
    required String rewardedIosAdUnitId,
    required int rewardDailyMax,
    required int rewardCooldownMinutes,
    required List<Map<String, dynamic>> paidPackages,
  }) async {
    await _firestore.collection('settings').doc('listing_rights').set({
      'rewardedAndroidAdUnitId': rewardedAndroidAdUnitId,
      'rewardedIosAdUnitId': rewardedIosAdUnitId,
      'rewardDailyMax': rewardDailyMax,
      'rewardCooldownMinutes': rewardCooldownMinutes,
      'paidPackages': paidPackages,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // --- YENİ: ARAMA ALARMI FONKSİYONLARI ---
  Future<void> addSearchAlarm(
    String categoryPath,
    double minPrice,
    double maxPrice,
    String? city,
    String? district,
    Map<String, String> features,
  ) async {
    await _firestore.collection('search_alarms').add({
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'categoryPath': categoryPath,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'city': city,
      'district': district,
      'features': features,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSearchAlarm(String alarmId) async {
    await _firestore.collection('search_alarms').doc(alarmId).delete();
  }

  // --- YENİ: ALARM KURULDUĞUNDA MEVCUT İLANLARI KONTROL ETME ---
  Future<int> checkActiveListingsForAlarm({
    required String categoryPath,
    required double minPrice,
    required double maxPrice,
    String? city,
    String? district,
    required Map<String, String> features,
  }) async {
    try {
      var snap = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .get();
      int matchCount = 0;
      String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      for (var doc in snap.docs) {
        var data = doc.data();
        if (data['sellerId'] == currentUid) continue;

        bool match = true;
        final listingCategoryPath = (data['categoryPath'] ?? '').toString();
        if (!_matchesCategoryHierarchy(
          listingPath: listingCategoryPath,
          alarmPath: categoryPath,
        )) {
          match = false;
        }
        if (city != null && city.isNotEmpty && data['city'] != city)
          match = false;
        if (district != null &&
            district.isNotEmpty &&
            data['district'] != district)
          match = false;

        double price = double.tryParse(data['price'].toString()) ?? 0;
        if (minPrice > 0 && price < minPrice) match = false;
        if (maxPrice > 0 && maxPrice != double.infinity && price > maxPrice)
          match = false;

        if (features.isNotEmpty) {
          Map<String, dynamic> listingFeatures = data['features'] ?? {};
          features.forEach((key, val) {
            if (listingFeatures[key] != val) match = false;
          });
        }

        if (match) matchCount++;
      }
      return matchCount;
    } catch (e) {
      print("Alarm ilan kontrol hatası: $e");
      return 0;
    }
  }

  // --- YENİ: İLAN VERİLİRKEN ARAMA ALARMLARINI KONTROL ETME (GROWTH HACKING) ---
  Future<Map<String, dynamic>> checkAlarmsForListing({
    required String categoryPath,
    required String city,
    required String district,
    required Map<String, String> features,
    required String currentUserId,
  }) async {
    int matchCount = 0;
    double maxBudget = 0;

    try {
      final alarmDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final seenIds = <String>{};
      final categoryCandidates = _buildCategoryAncestors(categoryPath);
      for (var start = 0; start < categoryCandidates.length; start += 10) {
        final end = (start + 10).clamp(0, categoryCandidates.length);
        final chunk = categoryCandidates.sublist(start, end);
        final alarmsSnap = await _firestore
            .collection('search_alarms')
            .where('categoryPath', whereIn: chunk)
            .get();
        for (final doc in alarmsSnap.docs) {
          if (seenIds.add(doc.id)) {
            alarmDocs.add(doc);
          }
        }
      }

      for (var doc in alarmDocs) {
        var data = doc.data();
        if (data['userId'] == currentUserId) continue; // Kendi alarmıysa geç
        final alarmCategoryPath = (data['categoryPath'] ?? '').toString();
        if (!_matchesCategoryHierarchy(
          listingPath: categoryPath,
          alarmPath: alarmCategoryPath,
        )) {
          continue;
        }

        bool match = true;
        if (data['city'] != null && data['city'] != city) match = false;
        if (data['district'] != null && data['district'] != district)
          match = false;

        Map<String, dynamic> alarmFeatures = data['features'] ?? {};
        if (alarmFeatures.isNotEmpty) {
          alarmFeatures.forEach((key, value) {
            if (features[key] != value) match = false;
          });
        }

        if (match) {
          matchCount++;
          double budget = (data['maxPrice'] ?? double.infinity).toDouble();
          // Bütçesi sınırsız (infinity) olmayanlar arasında en yüksek bütçeyi bul
          if (budget > maxBudget && budget != double.infinity)
            maxBudget = budget;
        }
      }
    } catch (e) {
      print("Alarm kontrolü hatası: $e");
    }

    return {'matchCount': matchCount, 'maxBudget': maxBudget};
  }

  // --- YENİ: ADMİN PANELİ İÇİN TOPLAM AKTİF İLAN SAYISI ---
  Future<int> getTotalActiveListingsCount() async {
    try {
      var snap = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      print("Aktif ilan sayısı alınamadı: $e");
      return 0;
    }
  }

  // --- YENİ: KULLANICIYI PRO MAĞAZA YAPMA FONKSİYONU ---
  Future<void> upgradeToPro(
    int days,
    int limit, {
    String? packageId,
    String? price,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final userDoc = await _firestore.collection('users').doc(uid).get();
    DateTime baseDate = DateTime.now();
    if (userDoc.exists && userDoc.data()?['proUntil'] != null) {
      DateTime currentProUntil = (userDoc.data()!['proUntil'] as Timestamp)
          .toDate();
      if (currentProUntil.isAfter(baseDate)) {
        baseDate =
            currentProUntil; // Mevcut paket devam ediyorsa, yeni paketi sürenin üzerine ekle
      }
    }

    final proUntil = baseDate.add(Duration(days: days));

    int addHomeShowcase = 0;
    int addCategoryShowcase = 0;
    int addUrgentCount = 0;

    // Satın alınan paketin gün sayısına göre hediye vitrin haklarını belirliyoruz
    if (days >= 80 && days <= 100) {
      // 3 Aylık (Yaklaşık 90 gün)
      addHomeShowcase = 2;
      addCategoryShowcase = 2;
      addUrgentCount = 2;
    } else if (days >= 170 && days <= 190) {
      // 6 Aylık (Yaklaşık 180 gün)
      addHomeShowcase = 10;
      addCategoryShowcase = 10;
      addUrgentCount = 10;
    } else if (days >= 350) {
      // 1 Yıllık (Yaklaşık 365 gün)
      addHomeShowcase = 25;
      addCategoryShowcase = 25;
      addUrgentCount = 25;
    }

    WriteBatch batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'proUntil': Timestamp.fromDate(proUntil),
      'proListingLimit': limit,
      'freeHomeShowcaseCount': FieldValue.increment(addHomeShowcase),
      'freeCategoryShowcaseCount': FieldValue.increment(addCategoryShowcase),
      'freeUrgentCount': FieldValue.increment(addUrgentCount),
    });

    // YENİ: Kullanıcının mevcut tüm ilanlarını da Pro olarak işaretle
    var listings = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .get();
    for (var doc in listings.docs) {
      batch.update(doc.reference, {
        'isPro': true,
        'proUntil': Timestamp.fromDate(proUntil),
      });
    }

    if (packageId != null && price != null) {
      var purchaseRef = _firestore.collection('purchases').doc();
      batch.set(purchaseRef, {
        'userId': uid,
        'userName': user.displayName ?? 'İsimsiz',
        'userEmail': user.email ?? '',
        'packageId': packageId,
        'price': price,
        'days': days,
        'limit': limit,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'Pro Paket',
      });
    }

    await batch.commit();
  }

  /// Yönetici panelinden üyeye bağımsız olarak Pro süresi ve/veya ilan hakkı tanımlar.
  Future<int?> grantProToUser({
    required String userId,
    required bool grantPro,
    int? days,
    int? additionalListingRights,
  }) async {
    if (userId.isEmpty ||
        (!grantPro && additionalListingRights == null) ||
        (grantPro && (days == null || days <= 0)) ||
        (additionalListingRights != null && additionalListingRights <= 0)) {
      throw ArgumentError('Geçerli paket bilgileri gerekli.');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    int readLimit(dynamic value, {int fallback = 0}) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    final previousProUntil = userData['proUntil'];
    final hasActivePro =
        previousProUntil is Timestamp &&
        previousProUntil.toDate().isAfter(DateTime.now());
    final currentProLimit = readLimit(
      userData['proListingLimit'],
      fallback: 10,
    );
    final currentExtraLimit = readLimit(userData['adminExtraListingLimit']);
    final currentAdminLimit = userData.containsKey('adminListingLimit')
        ? readLimit(userData['adminListingLimit'])
        : null;
    var homeShowcaseBonus = 0;
    var categoryShowcaseBonus = 0;
    var urgentBonus = 0;
    Timestamp? proUntil;
    if (grantPro) {
      final proDays = days!;
      var baseDate = DateTime.now();
      if (hasActivePro) {
        baseDate = previousProUntil.toDate();
      }
      proUntil = Timestamp.fromDate(baseDate.add(Duration(days: proDays)));

      if (proDays >= 80 && proDays <= 100) {
        homeShowcaseBonus = 2;
        categoryShowcaseBonus = 2;
        urgentBonus = 2;
      } else if (proDays >= 170 && proDays <= 190) {
        homeShowcaseBonus = 10;
        categoryShowcaseBonus = 10;
        urgentBonus = 10;
      } else if (proDays >= 350) {
        homeShowcaseBonus = 25;
        categoryShowcaseBonus = 25;
        urgentBonus = 25;
      }
    }

    final userUpdate = <String, dynamic>{};
    int? assignedListingLimit;
    if (proUntil != null) {
      userUpdate.addAll({
        'proUntil': proUntil,
        'freeHomeShowcaseCount': FieldValue.increment(homeShowcaseBonus),
        'freeCategoryShowcaseCount': FieldValue.increment(
          categoryShowcaseBonus,
        ),
        'freeUrgentCount': FieldValue.increment(urgentBonus),
      });
    }
    if (additionalListingRights != null) {
      // YENI: Ek haklar bakiye mantigiyla saklanir. Toplam limit = ana limit + ek hak bakiyesi.
      final baseLimit = hasActivePro ? max(10, currentProLimit) : 10;
      final derivedExtraFromLimit = currentAdminLimit == null
          ? 0
          : max(0, currentAdminLimit - baseLimit);
      final currentExtraBalance = max(currentExtraLimit, derivedExtraFromLimit);
      final nextExtraBalance = currentExtraBalance + additionalListingRights;
      final newTotalLimit = baseLimit + nextExtraBalance;
      userUpdate['adminListingLimit'] = newTotalLimit;
      assignedListingLimit = newTotalLimit;
      userUpdate['adminExtraListingLimit'] = nextExtraBalance;
    }

    final listings = grantPro
        ? await _firestore
              .collection('listings')
              .where('sellerId', isEqualTo: userId)
              .get()
        : null;

    final actionType = grantPro && additionalListingRights != null
        ? 'Yönetici Pro Paketi ve İlan Hakkı'
        : grantPro
        ? 'Yönetici Pro Paketi'
        : 'Yönetici İlan Hakkı';

    // Önce üyenin hakkını atomik olarak yazıyoruz. Böylece satın alma kaydı
    // veya çok sayıdaki ilan güncellemesi hata verse bile ilan hakkı kaybolmaz.
    await _firestore.runTransaction((transaction) async {
      transaction.set(userRef, userUpdate, SetOptions(merge: true));
    });

    if (assignedListingLimit != null) {
      final verifiedUser = await userRef.get();
      final verifiedLimit = readLimit(
        verifiedUser.data()?['adminListingLimit'],
      );
      if (verifiedLimit != assignedListingLimit) {
        throw StateError('İlan hakkı doğrulanamadı.');
      }
    }

    // Firestore bir batch'te en fazla 500 yazma kabul eder. Büyük mağazalar
    // için işlemi güvenli parçalara ayırıyoruz.
    final writes = <void Function(WriteBatch)>[
      (batch) => batch.set(_firestore.collection('purchases').doc(), {
        'userId': userId,
        'userName': userData['name'] ?? 'İsimsiz',
        'userEmail': userData['email'] ?? '',
        'packageId': 'admin_manual',
        'price': 'Yönetici tanımı',
        'days': days ?? 0,
        'addedListingLimit': additionalListingRights ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
        'type': actionType,
      }),
      ...?listings?.docs.map(
        (listing) =>
            (WriteBatch batch) => batch.update(listing.reference, {
              'isPro': true,
              'proUntil': proUntil,
            }),
      ),
    ];

    for (var start = 0; start < writes.length; start += 450) {
      final batch = _firestore.batch();
      final end = (start + 450).clamp(0, writes.length);
      for (var index = start; index < end; index++) {
        writes[index](batch);
      }
      await batch.commit();
    }

    final notificationParts = <String>[];
    if (grantPro) notificationParts.add('$days günlük Pro paketiniz');
    if (additionalListingRights != null) {
      notificationParts.add('$additionalListingRights ek ilan hakkınız');
    }
    await sendNotification(
      userId,
      'Paket Tanımlandı',
      '${notificationParts.join(' ve ')} tanımlandı.',
      targetId: userId,
    );
    return assignedListingLimit;
  }

  /// Yönetici kampanya/duyuru bildirimlerini tek kullanıcıya veya tüm üyelere gönderir.
  Future<int> sendAdminBroadcastNotification({
    required String title,
    required String message,
    required String notificationType,
    List<String>? targetUserIds,
    String targetId = '',
    String imageUrl = '',
  }) async {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    final normalizedType = notificationType.trim();
    final normalizedImageUrl = imageUrl.trim();

    if (normalizedTitle.isEmpty ||
        normalizedMessage.isEmpty ||
        normalizedType.isEmpty) {
      throw ArgumentError('Bildirim başlığı, mesajı ve tipi zorunludur.');
    }

    List<String> recipients;
    if (targetUserIds != null && targetUserIds.isNotEmpty) {
      recipients = targetUserIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } else {
      final usersSnap = await _firestore.collection('users').get();
      recipients = usersSnap.docs.map((doc) => doc.id).toList();
    }

    if (recipients.isEmpty) return 0;

    final adminUid = _auth.currentUser?.uid;

    for (var start = 0; start < recipients.length; start += 400) {
      final batch = _firestore.batch();
      final end = (start + 400).clamp(0, recipients.length);

      for (var index = start; index < end; index++) {
        final userId = recipients[index];
        final ref = _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();

        batch.set(ref, {
          'title': normalizedTitle,
          'message': normalizedMessage,
          'isRead': false,
          'timestamp': FieldValue.serverTimestamp(),
          'type': normalizedType,
          'targetId': targetId,
          'source': 'admin_broadcast',
          'createdBy': adminUid,
          if (normalizedImageUrl.isNotEmpty) 'imageUrl': normalizedImageUrl,
        });
      }

      await batch.commit();
    }

    return recipients.length;
  }

  // --- YENİ: KÜFÜR FİLTRESİ FONKSİYONLARI ---
  Future<List<String>> getProfanityWords() async {
    try {
      var doc = await _firestore.collection('settings').doc('profanity').get();
      if (doc.exists && doc.data() != null) {
        return List<String>.from(doc.data()!['words'] ?? []);
      }
    } catch (e) {
      print("Küfür listesi alınırken izin/ağ hatası: $e");
    }
    return [];
  }

  Future<void> addProfanityWord(String word) async {
    await _firestore.collection('settings').doc('profanity').set({
      'words': FieldValue.arrayUnion([word.toLowerCase().trim()]),
    }, SetOptions(merge: true));
  }

  Future<void> removeProfanityWord(String word) async {
    await _firestore.collection('settings').doc('profanity').set({
      'words': FieldValue.arrayRemove([word.toLowerCase().trim()]),
    }, SetOptions(merge: true));
  }

  Future<bool> _containsProfanity(List<String> texts) async {
    List<String> badWords = await getProfanityWords();
    for (String text in texts) {
      String lowerText = text.toLowerCase();
      for (String word in badWords) {
        if (word.isNotEmpty && lowerText.contains(word)) return true;
      }
    }
    return false;
  }
}
