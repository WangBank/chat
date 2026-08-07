class ReplyMessageSnapshot {
  final int? id;
  final String senderName;
  final String content;
  final MessageType type;
  final String? filePath;

  ReplyMessageSnapshot({
    this.id,
    required this.senderName,
    required this.content,
    required this.type,
    this.filePath,
  });

  factory ReplyMessageSnapshot.fromJson(Map<String, dynamic> json) {
    return ReplyMessageSnapshot(
      id: (json['id'] as num?)?.toInt(),
      senderName: json['sender_name'] as String? ?? '未知用户',
      content: json['content'] as String? ?? '',
      type: ChatMessage._parseMessageType(json['type']),
      filePath: json['file_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_name': senderName,
      'content': content,
      'type': type.toString().split('.').last,
      'file_path': filePath,
    };
  }
}

class ChatMessage {
  final String id;
  final int senderId;
  final int receiverId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? filePath;
  final int? fileSize;
  final int? duration;
  final int? replyToMessageId;
  final ReplyMessageSnapshot? replyTo;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.filePath,
    this.fileSize,
    this.duration,
    this.replyToMessageId,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final replyToJson = json['reply_to'];
    return ChatMessage(
      id: json['id'].toString(), // 后端返回的是 int，但 Flutter 期望 String
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      content: json['content'] as String,
      type: _parseMessageType(json['type']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      filePath: json['file_path'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      duration: (json['duration'] as num?)?.toInt(),
      replyToMessageId: (json['reply_to_message_id'] as num?)?.toInt(),
      replyTo: replyToJson is Map
          ? ReplyMessageSnapshot.fromJson(
              Map<String, dynamic>.from(replyToJson),
            )
          : null,
    );
  }

  // 解析MessageType的辅助方法
  static MessageType _parseMessageType(dynamic typeValue) {
    if (typeValue == null) return MessageType.text;

    String typeStr = typeValue.toString().toLowerCase();
    switch (typeStr) {
      case 'text':
      case '1':
        return MessageType.text;
      case 'image':
      case '2':
        return MessageType.image;
      case 'video':
      case '3':
        return MessageType.video;
      case 'audio':
      case '4':
        return MessageType.audio;
      case 'file':
      case '5':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'file_path': filePath,
      'file_size': fileSize,
      'duration': duration,
      'reply_to_message_id': replyToMessageId,
      'reply_to': replyTo?.toJson(),
    };
  }

  ChatMessage copyWith({
    String? id,
    int? senderId,
    int? receiverId,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    String? filePath,
    int? fileSize,
    int? duration,
    int? replyToMessageId,
    ReplyMessageSnapshot? replyTo,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}

enum MessageType { text, image, video, audio, file }
