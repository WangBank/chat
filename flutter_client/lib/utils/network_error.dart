import 'dart:async';
import 'dart:io';

/// 用户不需要知道服务器地址、端口或底层连接异常，统一使用这条提示。
const serviceMaintenanceMessage = '服务正在维护，请稍后重试';

bool isServiceUnavailableStatusCode(int statusCode) {
  return statusCode == 408 || statusCode >= 500;
}

bool isServiceUnavailableError(Object? error) {
  if (error == null) return false;
  if (error is SocketException || error is TimeoutException) return true;

  final message = error.toString().toLowerCase();
  const indicators = [
    'socketexception',
    'timeoutexception',
    'connection refused',
    'connection reset',
    'connection closed',
    'failed host lookup',
    'network is unreachable',
    'network unreachable',
    'no route to host',
    'signalr连接失败',
    'signalr未连接',
    '恢复signalr在线状态失败',
    'websocket',
    'service unavailable',
    'statuscode: 503',
  ];
  return indicators.any(message.contains);
}

String userFacingServiceError(
  Object? error, {
  String fallback = '请求失败',
}) {
  if (isServiceUnavailableError(error)) return serviceMaintenanceMessage;

  var message = error?.toString().trim() ?? '';
  var changed = true;
  while (changed) {
    final next = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Error:\s*'), '')
        .trim();
    changed = next != message;
    message = next;
  }
  return message.isEmpty ? fallback : message;
}
