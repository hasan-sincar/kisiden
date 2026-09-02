part of 'database_service.dart';

extension DatabaseServiceCommunity on DatabaseService {
  Future<void> toggleFavorite(String listingId, bool isFavorite) async {
    final uid = _auth.currentUser!.uid;
    if (isFavorite) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(listingId)
          .delete();
      await _firestore.collection('listings').doc(listingId).update({
        'favoriteCount': FieldValue.increment(-1),
        'favoritedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(listingId)
          .set({'addedAt': FieldValue.serverTimestamp()});
      await _firestore.collection('listings').doc(listingId).update({
        'favoriteCount': FieldValue.increment(1),
        'favoritedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> incrementViewCount(String listingId) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return;
      var docRef = _firestore.collection('listings').doc(listingId);
      await _firestore.runTransaction((transaction) async {
        var snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        var data = snapshot.data() as Map<String, dynamic>;
        List viewedBy = data['viewedBy'] ?? [];
        if (!viewedBy.contains(uid)) {
          transaction.update(docRef, {
            'viewCount': FieldValue.increment(1),
            'viewedBy': FieldValue.arrayUnion([uid]),
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> deactivateListing(String listingId) async {
    try {
      var doc = await _firestore.collection('listings').doc(listingId).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        List<dynamic> favoritedBy = data['favoritedBy'] ?? [];
        String title = data['title'] ?? 'İlan';
        for (String uid in favoritedBy) {
          await sendNotification(
            uid,
            'notif_title_deactivated',
            'notif_msg_deactivated',
            messageArgs: [title],
          );
        }
      }
    } catch (e) {
      print('İlan pasife alınırken favori bildirimi hatası: $e');
    }
    await _firestore.collection('listings').doc(listingId).update({
      'status': 'passive',
    });
  }

  Stream<bool> isFavoriteStream(String listingId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<bool>.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(listingId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<void> reportListing(String listingId, String reason) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final listingDoc = await _firestore
        .collection('listings')
        .doc(listingId)
        .get();
    final listingData = listingDoc.data();
    final reporterName = (userData?['name'] ?? user.displayName ?? '')
        .toString()
        .trim();
    final reporterEmail = (userData?['email'] ?? user.email ?? '')
        .toString()
        .trim();
    final listingTitle = (listingData?['title'] ?? 'İlan').toString().trim();

    await _firestore.collection('reports').add({
      'listingId': listingId,
      'reporterId': user.uid,
      'reporterName': reporterName,
      'reporterEmail': reporterEmail,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    try {
      await notifyAdminsForNewReport(
        listingId: listingId,
        listingTitle: listingTitle,
        reporterName: reporterName.isNotEmpty ? reporterName : 'Kullanıcı',
        reason: reason,
      );
    } catch (_) {
      // Admin alert is best-effort and should not block report creation.
    }
  }

  Future<void> deleteReport(String reportId) async {
    await _firestore.collection('reports').doc(reportId).delete();
  }

  Future<void> blockUser(String blockedUid) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .set({'timestamp': FieldValue.serverTimestamp()});
    await _firestore.collection('users').doc(uid).set({
      'blockedUsers': FieldValue.arrayUnion([blockedUid]),
    }, SetOptions(merge: true));
    final blockedRef = _firestore.collection('users').doc(blockedUid);
    final blockedSnap = await blockedRef.get();
    if (blockedSnap.exists) {
      await blockedRef.update({
        'blockedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> unblockUser(String blockedUid) async {
    final uid = _auth.currentUser!.uid;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .doc(blockedUid)
        .delete();
    await _firestore.collection('users').doc(uid).set({
      'blockedUsers': FieldValue.arrayRemove([blockedUid]),
    }, SetOptions(merge: true));
    final blockedRef = _firestore.collection('users').doc(blockedUid);
    final blockedSnap = await blockedRef.get();
    if (blockedSnap.exists) {
      await blockedRef.update({
        'blockedBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  Future<bool> askQuestion(
    String listingId,
    String sellerId,
    String question,
    String listingTitle,
  ) async {
    if (await _containsProfanity([question])) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('profanity_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    final user = _auth.currentUser!;

    var userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      List blockedBy = userDoc.data()?['blockedBy'] ?? [];
      List blockedUsers = userDoc.data()?['blockedUsers'] ?? [];
      if (blockedBy.contains(sellerId) || blockedUsers.contains(sellerId)) {
        final ctx = navigatorKey.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(tr('cannot_contact_blocked_seller')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }

    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('questions')
        .add({
          'userId': user.uid,
          'userName': user.displayName ?? 'Kullanıcı',
          'question': question,
          'answer': '',
          'replies': [],
          'timestamp': FieldValue.serverTimestamp(),
        });
    try {
      await sendNotification(
        sellerId,
        'notif_title_new_question',
        'notif_msg_new_question',
        messageArgs: [listingTitle, question],
        type: 'listing',
        targetId: listingId,
      );
    } catch (e) {
      print('Yeni soru bildirimi gönderilemedi: $e');
    }
    return true;
  }

  Future<void> answerQuestion(
    String listingId,
    String questionId,
    String answer,
    String askerId,
    String sellerId,
  ) async {
    if (await _containsProfanity([answer])) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('profanity_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final user = _auth.currentUser!;
    await _firestore
        .collection('listings')
        .doc(listingId)
        .collection('questions')
        .doc(questionId)
        .update({
          'replies': FieldValue.arrayUnion([
            {
              'userId': user.uid,
              'userName': user.displayName ?? 'Kullanıcı',
              'message': answer,
              'timestamp': DateTime.now().toIso8601String(),
            },
          ]),
        });
    String receiverId = (user.uid == sellerId) ? askerId : sellerId;
    String titleKey = (user.uid == sellerId)
        ? 'notif_title_answer_received'
        : 'notif_title_new_reply';
    var listingDoc = await _firestore
        .collection('listings')
        .doc(listingId)
        .get();
    String listingTitle = listingDoc.exists
        ? (listingDoc.data() as Map<String, dynamic>)['title'] ?? ''
        : '';
    await sendNotification(
      receiverId,
      titleKey,
      'notif_msg_new_reply',
      messageArgs: [listingTitle, answer],
      type: 'listing',
      targetId: listingId,
    );
  }

  Future<void> markAsSoldAndGrantReviewPermission(
    String listingId,
    String buyerId,
    String listingTitle,
  ) async {
    final user = _auth.currentUser!;
    final uid = user.uid;
    final userName = user.displayName ?? 'Satıcı';

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('review_permissions')
        .doc(buyerId)
        .set({
          'listingId': listingId,
          'listingTitle': listingTitle,
          'grantedAt': FieldValue.serverTimestamp(),
        });
    await _firestore.collection('users').doc(uid).update({
      'soldCount': FieldValue.increment(1),
    });
    await deleteListing(listingId);

    await sendNotification(
      buyerId,
      'notif_title_rate_seller',
      'notif_msg_rate_seller',
      messageArgs: [userName],
      type: 'review',
      targetId: uid,
    );
  }

  Future<void> addSellerReview(
    String sellerId,
    double rating,
    String comment,
    String listingTitle,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;

    WriteBatch batch = _firestore.batch();

    var reviewRef = _firestore
        .collection('users')
        .doc(sellerId)
        .collection('reviews')
        .doc();
    batch.set(reviewRef, {
      'buyerId': user.uid,
      'buyerName': user.displayName ?? 'İsimsiz',
      'buyerPhoto': user.photoURL ?? '',
      'rating': rating,
      'comment': comment,
      'listingTitle': listingTitle,
      'timestamp': FieldValue.serverTimestamp(),
    });

    var permRef = _firestore
        .collection('users')
        .doc(sellerId)
        .collection('review_permissions')
        .doc(user.uid);
    batch.delete(permRef);

    int roundedRating = rating.round().clamp(1, 5);
    var userRef = _firestore.collection('users').doc(sellerId);
    batch.set(userRef, {
      'ratingCount$roundedRating': FieldValue.increment(1),
      'totalReviewCount': FieldValue.increment(1),
      'totalRatingScore': FieldValue.increment(rating),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> sendNotification(
    String userId,
    String titleKey,
    String messageKey, {
    List<String>? titleArgs,
    List<String>? messageArgs,
    String type = 'general',
    String targetId = '',
    String? reason,
    String source = '',
  }) async {
    final currentUid = _auth.currentUser?.uid;
    String lang = 'tr';
    try {
      var userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        lang = userDoc.data()?['languageCode'] ?? 'tr';
      }
    } catch (e) {}

    String title = translateNotification(titleKey, lang, titleArgs);
    String message = translateNotification(messageKey, lang, messageArgs);

    Map<String, dynamic> payload = {
      'title': title,
      'message': message,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'targetId': targetId,
    };
    if (reason != null && reason.isNotEmpty) payload['reason'] = reason;
    if (source.isNotEmpty) payload['source'] = source;

    // Güvenlik için başka kullanıcıya bildirim yazımı server-side callable ile yapılır.
    if (currentUid != null && currentUid != userId) {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west1',
      ).httpsCallable('sendUserNotification');

      await callable.call({
        'receiverId': userId,
        'title': title,
        'message': message,
        'type': type,
        'targetId': targetId,
        'reason': reason ?? '',
        'source': source.isNotEmpty ? source : 'system',
      });
      return;
    }

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add(payload);
  }

  Future<void> sendMessage(
    String receiverId,
    String message,
    String listingTitle, {
    String? listingId,
    String? listingImage,
    String? listingPrice,
    int? riskScore,
    String? riskLevel,
    List<String>? riskSignals,
  }) async {
    if (await _containsProfanity([message])) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(tr('profanity_error')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    final currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId]..sort();
    String chatRoomId = ids.join('_');
    final payload = <String, dynamic>{
      'participants': ids,
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'listingTitle': listingTitle,
      'unreadBy': FieldValue.arrayUnion([receiverId]),
      if (listingId != null && listingId.isNotEmpty) 'listingId': listingId,
      if (listingImage != null && listingImage.isNotEmpty)
        'listingImage': listingImage,
      if (listingPrice != null && listingPrice.isNotEmpty)
        'listingPrice': listingPrice,
    };
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .set(payload, SetOptions(merge: true));
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'senderName': _auth.currentUser!.displayName ?? 'Kullanıcı',
          'message': message,
          if (riskScore != null) 'riskScore': riskScore,
          if (riskLevel != null && riskLevel.isNotEmpty) 'riskLevel': riskLevel,
          if (riskSignals != null && riskSignals.isNotEmpty)
            'riskSignals': riskSignals,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<List<String>> getCustomReadyMessages() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const <String>[];

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return const <String>[];

    final data = userDoc.data();
    final dynamic raw = data?['customReadyMessages'];
    if (raw is! List) return const <String>[];

    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> saveCustomReadyMessages(List<String> messages) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final sanitized = messages
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    await _firestore.collection('users').doc(uid).set({
      'customReadyMessages': sanitized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendOffer(
    String receiverId,
    String listingTitle,
    String listingId,
    double offerAmount,
  ) async {
    final currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId]..sort();
    String chatRoomId = ids.join('_');
    String messageText = 'Yeni bir teklif: ₺${offerAmount.toStringAsFixed(0)}';

    await _firestore.collection('chats').doc(chatRoomId).set({
      'participants': ids,
      'lastMessage': messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'listingTitle': listingTitle,
      'unreadBy': FieldValue.arrayUnion([receiverId]),
    }, SetOptions(merge: true));

    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'senderId': currentUserId,
          'senderName': _auth.currentUser!.displayName ?? 'Kullanıcı',
          'message': messageText,
          'type': 'offer',
          'offerAmount': offerAmount,
          'offerStatus': 'pending',
          'listingId': listingId,
          'timestamp': FieldValue.serverTimestamp(),
        });
    await sendNotification(
      receiverId,
      'notif_title_new_reply',
      'notif_msg_new_reply',
      type: 'chat',
    );
  }

  Future<void> updateOfferStatus(
    String chatRoomId,
    String messageId,
    String status,
    String receiverId,
  ) async {
    await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .doc(messageId)
        .update({'offerStatus': status});
    await sendNotification(
      receiverId,
      'notif_title_new_reply',
      'notif_msg_new_reply',
      type: 'chat',
    );
  }

  Future<void> markChatAsRead(String chatRoomId) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('chats').doc(chatRoomId).update({
      'unreadBy': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteChat(String chatRoomId) async {
    var messages = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('chats').doc(chatRoomId).delete();
  }

  Future<void> toggleFollowSeller(String sellerId, bool isFollowing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (isFollowing) {
      await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('followers')
          .doc(uid)
          .delete();
      await _firestore.collection('users').doc(sellerId).update({
        'followerCount': FieldValue.increment(-1),
      });
    } else {
      await _firestore
          .collection('users')
          .doc(sellerId)
          .collection('followers')
          .doc(uid)
          .set({'timestamp': FieldValue.serverTimestamp()});
      await _firestore.collection('users').doc(sellerId).update({
        'followerCount': FieldValue.increment(1),
      });
    }
  }

  Stream<bool> isFollowingStream(String sellerId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(false);
    }
    return _firestore
        .collection('users')
        .doc(sellerId)
        .collection('followers')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingTradeOffersStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('trade_offers')
        .where('receiverId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> outgoingTradeOffersStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('trade_offers')
        .where('senderId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendTradeOffer({
    required String receiverId,
    required String senderListingId,
    required String receiverListingId,
    required String message,
    required double estimatedPriceDiff,
  }) async {
    final senderId = _auth.currentUser?.uid;
    if (senderId == null) return;

    final senderListing = await _firestore
        .collection('listings')
        .doc(senderListingId)
        .get();
    final receiverListing = await _firestore
        .collection('listings')
        .doc(receiverListingId)
        .get();

    final senderData = senderListing.data() ?? <String, dynamic>{};
    final receiverData = receiverListing.data() ?? <String, dynamic>{};
    final senderName = (_auth.currentUser?.displayName ?? '').trim().isNotEmpty
        ? _auth.currentUser!.displayName!
        : tr('user');
    final receiverName =
        (receiverData['sellerName'] ?? '').toString().trim().isNotEmpty
        ? receiverData['sellerName'].toString()
        : tr('seller');

    await _firestore
        .collection('trade_offers')
        .add(
          DatabaseService.buildTradeOfferPayload(
            senderId: senderId,
            receiverId: receiverId,
            senderListingId: senderListingId,
            receiverListingId: receiverListingId,
            senderListingTitle: senderData['title']?.toString() ?? '',
            receiverListingTitle: receiverData['title']?.toString() ?? '',
            senderListingImage: senderData['imageUrl']?.toString() ?? '',
            receiverListingImage: receiverData['imageUrl']?.toString() ?? '',
            senderName: senderName,
            receiverName: receiverName,
            senderPrice: (senderData['price'] as num?)?.toDouble() ?? 0,
            receiverPrice: (receiverData['price'] as num?)?.toDouble() ?? 0,
            estimatedPriceDiff: estimatedPriceDiff,
            message: message,
          ),
        );

    await sendNotification(
      receiverId,
      'notif_title_trade_offer',
      'notif_msg_trade_offer',
      messageArgs: [receiverData['title']?.toString() ?? tr('listing_detail')],
      type: 'trade_offer',
      targetId: receiverListingId,
    );
  }

  Future<void> respondTradeOffer({
    required String offerId,
    required bool accepted,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _firestore.collection('trade_offers').doc(offerId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? <String, dynamic>{};
    if (data['receiverId'] != uid) return;

    final status = accepted ? 'accepted' : 'rejected';
    await ref.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final senderId = data['senderId']?.toString() ?? '';
    if (senderId.isNotEmpty) {
      await sendNotification(
        senderId,
        accepted ? 'notif_title_trade_accepted' : 'notif_title_trade_rejected',
        accepted ? 'notif_msg_trade_accepted' : 'notif_msg_trade_rejected',
        messageArgs: [data['senderListingTitle']?.toString() ?? ''],
        type: 'trade_offer',
        targetId: offerId,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getUserListingsForTrade({
    required String uid,
    int limit = 20,
  }) async {
    final snap = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .limit(limit)
        .get();

    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<List<Map<String, dynamic>>> findTradeMatchesForUser({
    int limit = 12,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    final myListingsSnap = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .where('tradeEnabled', isEqualTo: true)
        .limit(6)
        .get();

    final matches = <Map<String, dynamic>>[];
    for (final myDoc in myListingsSnap.docs) {
      final myData = myDoc.data();
      final prefs = Map<String, dynamic>.from(
        myData['tradePreferences'] ?? <String, dynamic>{},
      );
      final desiredCategories = _toStringList(prefs['desiredCategories']);
      final queryCategories = desiredCategories.isEmpty
          ? [myData['categoryPath']?.toString() ?? '']
          : desiredCategories;
      if (queryCategories.isEmpty) continue;

      QuerySnapshot<Map<String, dynamic>> candidatesSnap = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .where('tradeEnabled', isEqualTo: true)
          .where('categoryPath', whereIn: queryCategories.take(10).toList())
          .limit(40)
          .get();

      if (candidatesSnap.docs.isEmpty && desiredCategories.isNotEmpty) {
        // Fallback for parent category selections in hierarchical paths.
        candidatesSnap = await _firestore
            .collection('listings')
            .where('status', isEqualTo: 'active')
            .where('tradeEnabled', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(120)
            .get();
      }

      for (final candidate in candidatesSnap.docs) {
        if (candidate.id == myDoc.id) continue;
        final other = candidate.data();
        if (other['sellerId'] == uid) continue;
        if (!_categoryPathMatchesAny(
          other['categoryPath']?.toString() ?? '',
          queryCategories,
        )) {
          continue;
        }

        final score = _calculateTradeCompatibilityScore(
          myListing: myData,
          otherListing: other,
        );
        if (score < 55) continue;

        final myPrice = (myData['price'] as num?)?.toDouble() ?? 0;
        final otherPrice = (other['price'] as num?)?.toDouble() ?? 0;
        matches.add({
          'myListingId': myDoc.id,
          'otherListingId': candidate.id,
          'myListingTitle': myData['title'] ?? '',
          'otherListingTitle': other['title'] ?? '',
          'otherSellerId': other['sellerId'] ?? '',
          'otherSellerName': other['sellerName'] ?? tr('anonymous_seller'),
          'myListingImage': myData['imageUrl'] ?? '',
          'otherListingImage': other['imageUrl'] ?? '',
          'myPrice': myPrice,
          'otherPrice': otherPrice,
          'estimatedPriceDiff': (myPrice - otherPrice).abs(),
          'compatibilityScore': score,
          'myListingData': myData,
          'otherListingData': other,
        });
      }
    }

    matches.sort(
      (a, b) => (b['compatibilityScore'] as int).compareTo(
        a['compatibilityScore'] as int,
      ),
    );
    return matches.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> getPersonalizedTradeSuggestions({
    int limit = 8,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const [];

    final interestCategories = <String>{};
    final interestBrands = <String>{};
    final interestModels = <String>{};

    final alarmSnap = await _firestore
        .collection('search_alarms')
        .where('userId', isEqualTo: uid)
        .limit(15)
        .get();
    for (final doc in alarmSnap.docs) {
      final data = doc.data();
      final category = data['categoryPath']?.toString();
      if (category != null && category.isNotEmpty) {
        interestCategories.add(category);
      }
      final features = Map<String, dynamic>.from(
        data['features'] ?? <String, dynamic>{},
      );
      final brand = features['Marka']?.toString();
      final model = features['Model']?.toString();
      if (brand != null && brand.isNotEmpty) interestBrands.add(brand);
      if (model != null && model.isNotEmpty) interestModels.add(model);
    }

    final favoritesSnap = await _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .limit(20)
        .get();
    final favoriteIds = favoritesSnap.docs.map((doc) => doc.id).toList();
    for (final chunk in _chunkList(favoriteIds, 10)) {
      final favListings = await _firestore
          .collection('listings')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final listing in favListings.docs) {
        final data = listing.data();
        final category = data['categoryPath']?.toString();
        if (category != null && category.isNotEmpty) {
          interestCategories.add(category);
        }
        final features = Map<String, dynamic>.from(
          data['features'] ?? <String, dynamic>{},
        );
        final brand = features['Marka']?.toString();
        final model = features['Model']?.toString();
        if (brand != null && brand.isNotEmpty) interestBrands.add(brand);
        if (model != null && model.isNotEmpty) interestModels.add(model);
      }
    }

    final viewedSnap = await _firestore
        .collection('listings')
        .where('viewedBy', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .limit(20)
        .get();
    for (final listing in viewedSnap.docs) {
      final data = listing.data();
      final category = data['categoryPath']?.toString();
      if (category != null && category.isNotEmpty) {
        interestCategories.add(category);
      }
    }

    if (interestCategories.isEmpty) {
      final myMatches = await findTradeMatchesForUser(limit: limit);
      return myMatches;
    }

    final suggestions = <Map<String, dynamic>>[];
    for (final categories in _chunkList(interestCategories.toList(), 10)) {
      final snap = await _firestore
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .where('tradeEnabled', isEqualTo: true)
          .where('categoryPath', whereIn: categories)
          .limit(25)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['sellerId'] == uid) continue;
        final features = Map<String, dynamic>.from(
          data['features'] ?? <String, dynamic>{},
        );
        final brand = features['Marka']?.toString() ?? '';
        final model = features['Model']?.toString() ?? '';
        int score = 50;
        if (interestCategories.contains(data['categoryPath'])) score += 22;
        if (brand.isNotEmpty && interestBrands.contains(brand)) score += 14;
        if (model.isNotEmpty && interestModels.contains(model)) score += 14;

        final city = data['city']?.toString() ?? '';
        if (city.isNotEmpty) {
          final myUserDoc = await _firestore.collection('users').doc(uid).get();
          final myCity = myUserDoc.data()?['city']?.toString() ?? '';
          if (myCity.isNotEmpty && myCity == city) {
            score += 8;
          }
        }

        final normalized = score.clamp(55, 98);
        suggestions.add({
          'otherListingId': doc.id,
          'otherListingData': data,
          'otherSellerId': data['sellerId'] ?? '',
          'otherSellerName': data['sellerName'] ?? tr('anonymous_seller'),
          'otherListingTitle': data['title'] ?? '',
          'otherListingImage': data['imageUrl'] ?? '',
          'compatibilityScore': normalized,
          'estimatedPriceDiff': 0.0,
          'explanation': tr('trade_match_explanation_default'),
        });
      }
    }

    suggestions.sort(
      (a, b) => (b['compatibilityScore'] as int).compareTo(
        a['compatibilityScore'] as int,
      ),
    );
    return suggestions.take(limit).toList();
  }

  int _calculateTradeCompatibilityScore({
    required Map<String, dynamic> myListing,
    required Map<String, dynamic> otherListing,
  }) {
    final myPrefs = Map<String, dynamic>.from(
      myListing['tradePreferences'] ?? <String, dynamic>{},
    );
    final otherPrefs = Map<String, dynamic>.from(
      otherListing['tradePreferences'] ?? <String, dynamic>{},
    );

    final myFeatures = Map<String, dynamic>.from(
      myListing['features'] ?? <String, dynamic>{},
    );
    final otherFeatures = Map<String, dynamic>.from(
      otherListing['features'] ?? <String, dynamic>{},
    );

    final myCategory = myListing['categoryPath']?.toString() ?? '';
    final otherCategory = otherListing['categoryPath']?.toString() ?? '';

    final myDesiredCategories = _toStringList(myPrefs['desiredCategories']);
    final otherDesiredCategories = _toStringList(
      otherPrefs['desiredCategories'],
    );

    final categoryForward =
        myDesiredCategories.isEmpty ||
        _categoryPathMatchesAny(otherCategory, myDesiredCategories);
    final categoryBackward =
        otherDesiredCategories.isEmpty ||
        _categoryPathMatchesAny(myCategory, otherDesiredCategories);
    if (!categoryForward || !categoryBackward) return 0;

    int score = 0;
    score += 25;

    final myPrice = (myListing['price'] as num?)?.toDouble() ?? 0;
    final otherPrice = (otherListing['price'] as num?)?.toDouble() ?? 0;
    final diff = (myPrice - otherPrice).abs();

    final myAllowDiff = (myPrefs['allowPriceDifference'] ?? true) == true;
    final otherAllowDiff = (otherPrefs['allowPriceDifference'] ?? true) == true;
    final myMaxDiff =
        (myPrefs['maxPriceDifference'] as num?)?.toDouble() ?? 5000;
    final otherMaxDiff =
        (otherPrefs['maxPriceDifference'] as num?)?.toDouble() ?? 5000;

    if (!myAllowDiff && diff > 0) return 0;
    if (!otherAllowDiff && diff > 0) return 0;
    if (diff <= myMaxDiff && diff <= otherMaxDiff) {
      final ratio = (myPrice <= 0 || otherPrice <= 0)
          ? 0.5
          : (1 - (diff / max(myPrice, otherPrice))).clamp(0.0, 1.0);
      score += (20 * ratio).round();
    }

    final myCity = myListing['city']?.toString() ?? '';
    final otherCity = otherListing['city']?.toString() ?? '';
    if (myCity.isNotEmpty && otherCity.isNotEmpty) {
      score += myCity == otherCity ? 10 : 4;
    }

    final myCreatedAt = (myListing['createdAt'] as Timestamp?)?.toDate();
    final otherCreatedAt = (otherListing['createdAt'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final myAge = myCreatedAt == null
        ? 365
        : now.difference(myCreatedAt).inDays;
    final otherAge = otherCreatedAt == null
        ? 365
        : now.difference(otherCreatedAt).inDays;
    final avgAge = ((myAge + otherAge) / 2).round();
    if (avgAge <= 7) {
      score += 8;
    } else if (avgAge <= 30) {
      score += 6;
    } else if (avgAge <= 90) {
      score += 3;
    }

    final myCondition = _featureByKeys(myFeatures, const [
      'Durum',
      'durum',
      'Condition',
    ]);
    final otherCondition = _featureByKeys(otherFeatures, const [
      'Durum',
      'durum',
      'Condition',
    ]);
    if (myCondition.isNotEmpty && otherCondition.isNotEmpty) {
      score += myCondition == otherCondition ? 7 : 3;
    }

    return score.clamp(0, 100);
  }

  List<String> _toStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _featureByKeys(Map<String, dynamic> features, List<String> keys) {
    for (final key in keys) {
      final value = features[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _categoryPathMatchesAny(String path, List<String> selectedCategories) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) return false;
    for (final selected in selectedCategories) {
      final normalizedSelected = selected.trim();
      if (normalizedSelected.isEmpty) continue;
      if (normalizedPath == normalizedSelected ||
          normalizedPath.startsWith('$normalizedSelected > ')) {
        return true;
      }
    }
    return false;
  }

  List<List<T>> _chunkList<T>(List<T> input, int chunkSize) {
    final chunks = <List<T>>[];
    for (int i = 0; i < input.length; i += chunkSize) {
      final end = min(i + chunkSize, input.length);
      chunks.add(input.sublist(i, end));
    }
    return chunks;
  }
}
