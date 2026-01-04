class User {
  final int id;
  final String username;
  final String email;
  final String? display_name;
  final String? avatarPath;
  final bool isOnline;
  final DateTime? lastLoginAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.display_name,
    this.avatarPath,
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
      display_name: json['display_name'] as String?,
      avatarPath: json['avatar_path'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] != null 
          ? DateTime.parse(json['last_login_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'display_name': display_name,
      'avatar_path': avatarPath,
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
    String? display_name,
    String? avatarPath,
    bool? isOnline,
    DateTime? lastLoginAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      display_name: display_name ?? this.display_name,
      avatarPath: avatarPath ?? this.avatarPath,
      isOnline: isOnline ?? this.isOnline,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
