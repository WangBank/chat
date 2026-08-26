import 'package:flutter_test/flutter_test.dart';

import 'package:chat/config/app_config.dart';
import 'package:chat/models/user.dart';

void main() {
  test('user retains the server email verification status', () {
    final user = User.fromJson({
      'id': 7,
      'username': 'test-user',
      'email': 'user@example.com',
      'email_verified': true,
      'created_at': '2026-08-26T00:00:00.000Z',
      'updated_at': '2026-08-26T00:00:00.000Z',
    });

    expect(user.emailVerified, isTrue);
    expect(user.toJson()['email_verified'], isTrue);
    expect(user.copyWith(emailVerified: false).emailVerified, isFalse);
  });

  test('media URLs keep absolute URLs and resolve chat attachments against server', () {
    expect(
      AppConfig.resolveMediaUrl('/chat-files/20260826/voice.m4a'),
      'https://chat.wangbank.top/chat-files/20260826/voice.m4a',
    );
    expect(
      AppConfig.resolveMediaUrl('https://cdn.example.test/voice.weba'),
      'https://cdn.example.test/voice.weba',
    );
  });
}
