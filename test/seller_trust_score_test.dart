import 'package:flutter_test/flutter_test.dart';
import 'package:appim/screens/seller_profile_screen.dart';

void main() {
  group('calculateSellerTrustScore', () {
    test('gives a high score for a seller with strong sales and ratings', () {
      final score = calculateSellerTrustScore({
        'soldCount': 20,
        'totalReviewCount': 8,
        'totalRatingScore': 40.0,
        'avgResponseHours': 1,
        'approvalRate': 98,
      });

      expect(score, greaterThan(85));
    });

    test('keeps a lower score for a new seller without enough feedback', () {
      final score = calculateSellerTrustScore({
        'soldCount': 1,
        'totalReviewCount': 0,
        'totalRatingScore': 0.0,
        'avgResponseHours': 24,
        'approvalRate': 90,
      });

      expect(score, lessThan(70));
    });
  });
}
