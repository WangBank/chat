import 'package:flutter_test/flutter_test.dart';

import 'package:chat/config/app_config.dart';
import 'package:chat/models/call.dart';
import 'package:chat/models/user.dart';
import 'package:chat/utils/chat_time.dart';

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

  test(
      'media URLs keep absolute URLs and resolve chat attachments against server',
      () {
    expect(
      AppConfig.resolveMediaUrl('/chat-files/20260826/voice.m4a'),
      'https://chat.wangbank.top/chat-files/20260826/voice.m4a',
    );
    expect(
      AppConfig.resolveMediaUrl('https://cdn.example.test/voice.weba'),
      'https://cdn.example.test/voice.weba',
    );
  });

  test('call history keeps the backend call type and time contract', () {
    final call = Call.fromJson({
      'call_id': 'call-123',
      'caller': {
        'id': 7,
        'username': 'caller',
        'email': 'caller@example.com',
        'created_at': '2026-08-31T00:00:00.000Z',
        'updated_at': '2026-08-31T00:00:00.000Z',
      },
      'receiver': {
        'id': 8,
        'username': 'receiver',
        'email': 'receiver@example.com',
        'created_at': '2026-08-31T00:00:00.000Z',
        'updated_at': '2026-08-31T00:00:00.000Z',
      },
      'call_type': 1,
      'status': 6,
      'start_time': '2026-08-31T01:02:03.000Z',
      'end_time': '2026-08-31T01:04:03.000Z',
      'duration': 120,
    });

    expect(call.callId, 'call-123');
    expect(call.callType, CallType.voice);
    expect(call.status, CallStatus.ended);
    expect(call.startTime.toUtc(), DateTime.utc(2026, 8, 31, 1, 2, 3));
    expect(call.endTime?.toUtc(), DateTime.utc(2026, 8, 31, 1, 4, 3));
    expect(call.duration, 120);
  });

  test('conversation timestamps are compared in the device local time zone', () {
    final callStartedAt = DateTime.utc(2026, 9, 1, 1, 0);
    final deviceNow = callStartedAt.toLocal().add(const Duration(minutes: 5));

    expect(
      formatConversationTime(callStartedAt, now: deviceNow),
      '5分钟前',
    );
  });
}
