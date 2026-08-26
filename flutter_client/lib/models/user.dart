class User {
  final int id;
  final String username;
  final String email;
  final bool emailVerified;
  final String? display_name;
  final String? signature;
  final String? avatarPath;
  final bool qqBound;
  final String? qqNickname;
  final String? qqAvatarUrl;
  final DateTime? qqBoundAt;
  final bool isOnline;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.emailVerified = false,
    this.display_name,
    this.signature,
    this.avatarPath,
    this.qqBound = false,
    this.qqNickname,
    this.qqAvatarUrl,
    this.qqBoundAt,
    this.isOnline = false,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String,
      emailVerified:
          (json['email_verified'] ?? json['emailVerified']) as bool? ?? false,
      display_name: (json['display_name'] ?? json['displayName']) as String?,
      signature: json['signature'] as String?,
      avatarPath: (json['avatar_path'] ?? json['avatarPath']) as String?,
      qqBound: (json['qq_bound'] ?? json['qqBound']) as bool? ?? false,
      qqNickname: (json['qq_nickname'] ?? json['qqNickname']) as String?,
      qqAvatarUrl: (json['qq_avatar_url'] ?? json['qqAvatarUrl']) as String?,
      qqBoundAt: (json['qq_bound_at'] ?? json['qqBoundAt']) != null
          ? DateTime.parse((json['qq_bound_at'] ?? json['qqBoundAt']) as String)
          : null,
      isOnline: (json['is_online'] ?? json['isOnline']) as bool? ?? false,
      lastLoginAt: (json['last_login_at'] ?? json['lastLoginAt']) != null
          ? DateTime.parse(
              (json['last_login_at'] ?? json['lastLoginAt']) as String,
            )
          : null,
      createdAt: DateTime.parse(
        (json['created_at'] ?? json['createdAt']) as String,
      ),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['updatedAt']) as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'email_verified': emailVerified,
      'display_name': display_name,
      'signature': signature,
      'avatar_path': avatarPath,
      'qq_bound': qqBound,
      'qq_nickname': qqNickname,
      'qq_avatar_url': qqAvatarUrl,
      'qq_bound_at': qqBoundAt?.toIso8601String(),
      'is_online': isOnline,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    bool? emailVerified,
    String? display_name,
    String? signature,
    String? avatarPath,
    bool? qqBound,
    String? qqNickname,
    String? qqAvatarUrl,
    DateTime? qqBoundAt,
    bool? isOnline,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      display_name: display_name ?? this.display_name,
      signature: signature ?? this.signature,
      avatarPath: avatarPath ?? this.avatarPath,
      qqBound: qqBound ?? this.qqBound,
      qqNickname: qqNickname ?? this.qqNickname,
      qqAvatarUrl: qqAvatarUrl ?? this.qqAvatarUrl,
      qqBoundAt: qqBoundAt ?? this.qqBoundAt,
      isOnline: isOnline ?? this.isOnline,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
