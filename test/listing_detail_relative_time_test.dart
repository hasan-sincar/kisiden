import 'package:flutter_test/flutter_test.dart';
import 'package:appim/screens/listing_detail_screen.dart';

void main() {
  group('formatRelativeTime', () {
    test('returns just-now text for very recent timestamps', () {
      final recent = DateTime.now().subtract(const Duration(seconds: 30));
      expect(formatRelativeTime(recent), 'az önce');
    });

    test('returns minute text for recent timestamps', () {
      final recent = DateTime.now().subtract(const Duration(minutes: 5));
      expect(formatRelativeTime(recent), '5 dk önce');
    });

    test('returns day text for older timestamps', () {
      final recent = DateTime.now().subtract(const Duration(days: 2));
      expect(formatRelativeTime(recent), '2 gün önce');
    });
  });
}
