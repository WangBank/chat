import 'package:signalr_netcore/signalr_client.dart';
import '../models/call.dart';
import '../config/app_config.dart';

typedef OnIncomingCallCallback = void Function(Call call);
typedef OnCallAcceptedCallback = void Function(String callId);
typedef OnCallRejectedCallback = void Function(String callId);
typedef OnCallEndedCallback = void Function(String callId);
typedef OnOfferReceivedCallback = void Function(String callId, String offer, int senderId);
typedef OnAnswerReceivedCallback = void Function(String callId, String answer, int senderId);
typedef OnIceCandidateReceivedCallback = void Function(String callId, String candidate, int senderId);

class SignalRService {
  static String get hubUrl => AppConfig.signalRUrl;
  
  HubConnection? _connection;
  
  // 回调函数
  OnIncomingCallCallback? onIncomingCall;
  OnCallAcceptedCallback? onCallAccepted;
  OnCallRejectedCallback? onCallRejected;
  OnCallEndedCallback? onCallEnded;
  OnOfferReceivedCallback? onOfferReceived;
  OnAnswerReceivedCallback? onAnswerReceived;
  OnIceCandidateReceivedCallback? onIceCandidateReceived;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  // 连接到SignalR Hub
  Future<void> connect(String token) async {
    if (_connection != null && isConnected) {
      print('SignalR already connected');
      return;
    }

    try {
      _connection = HubConnectionBuilder()
          .withUrl(hubUrl, options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ))
          .withAutomaticReconnect()
          .build();

      // 设置事件监听器
      _setupEventListeners();

      await _connection!.start();
      print('SignalR connected successfully');
    } catch (e) {
      print('SignalR connection failed: $e');
      throw Exception('SignalR连接失败: $e');
    }
  }

  // 用户认证
  Future<void> authenticate(int userId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('Authenticate', args: [userId]);
      print('User authenticated: $userId');
    } catch (e) {
      print('Error authenticating user: $e');
      throw Exception('用户认证失败: $e');
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
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        print('Call ended: $callId');
        onCallEnded?.call(callId);
      } catch (e) {
        print('Error parsing call ended: $e');
      }
    });

    // 接收WebRTC消息
    _connection!.on('WebRTCMessage', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        final type = data['type'] as String;
        final messageData = data['data'] as String;
        final senderId = data['sender_id'] as int;
        
        print('Received WebRTC message for call: $callId, type: $type');
        
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
  Future<void> sendWebRTCMessage(String callId, String type, String data, int receiverId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      final message = {
        'call_id': callId,
        'type': type,
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
  Future<void> sendIceCandidate(WebRTCCandidate candidate, int receiverId) async {
    await sendWebRTCMessage(candidate.callId, 'IceCandidate', candidate.candidate, receiverId);
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
      if (_connection != null) {
        await _connection!.stop();
        _connection = null;
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
  }
}
