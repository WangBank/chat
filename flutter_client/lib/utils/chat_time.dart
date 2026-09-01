/// Formats a conversation-list timestamp in the device's local time zone.
///
/// The API stores timestamps as UTC. Keeping the conversion here prevents the
/// chat list from comparing UTC values to `DateTime.now()` (local time), which
/// otherwise makes a just-completed call appear several hours old on phones in
/// China and other non-UTC time zones.
String formatConversationTime(DateTime timestamp, {DateTime? now}) {
  final localTimestamp = timestamp.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final difference = localNow.difference(localTimestamp);

  if (difference.isNegative || difference.inMinutes <= 0) {
    return '刚刚';
  }
  if (difference.inDays > 0) {
    return '${difference.inDays}天前';
  }
  if (difference.inHours > 0) {
    return '${difference.inHours}小时前';
  }
  return '${difference.inMinutes}分钟前';
}
