import 'package:signalr_netcore/signalr_client.dart';
import '../models/call.dart';
import '../models/chat_message.dart';
import '../config/app_config.dart';
import 'dart:async';
import 'dart:convert';

typedef OnIncomingCallCallback = void Function(Call call);
typedef OnCallAcceptedCallback = void Function(String callId);
typedef OnCallRejectedCallback = void Function(String callId);
typedef OnCallEndedCallback = void Function(String callId);
typedef OnOfferReceivedCallback = void Function(
    String callId, String offer, int senderId);
typedef OnAnswerReceivedCallback = void Function(
    String callId, String answer, int senderId);
typedef OnIceCandidateReceivedCallback = void Function(
    String callId, String candidate, int senderId);
typedef OnNewMessageCallback = void Function(ChatMessage message);
typedef OnUserOnlineStatusChangedCallback = void Function(
    int userId, bool isOnline);

class SignalRService {
  static String get hubUrl => AppConfig.signalRUrl;

  HubConnection? _connection;
  int? _currentUserId; // 当前用户ID（用于日志）
  String? _lastToken;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _heartbeatInFlight = false;
  bool _reconnectInFlight = false;
  bool _manualDisconnect = false;

  // 回调函数
  OnIncomingCallCallback? onIncomingCall;
  OnCallAcceptedCallback? onCallAccepted;
  OnCallRejectedCallback? onCallRejected;
  OnCallEndedCallback? onCallEnded;
  OnOfferReceivedCallback? onOfferReceived;
  OnAnswerReceivedCallback? onAnswerReceived;
  OnIceCandidateReceivedCallback? onIceCandidateReceived;
  OnNewMessageCallback? onNewMessage;
  final Set<OnUserOnlineStatusChangedCallback> _onlineStatusListeners = {};

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  void addOnlineStatusListener(OnUserOnlineStatusChangedCallback listener) {
    _onlineStatusListeners.add(listener);
  }

  void removeOnlineStatusListener(OnUserOnlineStatusChangedCallback listener) {
    _onlineStatusListeners.remove(listener);
  }

  // 连接到SignalR Hub
  Future<void> connect(String token) async {
    _lastToken = token;
    _manualDisconnect = false;

    if (_connection != null && isConnected) {
      print('SignalR already connected');
      return;
    }

    try {
      _stopReconnectTimer();
      _stopHeartbeat();

      final previousConnection = _connection;
      if (previousConnection != null) {
        _connection = null;
        try {
          await previousConnection.stop();
        } catch (e) {
          print('停止旧SignalR连接失败: $e');
        }
      }

      final connection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
            ),
          )
          .withAutomaticReconnect()
          .build();

      _connection = connection;

      // 重连后重新登记当前连接，服务端身份来自 JWT。
      connection.onreconnecting(({Exception? error}) {
        print('🔄 SignalR正在重连: $error');
      });
      connection.onreconnected(({String? connectionId}) {
        print(
          '✅ SignalR重连成功: connectionId=$connectionId, 当前用户=$_currentUserId',
        );
        final uid = _currentUserId;
        if (uid != null) {
          authenticate(uid).then((_) {
            print('🔐 重连后已重新认证用户: $uid');
          }).catchError((e) {
            print('❌ 重连后重新认证失败: $e');
          });
        } else {
          print('⚠️ 重连后无法重新认证：当前用户ID为空');
        }
      });
      connection.onclose(({Exception? error}) {
        print('🛑 SignalR连接关闭: $error');
        _stopHeartbeat();
        if (!_manualDisconnect && identical(_connection, connection)) {
          _scheduleReconnect();
        }
      });

      // 设置事件监听器
      _setupEventListeners();

