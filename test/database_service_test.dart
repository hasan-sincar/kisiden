import 'package:appim/services/database_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseService', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late MockUser user;
    late DatabaseService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      user = MockUser(
        uid: 'user-1',
        email: 'user@example.com',
        displayName: 'Test User',
      );
      auth = MockFirebaseAuth(mockUser: user, signedIn: true);
      service = DatabaseService(firestore: firestore, auth: auth);
    });

    test('isProfileComplete returns true when required fields exist', () async {
      await firestore.collection('users').doc(user.uid).set({
        'phoneNumber': '+905321234567',
        'name': 'Test User',
        'email': 'user@example.com',
      });

      final result = await service.isProfileComplete(user.uid);

      expect(result, isTrue);
    });

    test(
      'markProfileSetupSkipped persists skip markers for current user',
      () async {
        await service.markProfileSetupSkipped();

        final snapshot = await firestore
            .collection('users')
            .doc(user.uid)
            .get();

        expect(snapshot.data()?['profileSetupSkipped'], isTrue);
        expect(snapshot.data()?['profileSetupSkippedAt'], isNotNull);
      },
    );

    test('toggleEmailNotifications updates stream-backed preference', () async {
      await firestore.collection('users').doc(user.uid).set({
        'emailNotificationsEnabled': true,
      });

      await service.toggleEmailNotifications(false);
      final isEnabled = await service.emailNotificationsStream().first;

      expect(isEnabled, isFalse);
    });

    test('blockUser records both blocker and blocked state', () async {
      await firestore.collection('users').doc('user-2').set({
        'blockedBy': <String>[],
      });

      await service.blockUser('user-2');

      final blockerDoc = await firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final blockedDoc = await firestore
          .collection('users')
          .doc('user-2')
          .get();
      final blockEdge = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocked')
          .doc('user-2')
          .get();

      expect(
        List<String>.from(blockerDoc.data()?['blockedUsers'] ?? []),
        contains('user-2'),
      );
      expect(
        List<String>.from(blockedDoc.data()?['blockedBy'] ?? []),
        contains(user.uid),
      );
      expect(blockEdge.exists, isTrue);
    });
  });
}
