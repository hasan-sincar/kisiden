import 'package:appim/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhoneNumber', () {
    test('formats Turkish mobile numbers with country code', () {
      expect(normalizePhoneNumber('05321234567'), '+905321234567');
      expect(normalizePhoneNumber('5321234567'), '+905321234567');
      expect(normalizePhoneNumber('+905321234567'), '+905321234567');
    });

    test('returns empty string for blank input', () {
      expect(normalizePhoneNumber('   '), '');
    });
  });
}
