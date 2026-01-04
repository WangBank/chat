import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/user.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../config/app_config.dart';
import 'user_search_page.dart';
import 'chat_page.dart';

class ContactsPage extends StatefulWidget {
  final ApiService apiService;
  final CallManager callManager;
  final int refreshToken; // 新增：刷新令牌
  const ContactsPage({
    super.key,
    required this.apiService,
    required this.callManager,
    required this.refreshToken, // 新增：构造入参
  });

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新增：当刷新令牌变化时，触发重新加载
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await widget.apiService.getContacts();
      setState(() {
        _contacts = contacts;
        _filteredContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取联系人失败: $e')),
        );
      }
    }
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _contacts;
      } else {
        _filteredContacts = _contacts.where((contact) {
          final displayName = contact.displayName?.toLowerCase() ?? '';
          final username = contact.contactUser.username.toLowerCase();
          final display_name = contact.contactUser.display_name?.toLowerCase() ?? '';
          final searchQuery = query.toLowerCase();
          
          return displayName.contains(searchQuery) ||
                 username.contains(searchQuery) ||
                 display_name.contains(searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _addContact(User user) async {
    try {
      await widget.apiService.addContact(username: user.username);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('联系人添加成功')),
      );
      _loadContacts(); // 重新加载联系人列表
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加联系人失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    try {
      await widget.apiService.removeContact(contact.id);
      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
        _filteredContacts.removeWhere((c) => c.id == contact.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('联系人删除成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除联系人失败: $e')),
        );
      }
    }
  }

  void _showDeleteDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定要删除联系人 "${contact.displayName?.isNotEmpty == true ? contact.displayName! : contact.contactUser.username}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteContact(contact);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showUserSearchPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSearchPage(
          apiService: widget.apiService,
          onUserSelected: _addContact,
        ),
      ),
    ).then((_) {
      // 返回时重新加载联系人列表
      _loadContacts();
    });
  }

  void _navigateToChatPage(Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          contact: contact,
          apiService: widget.apiService,
          callManager: widget.callManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showUserSearchPage,
            tooltip: '添加联系人',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterContacts,
              decoration: InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          
          // 联系人列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? const Center(
                        child: Text(
                          '没有联系人',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: ListView.builder(
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue,
                                backgroundImage: contact.contactUser.avatarPath != null
                                    ? NetworkImage('${AppConfig.baseUrl}${contact.contactUser.avatarPath!}')
                                    : null,
                                child: contact.contactUser.avatarPath == null
                                    ? Text(
                                        (contact.displayName?.isNotEmpty == true
                                                ? contact.displayName![0]
                                                : (contact.contactUser.display_name?.isNotEmpty == true
                                                    ? contact.contactUser.display_name![0]
                                                    : contact.contactUser.username[0]))
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                contact.displayName?.isNotEmpty == true
                                    ? contact.displayName!
                                    : (contact.contactUser.display_name?.isNotEmpty == true
                                        ? contact.contactUser.display_name!
                                        : contact.contactUser.username),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('用户名: ${contact.contactUser.username}'),
                                  if (contact.contactUser.display_name?.isNotEmpty == true)
                                    Text('昵称: ${contact.contactUser.display_name}'),
                                  if (contact.lastMessageAt != null)
                                    Text(
                                      '最后消息: ${_formatTime(contact.lastMessageAt!)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  if (contact.unreadCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${contact.unreadCount} 条未读',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.call),
                                    onPressed: () {
                                      widget.callManager.initiateCall(
                                        contact.contactUser,
                                        CallType.voice,
                                      );
                                    },
                                    tooltip: '语音通话',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.video_call),
                                    onPressed: () {
                                      widget.callManager.initiateCall(
                                        contact.contactUser,
                                        CallType.video,
                                      );
                                    },
                                    tooltip: '视频通话',
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'chat':
                                          _navigateToChatPage(contact);
                                          break;
                                        case 'delete':
                                          _showDeleteDialog(contact);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'chat',
                                        child: Row(
                                          children: [
                                            Icon(Icons.chat),
                                            SizedBox(width: 8),
                                            Text('发送消息'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('删除联系人', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              onTap: () => _navigateToChatPage(contact),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
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
