import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/odoo_session_manager.dart';
import '../../../core/services/session_service.dart';
import '../../../core/odoo/odoo_compat.dart';
import '../../../core/odoo/odoo_version.dart';
import '../../../core/utils/base64_utils.dart';

class ProfileProvider extends ChangeNotifier {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  Uint8List? _userAvatar;
  String? _error;
  bool _hasInternet = true;
  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _states = [];
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// The pre-scoping key, shared by every account; dropped on first read.
  static const String _legacyCacheKeyUser = 'user_profile';

  /// The cached profile is stored per account. One shared blob painted
  /// account A's name, avatar and numbers on account B until B's fetch
  /// landed.
  Future<String?> _userCacheKey() async {
    final key = await _accountKey();
    return key == null ? null : '$_legacyCacheKeyUser|$key';
  }

  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  Uint8List? get userAvatar => _userAvatar;
  String? get userAvatarBase64 {
    final val = odooBinaryToBase64(_userData?['image_1920']);
    if (val.isNotEmpty && val != 'false') {
      return val;
    }
    return null;
  }

  String? get error => _error;
  bool get hasInternet => _hasInternet;
  List<Map<String, dynamic>> get countries => _countries;
  List<Map<String, dynamic>> get states => _states;
  bool get isLoadingCountries => _isLoadingCountries;
  bool get isLoadingStates => _isLoadingStates;

  String normalizeForEdit(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'true' : '';
    final s = value.toString().trim();
    return (s.toLowerCase() == 'false' || s.isEmpty) ? '' : s;
  }

  // ------------------------------------------------------------ discovery

  /// The `res.users` fields the profile read falls back to when the server's
  /// own field list cannot be discovered. Every one is a plain column or a
  /// partner-delegated field present on 16 through 19.
  static const List<String> _fallbackUserFields = [
    'name',
    'login',
    'email',
    'website',
    'function',
    'image_1920',
    'company_id',
    'partner_id',
  ];

  /// The `res.partner` fields the profile wants, in read order.
  static const List<String> _wantedPartnerFields = [
    // `phone` is deliberately absent: it is resolved per server and may live
    // on res.users instead — see [_getPhoneFieldName].
    'street',
    // Read even though only the address dialog shows it: that dialog writes
    // the whole address back, so a street2 that was never read would be
    // written back as false and wipe the server's value.
    'street2',
    'city',
    'zip',
    'state_id',
    'country_id',
    'parent_id',
  ];

  /// Which model owns each row, so availability is checked against the schema
  /// of the model that actually stores it.
  static const Map<String, String> _profileFieldOwner = {
    'name': 'res.users',
    'login': 'res.users',
    'email': 'res.users',
    'website': 'res.users',
    'function': 'res.users',
    'image_1920': 'res.users',
    'company_id': 'res.users',
    // `phone` and `mobile` are absent on purpose: neither has a fixed owner,
    // so both are gated on their own resolution instead.
    'street': 'res.partner',
    'street2': 'res.partner',
    'city': 'res.partner',
    'zip': 'res.partner',
    'state_id': 'res.partner',
    'country_id': 'res.partner',
    'parent_id': 'res.partner',
  };

  List<String>? _profileUserFieldsCache;
  String? _profileFieldsAccountKey;
  Set<String> _discoveredUserFields = {};
  Set<String> _discoveredPartnerFields = {};
  bool _userFieldsDiscovered = false;
  bool _partnerFieldsDiscovered = false;

  /// Which field holds the mobile number, or null when the server has none.
  String? _partnerMobileFieldNameCache;

  /// Which model it lives on: `res.partner`, or `res.users` for `hr`'s field.
  String? _mobileFieldModel;
  String? _mobileFieldAccountKey;
  bool _mobileFieldResolved = false;

  /// What the *version* says, standing in until the probe answers.
  bool? _versionSaysMobileExists;

  String? _phoneFieldName;
  String? _phoneFieldModel;
  String? _phoneFieldAccountKey;
  bool _phoneFieldResolved = false;

