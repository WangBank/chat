import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../models/contact.dart';
import 'chat_page.dart';

class ChatHistoryPage extends StatefulWidget {
  final ApiService apiService;
  final CallManager callManager;

  const ChatHistoryPage({
    super.key,
    required this.apiService,
    required this.callManager,
  });

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final contacts = await widget.apiService.getContacts();
      
      // 过滤出有聊天记录的联系人
      final contactsWithChat = contacts.where((contact) => 
        contact.lastMessageAt != null || contact.unreadCount > 0
      ).toList();
      
      // 按最后消息时间排序
      contactsWithChat.sort((a, b) {
        final aTime = a.lastMessageAt ?? DateTime(1900);
        final bTime = b.lastMessageAt ?? DateTime(1900);
        return bTime.compareTo(aTime);
      });

      setState(() {
        _contacts = contactsWithChat;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteChatHistory(Contact contact) async {
    try {
      await widget.apiService.deleteChatHistory(contact.id);
      
      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('聊天记录已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除聊天记录'),
        content: Text('确定要删除与 ${contact.displayNameOrUsername} 的聊天记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteChatHistory(contact);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天记录'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('加载失败: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadContacts,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _contacts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('暂无聊天记录', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadContacts,
                      child: ListView.builder(
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final contact = _contacts[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: contact.contactUser.avatarPath != null
                                  ? NetworkImage(contact.contactUser.avatarPath!)
                                  : null,
                              child: contact.contactUser.avatarPath == null
                                  ? Text(contact.displayNameOrUsername[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(contact.displayNameOrUsername),
                            subtitle: Text(
                              contact.lastMessageAt != null
                                  ? '最后消息: ${_formatTime(contact.lastMessageAt!)}'
                                  : '暂无消息',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (contact.unreadCount > 0)
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${contact.unreadCount}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _showDeleteDialog(contact);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('删除聊天记录'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    contact: contact,
                                    apiService: widget.apiService,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
} 