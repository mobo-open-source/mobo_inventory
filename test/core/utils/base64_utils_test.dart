import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/utils/base64_utils.dart';

void main() {
  group('decodeBase64ToBytes', () {
    test('decodes valid base64 string to bytes', () {
      // "hello" in base64
      const b64 = 'aGVsbG8=';
      final bytes = decodeBase64ToBytes(b64);
      expect(bytes, isA<Uint8List>());
      expect(String.fromCharCodes(bytes), 'hello');
    });

    test('throws for invalid base64 string', () {
      const invalid = 'not-base64!!';
      expect(() => decodeBase64ToBytes(invalid), throwsA(isA<FormatException>()));
    });
  });

  group('odooBinaryToBase64', () {
    test('returns a base64 string as is (Odoo 17–19)', () {
      expect(odooBinaryToBase64('aGVsbG8='), 'aGVsbG8=');
    });

    test('returns content from the Odoo 20 map', () {
      expect(
        odooBinaryToBase64({
          'content': 'aGVsbG8=',
          'size': 5,
          'filename': 'me.png',
        }),
        'aGVsbG8=',
      );
      expect(odooBinaryToBase64({'content': 'aGVsbG8=', 'size': 5}), 'aGVsbG8=');
    });

    test('returns empty string for false, null or anything else', () {
      expect(odooBinaryToBase64(false), '');
      expect(odooBinaryToBase64(null), '');
      expect(odooBinaryToBase64(123), '');
      expect(odooBinaryToBase64({'size': 5}), '');
      expect(odooBinaryToBase64({'content': false}), '');
    });
  });
}
