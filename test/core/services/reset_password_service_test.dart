import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/reset_password_service.dart';

void main() {
  group('ResetPasswordService validators', () {
    test('isValidEmail returns true for valid emails', () {
      expect(ResetPasswordService.isValidEmail('user@example.com'), isTrue);
      expect(ResetPasswordService.isValidEmail('first.last+tag@sub.domain.co'), isTrue);
    });

    test('isValidEmail returns false for invalid emails', () {
      expect(ResetPasswordService.isValidEmail('invalid'), isFalse);
      expect(ResetPasswordService.isValidEmail('user@'), isFalse);
      expect(ResetPasswordService.isValidEmail('@domain.com'), isFalse);
      expect(ResetPasswordService.isValidEmail('user@domain'), isFalse);
    });

    test('isValidUrl returns true for valid URLs and bare hosts', () {
      expect(ResetPasswordService.isValidUrl('https://example.com'), isTrue);
      expect(ResetPasswordService.isValidUrl('http://example.com'), isTrue);
      expect(ResetPasswordService.isValidUrl('example.com'), isTrue);
      expect(ResetPasswordService.isValidUrl('odoo.example.org:8069'), isTrue);
    });

    test('isValidUrl returns false for invalid URLs', () {
      expect(ResetPasswordService.isValidUrl(''), isFalse);
      expect(ResetPasswordService.isValidUrl('://bad'), isFalse);
      expect(ResetPasswordService.isValidUrl('http:///bad'), isFalse);
    });
  });
}
