import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/api_service.dart';
import '../utils/network_error.dart';

class AnnouncementsPage extends StatefulWidget {
  final ApiService apiService;
  final int refreshToken;
  final ValueChanged<int> onUnreadChanged;

  const AnnouncementsPage({
    super.key,
    required this.apiService,
    required this.refreshToken,
    required this.onUnreadChanged,
  });

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int _request = 0;
  int _page = 1;
  bool _loading = true;
  String? _error;
  AnnouncementPageData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AnnouncementsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  Future<void> _load({int? page}) async {
    final request = ++_request;
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.apiService.getAnnouncements(targetPage);
      if (!mounted || request != _request) return;
      setState(() {
        _page = targetPage;
        _data = data;
        _loading = false;
      });
      widget.onUnreadChanged(data.unreadCount);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = userFacingServiceError(error, fallback: '获取通知失败');
        _loading = false;
      });
    }
  }

  Future<void> _open(Announcement item) async {
    final dialog = showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(child: SelectableText(item.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    if (!item.isRead) {
      try {
        await widget.apiService.markAnnouncementRead(item.id);
        if (mounted) await _load();
      } catch (error) {
        await dialog;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingServiceError(error, fallback: '标记已读失败')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('系统通知'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: Text(_error!)),
                  TextButton(onPressed: () => _load(), child: const Text('重试')),
                ],
              ),
            ),
          if (data != null && data.items.isEmpty && _error == null)
            const Expanded(child: Center(child: Text('暂无系统通知'))),
          if (data != null && data.items.isNotEmpty)
            Expanded(
              child: ListView.separated(
                key: ValueKey(_page),
                itemCount: data.items.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = data.items[index];
                  final date = MaterialLocalizations.of(context)
                      .formatMediumDate(item.publishedAt);
                  final time = TimeOfDay.fromDateTime(item.publishedAt)
                      .format(context);
                  return ListTile(
                    onTap: () => _open(item),
                    leading: Icon(
                      item.isRead
                          ? Icons.drafts_outlined
                          : Icons.mark_email_unread_outlined,
                      semanticLabel: item.isRead ? '已读' : '未读',
                      color: item.isRead ? null : theme.colorScheme.primary,
                    ),
                    title: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: item.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('$date  $time'),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          if (data != null && (data.total > 20 || _page > 1))
            SafeArea(
              top: false,
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '上一页',
                    onPressed: _loading || _page == 1
                        ? null
                        : () => _load(page: _page - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('第 $_page 页'),
                  IconButton(
                    tooltip: '下一页',
                    onPressed: _loading || _page * 20 >= data.total
                        ? null
                        : () => _load(page: _page + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
