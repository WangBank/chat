import 'user.dart';

class FriendRequest {
  final int id;
  final User requester;
  final User receiver;
  final String? note;
  final String source;
  final String status;
  final String direction;
  final DateTime createdAt;
  final DateTime updatedAt;

  FriendRequest({
    required this.id,
    required this.requester,
    required this.receiver,
    this.note,
    required this.source,
    required this.status,
    required this.direction,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updated_at'] ?? json['updatedAt'];
    return FriendRequest(
      id: json['id'] as int,
      requester: User.fromJson(json['requester'] as Map<String, dynamic>),
      receiver: User.fromJson(json['receiver'] as Map<String, dynamic>),
      note: json['note'] as String?,
      source: json['source'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      direction: json['direction'] as String? ?? 'outgoing',
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']) as String,
      ),
      updatedAt: updatedAtValue != null
          ? DateTime.parse(updatedAtValue as String)
          : DateTime.parse((json['created_at'] ?? json['createdAt']) as String),
    );
  }

  User get peer => direction == 'incoming' ? requester : receiver;
  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}
