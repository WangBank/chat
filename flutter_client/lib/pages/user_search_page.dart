import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';

class UserSearchPage extends StatefulWidget {
  final ApiService apiService;
  final Function(User user) onUserSelected;

  const UserSearchPage({
    super.key,
    required this.apiService,
    required this.onUserSelected,
  });

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqBlueSoft = Color(0xFFE8F6FF);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<User> _users = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMore) {
        _loadMoreUsers();
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {});
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query, {bool force = false}) async {
    if (!force && query == _currentQuery) return;

    setState(() {
      _isLoading = true;
      _currentQuery = query;
      _currentPage = 1;
      _users.clear();
      _hasMore = true;
    });

    try {
      final result = await widget.apiService.searchUsers(
        query: query,
        page: _currentPage,
        page_size: 20,
      );

      final users = (result['users'] as List)
          .map((userData) => User.fromJson(userData))
          .toList();

      setState(() {
        _users = users;
        _isLoading = false;
        _hasMore = result['total_pages'] > _currentPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('搜索失败: $e')));
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.apiService.searchUsers(
        query: '',
        page: 1,
        page_size: 20,
      );

      final users = (result['users'] as List)
          .map((userData) => User.fromJson(userData))
          .toList();

      setState(() {
        _users = users;
        _isLoading = false;
        _hasMore = result['total_pages'] > 1;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载用户失败: $e')));
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await widget.apiService.searchUsers(
        query: _currentQuery,
        page: _currentPage + 1,
        page_size: 20,
      );

      final newUsers = (result['users'] as List)
          .map((userData) => User.fromJson(userData))
          .toList();

      setState(() {
        _users.addAll(newUsers);
        _currentPage++;
        _isLoading = false;
        _hasMore = result['total_pages'] > _currentPage;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载更多用户失败: $e')));
      }
    }
  }

  String _displayName(User user) {
    if (user.display_name?.trim().isNotEmpty == true) {
      return user.display_name!.trim();
    }
    return user.username;
  }

  String _initial(User user) {
    final name = _displayName(user);
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildAvatar(User user) {
    final avatarUrl = AppConfig.resolveMediaUrl(user.avatarPath);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: _qqBlue,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  _initial(user),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
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
              color: user.isOnline ? _qqOnline : _qqOffline,
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(User user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:
            user.isOnline ? const Color(0xFFE8F8EF) : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        user.isOnline ? '在线' : '离线',
        style: TextStyle(
          color: user.isOnline ? _qqOnline : _qqMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildUserTile(User user) {
    final signature = user.signature?.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => widget.onUserSelected(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _buildAvatar(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _displayName(user),
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
                          _buildStatusChip(user),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _qqMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        signature?.isNotEmpty == true ? signature! : user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _qqMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: () => widget.onUserSelected(user),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('添加'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _qqBlueSoft,
                    foregroundColor: _qqBlue,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 58, color: _qqMuted),
          SizedBox(height: 14),
          Text(
            '没有找到用户',
            style: TextStyle(
              color: _qqMuted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索用户'),
      ),
      body: Column(
        children: [
          Container(
            color: _qqShell,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: '搜索用户名、昵称或邮箱',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    tooltip: '清除',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                  ),
              ],
              backgroundColor: const WidgetStatePropertyAll(Colors.white),
              elevation: const WidgetStatePropertyAll(0),
              side: const WidgetStatePropertyAll(
                BorderSide(color: Color(0xFFE5EDF3)),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: _qqShell,
              child: _users.isEmpty && !_isLoading
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () => _searchUsers(
                        _searchController.text.trim(),
                        force: true,
                      ),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 18),
                        itemCount: _users.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _users.length) {
                            return _isLoading
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }

                          return _buildUserTile(_users[index]);
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
