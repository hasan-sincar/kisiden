import 'package:appim/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseService trade offer payload', () {
    test('builds a complete payload with seller and listing metadata', () {
      final payload = DatabaseService.buildTradeOfferPayload(
        senderId: 'sender-1',
        receiverId: 'receiver-1',
        senderListingId: 'listing-sender',
        receiverListingId: 'listing-receiver',
        senderListingTitle: 'iPhone 14',
        receiverListingTitle: 'AirPods Pro',
        senderListingImage: 'https://example.com/phone.jpg',
        receiverListingImage: 'https://example.com/airpods.jpg',
        senderName: 'Ali',
        receiverName: 'Ayse',
        senderPrice: 12000,
        receiverPrice: 3000,
        estimatedPriceDiff: 9000,
        message: 'Takas etmek isterim.',
      );

      expect(payload['senderId'], 'sender-1');
      expect(payload['receiverId'], 'receiver-1');
      expect(payload['senderListingId'], 'listing-sender');
      expect(payload['receiverListingId'], 'listing-receiver');
      expect(payload['status'], 'pending');
      expect(payload['message'], 'Takas etmek isterim.');
      expect(payload['estimatedPriceDiff'], 9000);
      expect(payload['senderPrice'], 12000);
      expect(payload['receiverPrice'], 3000);
    });
  });
}
