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
}
