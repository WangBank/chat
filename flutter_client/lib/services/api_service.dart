import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/call.dart';
import '../models/contact.dart';
import '../models/friend_request.dart';
import '../models/chat_message.dart';
import '../config/app_config.dart';

class ChatUploadResult {
  final String fileName;
  final String filePath;
  final int fileSize;
  final String contentType;

  const ChatUploadResult({
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    required this.contentType,
  });

  factory ChatUploadResult.fromJson(Map<String, dynamic> json) {
    return ChatUploadResult(
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? '',
    );
  }

  bool get isImage => contentType.toLowerCase().startsWith('image/');
}

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  String? _token;
  User? _currentUser;

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  // 设置认证token
  void setToken(String token) {
    _token = token;
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // 获取HTTP请求头
  Map<String, String> get _headers {
    final headers = {'content-type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // 获取当前headers（用于调试）
  Map<String, String> get currentHeaders => _headers;

  // 用户注册
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      print('🚀 调用注册API...');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print('📡 注册响应状态码: ${response.statusCode}');
      print('📄 注册响应内容: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final authData = data['data'];
          if (authData['token'] != null) {
            _token = authData['token'];
            print('🔑 注册Token已保存: ${_token!.substring(0, 20)}...');
          }
          if (authData['user'] != null) {
            _currentUser = User.fromJson(authData['user']);
            print('✅ 注册用户信息已保存: ${_currentUser!.username}');
          }
        }
        print('✅ 注册成功');
        return data;
      } else {
        // 解析错误信息，提供用户友好的错误提示
        String errorMessage = '注册失败';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['errors'] != null) {
            // 处理验证错误
            final errors = errorData['errors'] as Map<String, dynamic>;
            final errorList = <String>[];

            if (errors['username'] != null) {
              final usernameErrors = errors['username'] as List;
              errorList.addAll(usernameErrors.cast<String>());
            }
            if (errors['email'] != null) {
              final emailErrors = errors['email'] as List;
              errorList.addAll(emailErrors.cast<String>());
            }
            if (errors['password'] != null) {
              final passwordErrors = errors['password'] as List;
              errorList.addAll(passwordErrors.cast<String>());
            }

            if (errorList.isNotEmpty) {
              errorMessage = errorList.join('\n');
            } else {
              errorMessage = errorData['message'] ?? '注册失败，请检查输入信息';
            }
          } else {
            errorMessage = errorData['message'] ?? '注册失败，请检查输入信息';
          }
        } catch (e) {
          errorMessage = '注册失败，请检查网络连接';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ 注册错误: $e');
      if (e.toString().contains('SocketException')) {
        throw Exception('网络连接失败，请检查服务器地址和网络连接');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查网络连接');
      } else {
        throw Exception(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  // 用户登录
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    String errorMessage = '登录失败';
    try {
      final url = '$baseUrl/auth/login';
      print(' 尝试连接到: $url');
      print(' 发送数据: {"username": "$username", "password": "***"}');

      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('📡 响应状态码: ${response.statusCode}');
      print('📄 响应头: ${response.headers}');
      print('📄 响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ 登录响应解析: $responseData');

        // 检查响应格式
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          if (data['token'] != null) {
            _token = data['token'];
            print('🔑 Token 已保存: ${_token!.substring(0, 20)}...');
            if (data['user'] != null) {
              try {
                print(' 用户数据: ${data['user']}');
                _currentUser = User.fromJson(data['user']);
                print('✅ 用户信息已保存: ${_currentUser!.username}');
              } catch (e) {
                print('❌ 用户数据解析失败: $e');
                print('❌ 用户数据内容: ${data['user']}');
                throw Exception('用户数据解析失败: $e');
              }
            }
          }
          return responseData;
        } else {
          print(
            '❌ 响应格式错误: success=${responseData['success']}, data=${responseData['data']}',
          );
          throw Exception('登录失败: 响应格式错误');
        }
      } else {
        print('❌ HTTP错误: ${response.statusCode}');

        try {
          final errorData = jsonDecode(response.body);
          print('📄 错误响应数据: $errorData');

          if (errorData['errors'] != null) {
            // 处理错误信息
            final errors = errorData['errors'];
            if (errors is List) {
              // errors是数组格式
              final errorList = errors.cast<String>();
              if (errorList.isNotEmpty) {
                errorMessage = errorList.join('\n');
              } else {
                errorMessage = errorData['message'] ?? '登录失败，请检查用户名和密码';
              }
            } else if (errors is Map) {
              // errors是对象格式（用于验证错误）
              final errorMap = errors as Map<String, dynamic>;
              final errorList = <String>[];

              if (errorMap['username'] != null) {
                final usernameErrors = errorMap['username'] as List;
                errorList.addAll(usernameErrors.cast<String>());
              }
              if (errorMap['password'] != null) {
                final passwordErrors = errorMap['password'] as List;
                errorList.addAll(passwordErrors.cast<String>());
              }

              if (errorList.isNotEmpty) {
                errorMessage = errorList.join('\n');
              } else {
                errorMessage = errorData['message'] ?? '登录失败，请检查用户名和密码';
              }
            } else {
              errorMessage = errorData['message'] ?? '登录失败，请检查用户名和密码';
            }
          } else {
            errorMessage = errorData['message'] ?? '登录失败，请检查用户名和密码';
          }
        } catch (e) {
          print('❌ 解析错误响应失败: $e');
          errorMessage = '登录失败，请检查网络连接';
        }
        print('❌ 错误详情: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(' 异常详情: $e');

      if (e.toString().contains('SocketException')) {
        throw Exception('网络连接失败，请检查服务器地址和网络连接');
      } else if (e.toString().contains('TimeoutException')) {
        throw Exception('请求超时，请检查网络连接');
      } else {
        throw Exception('登录错误: $errorMessage');
      }
    }
  }

  // QQ测试登录（真实QQ OAuth需要移动端应用跳转；本地验证使用后端受控dev-login）
  Future<Map<String, dynamic>> qqDevLogin() async {
    String errorMessage = 'QQ登录失败';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/qq/dev-login'),
        headers: _headers,
        body: jsonEncode({
          'open_id': 'dev_qq_flutter',
          'nickname': 'QQ手机测试用户',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          if (data['token'] != null) {
            _token = data['token'];
          }
          if (data['user'] != null) {
            _currentUser = User.fromJson(data['user']);
          }
          return responseData;
        }

        errorMessage = responseData['message'] ?? 'QQ登录失败';
        throw Exception(errorMessage);
      }

      final errorData = jsonDecode(response.body);
      errorMessage = errorData['message'] ?? 'QQ登录失败';
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ QQ登录错误: $e');
      throw Exception(errorMessage);
    }
  }

  // QQ测试绑定
  Future<User> qqDevBind({
    required String openId,
    String? nickname,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/qq/dev-bind'),
        headers: _headers,
        body: jsonEncode({
          'open_id': openId,
          'nickname': nickname,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final user = User.fromJson(responseData['data']);
          _currentUser = user;
          return user;
        }

        throw Exception(responseData['message'] ?? 'QQ绑定失败');
      }

      final errorData = jsonDecode(response.body);
      throw Exception('QQ绑定失败: ${errorData['message'] ?? response.body}');
    } catch (e) {
      throw Exception('QQ绑定错误: $e');
    }
  }

  // 获取联系人列表
  Future<List<Contact>> getContacts() async {
    String errorMessage = '获取联系人失败';
    try {
      print('📞 获取联系人列表...');
      final response = await http.get(
        Uri.parse('$baseUrl/contacts'),
        headers: _headers,
      );

      print('📡 联系人响应状态码: ${response.statusCode}');
      print('📄 联系人响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> contactsData = responseData['data'];
          final contacts =
              contactsData.map((json) => Contact.fromJson(json)).toList();
          print('✅ 成功获取 ${contacts.length} 个联系人');
          return contacts;
        } else {
          errorMessage = '获取联系人失败: 响应格式错误';
          throw Exception(errorMessage);
        }
      } else {
        final errorData = jsonDecode(response.body);
        errorMessage = '获取联系人失败: ${errorData['message'] ?? response.body}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ 获取联系人错误: $errorMessage');
      throw Exception('获取联系人错误: $errorMessage');
    }
  }

  // 发送好友申请。旧的添加联系人入口也必须走申请流程，不能直接成为联系人。
  Future<FriendRequest> addContact({
    required String username,
    String? displayName,
  }) async {
    return createFriendRequest(
      username: username,
      note: displayName,
      source: '联系人添加',
    );
  }

  Future<FriendRequest> createFriendRequest({
    required String username,
    String? note,
    String? source,
  }) async {
    try {
      print('➕ 发送好友申请: $username');
      final response = await http.post(
        Uri.parse('$baseUrl/contacts/friend-requests'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'note': note,
          'source': source ?? '账号搜索',
        }),
      );

      print('📡 好友申请响应状态码: ${response.statusCode}');
      print('📄 好友申请响应内容: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final request = FriendRequest.fromJson(responseData['data']);
          print('✅ 好友申请已发送: ${request.peer.username}');
          return request;
        } else {
          throw Exception('发送好友申请失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('发送好友申请失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 发送好友申请错误: $e');
      throw Exception('发送好友申请错误: $e');
    }
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/contacts/friend-requests'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> requestsData = responseData['data'];
          return requestsData
              .map((json) => FriendRequest.fromJson(json))
              .toList();
        }

        throw Exception('获取好友申请失败: 响应格式错误');
      }

      final errorData = jsonDecode(response.body);
      throw Exception('获取好友申请失败: ${errorData['message'] ?? response.body}');
    } catch (e) {
      print('❌ 获取好友申请错误: $e');
      throw Exception('获取好友申请错误: $e');
    }
  }

  Future<FriendRequest> respondFriendRequest(
    int requestId,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/contacts/friend-requests/$requestId'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return FriendRequest.fromJson(responseData['data']);
        }

        throw Exception('处理好友申请失败: 响应格式错误');
      }

      final errorData = jsonDecode(response.body);
      throw Exception('处理好友申请失败: ${errorData['message'] ?? response.body}');
    } catch (e) {
      print('❌ 处理好友申请错误: $e');
      throw Exception('处理好友申请错误: $e');
    }
  }

  Future<void> clearHandledFriendRequests() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/contacts/friend-requests/handled'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception('清理好友申请失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 清理好友申请错误: $e');
      throw Exception('清理好友申请错误: $e');
    }
  }

  // 删除联系人
  Future<void> removeContact(int contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/contacts/$contactId'),
        headers: currentHeaders,
      );

      if (response.statusCode == 200) {
        print('✅ 联系人删除成功');
      } else {
        print('❌ 删除联系人失败: ${response.statusCode}');
        throw Exception('删除联系人失败');
      }
    } catch (e) {
      print('❌ 删除联系人异常: $e');
      throw Exception('删除联系人失败: $e');
    }
  }

  // 修改联系人备注
  Future<Contact> updateContactDisplayName(
    int contactId,
    String displayName,
  ) async {
    try {
      print('✏️ 修改联系人备注: $contactId -> $displayName');
      final response = await http.patch(
        Uri.parse('$baseUrl/contacts/$contactId/display-name'),
        headers: _headers,
        body: jsonEncode(displayName),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final contact = Contact.fromJson(responseData['data']);
          print('✅ 成功修改联系人备注');
          return contact;
        } else {
          throw Exception('修改联系人备注失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('修改联系人备注失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 修改联系人备注错误: $e');
      throw Exception('修改联系人备注错误: $e');
    }
  }

  // 屏蔽/取消屏蔽联系人
  Future<void> blockContact(int contactId, bool isBlocked) async {
    try {
      print('🚫 ${isBlocked ? "屏蔽" : "取消屏蔽"}联系人: $contactId');
      final response = await http.patch(
        Uri.parse('$baseUrl/contacts/$contactId/block'),
        headers: _headers,
        body: jsonEncode(isBlocked),
      );

      if (response.statusCode == 200) {
        print('✅ 成功${isBlocked ? "屏蔽" : "取消屏蔽"}联系人');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          '${isBlocked ? "屏蔽" : "取消屏蔽"}联系人失败: ${errorData['message'] ?? response.body}',
        );
      }
    } catch (e) {
      print('❌ ${isBlocked ? "屏蔽" : "取消屏蔽"}联系人错误: $e');
      throw Exception('${isBlocked ? "屏蔽" : "取消屏蔽"}联系人错误: $e');
    }
  }

  // 获取聊天记录
  Future<List<ChatMessage>> getChatHistory(int contactId) async {
    try {
      print('💬 获取聊天记录: $contactId');
      final response = await http.get(
        Uri.parse('$baseUrl/chat/history/$contactId'),
        headers: _headers,
      );

      print('📡 聊天记录响应状态码: ${response.statusCode}');
      print('📄 聊天记录响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> messagesData = responseData['data'];
          final messages =
              messagesData.map((json) => ChatMessage.fromJson(json)).toList();
          print('✅ 成功获取 ${messages.length} 条聊天记录');
          return messages;
        } else {
          print('📝 没有聊天记录或响应格式错误');
          return []; // 如果没有聊天记录，返回空列表
        }
      } else {
        print('❌ 获取聊天记录失败: ${response.statusCode}');
        return []; // 如果API不存在，返回空列表
      }
    } catch (e) {
      print('❌ 获取聊天记录错误: $e');
      return []; // 出错时返回空列表
    }
  }

  // 删除聊天记录
  Future<void> deleteChatHistory(int contactId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/chat/chat-history/$contactId'),
        headers: currentHeaders,
      );

      if (response.statusCode == 200) {
        print('✅ 聊天记录删除成功');
      } else {
        print('❌ 删除聊天记录失败: ${response.statusCode}');
        throw Exception('删除聊天记录失败');
      }
    } catch (e) {
      print('❌ 删除聊天记录异常: $e');
      throw Exception('删除聊天记录失败: $e');
    }
  }

  // 标记消息为已读
  Future<void> markMessageAsRead(String messageId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/chat/messages/$messageId/read'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception('标记消息已读失败: ${errorData['message'] ?? response.body}');
      }
    } catch (_) {
      rethrow;
    }
  }

  // 上传聊天附件
  Future<ChatUploadResult> uploadChatFile(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/upload'),
      );

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          return ChatUploadResult.fromJson(
            responseData['data'] as Map<String, dynamic>,
          );
        }

        throw Exception('上传文件失败: 响应格式错误');
      }

      final errorData = jsonDecode(response.body);
      throw Exception('上传文件失败: ${errorData['message'] ?? response.body}');
    } catch (e) {
      throw Exception('上传文件错误: $e');
    }
  }

  // 搜索用户
  Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 1,
    int page_size = 20,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.baseUrl}/auth/search-users').replace(
        queryParameters: {
          'query': query,
          'page': page.toString(),
          'page_size': page_size.toString(),
        },
      );

      final response = await http.get(uri, headers: currentHeaders);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ 搜索用户成功: ${data['data']['users'].length} 个用户');
        return data['data'];
      } else {
        print('❌ 搜索用户失败: ${response.statusCode}');
        throw Exception('搜索用户失败');
      }
    } catch (e) {
      print('❌ 搜索用户异常: $e');
      throw Exception('搜索用户失败: $e');
    }
  }

  // 发送消息
  Future<ChatMessage> sendMessage(
    int receiverId,
    String content,
    MessageType type, {
    String? filePath,
    int? fileSize,
    int? duration,
  }) async {
    try {
      print('📤 发送消息给: $receiverId');

      // 将MessageType转换为后端期望的格式
      String typeString;
      switch (type) {
        case MessageType.text:
          typeString = 'Text';
          break;
        case MessageType.image:
          typeString = 'Image';
          break;
        case MessageType.video:
          typeString = 'Video';
          break;
        case MessageType.audio:
          typeString = 'Audio';
          break;
        case MessageType.file:
          typeString = 'File';
          break;
      }

      final body = <String, dynamic>{
        'receiver_id': receiverId,
        'content': content,
        'type': typeString,
      };
      if (filePath != null) {
        body['file_path'] = filePath;
      }
      if (fileSize != null) {
        body['file_size'] = fileSize;
      }
      if (duration != null) {
        body['duration'] = duration;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final message = ChatMessage.fromJson(responseData['data']);
          print('✅ 成功发送消息');
          return message;
        } else {
          throw Exception('发送消息失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('发送消息失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 发送消息错误: $e');
      throw Exception('发送消息错误: $e');
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
        body: jsonEncode({'room_name': roomName}),
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

  // 获取用户个人资料
  Future<User> getUserProfile() async {
    try {
      print('👤 获取用户个人资料...');
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
      );

      print('📡 个人资料响应状态码: ${response.statusCode}');
      print('📄 个人资料响应内容: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final user = User.fromJson(responseData['data']);
          print('✅ 成功获取用户个人资料');
          return user;
        } else {
          throw Exception('获取个人资料失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('获取个人资料失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 获取个人资料错误: $e');
      throw Exception('获取个人资料错误: $e');
    }
  }

  // 更新个人资料
  Future<User> updateProfile({
    String? display_name,
    String? signature,
    String? avatarPath,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (display_name != null) body['display_name'] = display_name;
      if (signature != null) body['signature'] = signature;
      if (avatarPath != null) body['avatar_path'] = avatarPath;

      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile'),
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final user = User.fromJson(responseData['data']);
          _currentUser = user;
          return user;
        } else {
          throw Exception('更新个人资料失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('更新个人资料失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('更新个人资料错误: $e');
    }
  }

  // 上传头像
  Future<User> uploadAvatar(File imageFile) async {
    try {
      print('📤 上传头像...');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/upload-avatar'),
      );

      // 添加认证头
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      // 添加文件
      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final user = User.fromJson(responseData['data']);
          _currentUser = user;
          print('✅ 头像上传成功');
          return user;
        } else {
          throw Exception('头像上传失败: 响应格式错误');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('头像上传失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 头像上传错误: $e');
      throw Exception('头像上传错误: $e');
    }
  }

  // 修改密码
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      print('🔐 修改密码...');
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: _headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );

      print('📡 修改密码响应状态码: ${response.statusCode}');
      print('📄 修改密码响应内容: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ 成功修改密码');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('修改密码失败: ${errorData['message'] ?? response.body}');
      }
    } catch (e) {
      print('❌ 修改密码错误: $e');
      throw Exception('修改密码错误: $e');
    }
  }
}
