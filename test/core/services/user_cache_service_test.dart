import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobo_inv_app/core/services/user_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserCacheService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveUserInfo saves data to SharedPreferences', () async {
      await UserCacheService.instance.saveUserInfo(
        userId: 123,
        userName: 'John Doe',
        avatarBase64: 'SGVsbG8=', // "Hello" in base64
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('dashboard_user_id'), 123);
      expect(prefs.getString('dashboard_user_name'), 'John Doe');
      expect(prefs.getString('dashboard_user_avatar'), 'SGVsbG8=');
    });

    test('getCachedUserName retrieves saved name', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_user_name': 'Jane Doe',
      });

      final name = await UserCacheService.instance.getCachedUserName();
      expect(name, 'Jane Doe');
    });

    test('getCachedUserId retrieves saved ID', () async {
      SharedPreferences.setMockInitialValues({'dashboard_user_id': 456});

      final id = await UserCacheService.instance.getCachedUserId();
      expect(id, 456);
    });

    test('getCachedUserAvatar retrieves and decodes avatar', () async {
      final base64Str = base64Encode(utf8.encode('Avatar Data'));
      SharedPreferences.setMockInitialValues({
        'dashboard_user_avatar': base64Str,
      });

      final bytes = await UserCacheService.instance.getCachedUserAvatar();

      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), 'Avatar Data');
    });

    test('getCachedUserAvatar returns null if not set or invalid', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await UserCacheService.instance.getCachedUserAvatar(), isNull);

      SharedPreferences.setMockInitialValues({
        'dashboard_user_avatar': 'false',
      });
      expect(await UserCacheService.instance.getCachedUserAvatar(), isNull);

      SharedPreferences.setMockInitialValues({'dashboard_user_avatar': ''});
      expect(await UserCacheService.instance.getCachedUserAvatar(), isNull);
    });

    test('hasCachedUserInfo returns correct boolean', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await UserCacheService.instance.hasCachedUserInfo(), isFalse);

      SharedPreferences.setMockInitialValues({'dashboard_user_name': 'Exists'});
      expect(await UserCacheService.instance.hasCachedUserInfo(), isTrue);
    });

    test('clearCache removes all user data', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_user_id': 1,
        'dashboard_user_name': 'Test',
        'dashboard_user_avatar': 'data',
      });

      await UserCacheService.instance.clearCache();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('dashboard_user_id'), isNull);
      expect(prefs.getString('dashboard_user_name'), isNull);
      expect(prefs.getString('dashboard_user_avatar'), isNull);
    });
  });
}
