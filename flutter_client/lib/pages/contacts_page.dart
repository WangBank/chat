import 'dart:async';
import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../services/signalr_service.dart';
import '../config/app_config.dart';
import '../widgets/load_error_state.dart';
import '../utils/network_error.dart';
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
  List<FriendRequest> _friendRequests = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isFriendRequestsLoading = false;
  String? _contactsErrorMessage;
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
    _loadFriendRequests();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_isLoading) {
        _loadContacts(showLoading: false);
      }
      if (mounted && !_isFriendRequestsLoading) {
        _loadFriendRequests(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 新增：当刷新令牌变化时，触发重新加载
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadContacts();
      _loadFriendRequests();
    }
  }

  Future<void> _loadContacts({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _contactsErrorMessage = null;
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
        _contactsErrorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (showLoading || _contacts.isEmpty) {
          _contactsErrorMessage = userFacingServiceError(
            e,
            fallback: '获取联系人失败',
          );
        }
      });

      if (!showLoading && _contacts.isNotEmpty) {
        showCompactErrorSnackBar(context, '联系人刷新失败，请稍后重试');
      }
    }
  }

  Future<void> _retryContacts() async {
    try {
      final token = widget.apiService.token;
      if (token == null || token.isEmpty) {
        throw Exception('登录状态已失效，请重新登录');
      }
      await widget.callManager.ensureOnline(token);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _contactsErrorMessage = userFacingServiceError(
          e,
          fallback: '获取联系人失败',
        );
      });
      return;
    }
    await _loadContacts();
    await _loadFriendRequests(showLoading: false);
  }

  Future<void> _loadFriendRequests({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isFriendRequestsLoading = true;
      });
    }

    try {
      final requests = await widget.apiService.getFriendRequests();
      if (!mounted) return;

      setState(() {
        _friendRequests = requests;
        _isFriendRequestsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFriendRequestsLoading = false;
      });
      if (showLoading) {
        showCompactErrorSnackBar(context, '获取好友申请失败，请稍后重试');
      }
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
    final note = await _showFriendRequestNoteDialog(user);
    if (note == null) return;

    try {
      final request = await widget.apiService.createFriendRequest(
        username: user.username,
        note: note.trim().isEmpty ? null : note.trim(),
        source: '账号搜索',
      );
      if (!mounted) return;

      final currentUserId = widget.apiService.currentUser?.id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            request.isIncomingForUser(currentUserId)
                ? '对方已向你发送申请，请在好友通知中处理'
                : '好友申请已发送，等待对方同意',
          ),
        ),
      );
      _loadFriendRequests(showLoading: false);
    } catch (e) {
      if (mounted) {
        showCompactErrorSnackBar(context, '添加联系人失败，请稍后重试');
      }
    }
  }

  Future<String?> _showFriendRequestNoteDialog(User user) async {
    final controller = TextEditingController(
      text: _buildDefaultFriendRequestNote(),
    );
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('添加 ${_displayUserName(user)}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '验证消息 / 备注',
              helperText: '对方会在好友通知里看到这条消息',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('发送申请'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  String _buildDefaultFriendRequestNote() {
    final currentUser = widget.apiService.currentUser;
    final name = currentUser?.display_name?.trim().isNotEmpty == true
        ? currentUser!.display_name!.trim()
        : currentUser?.username ?? '我';
    return '我是$name，请求添加你为好友';
  }

  String _displayUserName(User user) {
    if (user.display_name?.trim().isNotEmpty == true) {
      return user.display_name!.trim();
    }
    return user.username;
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

      showCompactErrorSnackBar(context, '删除联系人失败，请稍后重试');
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

      showCompactErrorSnackBar(context, '修改备注失败，请稍后重试');
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
        _loadFriendRequests();
      }
    });
  }

  void _showFriendRequestsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendRequestsPage(
          apiService: widget.apiService,
          initialRequests: _friendRequests,
          onRequestsChanged: () {
            _loadFriendRequests(showLoading: false);
          },
          onContactsChanged: () {
            _loadContacts(showLoading: false);
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        _loadContacts(showLoading: false);
        _loadFriendRequests(showLoading: false);
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

  int get _pendingFriendRequestCount => _friendRequests
      .where((request) => request.isIncoming && request.isPending)
      .length;

  Widget _buildFriendRequestAction() {
    final count = _pendingFriendRequestCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none),
          onPressed: _showFriendRequestsPage,
          tooltip: '好友通知',
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
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
          _buildFriendRequestAction(),
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
                  : _contactsErrorMessage != null
                      ? LoadErrorState(
                          title: '联系人加载失败',
                          message: serviceMaintenanceMessage,
                          details: _contactsErrorMessage,
                          onRetry: _retryContacts,
                          accentColor: _qqBlue,
                          textColor: _qqText,
                          mutedColor: _qqMuted,
                        )
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

class FriendRequestsPage extends StatefulWidget {
  final ApiService apiService;
  final List<FriendRequest> initialRequests;
  final VoidCallback onRequestsChanged;
  final VoidCallback onContactsChanged;

  const FriendRequestsPage({
    super.key,
    required this.apiService,
    required this.initialRequests,
    required this.onRequestsChanged,
    required this.onContactsChanged,
  });

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);

  late List<FriendRequest> _requests;
  bool _isLoading = false;
  bool _isHandling = false;

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests;
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final requests = await widget.apiService.getFriendRequests();
      if (!mounted) return;

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
      widget.onRequestsChanged();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
      showCompactErrorSnackBar(context, '获取好友申请失败，请稍后重试');
    }
  }

  Future<void> _respond(FriendRequest request, String status) async {
    if (_isHandling) return;

    setState(() {
      _isHandling = true;
    });

    try {
      final updatedRequest = await widget.apiService.respondFriendRequest(
        request.id,
        status,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updatedRequest.isAccepted ? '已同意好友申请' : '已拒绝好友申请',
          ),
        ),
      );
      await _loadRequests();
      if (updatedRequest.isAccepted) {
        widget.onContactsChanged();
      }
    } catch (e) {
      if (!mounted) return;

      showCompactErrorSnackBar(context, '处理好友申请失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _isHandling = false;
        });
      }
    }
  }

  Future<void> _clearHandled() async {
    try {
      await widget.apiService.clearHandledFriendRequests();
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已清理处理过的好友申请')));
      await _loadRequests();
    } catch (e) {
      if (!mounted) return;

      showCompactErrorSnackBar(context, '清理好友申请失败，请稍后重试');
    }
  }

  String _displayName(User user) {
    if (user.display_name?.trim().isNotEmpty == true) {
      return user.display_name!.trim();
    }
    return user.username;
  }

  String _statusText(FriendRequest request) {
    if (request.isAccepted) return '已同意';
    if (request.isRejected) return '已拒绝';
    return request.isIncomingForUser(widget.apiService.currentUser?.id)
        ? '待你处理'
        : '等待验证';
  }

  Color _statusColor(FriendRequest request) {
    if (request.isAccepted) return Colors.green;
    if (request.isRejected) return Colors.red;
    return _qqBlue;
  }

  Widget _buildSection(String title, List<FriendRequest> requests) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Text(
            '$title (${requests.length})',
            style: const TextStyle(
              color: _qqText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (requests.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              '暂无记录',
              style: TextStyle(color: _qqMuted, fontSize: 13),
            ),
          )
        else
          ...requests.map(_buildRequestCard),
      ]),
    );
  }

  Widget _buildRequestCard(FriendRequest request) {
    final currentUserId = widget.apiService.currentUser?.id;
    final peer = request.peerForUser(currentUserId);
    if (peer == null) return const SizedBox.shrink();

    final note = request.note?.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _qqBlue,
                child: Text(
                  _displayName(peer).isNotEmpty
                      ? _displayName(peer)[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName(peer),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _qqText,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _statusText(request),
                          style: TextStyle(
                            color: _statusColor(request),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${peer.username} · ${request.source}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _qqMuted, fontSize: 12),
                    ),
                    if (note?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        note!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _qqMuted, fontSize: 12),
                      ),
                    ],
                    if (request.isIncomingForUser(currentUserId) &&
                        request.isPending) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: _isHandling
                                ? null
                                : () => _respond(request, 'accepted'),
                            child: const Text('同意'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isHandling
                                ? null
                                : () => _respond(request, 'rejected'),
                            child: const Text('拒绝'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.apiService.currentUser?.id;
    final visibleRequests = _requests
        .where((request) => request.isVisibleForUser(currentUserId))
        .toList();
    final incomingPending = visibleRequests
        .where(
          (request) =>
              request.isIncomingForUser(currentUserId) && request.isPending,
        )
        .toList();
    final outgoingPending = visibleRequests
        .where(
          (request) =>
              request.isOutgoingForUser(currentUserId) && request.isPending,
        )
        .toList();
    final handled =
        visibleRequests.where((request) => !request.isPending).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友通知'),
        actions: [
          if (handled.isNotEmpty)
            TextButton(
              onPressed: _clearHandled,
              child: const Text('清理'),
            ),
        ],
      ),
      body: Container(
        color: _qqShell,
        child: RefreshIndicator(
          onRefresh: _loadRequests,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    _buildSection('待我处理', incomingPending),
                    _buildSection('等待验证', outgoingPending),
                    _buildSection('已处理', handled),
                    const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  ],
                ),
        ),
      ),
    );
  }
}
