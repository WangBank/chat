import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/call.dart';
import '../models/user.dart';
import '../utils/webrtc_debug.dart';
import 'signalr_service.dart';

class WebRTCVideoService extends ChangeNotifier {
  final SignalRService _signalRService;
  
  // WebRTC 状态
  bool _isInitialized = false;
  Call? _currentCall;
  bool _isInCall = false;
  User? _currentUser;
  
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
  RTCVideoRenderer? get localRenderer {
    try {
      return _localRenderer;
    } catch (e) {
      print('⚠️ 获取本地渲染器失败: $e');
      return null;
    }
  }
  
  RTCVideoRenderer? get remoteRenderer {
    try {
      return _remoteRenderer;
    } catch (e) {
      print('⚠️ 获取远程渲染器失败: $e');
      return null;
    }
  }
  SignalRService get signalRService => _signalRService;

  // 初始化视频渲染器
  Future<void> _initializeRenderers() async {
    try {
      // 确保先释放旧的渲染器
      await _disposeRenderers();
      
      _localRenderer = await WebRTCDebug.safeCreateRenderer('本地渲染器');
      _remoteRenderer = await WebRTCDebug.safeCreateRenderer('远程渲染器');
      
      if (_localRenderer == null || _remoteRenderer == null) {
        throw Exception('渲染器创建失败');
      }
      
      print('✅ 视频渲染器初始化成功');
    } catch (e) {
      print('❌ 视频渲染器初始化失败: $e');
      await _disposeRenderers();
      rethrow;
    }
  }

  // 释放视频渲染器
  Future<void> _disposeRenderers() async {
    try {
      // 立即清除引用
      final localRenderer = _localRenderer;
      final remoteRenderer = _remoteRenderer;
      _localRenderer = null;
      _remoteRenderer = null;
      
      // 异步释放渲染器
      WebRTCDebug.safeDisposeRenderer('本地渲染器', localRenderer);
      WebRTCDebug.safeDisposeRenderer('远程渲染器', remoteRenderer);
      
      print('✅ 视频渲染器释放完成');
    } catch (e) {
      print('❌ 视频渲染器释放失败: $e');
    }
  }

