import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class StorageService {
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';
  static const String _serverUrlKey = 'server_url';

  // 保存用户信息
  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    print('✅ 用户信息已保存到本地存储');
  }

  // 获取用户信息
  static Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        return User.fromJson(userMap);
      }
    } catch (e) {
      print('❌ 读取用户信息失败: $e');
    }
    return null;
  }

  // 保存认证令牌
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    print('✅ 认证令牌已保存到本地存储');
  }

  // 获取认证令牌
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      print('❌ 读取认证令牌失败: $e');
      return null;
    }
  }

  // 保存服务器URL
  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    print('✅ 服务器URL已保存到本地存储');
  }

  // 获取服务器URL
  static Future<String?> getServerUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_serverUrlKey);
    } catch (e) {
      print('❌ 读取服务器URL失败: $e');
      return null;
    }
  }

  // 清除所有存储的数据
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ 本地存储已清空');
    } catch (e) {
      print('❌ 清空本地存储失败: $e');
    }
  }

  // 检查是否有保存的登录信息
  static Future<bool> hasStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasUser = prefs.containsKey(_userKey);
      final hasToken = prefs.containsKey(_tokenKey);
      return hasUser && hasToken;
    } catch (e) {
      print('❌ 检查存储凭据失败: $e');
      return false;
    }
  }

  // 保存登录信息（用户+令牌）
  static Future<void> saveLoginInfo(User user, String token) async {
    await saveUser(user);
    await saveToken(token);
    print('✅ 登录信息已保存');
  }
}
