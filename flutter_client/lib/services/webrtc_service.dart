import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'signalr_service.dart';

class WebRTCService extends ChangeNotifier {
  final SignalRService _signalRService;
  
  // WebRTC 状态
  bool _isInitialized = false;
  Call? _currentCall;
  bool _isInCall = false;
  String? _localStreamId;
  String? _remoteStreamId;
  
  // 回调函数
  Function(Call)? onIncomingCall;
  Function(Call)? onCallAccepted;
  Function(Call)? onCallRejected;
  Function(Call)? onCallEnded;
  Function(String)? onConnectionEstablished;
  Function(String)? onConnectionLost;
  Function(String)? onError;

  WebRTCService(this._signalRService) {
    _setupSignalRHandlers();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  Call? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  String? get localStreamId => _localStreamId;
  String? get remoteStreamId => _remoteStreamId;

  // 初始化WebRTC服务
  Future<void> initialize(String token) async {
    try {
      await _signalRService.connect(token);
      _isInitialized = true;
      notifyListeners();
      print('✅ WebRTC服务初始化成功');
    } catch (e) {
      print('❌ WebRTC服务初始化失败: $e');
      onError?.call('WebRTC服务初始化失败: $e');
    }
  }

  // 设置SignalR事件处理器
  void _setupSignalRHandlers() {
    _signalRService.onIncomingCall = (call) {
      _currentCall = call;
      onIncomingCall?.call(call);
      notifyListeners();
    };

    _signalRService.onCallAccepted = (callId) {
      if (_currentCall != null) {
        _isInCall = true;
        onCallAccepted?.call(_currentCall!);
        notifyListeners();
      }
    };

    _signalRService.onCallRejected = (callId) {
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
    };

    _signalRService.onCallEnded = (callId) {
      _currentCall = null;
      _isInCall = false;
      _localStreamId = null;
      _remoteStreamId = null;
      notifyListeners();
    };
  }

  // 处理WebRTC信令消息
  void _handleWebRTCMessage(Map<String, dynamic> messageData) {
    try {
      final messageType = messageData['type'] as String;
      final callId = messageData['callId'] as String;
      final data = messageData['data'] as String;

      switch (messageType) {
        case 'Offer':
          _handleOffer(callId, data);
          break;
        case 'Answer':
          _handleAnswer(callId, data);
          break;
        case 'IceCandidate':
          _handleIceCandidate(callId, data);
          break;
        default:
          print('⚠️ 未知的WebRTC消息类型: $messageType');
      }
    } catch (e) {
      print('❌ 处理WebRTC消息失败: $e');
      onError?.call('处理WebRTC消息失败: $e');
    }
  }

  // 处理Offer
  void _handleOffer(String callId, String offer) {
    print('📥 收到Offer: $callId');
    // TODO: 实现WebRTC Offer处理
    // 这里需要与具体的WebRTC实现集成
  }

  // 处理Answer
  void _handleAnswer(String callId, String answer) {
    print('📥 收到Answer: $callId');
    // TODO: 实现WebRTC Answer处理
  }

  // 处理ICE候选
  void _handleIceCandidate(String callId, String candidate) {
    print('📥 收到ICE候选: $callId');
    // TODO: 实现ICE候选处理
  }

  // 发起通话
  Future<void> initiateCall(User receiver, CallType callType) async {
    try {
      if (!_isInitialized) {
        throw Exception('WebRTC服务未初始化');
      }

      // 通过SignalR发起通话
      await _signalRService.initiateCall(InitiateCallRequest(
        receiverId: receiver.id,
        callType: callType,
      ));

      print('📞 发起通话: ${receiver.username}');
    } catch (e) {
      print('❌ 发起通话失败: $e');
      onError?.call('发起通话失败: $e');
      rethrow;
    }
  }

  // 应答通话
  Future<void> answerCall(String callId, bool accept) async {
    try {
      if (!_isInitialized) {
        throw Exception('WebRTC服务未初始化');
      }

      // 通过SignalR应答通话
      await _signalRService.answerCall(AnswerCallRequest(
        callId: callId,
        accept: accept,
      ));

      if (accept) {
        _isInCall = true;
      } else {
        _currentCall = null;
        _isInCall = false;
      }
      notifyListeners();

      print('📞 ${accept ? "应答" : "拒绝"}通话: $callId');
    } catch (e) {
      print('❌ 应答通话失败: $e');
      onError?.call('应答通话失败: $e');
      rethrow;
    }
  }

  // 结束通话
  Future<void> endCall() async {
    try {
      if (_currentCall == null) return;

      final callId = _currentCall!.callId;

      // 通过SignalR结束通话
      await _signalRService.endCall(callId);

      _currentCall = null;
      _isInCall = false;
      _localStreamId = null;
      _remoteStreamId = null;
      notifyListeners();

      print('📞 结束通话: $callId');
    } catch (e) {
      print('❌ 结束通话失败: $e');
      onError?.call('结束通话失败: $e');
      rethrow;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      await _signalRService.disconnect();
      _isInitialized = false;
      _currentCall = null;
      _isInCall = false;
      _localStreamId = null;
      _remoteStreamId = null;
      notifyListeners();
      print('🔌 WebRTC服务已断开连接');
    } catch (e) {
      print('❌ 断开连接失败: $e');
      onError?.call('断开连接失败: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
