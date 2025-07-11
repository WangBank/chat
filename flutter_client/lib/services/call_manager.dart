import 'package:flutter/material.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'signalr_service.dart';
import 'webrtc_service.dart';

enum CallState {
  idle,
  initiating,
  ringing,
  connecting,
  connected,
  ending,
}

class CallManager extends ChangeNotifier {
  final ApiService _apiService;
  final SignalRService _signalRService;
  late final WebRTCService _webRTCService;

  CallState _callState = CallState.idle;
  Call? _currentCall;
  String? _errorMessage;

  CallManager(this._apiService, this._signalRService) {
    _webRTCService = WebRTCService(_signalRService);
    _initializeServices();
  }

  // Getters
  CallState get callState => _callState;
  Call? get currentCall => _currentCall;
  String? get errorMessage => _errorMessage;
  WebRTCService get webRTCService => _webRTCService;
  bool get isInCall => _callState != CallState.idle;

  // 初始化服务
  Future<void> _initializeServices() async {
    await _webRTCService.initialize();
    
    // 设置SignalR回调
    _signalRService.onIncomingCall = _handleIncomingCall;
    _signalRService.onCallAccepted = _handleCallAccepted;
    _signalRService.onCallRejected = _handleCallRejected;
    _signalRService.onCallEnded = _handleCallEnded;

    // 设置WebRTC回调
    _webRTCService.onConnectionEstablished = _handleConnectionEstablished;
    _webRTCService.onConnectionLost = _handleConnectionLost;
  }

  // 发起通话
  Future<void> initiateCall(User receiver, CallType callType) async {
    try {
      _setCallState(CallState.initiating);
      _errorMessage = null;

      // 通过SignalR发起通话
      await _signalRService.initiateCall(InitiateCallRequest(
        receiverId: receiver.id,
        callType: callType,
      ));

      // 创建本地通话对象
      _currentCall = Call(
        callId: DateTime.now().millisecondsSinceEpoch.toString(),
        caller: _apiService.currentUser!,
        receiver: receiver,
        callType: callType,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );

      _setCallState(CallState.ringing);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _setCallState(CallState.idle);
      notifyListeners();
    }
  }

  // 应答通话
  Future<void> answerCall(bool accept) async {
    if (_currentCall == null) return;

    try {
      await _signalRService.answerCall(AnswerCallRequest(
        callId: _currentCall!.callId,
        accept: accept,
      ));

      if (accept) {
        _setCallState(CallState.connecting);
        await _webRTCService.answerCall(_currentCall!.callId, _currentCall!.callType);
      } else {
        await _endCallInternal();
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      await _endCallInternal();
      notifyListeners();
    }
  }

  // 结束通话
  Future<void> endCall() async {
    if (_currentCall == null) return;

    try {
      _setCallState(CallState.ending);
      await _signalRService.endCall(_currentCall!.callId);
      await _endCallInternal();
    } catch (e) {
      _errorMessage = e.toString();
      await _endCallInternal();
    }
  }

  // 内部结束通话逻辑
  Future<void> _endCallInternal() async {
    await _webRTCService.endCall();
    _currentCall = null;
    _setCallState(CallState.idle);
    notifyListeners();
  }

  // 处理来电
  void _handleIncomingCall(Call call) {
    _currentCall = call;
    _setCallState(CallState.ringing);
    notifyListeners();
  }

  // 处理通话被接受
  void _handleCallAccepted(String callId) async {
    if (_currentCall?.callId != callId) return;

    try {
      _setCallState(CallState.connecting);
      await _webRTCService.initiateCall(callId, _currentCall!.callType);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      await _endCallInternal();
    }
  }

  // 处理通话被拒绝
  void _handleCallRejected(String callId) async {
    if (_currentCall?.callId != callId) return;
    await _endCallInternal();
  }

  // 处理通话结束
  void _handleCallEnded(String callId) async {
    if (_currentCall?.callId != callId) return;
    await _endCallInternal();
  }

  // 处理WebRTC连接建立
  void _handleConnectionEstablished() {
    _setCallState(CallState.connected);
    notifyListeners();
  }

  // 处理WebRTC连接丢失
  void _handleConnectionLost() async {
    if (_callState == CallState.connected) {
      await endCall();
    }
  }

  // 设置通话状态
  void _setCallState(CallState state) {
    _callState = state;
  }

  // 切换摄像头
  Future<void> switchCamera() async {
    await _webRTCService.switchCamera();
  }

  // 切换麦克风
  void toggleMicrophone() {
    _webRTCService.toggleMicrophone();
  }

  // 切换摄像头开关
  void toggleCamera() {
    _webRTCService.toggleCamera();
  }

  // 清理错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    super.dispose();
  }
}
