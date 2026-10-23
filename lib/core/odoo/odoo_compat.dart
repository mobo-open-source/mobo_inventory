import 'odoo_version.dart';

/// Version-dependent field names and write rules for Odoo 16 / 17 / 18 / 19 /
/// 20.
class OdooCompat {
  final int major;
  const OdooCompat(this.major);

  /// Holds no cache: [OdooVersion.major] reads the live session every call, so
  /// switching or adding an account is picked up immediately.
  static Future<OdooCompat> current() async =>
      OdooCompat(await OdooVersion.major());

  /// Odoo 19 removed `mobile` from `res.partner`, merging it into `phone`.
  bool get hasMobileField => major < 19;

  /// Whether `phone` can be written on the user's own `res.users` record.
  ///
  /// `res.users.write` bypasses access rights only when every key of the write
  /// is in `SELF_WRITEABLE_FIELDS`. Odoo 19 added `phone` to that list; 16/17/18
  /// must write the number on `res.partner`, which needs
  /// `base.group_partner_manager`.
  bool get userPhoneIsSelfWritable => major >= 19;

  /// Odoo 19 removed `name` from `stock.move`.
  bool get stockMoveHasName => major < 19;

  /// Odoo 20 renamed `stock.move.product_uom` to `uom_id`; reading or writing
  /// the old name fails the whole call with "Invalid field".
  String get stockMoveUomField => major >= 20 ? 'uom_id' : 'product_uom';

  /// Odoo 20 renamed `mrp.production.product_uom_id` to `uom_id`.
  String get mrpProductionUomField => major >= 20 ? 'uom_id' : 'product_uom_id';

  /// Odoo 19 dropped `stock.picking.move_ids_without_package`; `move_ids`
  /// holds the same moves there.
  String get pickingMoveIdsField =>
      major >= 19 ? 'move_ids' : 'move_ids_without_package';

  /// Odoo 19 removed `stock.picking.date`; `scheduled_date` is the date a
  /// transfer is grouped and sorted by from then on.
  bool get pickingHasDateField => major < 19;

  /// Odoo 20 turned `read_group` into the old private `_read_group`
  /// (`domain, groupby, aggregates` → tuples). `formatted_read_group`, which
  /// returns the dict rows the app reads, exists from 19 on.
  bool get hasLegacyReadGroup => major < 20;

  /// Odoo 20 asks, through a wizard, before confirming a transfer with a
  /// zero-quantity line. This context key skips that question (as every
  /// earlier release did); older releases ignore it.
  Map<String, dynamic> get confirmPickingContext =>
      major >= 20 ? const {'skip_zero_demand_check': true} : const {};

  /// Odoo 17 merged `stock.move.quantity_done` and the reserved quantity into
  /// one `quantity` field, which is what `button_validate` moves.
  String get stockMoveQuantityField =>
      major >= 17 ? 'quantity' : 'quantity_done';

  /// Odoo 17 added `stock.move.picked`; a move with a quantity but not picked
  /// is left for a backorder.
  bool get stockMoveHasPicked => major >= 17;

  /// Odoo 20 replaced `SELF_WRITEABLE_FIELDS` with `user_writeable=True` on
  /// each field, and `action_id` is no longer one of them.
  Set<String> get userSelfWritableFields => {
    'signature',
    if (major < 20) 'action_id',
    'company_id',
    'email',
    'name',
    'image_1920',
    'lang',
    'tz',
    if (userPhoneIsSelfWritable) 'phone',
  };

  bool get isUntested =>
      major < OdooVersion.minSupported || major > OdooVersion.maxSupported;

  @override
  String toString() => 'OdooCompat(major: $major)';
}
