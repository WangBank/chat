import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/user.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../services/signalr_service.dart';
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
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);

  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Timer? _refreshTimer;
  late final OnUserOnlineStatusChangedCallback _onlineStatusListener;

  @override
  void initState() {
    super.initState();
    _onlineStatusListener = _handleOnlineStatusChanged;
    widget.callManager.webRTCService.signalRService.addOnlineStatusListener(
      _onlineStatusListener,
    );
    _loadContacts();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isLoading) {
        _loadContacts(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新增：当刷新令牌变化时，触发重新加载
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadContacts();
    }
  }

  Future<void> _loadContacts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final contacts = await widget.apiService.getContacts();
      if (!mounted) return;

      setState(() {
        _contacts = contacts;
        _filteredContacts = _filterContactList(
          contacts,
          _searchController.text,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取联系人失败: $e')));
    }
  }

  List<Contact> _filterContactList(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;

    final searchQuery = query.toLowerCase();
    return contacts.where((contact) {
      final displayName = contact.displayName?.toLowerCase() ?? '';
      final username = contact.contactUser.username.toLowerCase();
      final profileDisplayName =
          contact.contactUser.display_name?.toLowerCase() ?? '';

      return displayName.contains(searchQuery) ||
          username.contains(searchQuery) ||
          profileDisplayName.contains(searchQuery);
    }).toList();
  }

  void _filterContacts(String query) {
    setState(() {
      _filteredContacts = _filterContactList(_contacts, query);
    });
  }

  void _handleOnlineStatusChanged(int userId, bool isOnline) {
    if (!mounted) return;
    final hasContact = _contacts.any(
      (contact) => contact.contactUser.id == userId,
    );
    if (!hasContact) return;

    setState(() {
      _contacts = _contacts.map((contact) {
        if (contact.contactUser.id != userId) return contact;
        return contact.copyWith(
          contactUser: contact.contactUser.copyWith(isOnline: isOnline),
        );
      }).toList();
      _filteredContacts = _filterContactList(_contacts, _searchController.text);
    });
  }

  Future<void> _addContact(User user) async {
    try {
      await widget.apiService.addContact(username: user.username);
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('联系人添加成功')));
      _loadContacts(); // 重新加载联系人列表
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加联系人失败: $e')));
      }
    }
  }

  Future<void> _deleteContact(Contact contact) async {
    try {
      await widget.apiService.removeContact(contact.id);
      if (!mounted) return;

      setState(() {
        _contacts.removeWhere((c) => c.id == contact.id);
        _filteredContacts.removeWhere((c) => c.id == contact.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('联系人删除成功')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除联系人失败: $e')));
    }
  }

  Future<void> _updateContactDisplayName(
    Contact contact,
    String displayName,
  ) async {
    try {
      final updatedContact = await widget.apiService.updateContactDisplayName(
        contact.id,
        displayName,
      );
      if (!mounted) return;

      setState(() {
        _contacts = _contacts
            .map((item) => item.id == updatedContact.id ? updatedContact : item)
            .toList();
        _filteredContacts = _filterContactList(
          _contacts,
          _searchController.text,
        );
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('备注已更新')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('修改备注失败: $e')));
    }
  }

  Future<void> _showEditDisplayNameDialog(Contact contact) async {
    final controller = TextEditingController(text: contact.displayName ?? '');

    try {
      final displayName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('修改备注'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '备注名',
              hintText: contact.contactUser.display_name?.isNotEmpty == true
                  ? contact.contactUser.display_name
                  : contact.contactUser.username,
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('清除'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      );

      if (displayName == null) return;
      await _updateContactDisplayName(contact, displayName);
    } finally {
      controller.dispose();
    }
  }

  void _showDeleteDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text(
          '确定要删除联系人 "${contact.displayName?.isNotEmpty == true ? contact.displayName! : contact.contactUser.username}" 吗？',
        ),
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
      if (mounted) {
        _loadContacts();
      }
    });
  }

  void _navigateToChatPage(Contact contact) {
    setState(() {
      _contacts = _contacts
          .map(
            (item) =>
                item.id == contact.id ? item.copyWith(unreadCount: 0) : item,
          )
          .toList();
      _filteredContacts = _filterContactList(_contacts, _searchController.text);
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          contact: contact,
          apiService: widget.apiService,
          callManager: widget.callManager,
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadContacts(showLoading: false);
      }
    });
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

  Widget _buildAvatar(Contact contact, {double radius = 24}) {
    final avatarUrl = AppConfig.resolveMediaUrl(contact.contactUser.avatarPath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
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

  Widget _buildRoundIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color color = _qqBlue,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        color: color,
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFE8F6FF),
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
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

  Widget _buildContactCard(Contact contact) {
    final displayName = _displayName(contact);
    final signature = contact.contactUser.signature?.trim();
    final statusText = contact.contactUser.isOnline ? '在线' : '离线';
    final secondaryText = signature?.isNotEmpty == true
        ? signature!
        : contact.contactUser.username;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _navigateToChatPage(contact),
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
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _qqText,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildUnreadBadge(contact.unreadCount),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '[$statusText]',
                            style: TextStyle(
                              color: contact.contactUser.isOnline
                                  ? _qqOnline
                                  : _qqMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _qqMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (contact.lastMessageAt != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _formatTime(contact.lastMessageAt!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _qqMuted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildRoundIconButton(
                  icon: Icons.call,
                  tooltip: '语音通话',
                  onPressed: () => widget.callManager.initiateCall(
                    contact.contactUser,
                    CallType.voice,
                  ),
                ),
                const SizedBox(width: 6),
                _buildRoundIconButton(
                  icon: Icons.videocam,
                  tooltip: '视频通话',
                  onPressed: () => widget.callManager.initiateCall(
                    contact.contactUser,
                    CallType.video,
                  ),
                ),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'chat':
                        _navigateToChatPage(contact);
                        break;
                      case 'edit':
                        _showEditDisplayNameDialog(contact);
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
                          Icon(Icons.chat_bubble_outline),
                          SizedBox(width: 8),
                          Text('发送消息'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('修改备注'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除联系人', style: TextStyle(color: Colors.red)),
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
  void dispose() {
    _refreshTimer?.cancel();
    widget.callManager.webRTCService.signalRService.removeOnlineStatusListener(
      _onlineStatusListener,
    );
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联系人'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _showUserSearchPage,
            tooltip: '添加联系人',
          ),
        ],
      ),
      body: Container(
        color: _qqShell,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _filterContacts,
                decoration: const InputDecoration(
                  hintText: '搜索联系人',
                  prefixIcon: Icon(Icons.search, color: _qqMuted),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredContacts.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_search_outlined,
                                size: 58,
                                color: _qqMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                '没有联系人',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _qqMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadContacts,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount: _filteredContacts.length,
                            itemBuilder: (context, index) =>
                                _buildContactCard(_filteredContacts[index]),
                          ),
                        ),
            ),
          ],
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
