import 'dart:convert';
import 'dart:typed_data';

Uint8List decodeBase64ToBytes(String data) {
  return base64Decode(data);
}
