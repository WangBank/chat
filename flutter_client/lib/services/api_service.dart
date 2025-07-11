import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/call.dart';

class ApiService {
  static const String baseUrl = 'https://localhost:7000/api';
  
  String? _token;
  User? _currentUser;

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  // 设置认证token
  void setToken(String token) {
    _token = token;
  }

  // 获取HTTP请求头
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // 用户注册
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          _token = data['token'];
          if (data['user'] != null) {
            _currentUser = User.fromJson(data['user']);
          }
        }
        return data;
      } else {
        throw Exception('注册失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('注册错误: $e');
    }
  }

  // 用户登录
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          _token = data['token'];
          if (data['user'] != null) {
            _currentUser = User.fromJson(data['user']);
          }
        }
        return data;
      } else {
        throw Exception('登录失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('登录错误: $e');
    }
  }

  // 获取联系人列表
  Future<List<User>> getContacts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/contacts'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => User.fromJson(json)).toList();
      } else {
        throw Exception('获取联系人失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('获取联系人错误: $e');
    }
  }

  // 添加联系人
  Future<User> addContact({required String username}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contacts'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        throw Exception('添加联系人失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('添加联系人错误: $e');
    }
  }

  // 获取通话历史
  Future<List<Call>> getCallHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/calls/history'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Call.fromJson(json)).toList();
      } else {
        throw Exception('获取通话历史失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('获取通话历史错误: $e');
    }
  }

  // 创建会议室
  Future<Map<String, dynamic>> createRoom({required String roomName}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/calls/rooms'),
        headers: _headers,
        body: jsonEncode({
          'roomName': roomName,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('创建会议室失败: ${response.body}');
      }
    } catch (e) {
      throw Exception('创建会议室错误: $e');
    }
  }

  // 登出
  void logout() {
    _token = null;
    _currentUser = null;
  }
}
