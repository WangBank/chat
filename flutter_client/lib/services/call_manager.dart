import 'package:flutter/foundation.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'webrtc_service.dart';

class CallManager extends ChangeNotifier {
  final WebRTCService _webRTCService;
  
  Call? _currentCall;
  bool _isInCall = false;
  User? _currentUser;

  CallManager(this._webRTCService) {
    _setupWebRTCHandlers();
  }

  // Getters
  Call? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  User? get currentUser => _currentUser;

  // 设置WebRTC事件处理器
  void _setupWebRTCHandlers() {
    _webRTCService.onIncomingCall = (call) {
      _currentCall = call;
      _isInCall = true;
      notifyListeners();
      print('📞 收到来电: ${call.caller.username}');
    };

    _webRTCService.onCallAccepted = (call) {
      _currentCall = call;
      _isInCall = true;
      notifyListeners();
      print('📞 通话被接受: ${call.callId}');
    };

    _webRTCService.onCallRejected = (call) {
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      print('📞 通话被拒绝: ${call.callId}');
    };

    _webRTCService.onCallEnded = (call) {
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      print('📞 通话结束: ${call.callId}');
    };

    _webRTCService.onError = (error) {
      print('❌ WebRTC错误: $error');
    };
  }

  // 初始化
  Future<void> initialize(String token, User user) async {
    try {
      _currentUser = user;
      await _webRTCService.initialize(token);
      print('✅ CallManager初始化成功');
    } catch (e) {
      print('❌ CallManager初始化失败: $e');
      rethrow;
    }
  }

  // 发起通话
  Future<void> initiateCall(User receiver, CallType callType) async {
    try {
      await _webRTCService.initiateCall(receiver, callType);
      print('📞 发起通话: ${receiver.username}');
    } catch (e) {
      print('❌ 发起通话失败: $e');
      rethrow;
    }
  }

  // 应答通话
  Future<void> answerCall(String callId, bool accept) async {
    try {
      await _webRTCService.answerCall(callId, accept);
      print('📞 ${accept ? "应答" : "拒绝"}通话: $callId');
    } catch (e) {
      print('❌ 应答通话失败: $e');
      rethrow;
    }
  }

  // 结束通话
  Future<void> endCall() async {
    try {
      await _webRTCService.endCall();
      print('📞 结束通话');
    } catch (e) {
      print('❌ 结束通话失败: $e');
      rethrow;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      await _webRTCService.disconnect();
      _currentCall = null;
      _isInCall = false;
      _currentUser = null;
      notifyListeners();
      print('🔌 CallManager已断开连接');
    } catch (e) {
      print('❌ 断开连接失败: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