      await connection.start();
      print('SignalR connected successfully');
    } catch (e) {
      _connection = null;
      print('SignalR connection failed: $e');
      throw Exception('SignalR连接失败: $e');
    }
  }

  Future<void> ensureConnectedAndAuthenticated(String token, int userId) async {
    _lastToken = token;
    _currentUserId = userId;
    _manualDisconnect = false;

    if (!isConnected) {
      await connect(token);
    }

    await authenticate(userId);
  }

  // 用户认证
  Future<void> authenticate(int userId) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      await _connection!.invoke('Authenticate');
      _currentUserId = userId;
      _startHeartbeat();
      print('User authenticated: $userId');
    } catch (e) {
      print('Error authenticating user: $e');
      throw Exception('用户认证失败: $e');
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _sendHeartbeat();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatInFlight = false;
  }

  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnect() {
    if (_manualDisconnect || _reconnectTimer != null || _reconnectInFlight) {
      return;
    }

    final token = _lastToken;
    final userId = _currentUserId;
    if (token == null || token.isEmpty || userId == null) {
      print('⚠️ SignalR无法自动重连：缺少token或用户ID');
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      _reconnectTimer = null;
      if (_manualDisconnect || isConnected || _reconnectInFlight) {
        return;
      }

      _reconnectInFlight = true;
      var shouldRetry = false;
      try {
        print('🔄 SignalR尝试自动恢复连接: user=$userId');
        await connect(token);
        await authenticate(userId);
        print('✅ SignalR自动恢复成功: user=$userId');
      } catch (e) {
        print('❌ SignalR自动恢复失败: $e');
        shouldRetry = !_manualDisconnect;
      } finally {
        _reconnectInFlight = false;
        if (shouldRetry) {
          _scheduleReconnect();
        }
      }
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!isConnected || _heartbeatInFlight || _connection == null) {
      return;
    }

    _heartbeatInFlight = true;
    try {
      await _connection!.invoke('Heartbeat');
    } catch (e) {
      print('SignalR heartbeat failed: $e');
    } finally {
      _heartbeatInFlight = false;
    }
  }

  // 设置事件监听器
  void _setupEventListeners() {
    if (_connection == null) return;

    // 接收来电
    _connection!.on('IncomingCall', (arguments) {
      print('IncomingCall: $arguments');
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final call = Call.fromJson(data);
        print('Incoming call from: ${call.caller.username}');
        onIncomingCall?.call(call);
      } catch (e) {
        print('Error parsing incoming call: $e');
      }
    });

    // 通话被接受
    _connection!.on('CallAccepted', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        print('Call accepted: $callId');
        onCallAccepted?.call(callId);
      } catch (e) {
        print('Error parsing call accepted: $e');
      }
    });

    // 通话被拒绝
    _connection!.on('CallRejected', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        print('Call rejected: $callId');
        onCallRejected?.call(callId);
      } catch (e) {
        print('Error parsing call rejected: $e');
      }
    });

    // 通话结束
    _connection!.on('CallEnded', (arguments) {
      print('CallEnded 11: $arguments');
      try {
        final dynamic arg0 = arguments?[0];

        String? callId;
        int? endedBy;

        Map<String, dynamic>? dataMap;
        if (arg0 is Map) {
          dataMap = Map<String, dynamic>.from(arg0);
        } else if (arg0 is String) {
          dataMap = Map<String, dynamic>.from(jsonDecode(arg0) as Map);
        }

        if (dataMap != null) {
          callId = dataMap['call_id'] as String?;
          final dynamic endedRaw =
              dataMap['endedBy'] ?? dataMap['EndedBy'] ?? dataMap['ended_by'];
          if (endedRaw is int) {
            endedBy = endedRaw;
          } else if (endedRaw is num) {
            endedBy = endedRaw.toInt();
          } else if (endedRaw is String) {
            endedBy = int.tryParse(endedRaw);
          }
        }

        print(
          '📨 CallEnded事件: call_id=$callId, current_user=$_currentUserId, ended_by=$endedBy, raw=$arg0',
        );

        if (callId != null) {
          onCallEnded?.call(callId);
        } else {
          print('⚠️ CallEnded负载缺少call_id，无法触发回调');
        }
      } catch (e) {
        print('❌ 解析CallEnded事件失败: $e, arguments=$arguments');
      }
    });

    // 接收WebRTC消息
    _connection!.on('WebRTCMessage', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;

        final dynamic typeVal = data['type'];
        final String type = typeVal is String
            ? typeVal
            : _webRTCTypeIntToString((typeVal as num).toInt());

        final messageData = data['data'] as String;
        final senderId = data['sender_id'] as int;

        print(
          'Received WebRTC message: call=$callId, type=$type, sender_id=$senderId, current_user=$_currentUserId',
        );

        switch (type) {
          case 'Offer':
            onOfferReceived?.call(callId, messageData, senderId);
            break;
          case 'Answer':
            onAnswerReceived?.call(callId, messageData, senderId);
            break;
          case 'IceCandidate':
            onIceCandidateReceived?.call(callId, messageData, senderId);
            break;
          default:
            print('Unknown WebRTC message type: $type');
        }
      } catch (e) {
        print('Error parsing WebRTC message: $e');
      }
    });

    // 接收新消息
    _connection!.on('NewMessage', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        print('Received new message: $data');

        final message = ChatMessage.fromJson(data);
        onNewMessage?.call(message);
      } catch (e) {
        print('Error parsing new message: $e');
      }
    });

    // 接收用户在线状态变化
    _connection!.on('UserOnlineStatusChanged', (arguments) {
      try {
        final dynamic arg0 = arguments?[0];
        Map<String, dynamic>? dataMap;
        if (arg0 is Map) {
          dataMap = Map<String, dynamic>.from(arg0);
        } else if (arg0 is String) {
          dataMap = Map<String, dynamic>.from(jsonDecode(arg0) as Map);
        }

        if (dataMap == null) return;

        final dynamic userIdRaw = dataMap['user_id'] ?? dataMap['userId'];
        final dynamic onlineRaw = dataMap['is_online'] ?? dataMap['isOnline'];
        final int? userId = userIdRaw is int
            ? userIdRaw
            : userIdRaw is num
                ? userIdRaw.toInt()
                : int.tryParse(userIdRaw?.toString() ?? '');
        final bool? isOnline = onlineRaw is bool
            ? onlineRaw
            : onlineRaw is String
                ? onlineRaw.toLowerCase() == 'true'
                : null;

        if (userId == null || isOnline == null) return;

        print('👤 在线状态变化: user_id=$userId, is_online=$isOnline');
        for (final listener in List<OnUserOnlineStatusChangedCallback>.from(
          _onlineStatusListeners,
        )) {
          listener(userId, isOnline);
        }
      } catch (e) {
        print('Error parsing online status: $e');
      }
    });
  }

  // 发起通话
  Future<void> initiateCall(InitiateCallRequest request) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      final requestData = request.toJson();
      print('📤 发送InitiateCall请求: $requestData');
      await _connection!.invoke('InitiateCall', args: [requestData]);
      print('✅ Call initiated to user: ${request.receiverId}');
    } catch (e) {
      print('❌ Error initiating call: $e');
      throw Exception('发起通话失败: $e');
    }
  }

  // 应答通话
  Future<void> answerCall(AnswerCallRequest request) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      await _connection!.invoke('AnswerCall', args: [request.toJson()]);
      print('Call answered: ${request.callId}, accepted: ${request.accept}');
    } catch (e) {
      print('Error answering call: $e');
      throw Exception('应答通话失败: $e');
    }
  }

  // 结束通话
  Future<void> endCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      await _connection!.invoke('EndCall', args: [callId]);
      print('Call ended: $callId');
    } catch (e) {
      print('Error ending call: $e');
      throw Exception('结束通话失败: $e');
    }
  }

  // 发送WebRTC消息
  Future<void> sendWebRTCMessage(
    String callId,
    String type,
    String data,
    int receiverId,
  ) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      final message = {
        'call_id': callId,
        // 用枚举数值发送，满足后端的绑定要求
        'type': _webRTCTypeToInt(type),
        'data': data,
        'receiver_id': receiverId,
      };
      await _connection!.invoke('SendWebRTCMessage', args: [message]);
      print('WebRTC message sent for call: $callId, type: $type');
    } catch (e) {
      print('Error sending WebRTC message: $e');
      throw Exception('发送WebRTC消息失败: $e');
    }
  }

  // 发送WebRTC Offer
  Future<void> sendOffer(WebRTCOffer offer, int receiverId) async {
    await sendWebRTCMessage(offer.callId, 'Offer', offer.offer, receiverId);
  }

  // 发送WebRTC Answer
  Future<void> sendAnswer(WebRTCAnswer answer, int receiverId) async {
    await sendWebRTCMessage(answer.callId, 'Answer', answer.answer, receiverId);
  }

  // 发送ICE Candidate
  Future<void> sendIceCandidate(
    WebRTCCandidate candidate,
    int receiverId,
  ) async {
    await sendWebRTCMessage(
      candidate.callId,
      'IceCandidate',
      candidate.candidate,
      receiverId,
    );
  }

  // 加入通话
  Future<void> joinCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      await _connection!.invoke('JoinCall', args: [callId]);
      print('Joined call: $callId');
    } catch (e) {
      print('Error joining call: $e');
      throw Exception('加入通话失败: $e');
    }
  }

  // 离开通话
  Future<void> leaveCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');

    try {
      await _connection!.invoke('LeaveCall', args: [callId]);
      print('Left call: $callId');
    } catch (e) {
      print('Error leaving call: $e');
      throw Exception('离开通话失败: $e');
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      _manualDisconnect = true;
      _stopReconnectTimer();
      _stopHeartbeat();
      final connection = _connection;
      _connection = null;
      _currentUserId = null;
      _lastToken = null;
      if (connection != null) {
        await connection.stop();
        print('SignalR disconnected');
      }
    } catch (e) {
      print('Error disconnecting SignalR: $e');
    }
  }

  // 清理资源
  void dispose() {
    disconnect();
    onIncomingCall = null;
    onCallAccepted = null;
    onCallRejected = null;
    onCallEnded = null;
    onOfferReceived = null;
    onAnswerReceived = null;
    onIceCandidateReceived = null;
    onNewMessage = null;
  }

  int _webRTCTypeToInt(String type) {
    switch (type) {
      case 'Offer':
        return 0;
      case 'Answer':
        return 1;
      case 'IceCandidate':
        return 2;
      case 'CallRequest':
        return 3;
      case 'CallResponse':
        return 4;
      case 'CallEnd':
        return 5;
      default:
        return 0;
    }
  }

  String _webRTCTypeIntToString(int value) {
    switch (value) {
      case 0:
        return 'Offer';
      case 1:
        return 'Answer';
      case 2:
        return 'IceCandidate';
      case 3:
        return 'CallRequest';
      case 4:
        return 'CallResponse';
      case 5:
        return 'CallEnd';
      default:
        return 'Offer';
    }
  }
}
