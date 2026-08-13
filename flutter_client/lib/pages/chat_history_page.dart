import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../models/contact.dart';
import '../config/app_config.dart';
import '../widgets/load_error_state.dart';
import 'chat_page.dart';

class ChatHistoryPage extends StatefulWidget {
  final ApiService apiService;
  final CallManager callManager;
  final int refreshToken; // 新增：刷新令牌
  const ChatHistoryPage({
    super.key,
    required this.apiService,
    required this.callManager,
    required this.refreshToken, // 新增：构造入参
  });

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);

  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void didUpdateWidget(covariant ChatHistoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新增：当刷新令牌变化时，触发重新加载
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final contacts = await widget.apiService.getContacts();

      // 过滤出有聊天记录的联系人
      final contactsWithChat = contacts
          .where(
            (contact) =>
                contact.lastMessageAt != null || contact.unreadCount > 0,
          )
          .toList();

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
        _errorMessage = normalizeErrorMessage(e, fallback: '加载聊天记录失败');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('聊天记录已删除')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
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

  String _displayName(Contact contact) {
    if (contact.displayName?.isNotEmpty == true) {
      return contact.displayName!;
    }
    if (contact.contactUser.display_name?.isNotEmpty == true) {
      return contact.contactUser.display_name!;
    }
    return contact.contactUser.username;
  }

  String _initial(Contact contact) {
    final name = _displayName(contact);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildAvatar(Contact contact) {
    final avatarUrl = AppConfig.resolveMediaUrl(contact.contactUser.avatarPath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: _qqBlue,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  _initial(contact),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: contact.contactUser.isOnline ? _qqOnline : _qqOffline,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnreadBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildConversationTile(Contact contact) {
    final signature = contact.contactUser.signature?.trim();
    final preview = signature?.isNotEmpty == true ? signature! : '点击继续聊天';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _contacts = _contacts
                  .map(
                    (item) => item.id == contact.id
                        ? item.copyWith(unreadCount: 0)
                        : item,
                  )
                  .toList();
            });

            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  contact: contact,
                  apiService: widget.apiService,
                  callManager: widget.callManager,
                ),
              ),
            )
                .then((_) {
              if (mounted) {
                _loadContacts();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(contact),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayName(contact),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _qqText,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (contact.lastMessageAt != null)
                            Text(
                              _formatTime(contact.lastMessageAt!),
                              style: const TextStyle(
                                color: _qqMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _qqMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildUnreadBadge(contact.unreadCount),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz),
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
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除聊天记录', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天记录'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadContacts),
        ],
      ),
      body: Container(
        color: _qqShell,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? LoadErrorState(
                    title: '聊天记录加载失败',
                    message: '请确认后端服务已启动，或稍后重试。',
                    details: _errorMessage,
                    onRetry: _loadContacts,
                    accentColor: _qqBlue,
                    textColor: _qqText,
                    mutedColor: _qqMuted,
                  )
                : _contacts.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: _qqMuted,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '暂无聊天记录',
                              style: TextStyle(color: _qqMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) =>
                              _buildConversationTile(_contacts[index]),
                        ),
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
