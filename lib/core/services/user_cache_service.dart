import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/base64_utils.dart';

class UserCacheService {
  UserCacheService._();
  static final UserCacheService instance = UserCacheService._();

  static const String _cacheKeyUserName = 'dashboard_user_name';
  static const String _cacheKeyUserAvatar = 'dashboard_user_avatar';
  static const String _cacheKeyUserId = 'dashboard_user_id';

  Future<void> saveUserInfo({
    required int userId,
    required String userName,
    String? avatarBase64,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheKeyUserId, userId);
      await prefs.setString(_cacheKeyUserName, userName);

      if (avatarBase64 != null &&
          avatarBase64.isNotEmpty &&
          avatarBase64 != 'false') {
        await prefs.setString(_cacheKeyUserAvatar, avatarBase64);
      }

          } catch (e) {
          }
  }

  Future<String?> getCachedUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cacheKeyUserName);
    } catch (e) {
            return null;
    }
  }

  Future<Uint8List?> getCachedUserAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final avatarBase64 = prefs.getString(_cacheKeyUserAvatar);

      if (avatarBase64 != null &&
          avatarBase64.isNotEmpty &&
          avatarBase64 != 'false') {
        return await compute(decodeBase64ToBytes, avatarBase64);
      }

      return null;
    } catch (e) {
            return null;
    }
  }

  Future<int?> getCachedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_cacheKeyUserId);
    } catch (e) {
            return null;
    }
  }

  Future<bool> hasCachedUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_cacheKeyUserName);
    } catch (e) {
      return false;
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKeyUserName);
      await prefs.remove(_cacheKeyUserAvatar);
      await prefs.remove(_cacheKeyUserId);
          } catch (e) {
          }
  }
}
