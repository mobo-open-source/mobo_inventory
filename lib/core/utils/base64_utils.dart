import 'dart:convert';
import 'dart:typed_data';

Uint8List decodeBase64ToBytes(String data) {
  return base64Decode(data);
}

/// Reads an Odoo binary field (e.g. `image_1920`, `image_128`) as base64.
///
/// Odoo 17–19 return a base64 string (or `false` when empty); Odoo 20 returns
/// `{"content": "<base64>", "size": 123, "filename": "me.png"}` (or `false`).
/// Returns the base64 text for either shape, and `''` for anything else.
/// Writing is unchanged — Odoo 20 still accepts a plain base64 string.
String odooBinaryToBase64(dynamic value) {
  if (value is String) return value;
  if (value is Map && value['content'] is String) {
    return value['content'] as String;
  }
  return '';
}
