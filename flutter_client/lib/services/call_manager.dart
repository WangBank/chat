import 'package:flutter/foundation.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'webrtc_video_service.dart';

class CallManager extends ChangeNotifier {
  final WebRTCVideoService _webRTCService;
  
  Call? _currentCall;
  bool _isInCall = false;
  bool _isWaitingForAnswer = false; // 等待对方接听
  User? _currentUser;

  CallManager(this._webRTCService) {
    _setupWebRTCHandlers();
  }

  // Getters
  Call? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  bool get isWaitingForAnswer => _isWaitingForAnswer;
  User? get currentUser => _currentUser;
  WebRTCVideoService get webRTCService => _webRTCService;

  // 设置WebRTC事件处理器
  void _setupWebRTCHandlers() {
    _webRTCService.onIncomingCall = (call) {
      _currentCall = call;
      _isInCall = false; // 收到来电时，还没有接听，所以不是通话中
      notifyListeners();
      print('📞 收到来电: ${call.caller.username}');
    };

    _webRTCService.onCallAccepted = (call) {
      print('📞 收到通话接受事件: ${call.callId}');
      
      // 更新当前通话信息
      _currentCall = call;
      _isInCall = true;
      _isWaitingForAnswer = false;
      
      print('📞 状态更新: isInCall=$_isInCall, isWaitingForAnswer=$_isWaitingForAnswer');
      notifyListeners();
      print('📞 通话被接受: ${call.callId}');
    };

    _webRTCService.onCallRejected = (call) {
      print('📞 通话被拒绝: ${call.callId}');
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
    };

    _webRTCService.onCallEnded = (call) {
      print('📞 通话结束: ${call.callId}');
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
    };

    _webRTCService.onError = (error) {
      print('❌ WebRTC错误: $error');
    };
  }

  // 初始化
  Future<void> initialize(String token, User user) async {
    try {
      _currentUser = user;
      await _webRTCService.initialize(token, user.id);
      print('✅ CallManager初始化成功');
    } catch (e) {
      print('❌ CallManager初始化失败: $e');
      rethrow;
    }
  }

  // 发起通话
  Future<void> initiateCall(User receiver, CallType callType) async {
    try {
      print('📞 开始发起通话: ${receiver.username}');
      
      // 先发起通话，等待后端返回callId
      await _webRTCService.initiateCall(receiver, callType);
      
      // 发起成功后，设置等待状态
      _isWaitingForAnswer = true;
      _currentCall = Call(
        callId: 'temp_${DateTime.now().millisecondsSinceEpoch}', // 临时ID
        caller: _currentUser!,
        receiver: receiver,
        callType: callType,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );
      notifyListeners();
      
      print('📞 发起通话成功: ${receiver.username}');
    } catch (e) {
      _isWaitingForAnswer = false;
      _currentCall = null;
      notifyListeners();
      print('❌ 发起通话失败: $e');
      rethrow;
    }
  }

  // 应答通话
  Future<void> answerCall(String callId, bool accept) async {
    try {
      print('📞 开始${accept ? "应答" : "拒绝"}通话: $callId');
      await _webRTCService.answerCall(callId, accept);
      print('📞 ${accept ? "应答" : "拒绝"}通话成功: $callId');
      
      // 立即更新本地状态
      if (accept) {
        _isInCall = true;
        _isWaitingForAnswer = false;
        print('📞 通话已接听，状态更新为通话中');
      } else {
        _currentCall = null;
        _isInCall = false;
        _isWaitingForAnswer = false;
        print('📞 通话已拒绝，状态已重置');
      }
      notifyListeners();
    } catch (e) {
      print('❌ 应答通话失败: $e');
      rethrow;
    }
  }

  // 结束通话
  Future<void> endCall() async {
    try {
      await _webRTCService.endCall();
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
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
      _isWaitingForAnswer = false;
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
