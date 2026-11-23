import 'package:chat/models/announcement.dart';
import 'package:chat/pages/announcements_page.dart';
import 'package:chat/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AnnouncementApi extends ApiService {
  bool isRead = false;
  bool newlyPublished = false;
  int? readId;
  final pages = <int>[];

  @override
  Future<AnnouncementPageData> getAnnouncements(int page) async {
    pages.add(page);
    final item = Announcement(
      id: page,
      title: page == 2 ? '历史公告' : newlyPublished ? '刚发布' : '维护通知',
      body: '公告完整正文',
      publishedAt: DateTime(2026, 11, 23),
      isRead: isRead,
    );
    return AnnouncementPageData([item], 21, isRead ? 0 : 1);
  }

  @override
  Future<void> markAnnouncementRead(int id) async {
    readId = id;
    isRead = true;
  }
}

void main() {
  testWidgets('打开公告才标为已读，支持翻页和在线刷新', (tester) async {
    final api = _AnnouncementApi();
    final counts = <int>[];
    Widget app(int refreshToken) => MaterialApp(
      home: AnnouncementsPage(
        apiService: api, refreshToken: refreshToken, onUnreadChanged: counts.add,
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(find.text('维护通知'), findsOneWidget);
    expect(counts.last, 1);
    expect(api.readId, isNull);
    await tester.tap(find.text('维护通知'));
    await tester.pumpAndSettle();
    expect(find.text('公告完整正文'), findsOneWidget);
    expect(api.readId, 1);
    expect(counts.last, 0);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('历史公告'), findsOneWidget);
    expect(api.pages.last, 2);
    await tester.tap(find.byTooltip('上一页'));
    await tester.pumpAndSettle();
    api.newlyPublished = true;
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    expect(find.text('刚发布'), findsOneWidget);
  });
}
