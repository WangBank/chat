import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call.dart';
import '../models/user.dart';
import 'signalr_service.dart';

class WebRTCVideoService extends ChangeNotifier {
  final SignalRService _signalRService;
  
  // WebRTC 状态
  bool _isInitialized = false;
  Call? _currentCall;
  bool _isInCall = false;
  
  // WebRTC 连接
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // 视频渲染器
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  
  // 回调函数
  Function(Call)? onIncomingCall;
  Function(Call)? onCallAccepted;
  Function(Call)? onCallRejected;
  Function(Call)? onCallEnded;
  Function(String)? onConnectionEstablished;
  Function(String)? onConnectionLost;
  Function(String)? onError;

  WebRTCVideoService(this._signalRService) {
    _setupSignalRHandlers();
    _initializeRenderers();
  }

  // Getters
  bool get isInitialized => _isInitialized;
  Call? get currentCall => _currentCall;
  bool get isInCall => _isInCall;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCVideoRenderer? get localRenderer => _localRenderer;
  RTCVideoRenderer? get remoteRenderer => _remoteRenderer;
  SignalRService get signalRService => _signalRService;

  // 初始化视频渲染器
  Future<void> _initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();
  }

  // 初始化WebRTC服务
  Future<void> initialize(String token, int userId) async {
    try {
      await _signalRService.connect(token);
      await _signalRService.authenticate(userId);
      
      // 预检查媒体权限
      try {
        print('🔍 预检查媒体权限...');
        final testConstraints = {
          'audio': true,
          'video': false,
        };
        final testStream = await navigator.mediaDevices.getUserMedia(testConstraints);
        testStream.getTracks().forEach((track) => track.stop());
        print('✅ 媒体权限检查通过');
      } catch (e) {
        print('⚠️ 媒体权限检查失败: $e');
        // 不阻止初始化，但记录警告
      }
      
      _isInitialized = true;
      notifyListeners();
      print('✅ WebRTC视频服务初始化成功');
    } catch (e) {
      print('❌ WebRTC视频服务初始化失败: $e');
      onError?.call('WebRTC视频服务初始化失败: $e');
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
      print('📞 收到通话接受事件: $callId');
      if (_currentCall != null) {
        _isInCall = true;
        _startVideoCall().then((_) {
          // 主叫方接听后创建Offer
          if (_peerConnection != null) {
            _peerConnection!.createOffer().then((offer) {
              _peerConnection!.setLocalDescription(offer).then((_) {
                _signalRService.sendOffer(
                  WebRTCOffer(
                    callId: callId,
                    offer: jsonEncode(offer.toMap()),
                  ),
                  _currentCall!.receiver.id,
                );
                print('📤 主叫方已发送Offer');
              });
            });
          }
        });
        // 更新当前通话的callId为真实的callId
        _currentCall = Call(
          callId: callId,
          caller: _currentCall!.caller,
          receiver: _currentCall!.receiver,
          callType: _currentCall!.callType,
          status: CallStatus.inProgress,
          startTime: _currentCall!.startTime,
        );
        onCallAccepted?.call(_currentCall!);
        notifyListeners();
      }
    };

    _signalRService.onCallRejected = (callId) {
      print('📞 收到通话拒绝事件: $callId');
      _endVideoCall();
      final call = _currentCall;
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      if (call != null) {
        onCallRejected?.call(call);
      }
    };

    _signalRService.onCallEnded = (callId) {
      print('📞 收到通话结束事件: $callId');
      _endVideoCall();
      final call = _currentCall;
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      if (call != null) {
        onCallEnded?.call(call);
      }
    };

    // 处理WebRTC信令消息
    _signalRService.onOfferReceived = (callId, offer, senderId) {
      print('📥 收到Offer: $callId');
      _handleOffer(callId, offer, senderId);
    };

    _signalRService.onAnswerReceived = (callId, answer, senderId) {
      print('📥 收到Answer: $callId');
      _handleAnswer(callId, answer, senderId);
    };

    _signalRService.onIceCandidateReceived = (callId, candidate, senderId) {
      print('📥 收到ICE候选: $callId');
      _handleIceCandidate(callId, candidate, senderId);
    };
  }

  // 创建PeerConnection
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };

    final constraints = {
      'mandatory': {
        'OfferToReceiveAudio': true,
        'OfferToReceiveVideo': true,
      },
      'optional': [],
    };

    final pc = await createPeerConnection(configuration, constraints);
    
    // 添加本地流
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // 监听远程流
    pc.onTrack = (RTCTrackEvent event) {
      print('📹 收到远程视频流');
      _remoteStream = event.streams[0];
      _remoteRenderer?.srcObject = _remoteStream;
      notifyListeners();
    };

    // 监听ICE候选
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      print('📤 发送ICE候选');
      if (_currentCall != null) {
        _signalRService.sendIceCandidate(
          WebRTCCandidate(
            callId: _currentCall!.callId,
            candidate: jsonEncode(candidate.toMap()),
          ),
          _currentCall!.receiver.id,
        );
      }
    };

    // 监听连接状态
    pc.onConnectionState = (RTCPeerConnectionState state) {
      print('🔗 连接状态变化: $state');
      if (_currentCall != null) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          onConnectionEstablished?.call(_currentCall!.callId);
        } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          onConnectionLost?.call(_currentCall!.callId);
        }
      }
    };

    return pc;
  }

  // 请求权限
  Future<bool> _requestPermissions() async {
    try {
      print('🔐 请求摄像头和麦克风权限...');
      
      // 请求摄像头权限
      final cameraStatus = await Permission.camera.request();
      print('📷 摄像头权限状态: $cameraStatus');
      
      // 请求麦克风权限
      final microphoneStatus = await Permission.microphone.request();
      print('🎤 麦克风权限状态: $microphoneStatus');
      
      // 检查权限状态
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        print('✅ 所有权限已授予');
        return true;
      } else if (microphoneStatus.isGranted) {
        print('⚠️ 仅麦克风权限已授予，将使用音频通话');
        return true;
      } else {
        print('❌ 权限被拒绝');
        return false;
      }
    } catch (e) {
      print('❌ 权限请求失败: $e');
      return false;
    }
  }

  // 获取本地媒体流
  Future<MediaStream?> _getUserMedia() async {
    try {
      print('📹 请求摄像头和麦克风权限...');
      
      // 先请求权限
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        throw Exception('摄像头或麦克风权限被拒绝，请在设置中允许应用访问摄像头和麦克风');
      }
      
      final constraints = {
        'audio': true,
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '30',
          },
          'facingMode': 'user',
          'optional': [],
        }
      };

      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      print('✅ 成功获取媒体流');
      return stream;
    } catch (e) {
      print('❌ 获取媒体流失败: $e');
      
      // 如果视频获取失败，尝试只获取音频
      if (e.toString().contains('video') || e.toString().contains('camera')) {
        try {
          print('🔄 尝试仅获取音频流...');
          final audioConstraints = {
            'audio': true,
            'video': false,
          };
          final audioStream = await navigator.mediaDevices.getUserMedia(audioConstraints);
          print('✅ 成功获取音频流');
          return audioStream;
        } catch (audioError) {
          print('❌ 音频流获取也失败: $audioError');
        }
      }
      
      if (e.toString().contains('Permission denied') || e.toString().contains('NotAllowedError')) {
        throw Exception('摄像头或麦克风权限被拒绝，请在设置中允许应用访问摄像头和麦克风');
      } else if (e.toString().contains('NotFoundError') || e.toString().contains('DevicesNotFoundError')) {
        throw Exception('未找到摄像头或麦克风设备');
      } else {
        throw Exception('获取媒体流失败: $e');
      }
    }
  }

  // 开始视频通话
  Future<void> _startVideoCall() async {
    try {
      print('📹 开始视频通话');
      
      // 获取本地媒体流
      _localStream = await _getUserMedia();
      if (_localStream == null) {
        throw Exception('无法获取媒体流');
      }
      
      _localRenderer?.srcObject = _localStream;
      
      // 创建PeerConnection
      _peerConnection = await _createPeerConnection();
      
      notifyListeners();
      print('✅ 视频通话初始化成功');
    } catch (e) {
      print('❌ 视频通话初始化失败: $e');
      // 清理资源
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _localRenderer?.srcObject = null;
      
      onError?.call('视频通话初始化失败: $e');
      rethrow;
    }
  }

  // 结束视频通话
  Future<void> _endVideoCall() async {
    try {
      print('📹 结束视频通话');
      
      // 关闭本地流
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _localRenderer?.srcObject = null;
      
      // 关闭远程流
      _remoteStream = null;
      _remoteRenderer?.srcObject = null;
      
      // 关闭PeerConnection
      await _peerConnection?.close();
      _peerConnection = null;
      
      notifyListeners();
      print('✅ 视频通话结束成功');
    } catch (e) {
      print('❌ 结束视频通话失败: $e');
    }
  }

  // 处理Offer
  Future<void> _handleOffer(String callId, String offer, int senderId) async {
    try {
      if (_peerConnection == null) {
        await _startVideoCall();
      }
      
      final offerDesc = RTCSessionDescription(offer, 'offer');
      await _peerConnection!.setRemoteDescription(offerDesc);
      
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      _signalRService.sendAnswer(
        WebRTCAnswer(
          callId: callId,
          answer: jsonEncode(answer.toMap()),
        ),
        senderId,
      );
      
      print('✅ Offer处理成功');
    } catch (e) {
      print('❌ Offer处理失败: $e');
      onError?.call('Offer处理失败: $e');
    }
  }

  // 处理Answer
  Future<void> _handleAnswer(String callId, String answer, int senderId) async {
    try {
      final answerDesc = RTCSessionDescription(answer, 'answer');
      await _peerConnection!.setRemoteDescription(answerDesc);
      print('✅ Answer处理成功');
    } catch (e) {
      print('❌ Answer处理失败: $e');
      onError?.call('Answer处理失败: $e');
    }
  }

  // 处理ICE候选
  Future<void> _handleIceCandidate(String callId, String candidate, int senderId) async {
    try {
      final candidateMap = jsonDecode(candidate);
      final iceCandidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(iceCandidate);
      print('✅ ICE候选处理成功');
    } catch (e) {
      print('❌ ICE候选处理失败: $e');
      onError?.call('ICE候选处理失败: $e');
    }
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
        await _startVideoCall();
        
        // 被叫方不需要创建Offer，等待主叫方的Offer
        print('📞 已接听通话，等待主叫方发送Offer');
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

      // 结束视频通话
      await _endVideoCall();

      // 通过SignalR结束通话
      await _signalRService.endCall(callId);

      _currentCall = null;
      _isInCall = false;
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
      await _endVideoCall();
      await _signalRService.disconnect();
      _isInitialized = false;
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      print('🔌 WebRTC视频服务已断开连接');
    } catch (e) {
      print('❌ 断开连接失败: $e');
      onError?.call('断开连接失败: $e');
    }
  }

  @override
  void dispose() {
    _endVideoCall();
    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    disconnect();
    super.dispose();
  }
}
