import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

class ChatStorageService {
  static const String _chatPrefix = 'chat_';
  
  // 保存聊天记录
  Future<void> saveChatMessages(int contactId, List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_chatPrefix$contactId';
    final messagesJson = messages.map((msg) => msg.toJson()).toList();
    await prefs.setString(key, jsonEncode(messagesJson));
  }
  
  // 获取聊天记录
  Future<List<ChatMessage>> getChatMessages(int contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_chatPrefix$contactId';
    final messagesString = prefs.getString(key);
    
    if (messagesString == null) {
      return [];
    }
    
    try {
      final messagesJson = jsonDecode(messagesString) as List;
      return messagesJson.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      print('解析聊天记录失败: $e');
      return [];
    }
  }
  
  // 添加新消息
  Future<void> addMessage(int contactId, ChatMessage message) async {
    final messages = await getChatMessages(contactId);
    messages.add(message);
    await saveChatMessages(contactId, messages);
  }
  
  // 清除聊天记录
  Future<void> clearChatMessages(int contactId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_chatPrefix$contactId';
    await prefs.remove(key);
  }
  
  // 获取所有联系人的聊天记录
  Future<Map<int, List<ChatMessage>>> getAllChatMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_chatPrefix));
    final result = <int, List<ChatMessage>>{};
    
    for (final key in keys) {
      final contactId = int.tryParse(key.substring(_chatPrefix.length));
      if (contactId != null) {
        final messages = await getChatMessages(contactId);
        if (messages.isNotEmpty) {
          result[contactId] = messages;
        }
      }
    }
    
    return result;
  }
} 