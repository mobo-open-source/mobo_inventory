/// Reads an Odoo char/text/date field as display text.
///
/// Odoo returns `false`, not null, for an empty field, so a plain
/// `toString()` shows the word "false". Returns null for that, for null and
/// for blank text — and for a literal "false" already written to the offline
/// cache by an older build — so callers can fall back to `'-'`.
String? odooString(dynamic value) {
  if (value == null || value == false) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text == 'false') return null;
  return text;
}
