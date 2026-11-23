class Announcement {
  final int id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final bool isRead;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    required this.isRead,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
    publishedAt: DateTime.parse(json['published_at'] as String).toLocal(),
    isRead: json['is_read'] as bool,
  );
}

class AnnouncementPageData {
  final List<Announcement> items;
  final int total;
  final int unreadCount;

  const AnnouncementPageData(this.items, this.total, this.unreadCount);

  factory AnnouncementPageData.fromJson(Map<String, dynamic> json) =>
      AnnouncementPageData(
        (json['items'] as List)
            .map(
              (value) => Announcement.fromJson(value as Map<String, dynamic>),
            )
            .toList(),
        json['total'] as int,
        json['unread_count'] as int,
      );
}
