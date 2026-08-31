import 'dart:async';
import 'dart:io';

import 'package:chat/utils/network_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection failures use the maintenance message', () {
    expect(
        isServiceUnavailableError(const SocketException('Connection refused')),
        isTrue);
    expect(isServiceUnavailableError(TimeoutException('timed out')), isTrue);
    expect(
      userFacingServiceError(Exception('SignalR连接失败: Connection refused')),
      serviceMaintenanceMessage,
    );
  });

  test('service error status codes are recognized', () {
    expect(isServiceUnavailableStatusCode(408), isTrue);
    expect(isServiceUnavailableStatusCode(503), isTrue);
    expect(isServiceUnavailableStatusCode(500), isTrue);
    expect(isServiceUnavailableStatusCode(400), isFalse);
  });
}