  /// True until the probe has run: `res.partner.phone` exists on every
  /// supported release, so the row is worth showing while the answer is
  /// unknown.
  bool get hasPhoneField => _phoneFieldResolved ? _phoneFieldName != null : true;

  /// Null until the first fetch resolves it. False means no field anywhere.
  bool? get hasMobileField => _mobileFieldResolved
      ? _partnerMobileFieldNameCache != null
      : _versionSaysMobileExists;

  /// Whether the connected server exposes [field], so the screen can leave the
  /// row out entirely instead of showing an edit the server cannot store.
  ///
  /// True while discovery has not run: a cached profile then paints its rows
  /// immediately rather than flashing them away and back.
  bool isProfileFieldAvailable(String field) {
    if (field == 'mobile') return hasMobileField ?? true;
    // Not checked against the res.partner schema: it may have resolved to
    // `hr`'s res.users.work_phone instead.
    if (field == 'phone') return hasPhoneField;
    switch (_profileFieldOwner[field]) {
      case 'res.users':
        return _userFieldsDiscovered
            ? _discoveredUserFields.contains(field)
            : true;
      case 'res.partner':
        return _partnerFieldsDiscovered
            ? _discoveredPartnerFields.contains(field)
            : true;
      default:
        return true;
    }
  }

  /// Identity of the connected account, used to scope every cache here.
  Future<String?> _accountKey() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return null;
    return '${session.serverUrl}|${session.database}|${session.userId}';
  }

  /// This model's `fields_get`, keyed by field name. Throws on any RPC failure
  /// — deliberately not swallowed here, so a dropped connection is what the
  /// caller's own `catch` sees rather than looking identical to "the model
  /// genuinely has none of these fields".
  ///
  /// `fields_get`, never a search on `ir.model.fields`: that model grants
  /// `base.group_user` no access at all on 16–19, so probing it fails for
  /// every non-admin.
  Future<Map<String, Map<String, dynamic>>> _describeFields(
    String model,
  ) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': model,
      'method': 'fields_get',
      'args': [
        <String>[],
        ['type', 'related'],
      ],
      'kwargs': const {},
    });
    if (result is! Map) return const {};
    return result.map(
      (key, value) => MapEntry(
        '$key',
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
      ),
    );
  }

  /// True when [describe] shows the field is `related` through `employee_id`.
  /// Odoo reports `related` as a dotted path (`employee_id.mobile_phone`);
  /// some releases hand it back as a list of segments instead.
  bool _isEmployeeBacked(Map<String, dynamic>? describe) {
    final related = describe?['related'];
    if (related is String) return related.startsWith('employee_id.');
    if (related is List && related.isNotEmpty) {
      return '${related.first}' == 'employee_id';
    }
    return false;
  }

  /// Whether the signed-in user has an `hr.employee` behind them for the
  /// company the request runs under.
  ///
  /// `employee_id` is in `hr`'s `HR_READABLE_FIELDS`, so reading it alone takes
  /// the same-user sudo path and works for any user, not just HR staff. Odoo
  /// returns `false` for an unset many2one and `[id, name]` otherwise.
  Future<bool> _hasLinkedEmployee() async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) return false;
    final rows = await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'read',
      'args': [
        [session.userId],
        ['employee_id'],
      ],
      'kwargs': const {},
    });
    if (rows is! List || rows.isEmpty) return false;
    final value = (rows.first as Map)['employee_id'];
    return value is List && value.isNotEmpty;
  }

  /// Which field holds the phone number, and on which model.
  ///
  /// Probes `res.users` *first*, the reverse of mobile: `res.partner.phone`
  /// survives on every release, so probing the partner first would always
  /// win — and the app would quietly display the contact number while Odoo's
  /// user form shows the employee's Work Phone. They are different fields.
  Future<String?> _getPhoneFieldName() async {
    final accountKey = await _accountKey();
    if (_phoneFieldAccountKey != accountKey) {
      _phoneFieldAccountKey = accountKey;
      _phoneFieldResolved = false;
      _phoneFieldName = null;
      _phoneFieldModel = null;
    }
    if (_phoneFieldResolved) return _phoneFieldName;

    try {
      final userFields = await _describeFields('res.users');
      const userCandidates = ['work_phone', 'x_studio_work_phone'];
      for (final name in userCandidates) {
        final describe = userFields[name];
        if (describe == null) continue;
        // An employee-backed field with no linked employee writes to an empty
        // recordset — the value is dropped with no error — so it counts as
        // "no field". `continue`, not `break`: a rejected `work_phone` must
        // not stop a plain stored `x_studio_work_phone` from being found.
        if (_isEmployeeBacked(describe) && !await _hasLinkedEmployee()) {
          continue;
        }
        _phoneFieldName = name;
        _phoneFieldModel = 'res.users';
        _phoneFieldResolved = true;
        return name;
      }

      final partnerFields = await _describeFields('res.partner');
      if (partnerFields.containsKey('phone')) {
        _phoneFieldName = 'phone';
        _phoneFieldModel = 'res.partner';
        _phoneFieldResolved = true;
        return 'phone';
      }

      _phoneFieldName = null;
      _phoneFieldModel = null;
      _phoneFieldResolved = true;
      return null;
    } catch (_) {
      // Not marked resolved, so a probe that failed on a dropped connection is
      // retried. `res.partner.phone` exists on every release in the meantime.
      _phoneFieldName = null;
      _phoneFieldModel = null;
      return 'phone';
    }
  }

  /// Reads one resolved `res.users` field value on its own.
  ///
  /// Deliberately a separate, single-field read: `res.users.read` only takes
  /// the same-user sudo path when *every* requested field is self-readable,
  /// and `hr` puts `work_phone`/`mobile_phone` there. Asked for alone they come
  /// back for any user; asked for alongside the rest of the profile they lose
  /// that bypass and fall back to plain ACLs on `hr.employee`.
  Future<String?> _readUserFieldValue(String field) async {
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) return null;
      final rows = await OdooSessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          [field],
        ],
        'kwargs': const {},
      });
      if (rows is! List || rows.isEmpty) return null;
      final value = (rows.first as Map)[field];
      if (value == null || value == false) return null;
      final text = value.toString();
      return text.isEmpty || text == 'false' ? null : text;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _resolveProfileFields() async {
    final accountKey = await _accountKey();
    if (_profileFieldsAccountKey != accountKey) {
      _profileFieldsAccountKey = accountKey;
      _profileUserFieldsCache = null;
      _discoveredUserFields = {};
      _discoveredPartnerFields = {};
      _userFieldsDiscovered = false;
      _partnerFieldsDiscovered = false;
    }
    // Probed on its own so a transient failure here retries on the next fetch
    // instead of being short-circuited by the cached user-field list below.
    await _ensurePartnerFieldsDiscovered();

    final cached = _profileUserFieldsCache;
    if (cached != null) return cached;

    try {
      final described = await _describeFields('res.users');
      if (described.isEmpty) return _fallbackUserFields;

      const skippedTypes = {'one2many', 'many2many'};
      final fields = <String>[];
      described.forEach((name, describe) {
        final type = describe['type']?.toString() ?? '';
        if (skippedTypes.contains(type)) return;
        // Every image size and avatar variant is base64 — megabytes for
        // images the profile never shows. Only the one it displays is read.
        if (type == 'binary' && name != 'image_1920') return;
        // `fields_get` cannot see that these raise AccessError on read for a
        // non-HR user, failing the whole profile read with them.
        if (_isEmployeeBacked(describe)) return;
        fields.add(name);
      });

      if (fields.isEmpty) return _fallbackUserFields;
      fields.sort();

      _profileUserFieldsCache = fields;
      _discoveredUserFields = fields.toSet();
      _userFieldsDiscovered = true;
      return fields;
    } catch (_) {
      // Not cached, so a probe that failed on a dropped connection is retried
      // rather than pinning the profile to the short list for the session.
      return _fallbackUserFields;
    }
  }

  /// Learns which `res.partner` fields this server defines.
  ///
  /// A failure leaves [_partnerFieldsDiscovered] false, which reads as
  /// "unknown" rather than "absent" — the rows keep showing instead of all
  /// vanishing on one dropped call — and the probe runs again next fetch.
  Future<void> _ensurePartnerFieldsDiscovered() async {
    if (_partnerFieldsDiscovered) return;
    try {
      _discoveredPartnerFields = (await _describeFields(
        'res.partner',
      )).keys.toSet();
      _partnerFieldsDiscovered = _discoveredPartnerFields.isNotEmpty;
    } catch (_) {
      _discoveredPartnerFields = {};
    }
  }

  /// Seeds [hasMobileField] from the server's release before the real probe
  /// has answered.
  ///
  /// Runs ahead of the cached-profile paint: that paint lands well before the
  /// network fetch, and without a guess [hasMobileField] is null in that gap —
  /// the screen's `?? true` default then shows the Mobile row on every server,
  /// Odoo 19 included, until the fetch catches up and hides it again.
  Future<void> _primeMobileFieldVersionGuess() async {
    final accountKey = await _accountKey();
    if (_mobileFieldAccountKey != accountKey) {
      _mobileFieldAccountKey = accountKey;
      _mobileFieldResolved = false;
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _versionSaysMobileExists = null;
    }
    if (_versionSaysMobileExists != null || _mobileFieldResolved) return;
    try {
      final compat = await OdooCompat.current();
      _versionSaysMobileExists = compat.hasMobileField;
    } catch (_) {
      // Left null: falls through to the screen's own `?? true`.
    }
  }

  /// Which field holds the mobile number, and on which model.
  ///
  /// Probes `res.partner` first, then `hr`'s employee-backed field on
  /// `res.users`. Custom names are checked after the standard one so a stray
  /// Studio field cannot shadow `res.partner.mobile` on 16/17/18.
  Future<String?> _getPartnerMobileFieldName() async {
    await _primeMobileFieldVersionGuess();
    final accountKey = await _accountKey();
    if (_mobileFieldAccountKey != accountKey) {
      _mobileFieldAccountKey = accountKey;
      _mobileFieldResolved = false;
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _versionSaysMobileExists = null;
    }
    if (_mobileFieldResolved) return _partnerMobileFieldNameCache;

    final compat = await OdooCompat.current();
    _versionSaysMobileExists = compat.hasMobileField;

    try {
      final partnerFields = await _describeFields('res.partner');
      final candidates = <String>[
        if (compat.hasMobileField) 'mobile',
        'mobile_phone',
        'x_studio_mobile_phone',
      ];
      for (final name in candidates) {
        if (partnerFields.containsKey(name)) {
          _partnerMobileFieldNameCache = name;
          _mobileFieldModel = 'res.partner';
          _mobileFieldResolved = true;
          return name;
        }
      }

      // `hr` puts `mobile_phone` on res.users, related to
      // hr.employee.mobile_phone. On Odoo 19, where res.partner.mobile was
      // removed, that is the only place a mobile number lives — without this
      // probe the row vanishes on a server that plainly has one.
      final userFields = await _describeFields('res.users');
      const userCandidates = ['mobile_phone', 'x_studio_mobile_phone'];
      for (final name in userCandidates) {
        final describe = userFields[name];
        if (describe == null) continue;
        // `continue`, not `break`: a rejected `mobile_phone` must not stop a
        // plain stored `x_studio_mobile_phone` from being found.
        if (_isEmployeeBacked(describe) && !await _hasLinkedEmployee()) {
          continue;
        }
        _partnerMobileFieldNameCache = name;
        _mobileFieldModel = 'res.users';
        _mobileFieldResolved = true;
        return name;
      }

      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      _mobileFieldResolved = true;
      return null;
    } catch (_) {
      // Not marked resolved — a probe that failed on a dropped connection must
      // be retried. Until it succeeds the release's own answer stands.
      _partnerMobileFieldNameCache = null;
      _mobileFieldModel = null;
      return compat.hasMobileField ? 'mobile' : null;
    }
  }

  /// Inbound: folds a `mobile_phone` key back to the canonical `mobile`.
  Map<String, dynamic> _normalizePartnerUpdates(Map<String, dynamic> updates) {
    final out = <String, dynamic>{};
    updates.forEach((key, value) {
      String k = key;
      if (k == 'mobile_phone') k = 'mobile';
      out[k] = value;
    });
    return out;
  }

  /// Outbound: renames `mobile` to whatever res.partner field this server has.
  Future<Map<String, dynamic>> _preparePartnerUpdatesForServer(
    Map<String, dynamic> normalized,
  ) async {
    if (!normalized.containsKey('mobile')) return normalized;
    final fieldName = await _getPartnerMobileFieldName();
    // Usable here only when it actually lives on res.partner. It can just as
    // well be `hr`'s res.users.mobile_phone — renaming to that and sending it
    // to res.partner makes Odoo reject the whole write for an unrecognized
    // field, taking phone/website/function down with it. Dropping the key
    // loses one value; keeping it loses all.
    if (fieldName == null || _mobileFieldModel != 'res.partner') {
      final copy = Map<String, dynamic>.from(normalized);
      copy.remove('mobile');
      return copy;
    }
    if (fieldName == 'mobile') return normalized;
    final copy = Map<String, dynamic>.from(normalized);
    final value = copy.remove('mobile');
    copy[fieldName] = value;
    return copy;
  }

  // ------------------------------------------------------------ lifecycle

  Future<void> initialize() async {
    _startConnectivityListener();
    await loadCachedUser();
    await fetchUserProfile();
    await loadCountries();
  }

  void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final hasNet = await _checkInternet();
      _hasInternet = hasNet;
      notifyListeners();
    });

    _checkInternet().then((hasNet) {
      _hasInternet = hasNet;
      notifyListeners();
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadCachedUser() async {
    // Ahead of the paint below, not after it — see
    // [_primeMobileFieldVersionGuess] for why the ordering is the point.
    await _primeMobileFieldVersionGuess();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_legacyCacheKeyUser);
      final cacheKey = await _userCacheKey();
      final cached = cacheKey == null ? null : prefs.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        _userData = data;
        final img = odooBinaryToBase64(data['image_1920']);
        if (img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = await compute(decodeBase64ToBytes, img);
          } catch (_) {}
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {}
  }

  // ----------------------------------------------------------------- read

  Future<void> fetchUserProfile() async {
    if (_userData == null) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      Future<dynamic> readUser(List<String> fields) =>
          OdooSessionManager.callKwWithCompany({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [session.userId],
              fields,
            ],
            'kwargs': {},
          });

      final wanted = await _resolveProfileFields();
      dynamic res;
      try {
        res = await readUser(wanted);
      } catch (_) {
        // A single misbehaving field must not cost the whole profile. Some
        // modules add non-stored computed fields to res.users whose compute
        // needs rights an ordinary user does not have, and `fields_get` cannot
        // see that coming — so the wide read is retried once as the short list
        // that is known to work on every release.
        _profileUserFieldsCache = null;
        res = await readUser(_fallbackUserFields);
      }

      if (res is List && res.isNotEmpty) {
        final data = res.first as Map<String, dynamic>;

        final partner = data['partner_id'];
        if (partner != null && partner is List && partner.isNotEmpty) {
          try {
            final mobileFieldName = await _getPartnerMobileFieldName();
            // `hr`'s res.users.mobile_phone is the common case here on 19.
            final mobileOnUsers = _mobileFieldModel == 'res.users';
            final phoneFieldName = await _getPhoneFieldName();
            final phoneOnUsers = _phoneFieldModel == 'res.users';

            // Only the fields this server defines: Odoo rejects the entire
            // read for one unrecognized name, which would take the address
            // and phone down with it.
            final fields = _partnerFieldsDiscovered
                ? _wantedPartnerFields
                      .where(_discoveredPartnerFields.contains)
                      .toList()
                : List<String>.from(_wantedPartnerFields);
            // Added only when they really live on res.partner: asking this
            // read for a res.users-only name would fail the whole call.
            if (mobileFieldName != null && !mobileOnUsers) {
              fields.add(mobileFieldName);
            }
            if (phoneFieldName != null && !phoneOnUsers) {
              fields.add(phoneFieldName);
            }

            if (fields.isNotEmpty) {
              final partnerRes = await OdooSessionManager.callKwWithCompany({
                'model': 'res.partner',
                'method': 'read',
                'args': [
                  [partner[0]],
                  fields,
                ],
                'kwargs': {},
              });

              if (partnerRes is List && partnerRes.isNotEmpty) {
                final partnerData = partnerRes.first as Map<String, dynamic>;
                for (final field in fields) {
                  data[field] = partnerData[field];
                }

                String? mobileValue;
                if (mobileFieldName != null) {
                  if (mobileOnUsers) {
                    // Its own read — see [_readUserFieldValue] for why that
                    // is what makes it readable for a non-HR user.
                    mobileValue = await _readUserFieldValue(mobileFieldName);
                  } else {
                    // Odoo sends an empty value as the bool `false`, so the
                    // comparison has to be on the rendered text — comparing
                    // the raw value to 'false' never matches a bool and
                    // stored the literal string "false".
                    final text = partnerData[mobileFieldName]?.toString() ?? '';
                    if (text.isNotEmpty && text != 'false') {
                      mobileValue = text;
                    }
                  }
                }
                data['mobile'] = mobileValue ?? '';

                String? phoneValue;
                if (phoneFieldName != null) {
                  if (phoneOnUsers) {
                    phoneValue = await _readUserFieldValue(phoneFieldName);
                  } else {
                    final text = partnerData[phoneFieldName]?.toString() ?? '';
                    if (text.isNotEmpty && text != 'false') {
                      phoneValue = text;
                    }
                  }
                }
                data['phone'] = phoneValue ?? '';
              }
            }
          } catch (e) {}
        }

        _userData = data;
        final img = odooBinaryToBase64(data['image_1920']);
        if (img.isNotEmpty && img != 'false') {
          try {
            _userAvatar = base64Decode(img);
          } catch (_) {}
        }

        // Every profile save ends in this fetch, so this also carries a rename
        // or new photo into the account switcher's saved entry.
        try {
          await SessionService.instance.updateStoredAccountProfile(
            session,
            name: data['name']?.toString(),
            imageBase64: img,
          );
        } catch (_) {}

        final prefs = await SharedPreferences.getInstance();
        final cacheKey = await _userCacheKey();
        if (cacheKey != null) {
          await prefs.setString(cacheKey, jsonEncode(data));
        }
      }
    } catch (e) {
      _error = 'Failed to fetch user profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- writes

  /// Applies profile edits, routing every field to the model that owns it on
  /// the connected server.
  ///
  /// `res.users.write` bypasses access rights only when *every* key is
  /// self-writeable, so the split is per-release rather than fixed: Odoo 19
  /// takes `phone` there too, 16/17/18 must send it to `res.partner`.
  ///
  /// `mobile` cannot be classified from that release-based set at all — which
  /// model owns it depends on this server's schema — so it is routed
  /// separately, using the resolved field name whenever that lives on
  /// `res.users`.
  ///
  /// Throws if the server rejects either write, so the caller can tell the user
  /// the change did not stick.
  Future<void> saveProfileEdits(Map<String, dynamic> changes) async {
    if (changes.isEmpty) return;

    final compat = await OdooCompat.current();
    final selfWritable = compat.userSelfWritableFields;

    final userUpdates = <String, dynamic>{};
    final partnerUpdates = <String, dynamic>{};

    final remaining = Map<String, dynamic>.from(changes);
    if (remaining.containsKey('mobile')) {
      // Never classified by the release-based set: which model owns it depends
      // on this server's schema — a plain res.partner.mobile, `hr`'s
      // res.users.mobile_phone, a Studio field, or nothing at all.
      final value = remaining.remove('mobile');
      await _getPartnerMobileFieldName();
      final resolvedField = _partnerMobileFieldNameCache;
      if (_mobileFieldModel == 'res.users' && resolvedField != null) {
        userUpdates[resolvedField] = value;
      } else {
        // res.partner, or unresolved: `_preparePartnerUpdatesForServer`
        // renames or drops it per this server's schema.
        partnerUpdates['mobile'] = value;
      }
    }

    // Same treatment as mobile, and for the same reason: `hr`'s
    // res.users.work_phone and res.partner.phone are different fields holding
    // different numbers, so the release-based set cannot decide this either.
    if (remaining.containsKey('phone')) {
      final value = remaining.remove('phone');
      final resolvedPhone = await _getPhoneFieldName();
      if (_phoneFieldModel == 'res.users' && resolvedPhone != null) {
        userUpdates[resolvedPhone] = value;
      } else if (resolvedPhone != null) {
        partnerUpdates[resolvedPhone] = value;
      }
    }

    remaining.forEach((field, value) {
      if (selfWritable.contains(field)) {
        userUpdates[field] = value;
      } else {
        partnerUpdates[field] = value;
      }
    });

    try {
      if (userUpdates.isNotEmpty) {
        await _writeUserFields(userUpdates);
      }
      if (partnerUpdates.isNotEmpty) {
        await _writePartnerFields(partnerUpdates);
      }
    } finally {
      // One refetch for the whole save rather than one per model — a refetch
      // between the two writes would paint a half-applied profile. In a
      // `finally` because a save can be *partly* applied: the res.users write
      // commits before a failing res.partner write, and without this the
      // screen would keep showing the old name, re-send it on every retry,
      // and never agree with the server.
      await fetchUserProfile();
    }
  }

  Future<void> _writeUserFields(Map<String, dynamic> updates) async {
    final session = await OdooSessionManager.getCurrentSession();
    if (session == null) {
      throw Exception('No active session');
    }
    await OdooSessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [session.userId],
        updates,
      ],
      'kwargs': {},
    });
  }

  Future<void> _writePartnerFields(Map<String, dynamic> updates) async {
    final partnerId = _userData?['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      throw Exception('Partner ID not found');
    }
    final toSend = await _preparePartnerUpdatesForServer(
      _normalizePartnerUpdates(updates),
    );
    if (toSend.isEmpty) return;
    await OdooSessionManager.callKwWithCompany({
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [partnerId[0]],
        toSend,
      ],
      'kwargs': {},
    });
  }

  Future<void> updateProfileImage(String base64Image) async {
    await _writeUserFields({'image_1920': base64Image});
    await fetchUserProfile();
  }

  /// Writes the address as one payload. Only the fields this server defines are
  /// sent, so a release that dropped one of them does not fail the whole write.
  Future<void> updateAddressFields(Map<String, dynamic> addressData) async {
    final partnerId = _userData?['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      throw Exception('Partner ID not found');
    }

    final toSend = <String, dynamic>{};
    addressData.forEach((field, value) {
      if (isProfileFieldAvailable(field)) toSend[field] = value;
    });
    if (toSend.isEmpty) return;

    await OdooSessionManager.callKwWithCompany({
      'model': 'res.partner',
      'method': 'write',
      'args': [
        [partnerId[0]],
        toSend,
      ],
      'kwargs': {},
    });

    await fetchUserProfile();
  }

  Future<Map<String, dynamic>?> loadRelatedCompany() async {
    try {
      final partnerId = _userData?['partner_id'];
      if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
        return null;
      }

      final res = await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'read',
        'args': [
          [partnerId[0]],
        ],
        'kwargs': {
          'fields': ['parent_id'],
        },
      });

      if (res is List && res.isNotEmpty) {
        final row = res.first as Map<String, dynamic>;
        if (row['parent_id'] is List &&
            (row['parent_id'] as List).length >= 2 &&
            row['parent_id'][0] != null) {
          return {
            'id': row['parent_id'][0],
            'name': row['parent_id'][1]?.toString(),
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updateRelatedCompany(int? companyId) async {
    final partnerId = _userData?['partner_id'];
    if (partnerId == null || partnerId is! List || partnerId.isEmpty) {
      throw Exception('Partner ID not found');
    }

    try {
      await OdooSessionManager.callKwWithCompany({
        'model': 'res.partner',
        'method': 'write',
        'args': [
          [partnerId[0]],
          {'parent_id': companyId ?? false},
        ],
        'kwargs': {},
      });

      await fetchUserProfile();
    } catch (e) {
      _error = 'Failed to update related company: $e';
      rethrow;
    }
  }

  // ------------------------------------------------------ countries/states

  Future<void> loadCountries() async {
    _isLoadingCountries = true;
    notifyListeners();

    try {
      _countries = await fetchCountries();
    } catch (e) {
    } finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchCountries() async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'res.country',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name', 'code'],
        'order': 'name ASC',
      },
    });
    return result is List ? result.cast<Map<String, dynamic>>() : [];
  }

  Future<void> loadStates(int countryId) async {
    _isLoadingStates = true;
    notifyListeners();

    try {
      _states = await fetchStates(countryId);
    } catch (e) {
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchStates(int countryId) async {
    final result = await OdooSessionManager.callKwWithCompany({
      'model': 'res.country.state',
      'method': 'search_read',
      'args': [
        [
          ['country_id', '=', countryId],
        ],
      ],
      'kwargs': {
        'fields': ['id', 'name', 'code'],
        'order': 'name ASC',
      },
    });
    return result is List ? result.cast<Map<String, dynamic>>() : [];
  }

  String formatAddress(Map<String, dynamic> data) {
    final parts = [
      if (data['street'] != null &&
          data['street'].toString().isNotEmpty &&
          data['street'].toString().toLowerCase() != 'false')
        data['street'],
      if (data['street2'] != null &&
          data['street2'].toString().isNotEmpty &&
          data['street2'].toString().toLowerCase() != 'false')
        data['street2'],
      if (data['city'] != null &&
          data['city'].toString().isNotEmpty &&
          data['city'].toString().toLowerCase() != 'false')
        data['city'],
      if (data['state_id'] is List &&
          data['state_id'].length > 1 &&
          data['state_id'][1] != null &&
          data['state_id'][1].toString().isNotEmpty &&
          data['state_id'][1].toString().toLowerCase() != 'false')
        data['state_id'][1],
      if (data['zip'] != null &&
          data['zip'].toString().isNotEmpty &&
          data['zip'].toString().toLowerCase() != 'false')
        data['zip'],
      if (data['country_id'] is List &&
          data['country_id'].length > 1 &&
          data['country_id'][1] != null &&
          data['country_id'][1].toString().isNotEmpty &&
          data['country_id'][1].toString().toLowerCase() != 'false')
        data['country_id'][1],
    ];
    return parts.isNotEmpty ? parts.join(', ') : 'No address set';
  }

  void clearStates() {
    _states = [];
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      _error = 'Logout failed: $e';
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  void resetState() {
    _isLoading = true;
    _userData = null;
    _userAvatar = null;
    _error = null;
    _hasInternet = true;
    _countries = [];
    _states = [];
    _isLoadingCountries = false;
    _isLoadingStates = false;

    // This provider outlives the account, so every schema answer resolved
    // against the old server has to go with it.
    _profileUserFieldsCache = null;
    _profileFieldsAccountKey = null;
    _discoveredUserFields = {};
    _discoveredPartnerFields = {};
    _userFieldsDiscovered = false;
    _partnerFieldsDiscovered = false;
    _partnerMobileFieldNameCache = null;
    _mobileFieldModel = null;
    _mobileFieldAccountKey = null;
    _mobileFieldResolved = false;
    _versionSaysMobileExists = null;
    _phoneFieldName = null;
    _phoneFieldModel = null;
    _phoneFieldAccountKey = null;
    _phoneFieldResolved = false;
    OdooVersion.reset();

    notifyListeners();
  }
}
