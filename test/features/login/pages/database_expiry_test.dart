import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/features/login/pages/login_layout.dart';

String _odooDate(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year}-${two(u.month)}-${two(u.day)} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)}';
}

void main() {
  group('DatabaseExpiry.isExpiredSessionInfo', () {
    bool expired(Object? value) => DatabaseExpiry.isExpiredSessionInfo({
      'uid': 2,
      'expiration_date': value,
    });

    test('no expiration date never expires (Community, unset parameter)', () {
      expect(DatabaseExpiry.isExpiredSessionInfo(null), isFalse);
      expect(DatabaseExpiry.isExpiredSessionInfo({'uid': 2}), isFalse);
      expect(expired(''), isFalse);
      expect(expired(false), isFalse);
      expect(expired('not a date'), isFalse);
    });

    test('a date in the past is expired', () {
      expect(expired('2020-01-01 00:00:00'), isTrue);
      expect(
        expired(_odooDate(DateTime.now().subtract(const Duration(days: 3)))),
        isTrue,
      );
    });

    test('a date comfortably in the future is not expired', () {
      expect(
        expired(_odooDate(DateTime.now().add(const Duration(days: 30)))),
        isFalse,
      );
      expect(
        expired(_odooDate(DateTime.now().add(const Duration(days: 2)))),
        isFalse,
      );
    });

    test('follows the web client rule: expired once days left round to 0', () {
      // 11 hours left rounds to 0 days, so Odoo already blocks it.
      expect(
        expired(_odooDate(DateTime.now().add(const Duration(hours: 11)))),
        isTrue,
      );
      // 13 hours left rounds to 1 day, so it is still usable.
      expect(
        expired(_odooDate(DateTime.now().add(const Duration(hours: 13)))),
        isFalse,
      );
    });

    test('accepts a date without a time part', () {
      expect(expired('2020-01-01'), isTrue);
      expect(expired('2999-01-01'), isFalse);
    });
  });
}
