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
    // 在构造函数中不设置处理器，等待initialize时设置
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
      _isWaitingForAnswer = false; // 被叫方不是等待状态
      notifyListeners();
      print('📞 收到来电: ${call.caller.username}');
    };

    _webRTCService.onCallAccepted = (call) {
      print('📞 CallManager收到通话接受事件: ${call.callId}');
      print('📞 当前状态: isInCall=$_isInCall, isWaitingForAnswer=$_isWaitingForAnswer');
      
      // 更新当前通话信息
      _currentCall = call;
      _isInCall = true;
      _isWaitingForAnswer = false;
      
      print('📞 状态更新后: isInCall=$_isInCall, isWaitingForAnswer=$_isWaitingForAnswer');
      print('📞 准备通知监听器...');
      notifyListeners();
      print('📞 监听器已通知，通话被接受: ${call.callId}');
      
      // 强制触发状态更新，确保页面跳转
      Future.delayed(const Duration(milliseconds: 100), () {
        print('📞 强制触发状态更新 1');
        notifyListeners();
      });
      
      // 再次延迟触发，确保页面跳转
      Future.delayed(const Duration(milliseconds: 300), () {
        print('📞 强制触发状态更新 2');
        notifyListeners();
      });
    };

    _webRTCService.onCallRejected = (call) {
      print('📞 通话被拒绝: ${call.callId}');
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
    };

    _webRTCService.onCallEnded = (call) {
      print('📞 通话结束: ${call.callId}, current_user=${_currentUser?.id}/${_currentUser?.username}, prev_isInCall=$_isInCall, prev_isWaitingForAnswer=$_isWaitingForAnswer');
      // 无论当前状态如何，都重置所有状态
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
      print('📞 通话状态已重置: current_call=${_currentCall?.callId}, isInCall=$_isInCall, isWaitingForAnswer=$_isWaitingForAnswer');
      
      // 强制触发状态更新
      Future.delayed(const Duration(milliseconds: 100), () {
        print('📞 通话状态强制刷新(100ms): user=${_currentUser?.id}');
        notifyListeners();
      });
      
      // 再次延迟触发，确保页面关闭
      Future.delayed(const Duration(milliseconds: 300), () {
        print('📞 通话状态强制刷新(300ms): user=${_currentUser?.id}');
        notifyListeners();
      });
    };

    _webRTCService.onError = (error) {
      print('❌ WebRTC错误: $error');
    };
  }

  // 初始化
  Future<void> initialize(String token, User user) async {
    try {
      _currentUser = user;
      await _webRTCService.initialize(token, user);
      
      // 在WebRTCService初始化后设置处理器
      _setupWebRTCHandlers();
      
      // 验证回调是否正确设置
      print('🔍 CallManager: 验证回调设置');
      print('🔍 onCallAccepted回调: ${_webRTCService.onCallAccepted != null ? "已设置" : "未设置"}');
      print('🔍 onCallRejected回调: ${_webRTCService.onCallRejected != null ? "已设置" : "未设置"}');
      print('🔍 onCallEnded回调: ${_webRTCService.onCallEnded != null ? "已设置" : "未设置"}');
      
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
      print('📞 开始结束通话');
      await _webRTCService.endCall();
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
      print('📞 结束通话成功');
      
      // 强制触发状态更新
      Future.delayed(const Duration(milliseconds: 100), () {
        notifyListeners();
      });
    } catch (e) {
      print('❌ 结束通话失败: $e');
      // 即使失败也要重置状态
      _currentCall = null;
      _isInCall = false;
      _isWaitingForAnswer = false;
      notifyListeners();
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
