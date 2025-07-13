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

  // 设置事件监听器
  void _setupEventListeners() {
    if (_connection == null) return;

    // 接收来电
    _connection!.on('IncomingCall', (arguments) {
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
        final callId = data['CallId'] as String;
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
        final callId = data['CallId'] as String;
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
        final callId = data['CallId'] as String;
        print('Call ended: $callId');
        onCallEnded?.call(callId);
      } catch (e) {
        print('Error parsing call ended: $e');
      }
    });

    // 接收WebRTC Offer
    _connection!.on('ReceiveOffer', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['CallId'] as String;
        final offer = data['Offer'] as String;
        final senderId = data['SenderId'] as int;
        print('Received offer for call: $callId');
        onOfferReceived?.call(callId, offer, senderId);
      } catch (e) {
        print('Error parsing offer: $e');
      }
    });

    // 接收WebRTC Answer
    _connection!.on('ReceiveAnswer', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['CallId'] as String;
        final answer = data['Answer'] as String;
        final senderId = data['SenderId'] as int;
        print('Received answer for call: $callId');
        onAnswerReceived?.call(callId, answer, senderId);
      } catch (e) {
        print('Error parsing answer: $e');
      }
    });

    // 接收ICE Candidate
    _connection!.on('ReceiveIceCandidate', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['CallId'] as String;
        final candidate = data['Candidate'] as String;
        final senderId = data['SenderId'] as int;
        print('Received ICE candidate for call: $callId');
        onIceCandidateReceived?.call(callId, candidate, senderId);
      } catch (e) {
        print('Error parsing ICE candidate: $e');
      }
    });
  }

  // 发起通话
  Future<void> initiateCall(InitiateCallRequest request) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('InitiateCall', args: [request.toJson()]);
      print('Call initiated to user: ${request.receiverId}');
    } catch (e) {
      print('Error initiating call: $e');
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

  // 发送WebRTC Offer
  Future<void> sendOffer(WebRTCOffer offer) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('SendOffer', args: [offer.toJson()]);
      print('Offer sent for call: ${offer.callId}');
    } catch (e) {
      print('Error sending offer: $e');
      throw Exception('发送Offer失败: $e');
    }
  }

  // 发送WebRTC Answer
  Future<void> sendAnswer(WebRTCAnswer answer) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('SendAnswer', args: [answer.toJson()]);
      print('Answer sent for call: ${answer.callId}');
    } catch (e) {
      print('Error sending answer: $e');
      throw Exception('发送Answer失败: $e');
    }
  }

  // 发送ICE Candidate
  Future<void> sendIceCandidate(WebRTCCandidate candidate) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('SendIceCandidate', args: [candidate.toJson()]);
      print('ICE candidate sent for call: ${candidate.callId}');
    } catch (e) {
      print('Error sending ICE candidate: $e');
      throw Exception('发送ICE候选失败: $e');
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
