part of 'database_service.dart';

extension DatabaseServiceAccount on DatabaseService {
  Future<void> deleteMyAccountHard() async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west1',
    ).httpsCallable('deleteMyAccountHard');
    await callable.call();
  }

  Future<void> _deleteDocsByQuery(Query<Map<String, dynamic>> query) async {
    const int pageSize = 200;
    while (true) {
      final snap = await query.limit(pageSize).get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
      if (snap.docs.length < pageSize) break;
    }
  }

  Future<void> _deleteSubcollection(
    DocumentReference<Map<String, dynamic>> parentRef,
    String subcollection,
  ) async {
    const int pageSize = 200;
    while (true) {
      final snap = await parentRef
          .collection(subcollection)
          .limit(pageSize)
          .get();
      if (snap.docs.isEmpty) break;
      for (final doc in snap.docs) {
        try {
          await doc.reference.delete();
        } catch (_) {}
      }
      if (snap.docs.length < pageSize) break;
    }
  }

  Future<void> _deleteStorageFolderRecursive(Reference rootRef) async {
    try {
      final result = await rootRef.listAll();
      for (final file in result.items) {
        try {
          await file.delete();
        } catch (_) {}
      }
      for (final prefix in result.prefixes) {
        await _deleteStorageFolderRecursive(prefix);
      }
    } catch (_) {}
  }

  Future<void> saveDeviceToken() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
        String? token = await _messaging.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('FCM Token alınamadı (Web/In-App Tarayıcı): $e');
    }
  }

  Future<void> removeDeviceToken() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      await _messaging.deleteToken();
    } catch (e) {
      print('FCM Token silinemedi: $e');
    }
  }

  Future<void> saveUserToFirestore(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      String defaultName = user.displayName ?? 'İsimsiz';
      await docRef.set({
        'uid': user.uid,
        'name': defaultName,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'phoneNumber': user.phoneNumber ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'soldCount': 0,
        'bannedUntil': null,
        'aboutMe': '',
        'coverPhotoUrl': '',
        'contactPreference': 'both',
        'languageCode': appLocale.value.languageCode,
      });

      try {
        await _analytics.logSignUp(
          signUpMethod: user.email != null && user.email!.isNotEmpty
              ? 'email'
              : 'phone',
        );
      } catch (e) {
        print('Analytics sign_up log hatası: $e');
      }
    } else {
      final data = docSnap.data() as Map<String, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      final currentName = (data['name'] ?? '').toString().trim();
      final authDisplayName = (user.displayName ?? '').trim();
      if ((currentName.isEmpty || currentName == 'İsimsiz') &&
          authDisplayName.isNotEmpty &&
          authDisplayName != 'İsimsiz') {
        updates['name'] = authDisplayName;
      }

      final currentEmail = (data['email'] ?? '').toString().trim();
      final authEmail = (user.email ?? '').trim();
      if (currentEmail.isEmpty && authEmail.isNotEmpty) {
        updates['email'] = authEmail;
      }

      final currentPhone = (data['phoneNumber'] ?? '').toString().trim();
      final authPhone = (user.phoneNumber ?? '').trim();
      if (currentPhone.isEmpty && authPhone.isNotEmpty) {
        updates['phoneNumber'] = authPhone;
      }

      final currentPhoto = (data['photoUrl'] ?? '').toString().trim();
      final authPhoto = (user.photoURL ?? '').trim();
      if (currentPhoto.isEmpty && authPhoto.isNotEmpty) {
        updates['photoUrl'] = authPhoto;
      }

      final currentUid = (data['uid'] ?? '').toString().trim();
      if (currentUid.isEmpty) {
        updates['uid'] = user.uid;
      }

      if (data['createdAt'] == null) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }

      if (updates.isNotEmpty) {
        await docRef.set(updates, SetOptions(merge: true));
      }
    }
    await saveDeviceToken();
  }

  Future<void> updatePhoneNumber(String uid, String phoneNumber) async {
    await _firestore.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
    });
  }

  Future<void> updatePhoneAndName(
    String uid,
    String phoneNumber,
    String name,
    String email,
  ) async {
    final user = _auth.currentUser;
    if (user != null && name.isNotEmpty) await user.updateDisplayName(name);
    await _firestore.collection('users').doc(uid).update({
      'phoneNumber': phoneNumber,
      'name': name.isNotEmpty ? name : 'İsimsiz',
      'email': email,
    });
  }

  Future<void> updateUserProfile(
    String name,
    String email,
    String? photoUrl,
    String aboutMe,
    String? coverPhotoUrl,
    String contactPreference,
  ) async {
    final user = _auth.currentUser!;
    await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
    Map<String, dynamic> updateData = {
      'name': name,
      'email': email,
      'aboutMe': aboutMe,
      'contactPreference': contactPreference,
    };
    if (photoUrl != null) updateData['photoUrl'] = photoUrl;
    if (coverPhotoUrl != null) updateData['coverPhotoUrl'] = coverPhotoUrl;
    await _firestore.collection('users').doc(user.uid).update(updateData);
    var listings = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: user.uid)
        .get();
    for (var doc in listings.docs) {
      await doc.reference.update({'sellerName': name});
    }
  }

  Future<void> toggleEmailNotifications(bool isEnabled) async {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _firestore.collection('users').doc(uid).set({
        'emailNotificationsEnabled': isEnabled,
      }, SetOptions(merge: true));
    }
  }

  Stream<bool> emailNotificationsStream() {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(true);
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data())?['emailNotificationsEnabled'] ?? true);
  }

  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    final normalizedPhone = normalizePhoneNumber(phoneNumber);
    final candidates = <String>{normalizedPhone};

    if (normalizedPhone.startsWith('+90')) {
      candidates.add(normalizedPhone.replaceFirst('+90', '0'));
    }
    if (normalizedPhone.startsWith('0') && normalizedPhone.length > 10) {
      candidates.add(normalizedPhone.replaceFirst('0', '+90'));
    }

    String currentUid = _auth.currentUser?.uid ?? '';
    for (final candidate in candidates) {
      var query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: candidate)
          .get();
      for (var doc in query.docs) {
        if (doc.id != currentUid) return true;
      }
    }
    return false;
  }

  Future<void> markProfileSetupSkipped() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      'profileSetupSkipped': true,
      'profileSetupSkippedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isProfileComplete(String uid) async {
    final docSnap = await _firestore.collection('users').doc(uid).get();
    if (!docSnap.exists) return false;
    var data = docSnap.data() as Map<String, dynamic>;
    final skipped = data['profileSetupSkipped'] == true;
    final hasName =
        (data['name']?.toString().trim().isNotEmpty == true) &&
        data['name'] != 'İsimsiz';
    final hasEmail = data['email']?.toString().trim().isNotEmpty == true;
    final hasPhone = data['phoneNumber']?.toString().trim().isNotEmpty == true;
    final isPhoneAuthUser =
        _auth.currentUser?.providerData.any((p) => p.providerId == 'phone') ??
        false;

    if (isPhoneAuthUser) {
      // Phone-auth users must have name and email filled as mandatory fields
      // They cannot skip this requirement
      return hasName && hasEmail;
    }

    return skipped || (hasPhone && hasName && hasEmail);
  }

  Future<void> deleteAllUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    // 1) Kullanıcının ilanlarını sil
    final listings = await _firestore
        .collection('listings')
        .where('sellerId', isEqualTo: uid)
        .get();
    for (final doc in listings.docs) {
      try {
        await deleteListing(doc.id);
      } catch (_) {}
    }

    // 2) Kullanıcıya bağlı üst seviye koleksiyonları temizle
    await _deleteDocsByQuery(
      _firestore.collection('search_alarms').where('userId', isEqualTo: uid),
    );
    await _deleteDocsByQuery(
      _firestore.collection('reports').where('reporterId', isEqualTo: uid),
    );

    // 3) Kullanıcının ticket kayıtları ve alt mesajları
    final ticketSnap = await _firestore
        .collection('tickets')
        .where('userId', isEqualTo: uid)
        .get();
    for (final ticket in ticketSnap.docs) {
      await _deleteSubcollection(ticket.reference, 'messages');
      try {
        await ticket.reference.delete();
      } catch (_) {}
    }

    // 4) Kullanıcının dahil olduğu chat odaları ve mesajları
    final chatSnap = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    for (final chat in chatSnap.docs) {
      await _deleteSubcollection(chat.reference, 'messages');
      try {
        await chat.reference.delete();
      } catch (_) {}
    }

    // 5) users/{uid} alt koleksiyonlarını temizle
    await _deleteSubcollection(userRef, 'favorites');
    await _deleteSubcollection(userRef, 'blocked');
    await _deleteSubcollection(userRef, 'notifications');
    await _deleteSubcollection(userRef, 'followers');
    await _deleteSubcollection(userRef, 'review_permissions');
    await _deleteSubcollection(userRef, 'reviews');

    // 6) Storage klasörleri (ilan/profil görselleri ve ticket görselleri)
    await _deleteStorageFolderRecursive(
      _storage.ref().child('listing_images').child(uid),
    );
    await _deleteStorageFolderRecursive(
      _storage.ref().child('tickets').child(uid),
    );

    // 7) Son olarak kullanıcı dokümanı
    try {
      await userRef.delete();
    } catch (_) {}
  }

  Future<void> banUser(String sellerId, int days) async {
    final banUntil = DateTime.now().add(Duration(days: days));
    await _firestore.collection('users').doc(sellerId).update({
      'bannedUntil': Timestamp.fromDate(banUntil),
    });
  }

  Future<void> unbanUser(String sellerId) async {
    await _firestore.collection('users').doc(sellerId).update({
      'bannedUntil': null,
    });
  }

  Future<String?> uploadImage(Uint8List fileBytes, String fileName) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      Reference ref = _storage
          .ref()
          .child('listing_images')
          .child(currentUser.uid)
          .child('$fileName.jpg');
      UploadTask uploadTask = ref.putData(
        fileBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e, st) {
      // Daha iyi hata tespiti için hata ve stacktrace'i logluyoruz
      print('uploadImage hata: $e');
      print(st);
      return null;
    }
  }
}