  // 初始化WebRTC服务
  Future<void> initialize(String token, User user) async {
    try {
      _currentUser = user;
      await _signalRService.connect(token);
      await _signalRService.authenticate(user.id);
      
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

  // 确保渲染器已初始化
  Future<void> _ensureRenderersInitialized() async {
    if (_localRenderer == null || _remoteRenderer == null) {
      await _initializeRenderers();
    }
    
    // 记录渲染器状态用于调试
    WebRTCDebug.logRendererState('本地渲染器', _localRenderer);
    WebRTCDebug.logRendererState('远程渲染器', _remoteRenderer);
  }

  // 设置SignalR事件处理器
  void _setupSignalRHandlers() {
    _signalRService.onIncomingCall = (call) {
      _currentCall = call;
      onIncomingCall?.call(call);
      notifyListeners();
    };

    _signalRService.onCallAccepted = (callId) {
      print('📞 WebRTCService收到通话接受事件: $callId');
      print('📞 WebRTCService当前状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall');
      
      if (_currentCall != null) {
        _isInCall = true;
        
        // 立即更新当前通话的callId为真实的callId
        _currentCall = Call(
          callId: callId,
          caller: _currentCall!.caller,
          receiver: _currentCall!.receiver,
          callType: _currentCall!.callType,
          status: CallStatus.inProgress,
          startTime: _currentCall!.startTime,
        );
        
        print('📞 WebRTCService更新后状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall');
        print('📞 WebRTCService准备调用onCallAccepted回调');
        
        // 立即通知CallManager状态变化
        onCallAccepted?.call(_currentCall!);
        notifyListeners();
        
        print('📞 WebRTCService已调用onCallAccepted和notifyListeners');
        
        // 然后启动视频通话
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
      } else {
        print('⚠️ WebRTCService: _currentCall为null，无法处理通话接受事件');
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
      print('📞 通话结束事件处理完成');
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
    } else {
      print('⚠️ 没有本地流，跳过添加本地轨道（模拟器环境）');
    }

    // 监听远程流
    pc.onTrack = (RTCTrackEvent event) {
      print('📹 收到远程视频流');
      _remoteStream = event.streams[0];
      _safeSetRendererSrcObject(_remoteRenderer, _remoteStream);
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
        // 在模拟器环境中，允许没有权限的情况下继续
        print('⚠️ 权限被拒绝，但在模拟器环境中允许继续');
        return null;
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
      
      // 在模拟器环境中，允许没有媒体流的情况下继续
      print('⚠️ 无法获取媒体流，但在模拟器环境中允许继续');
      return null;
    }
  }

  // 安全地设置渲染器的srcObject
  void _safeSetRendererSrcObject(RTCVideoRenderer? renderer, MediaStream? stream) {
    try {
      if (renderer != null) {
        // 先清除旧的srcObject
        if (renderer.srcObject != null && stream == null) {
          renderer.srcObject = null;
          // 给一点时间让渲染器清理
          Future.delayed(const Duration(milliseconds: 50), () {
            try {
              renderer.srcObject = stream;
                        } catch (e) {
              print('⚠️ 延迟设置渲染器srcObject失败: $e');
            }
          });
        } else {
          renderer.srcObject = stream;
        }
      }
    } catch (e) {
      print('⚠️ 设置渲染器srcObject失败: $e');
    }
  }

  // 开始视频通话
  Future<void> _startVideoCall() async {
    try {
      print('📹 开始视频通话');
      
      // 确保渲染器已初始化
      await _ensureRenderersInitialized();
      
      // 如果还没有本地流，才获取媒体流
      if (_localStream == null) {
        _localStream = await _getUserMedia();
        if (_localStream != null) {
          _safeSetRendererSrcObject(_localRenderer, _localStream);
        } else {
          print('⚠️ 无法获取媒体流，但允许继续（模拟器环境）');
        }
      }
      
      // 创建PeerConnection
      _peerConnection = await _createPeerConnection();
      
      notifyListeners();
      print('✅ 视频通话初始化成功');
    } catch (e) {
      print('❌ 视频通话初始化失败: $e');
      // 清理资源
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _safeSetRendererSrcObject(_localRenderer, null);
      
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
      
      // 关闭远程流
      _remoteStream = null;
      
      // 关闭PeerConnection
      await _peerConnection?.close();
      _peerConnection = null;
      
      // 清空渲染器内容，但不释放渲染器本身
      _safeSetRendererSrcObject(_localRenderer, null);
      _safeSetRendererSrcObject(_remoteRenderer, null);
      
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

      // 先获取本地媒体流，用于等待页面显示
      print('📹 发起通话时获取本地视频流...');
      
      // 确保渲染器已初始化
      await _ensureRenderersInitialized();
      
      _localStream = await _getUserMedia();
      if (_localStream != null) {
        _safeSetRendererSrcObject(_localRenderer, _localStream);
        notifyListeners();
        print('✅ 本地视频流已获取，可用于等待页面显示');
      } else {
        print('⚠️ 无法获取本地视频流，但允许继续（模拟器环境）');
        notifyListeners();
      }

      // 通过SignalR发起通话
      await _signalRService.initiateCall(InitiateCallRequest(
        receiverId: receiver.id,
        callType: callType,
      ));

      // 设置当前通话状态（临时ID，等待后端返回真实ID）
      _currentCall = Call(
        callId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        caller: _currentUser!,
        receiver: receiver,
        callType: callType,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );

      print('📞 发起通话: ${receiver.username}');
      print('📞 WebRTCService: 设置临时通话ID: ${_currentCall!.callId}');
    } catch (e) {
      print('❌ 发起通话失败: $e');
      // 清理已获取的媒体流
      _localStream?.getTracks().forEach((track) => track.stop());
      _localStream = null;
      _safeSetRendererSrcObject(_localRenderer, null);
      notifyListeners();
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
        
        // 更新当前通话的callId
        if (_currentCall != null) {
          _currentCall = Call(
            callId: callId,
            caller: _currentCall!.caller,
            receiver: _currentCall!.receiver,
            callType: _currentCall!.callType,
            status: CallStatus.inProgress,
            startTime: _currentCall!.startTime,
          );
        }
        
        await _startVideoCall();
        
        // 被叫方接听后，通知CallManager状态变化
        if (_currentCall != null) {
          onCallAccepted?.call(_currentCall!);
        }
        
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
    _disposeRenderers();
    disconnect();
    super.dispose();
  }
}
