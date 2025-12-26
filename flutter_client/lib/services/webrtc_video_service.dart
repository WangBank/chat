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
  
  // 🔧 防重复处理：记录正在处理的通话结束事件
  final Set<String> _processingCallEnded = {};
  
  // 🔧 防竞态条件：标记是否正在释放摄像头
  bool _isReleasingCamera = false;

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
        final testStream =
            await navigator.mediaDevices.getUserMedia(testConstraints);
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
    _signalRService.onIncomingCall = (Call call) {
      _currentCall = call;
      onIncomingCall?.call(call);
      notifyListeners();

      // 来电侧：立即加入通话组，确保后续能收到 CallEnded 广播
      _signalRService.joinCall(call.callId).then((_) {
        print('🔗 已加入通话组(来电侧): ${call.callId}, user=${_currentUser?.id}');
      }).catchError((e) {
        print('❌ 加入通话组失败(来电侧): $e');
      });
    };

    _signalRService.onCallAccepted = (callId) {
      print('📞 WebRTCService收到通话接受事件: $callId');
      print(
          '📞 WebRTCService当前状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall');

      if (_currentCall != null) {
        _isInCall = true;

        _currentCall = Call(
          callId: callId,
          caller: _currentCall!.caller,
          receiver: _currentCall!.receiver,
          callType: _currentCall!.callType,
          status: CallStatus.inProgress,
          startTime: _currentCall!.startTime,
        );

        print(
            '📞 WebRTCService更新后状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall');
        print('📞 WebRTCService准备调用onCallAccepted回调');

        onCallAccepted?.call(_currentCall!);
        notifyListeners();

        print('📞 WebRTCService已调用onCallAccepted和notifyListeners');

        // 双方：确认加入通话组
        _signalRService.joinCall(callId).then((_) {
          print('🔗 已加入通话组(接受侧): $callId, user=${_currentUser?.id}');
        }).catchError((e) {
          print('❌ 加入通话组失败(接受侧): $e');
        });

        _startVideoCall().then((_) {
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
      print('🔍 [onCallRejected] ========== 开始处理通话拒绝事件 ==========');
      print('🔍 [onCallRejected] callId: $callId');
      print('🔍 [onCallRejected] current_user: ${_currentUser?.id}/${_currentUser?.username}');
      print('🔍 [onCallRejected] _localStream状态: ${_localStream != null ? "存在" : "null"}');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [onCallRejected] _localStream轨道数: ${tracks.length}');
      }
      
      // 🔧 修复：使用立即执行的异步函数，确保摄像头释放完成
      (() async {
        print('🔍 [onCallRejected] 开始异步执行 _endVideoCall()');
        try {
          await _endVideoCall();
          print('🔍 [onCallRejected] _endVideoCall() 执行完成');
        } catch (e, stackTrace) {
          print('❌ [onCallRejected] _endVideoCall() 执行失败: $e');
          print('❌ [onCallRejected] 错误堆栈: $stackTrace');
        }
        
        final call = _currentCall;
        _currentCall = null;
        _isInCall = false;
        notifyListeners();
        
        print('🔍 [onCallRejected] 状态已重置: currentCall=${_currentCall?.callId}, isInCall=$_isInCall');
        print('🔍 [onCallRejected] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}');
        
        if (call != null) {
          onCallRejected?.call(call);
          print('🔍 [onCallRejected] 已触发 onCallRejected 回调');
        } else {
          print('⚠️ [onCallRejected] call 为 null，未触发回调');
        }
        
        try {
          await _signalRService.leaveCall(callId);
          print('🔗 [onCallRejected] 已离开通话组(拒绝): $callId, user=${_currentUser?.id}');
        } catch (e) {
          print('❌ [onCallRejected] 离开通话组失败(拒绝): $e');
        }
        
        print('🔍 [onCallRejected] ========== 通话拒绝事件处理完成 ==========');
      })();
    };

    _signalRService.onCallEnded = (callId) {
      print('🔍 [onCallEnded] ========== 开始处理通话结束事件 ==========');
      print('🔍 [onCallEnded] callId: $callId');
      print('🔍 [onCallEnded] current_user: ${_currentUser?.id}/${_currentUser?.username}');
      print('🔍 [onCallEnded] prev_call: ${_currentCall?.callId}');
      print('🔍 [onCallEnded] prev_isInCall: $_isInCall');
      
      // 🔧 防重复处理：如果已经在处理这个通话的结束事件，直接返回
      if (_processingCallEnded.contains(callId)) {
        print('⚠️ [onCallEnded] 通话 $callId 的结束事件正在处理中，跳过重复处理');
        // 即使跳过，也要确保释放摄像头（可能是重复事件但摄像头仍被占用）
        if (_localStream != null || _peerConnection != null) {
          print('⚠️ [onCallEnded] 检测到仍有资源未释放，强制释放...');
          _endVideoCall().catchError((e) {
            print('❌ [onCallEnded] 强制释放失败: $e');
          });
        }
        return;
      }
      
      // 🔧 关键修复：即使当前通话ID不匹配，如果 _localStream 存在，也要释放
      // 这可能是另一个浏览器/账号的结束事件，但摄像头仍被占用
      final shouldRelease = _currentCall?.callId == callId || 
                           _localStream != null || 
                           _peerConnection != null;
      
      if (!shouldRelease && _currentCall?.callId != callId) {
        print('⚠️ [onCallEnded] 通话ID不匹配（当前: ${_currentCall?.callId}, 事件: $callId），且无资源需要释放，跳过');
        return;
      }
      
      // 标记为正在处理
      _processingCallEnded.add(callId);
      print('🔍 [onCallEnded] 已标记通话 $callId 为处理中');
      
      print('🔍 [onCallEnded] _localStream状态: ${_localStream != null ? "存在" : "null"}');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [onCallEnded] _localStream轨道数: ${tracks.length}');
        for (var track in tracks) {
          print('🔍 [onCallEnded] 轨道: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}');
        }
      }
      print('🔍 [onCallEnded] _peerConnection状态: ${_peerConnection != null ? "存在" : "null"}');
      
      // 🔧 修复：使用立即执行的异步函数，确保摄像头释放完成
      (() async {
        print('🔍 [onCallEnded] 开始异步执行 _endVideoCall()');
        try {
          // 🔧 关键：无论通话ID是否匹配，都要释放摄像头
          await _endVideoCall();
          print('🔍 [onCallEnded] _endVideoCall() 执行完成');
        } catch (e, stackTrace) {
          print('❌ [onCallEnded] _endVideoCall() 执行失败: $e');
          print('❌ [onCallEnded] 错误堆栈: $stackTrace');
        }
        
        // 只有在通话ID匹配时才更新状态
        if (_currentCall?.callId == callId) {
          final call = _currentCall;
          _currentCall = null;
          _isInCall = false;
          notifyListeners();
          
          print('🔍 [onCallEnded] 状态已重置: currentCall=${_currentCall?.callId}, isInCall=$_isInCall');
          
          if (call != null) {
            onCallEnded?.call(call);
            print('🔍 [onCallEnded] 已触发 onCallEnded 回调');
          } else {
            print('⚠️ [onCallEnded] call 为 null，未触发回调');
          }
        } else {
          print('⚠️ [onCallEnded] 通话ID不匹配，仅释放资源，不更新状态');
        }
        
        print('🔍 [onCallEnded] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}');
        print('🔍 [onCallEnded] 通话结束事件处理完成');
        
        try {
          await _signalRService.leaveCall(callId);
          print('🔗 [onCallEnded] 已离开通话组(被动结束): $callId, user=${_currentUser?.id}');
        } catch (e) {
          print('❌ [onCallEnded] 离开通话组失败(被动结束): $e');
        }
        
        // 移除处理标记（延迟移除，确保不会立即重复处理）
        Future.delayed(const Duration(seconds: 2), () {
          _processingCallEnded.remove(callId);
          print('🔍 [onCallEnded] 已移除通话 $callId 的处理标记');
        });
        
        print('🔍 [onCallEnded] ========== 通话结束事件处理完成 ==========');
      })();
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
        } else if (state ==
            RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
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
      print('🔍 [_getUserMedia] 当前用户: ${_currentUser?.id}/${_currentUser?.username}');

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

      print('🔍 [_getUserMedia] 开始调用 getUserMedia...');
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      print('✅ [_getUserMedia] 成功获取媒体流');
      final tracks = stream.getTracks();
      print('🔍 [_getUserMedia] 获取到的轨道数: ${tracks.length}');
      for (var track in tracks) {
        print('🔍 [_getUserMedia] 轨道: kind=${track.kind}, id=${track.id}');
      }
      return stream;
    } catch (e) {
      final errorMsg = e.toString();
      print('❌ [_getUserMedia] 获取媒体流失败: $e');
      print('🔍 [_getUserMedia] 错误详情: $errorMsg');
      
      // 检查是否是摄像头被占用（同一台机器上其他浏览器可能正在使用）
      if (errorMsg.contains('NotReadableError') || 
          errorMsg.contains('NotAllowedError') ||
          errorMsg.contains('OverconstrainedError') ||
          errorMsg.contains('device') ||
          errorMsg.contains('busy') ||
          errorMsg.contains('in use')) {
        print('⚠️ [_getUserMedia] 摄像头可能被其他应用或浏览器占用');
        print('💡 提示：如果在同一台机器上使用不同浏览器，请确保另一个浏览器已完全释放摄像头');
      }

      // 如果视频获取失败，尝试只获取音频
      if (errorMsg.contains('video') || errorMsg.contains('camera')) {
        try {
          print('🔄 [_getUserMedia] 尝试仅获取音频流...');
          final audioConstraints = {
            'audio': true,
            'video': false,
          };
          final audioStream =
              await navigator.mediaDevices.getUserMedia(audioConstraints);
          print('✅ [_getUserMedia] 成功获取音频流');
          return audioStream;
        } catch (audioError) {
          print('❌ [_getUserMedia] 音频流获取也失败: $audioError');
        }
      }

      // 在模拟器环境中，允许没有媒体流的情况下继续
      print('⚠️ [_getUserMedia] 无法获取媒体流，但在模拟器环境中允许继续');
      return null;
    }
  }

  // 安全地设置渲染器的srcObject
  void _safeSetRendererSrcObject(
      RTCVideoRenderer? renderer, MediaStream? stream) {
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
    print('🔍 [_startVideoCall] ========== 开始视频通话 ==========');
    print('🔍 [_startVideoCall] call: ${_currentCall?.callId}');
    print('🔍 [_startVideoCall] user: ${_currentUser?.id}/${_currentUser?.username}');
    print('🔍 [_startVideoCall] _isReleasingCamera: $_isReleasingCamera');
    
    // 🔧 防竞态条件：如果正在释放摄像头，等待释放完成
    if (_isReleasingCamera) {
      print('⚠️ [_startVideoCall] 检测到正在释放摄像头，等待释放完成...');
      int waitCount = 0;
      while (_isReleasingCamera && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      if (_isReleasingCamera) {
        print('❌ [_startVideoCall] 等待释放摄像头超时，但继续执行');
      } else {
        print('✅ [_startVideoCall] 摄像头释放完成，继续执行');
      }
    }
    
    try {
      // 确保渲染器已初始化
      print('🔍 [_startVideoCall] 确保渲染器已初始化...');
      await _ensureRenderersInitialized();
      print('🔍 [_startVideoCall] 渲染器初始化完成');

      // 如果还没有本地流，才获取媒体流
      print('🔍 [_startVideoCall] 检查 _localStream: ${_localStream != null ? "已存在" : "null"}');
      if (_localStream == null) {
        print('🔍 [_startVideoCall] 开始获取媒体流...');
        _localStream = await _getUserMedia();
        print('🔍 [_startVideoCall] 获取媒体流结果: ${_localStream != null ? "成功" : "失败"}');
        if (_localStream != null) {
          final tracks = _localStream!.getTracks();
          print('🔍 [_startVideoCall] 获取到的轨道数: ${tracks.length}');
          for (var i = 0; i < tracks.length; i++) {
            final track = tracks[i];
            print('🔍 [_startVideoCall] 轨道[$i]: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}');
          }
          _safeSetRendererSrcObject(_localRenderer, _localStream);
          print('🔍 [_startVideoCall] 已设置本地渲染器');
        } else {
          print('⚠️ [_startVideoCall] 无法获取媒体流，但允许继续（模拟器环境）');
        }
      } else {
        print('⚠️ [_startVideoCall] _localStream 已存在，跳过获取');
        final tracks = _localStream!.getTracks();
        print('🔍 [_startVideoCall] 现有轨道数: ${tracks.length}');
      }

      // 创建PeerConnection
      print('🔍 [_startVideoCall] 开始创建 PeerConnection...');
      _peerConnection = await _createPeerConnection();
      print('🔍 [_startVideoCall] PeerConnection 创建完成');

      notifyListeners();
      print('✅ [_startVideoCall] 视频通话初始化成功');
      print('🔍 [_startVideoCall] ========== 视频通话初始化完成 ==========');
    } catch (e, stackTrace) {
      print('❌ [_startVideoCall] 视频通话初始化失败: $e');
      print('❌ [_startVideoCall] 错误堆栈: $stackTrace');
      // 清理资源
      print('🔍 [_startVideoCall] 开始清理资源...');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [_startVideoCall] 清理 ${tracks.length} 个轨道');
        for (var track in tracks) {
          try {
            track.stop();
            print('🛑 [_startVideoCall] 已停止轨道: ${track.kind}');
          } catch (e) {
            print('❌ [_startVideoCall] 停止轨道失败: $e');
          }
        }
        _localStream = null;
      }
      _safeSetRendererSrcObject(_localRenderer, null);
      print('🔍 [_startVideoCall] 资源清理完成');

      onError?.call('视频通话初始化失败: $e');
      rethrow;
    }
  }

// 结束视频通话
  Future<void> _endVideoCall() async {
    print('🔍 [_endVideoCall] ========== 开始结束视频通话 ==========');
    print('🔍 [_endVideoCall] call: ${_currentCall?.callId}');
    print('🔍 [_endVideoCall] user: ${_currentUser?.id}/${_currentUser?.username}');
    print('🔍 [_endVideoCall] isInCall: $_isInCall');
    print('🔍 [_endVideoCall] _isReleasingCamera: $_isReleasingCamera');
    
    // 🔧 防竞态条件：如果已经在释放，直接返回
    if (_isReleasingCamera) {
      print('⚠️ [_endVideoCall] 已经在释放摄像头，跳过重复释放');
      return;
    }
    
    // 标记为正在释放
    _isReleasingCamera = true;
    print('🔍 [_endVideoCall] 已标记为正在释放摄像头');
    
    try {
      print('🔍 [_endVideoCall] 检查 _localStream: ${_localStream != null ? "存在" : "null"}');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [_endVideoCall] 本地流轨道数: ${tracks.length}');
        for (var i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          print('🔍 [_endVideoCall] 轨道[$i]: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}, muted=${track.muted}');
        }
      } else {
        print('⚠️ [_endVideoCall] _localStream 为 null，可能已经释放或未初始化');
      }
      
      print('🔍 [_endVideoCall] 检查 _peerConnection: ${_peerConnection != null ? "存在" : "null"}');

      // 🔧 修复：先停止所有轨道，然后关闭 PeerConnection
      // 关键：必须先停止轨道，再关闭 PeerConnection，才能确保摄像头被释放
      
      // 第一步：停止本地流的所有轨道（确保释放摄像头）
      print('🔍 [_endVideoCall] 开始处理本地流...');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [_endVideoCall] 准备停止 ${tracks.length} 个本地轨道');
        
        // 保存轨道引用，因为停止后可能无法再获取
        final tracksToStop = List<MediaStreamTrack>.from(tracks);
        
        for (var i = 0; i < tracksToStop.length; i++) {
          final track = tracksToStop[i];
          try {
            print('🔍 [_endVideoCall] 停止本地轨道[$i]: kind=${track.kind}, id=${track.id}');
            // 先禁用轨道
            track.enabled = false;
            // 然后停止轨道
            track.stop();
            print('🛑 [_endVideoCall] 已停止本地轨道[$i]: ${track.kind}, enabled=${track.enabled}');
            
            // 尝试从 MediaStream 中移除轨道（如果支持）
            try {
              _localStream!.removeTrack(track);
              print('🔍 [_endVideoCall] 已从 MediaStream 移除轨道[$i]');
            } catch (e) {
              print('⚠️ [_endVideoCall] 从 MediaStream 移除轨道[$i]失败（可能不支持）: $e');
            }
          } catch (e, stackTrace) {
            print('❌ [_endVideoCall] 停止本地轨道[$i]失败: $e');
            print('❌ [_endVideoCall] 错误堆栈: $stackTrace');
          }
        }
        
        // 确保所有轨道都被移除
        final remainingTracks = _localStream!.getTracks();
        if (remainingTracks.isNotEmpty) {
          print('⚠️ [_endVideoCall] MediaStream 中仍有 ${remainingTracks.length} 个轨道未移除');
          for (var track in remainingTracks) {
            try {
              track.stop();
              print('🛑 [_endVideoCall] 强制停止剩余轨道: ${track.kind}');
            } catch (e) {
              print('❌ [_endVideoCall] 强制停止剩余轨道失败: $e');
            }
          }
        }
        
        // 清空本地流引用
        final streamToDispose = _localStream;
        _localStream = null;
        print('✅ [_endVideoCall] 本地流已释放，_localStream 已设为 null');
        
        // 尝试释放 MediaStream（如果支持 dispose 方法）
        try {
          // 注意：MediaStream 可能没有 dispose 方法，这里只是尝试
          if (streamToDispose != null) {
            // 确保所有轨道都被停止
            for (var track in streamToDispose.getTracks()) {
              try {
                if (track.enabled) {
                  track.enabled = false;
                }
                track.stop();
              } catch (e) {
                // 忽略错误
              }
            }
            print('✅ [_endVideoCall] MediaStream 已彻底清理');
          }
        } catch (e) {
          print('⚠️ [_endVideoCall] 清理 MediaStream 时出错: $e');
        }
      } else {
        print('⚠️ [_endVideoCall] _localStream 为 null，无需释放');
      }

      // 第二步：从 PeerConnection 中停止发送器轨道
      if (_peerConnection != null) {
        try {
          print('🔍 [_endVideoCall] 开始获取发送器...');
          final senders = await _peerConnection!.getSenders();
          print('🔍 [_endVideoCall] 发送器数量: ${senders.length}');
          
          for (var i = 0; i < senders.length; i++) {
            final sender = senders[i];
            print('🔍 [_endVideoCall] 发送器[$i]: track=${sender.track != null ? "存在" : "null"}');
            if (sender.track != null) {
              print('🔍 [_endVideoCall] 发送器[$i]轨道: kind=${sender.track!.kind}, id=${sender.track!.id}');
              try {
                // 先禁用轨道
                sender.track!.enabled = false;
                // 然后停止轨道
                await sender.track!.stop();
                print('🛑 [_endVideoCall] 已停止发送器轨道[$i]: ${sender.track!.kind}');
              } catch (e) {
                print('❌ [_endVideoCall] 停止发送器轨道[$i]失败: $e');
              }
            }
          }
          print('✅ [_endVideoCall] 已停止所有发送器轨道');
        } catch (e, stackTrace) {
          print('❌ [_endVideoCall] 处理发送器时出错: $e');
          print('❌ [_endVideoCall] 错误堆栈: $stackTrace');
        }
      } else {
        print('⚠️ [_endVideoCall] _peerConnection 为 null，跳过发送器处理');
      }

      // 🔧 修复：停止远程流的所有轨道
      print('🔍 [_endVideoCall] 开始处理远程流...');
      if (_remoteStream != null) {
        final tracks = _remoteStream!.getTracks();
        print('🔍 [_endVideoCall] 准备停止 ${tracks.length} 个远程轨道');
        
        for (var track in tracks) {
          try {
            print('🔍 [_endVideoCall] 停止远程轨道: kind=${track.kind}, id=${track.id}');
            track.stop();
            print('🛑 [_endVideoCall] 已停止远程轨道: ${track.kind}');
          } catch (e) {
            print('❌ [_endVideoCall] 停止远程轨道失败: $e');
          }
        }
        
        _remoteStream = null;
        print('✅ [_endVideoCall] 远程流已释放');
      } else {
        print('⚠️ [_endVideoCall] _remoteStream 为 null，无需释放');
      }

      // 第三步：关闭 PeerConnection（在停止所有轨道之后）
      print('🔍 [_endVideoCall] 开始关闭 PeerConnection...');
      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
          _peerConnection = null;
          print('✅ [_endVideoCall] PeerConnection 已关闭');
        } catch (e, stackTrace) {
          print('❌ [_endVideoCall] 关闭 PeerConnection 时出错: $e');
          print('❌ [_endVideoCall] 错误堆栈: $stackTrace');
          _peerConnection = null;
        }
      } else {
        print('⚠️ [_endVideoCall] _peerConnection 为 null，无需关闭');
      }

      // 第四步：彻底清空渲染器（确保没有引用持有摄像头）
      print('🔍 [_endVideoCall] 开始清空渲染器...');
      try {
        // 使用安全方法清空本地渲染器
        _safeSetRendererSrcObject(_localRenderer, null);
        // 直接清空本地渲染器（双重保险）
        if (_localRenderer != null) {
          try {
            _localRenderer!.srcObject = null;
            print('✅ [_endVideoCall] 本地渲染器 srcObject 已清空');
          } catch (e) {
            print('⚠️ [_endVideoCall] 清空本地渲染器 srcObject 失败: $e');
          }
        }
        
        // 使用安全方法清空远程渲染器
        _safeSetRendererSrcObject(_remoteRenderer, null);
        // 直接清空远程渲染器（双重保险）
        if (_remoteRenderer != null) {
          try {
            _remoteRenderer!.srcObject = null;
            print('✅ [_endVideoCall] 远程渲染器 srcObject 已清空');
          } catch (e) {
            print('⚠️ [_endVideoCall] 清空远程渲染器 srcObject 失败: $e');
          }
        }
        print('✅ [_endVideoCall] 渲染器已彻底清空');
      } catch (e) {
        print('❌ [_endVideoCall] 清空渲染器时出错: $e');
      }
      
      // 第五步：等待一段时间，确保系统真正释放摄像头资源
      print('🔍 [_endVideoCall] 等待系统释放摄像头资源（300ms）...');
      await Future.delayed(const Duration(milliseconds: 300));
      print('✅ [_endVideoCall] 等待完成');

      notifyListeners();
      print('✅ [_endVideoCall] 视频通话结束成功: user=${_currentUser?.id}, call_cleared=${_currentCall == null}, isInCall=$_isInCall');
      print('🔍 [_endVideoCall] ========== 结束视频通话完成 ==========');
      
      // 移除释放标记
      _isReleasingCamera = false;
      print('🔍 [_endVideoCall] 已移除释放摄像头标记');
    } catch (e, stackTrace) {
      print('❌ [_endVideoCall] 结束视频通话失败: $e');
      print('❌ [_endVideoCall] 错误堆栈: $stackTrace');
      // 即使出错也要确保清理资源
      print('🔍 [_endVideoCall] 开始错误恢复清理...');
      try {
        if (_localStream != null) {
          final tracks = _localStream!.getTracks();
          print('🔍 [_endVideoCall] 错误恢复：准备停止 ${tracks.length} 个本地轨道');
          for (var track in tracks) {
            try {
              track.stop();
              print('🛑 [_endVideoCall] 错误恢复：已停止本地轨道: ${track.kind}');
            } catch (e) {
              print('❌ [_endVideoCall] 错误恢复：停止本地轨道失败: $e');
            }
          }
          _localStream = null;
          print('✅ [_endVideoCall] 错误恢复：本地流已清理');
        } else {
          print('⚠️ [_endVideoCall] 错误恢复：_localStream 已为 null');
        }
      } catch (e) {
        print('❌ [_endVideoCall] 错误恢复：清理本地流失败: $e');
      }
      
      try {
        if (_remoteStream != null) {
          final tracks = _remoteStream!.getTracks();
          print('🔍 [_endVideoCall] 错误恢复：准备停止 ${tracks.length} 个远程轨道');
          for (var track in tracks) {
            try {
              track.stop();
              print('🛑 [_endVideoCall] 错误恢复：已停止远程轨道: ${track.kind}');
            } catch (e) {
              print('❌ [_endVideoCall] 错误恢复：停止远程轨道失败: $e');
            }
          }
          _remoteStream = null;
          print('✅ [_endVideoCall] 错误恢复：远程流已清理');
        } else {
          print('⚠️ [_endVideoCall] 错误恢复：_remoteStream 已为 null');
        }
      } catch (e) {
        print('❌ [_endVideoCall] 错误恢复：清理远程流失败: $e');
      }
      
      _peerConnection = null;
      print('🔍 [_endVideoCall] ========== 错误恢复完成 ==========');
      
      // 移除释放标记（即使出错也要移除）
      _isReleasingCamera = false;
      print('🔍 [_endVideoCall] 已移除释放摄像头标记（错误恢复后）');
    }
  }

  // 处理Offer
  Future<void> _handleOffer(String callId, String offer, int senderId) async {
    try {
      if (_peerConnection == null) {
        await _startVideoCall();
      }

      // 兼容两种格式：JSON 包含 {"sdp": "..."} 或者纯 SDP 字符串
      String sdp;
      try {
        final decoded = jsonDecode(offer);
        sdp = decoded is Map && decoded['sdp'] is String
            ? decoded['sdp'] as String
            : offer;
      } catch (_) {
        sdp = offer;
      }

      final offerDesc = RTCSessionDescription(sdp, 'offer');
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
      // 兼容两种格式：JSON 包含 {"sdp": "..."} 或者纯 SDP 字符串
      String sdp;
      try {
        final decoded = jsonDecode(answer);
        sdp = decoded is Map && decoded['sdp'] is String
            ? decoded['sdp'] as String
            : answer;
      } catch (_) {
        sdp = answer;
      }

      final answerDesc = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(answerDesc);
      print('✅ Answer处理成功');
    } catch (e) {
      print('❌ Answer处理失败: $e');
      onError?.call('Answer处理失败: $e');
    }
  }

  // 处理ICE候选
  Future<void> _handleIceCandidate(
      String callId, String candidate, int senderId) async {
    try {
      // PeerConnection 未就绪时直接忽略，避免异常
      if (_peerConnection == null) {
        print(
            '⚠️ ICE候选到达但PeerConnection为空，忽略: call=$callId, user=${_currentUser?.id}/${_currentUser?.username}');
        return;
      }

      // 尝试解析 JSON；兼容纯字符串或类型不匹配情况
      dynamic decoded;
      try {
        decoded = jsonDecode(candidate);
      } catch (_) {
        decoded = null;
      }

      String candStr;
      String? sdpMid;
      int? sdpMLineIndex;

      if (decoded is Map) {
        final rawCandidate = decoded['candidate'];
        candStr = rawCandidate is String ? rawCandidate : candidate;

        final rawMid = decoded['sdpMid'];
        sdpMid = rawMid is String ? rawMid : (rawMid?.toString());

        final rawIndex = decoded['sdpMLineIndex'];
        if (rawIndex is int) {
          sdpMLineIndex = rawIndex;
        } else if (rawIndex is String) {
          sdpMLineIndex = int.tryParse(rawIndex);
        } else {
          sdpMLineIndex = null;
        }
      } else {
        // 纯字符串候选
        candStr = candidate;
        sdpMid = null;
        sdpMLineIndex = null;
      }

      // 记录解析后的关键信息
      print(
          '🔧 解析ICE候选: call=$callId, mid=$sdpMid, index=$sdpMLineIndex, user=${_currentUser?.id}/${_currentUser?.username}');

      final iceCandidate = RTCIceCandidate(candStr, sdpMid, sdpMLineIndex);
      await _peerConnection!.addCandidate(iceCandidate);
      print('✅ ICE候选处理成功: call=$callId');
    } catch (e) {
      // 打印原始数据片段便于调试
      final snippet = candidate.length > 120
          ? '${candidate.substring(0, 120)}...'
          : candidate;
      print(
          '❌ ICE候选处理失败: $e, user=${_currentUser?.id}/${_currentUser?.username}, raw="$snippet"');
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
        // 🔧 修复：被叫方拒绝通话时，释放可能已获取的摄像头
        print('🔍 [answerCall] 被叫方拒绝通话，检查是否需要释放摄像头...');
        print('🔍 [answerCall] _localStream状态: ${_localStream != null ? "存在" : "null"}');
        if (_localStream != null) {
          print('🔍 [answerCall] 被叫方拒绝通话，但检测到 _localStream 存在，开始释放...');
          try {
            final tracks = _localStream!.getTracks();
            print('🔍 [answerCall] 准备停止 ${tracks.length} 个轨道');
            for (var track in tracks) {
              try {
                track.enabled = false;
                track.stop();
                print('🛑 [answerCall] 已停止轨道: ${track.kind}');
              } catch (e) {
                print('❌ [answerCall] 停止轨道失败: $e');
              }
            }
            _localStream = null;
            _safeSetRendererSrcObject(_localRenderer, null);
            print('✅ [answerCall] 被叫方拒绝通话，摄像头已释放');
          } catch (e) {
            print('❌ [answerCall] 释放摄像头失败: $e');
          }
        }
        
        // 如果已创建 PeerConnection，也需要关闭
        if (_peerConnection != null) {
          try {
            await _peerConnection!.close();
            _peerConnection = null;
            print('✅ [answerCall] PeerConnection 已关闭');
          } catch (e) {
            print('⚠️ [answerCall] 关闭 PeerConnection 失败: $e');
            _peerConnection = null;
          }
        }
        
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
    print('🔍 [endCall] ========== 开始主动结束通话 ==========');
    try {
      if (_currentCall == null) {
        print('⚠️ [endCall] _currentCall 为 null，直接返回');
        return;
      }

      final callId = _currentCall!.callId;
      print('🔍 [endCall] callId: $callId');
      print('🔍 [endCall] user: ${_currentUser?.id}/${_currentUser?.username}');
      print('🔍 [endCall] _localStream状态: ${_localStream != null ? "存在" : "null"}');
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [endCall] _localStream轨道数: ${tracks.length}');
      }

      // 结束视频通话
      print('🔍 [endCall] 开始调用 _endVideoCall()...');
      await _endVideoCall();
      print('🔍 [endCall] _endVideoCall() 执行完成');

      // 通过SignalR结束通话
      print('🔍 [endCall] 开始通过 SignalR 结束通话...');
      await _signalRService.endCall(callId);
      print('🔍 [endCall] SignalR 结束通话完成');

      _currentCall = null;
      _isInCall = false;
      notifyListeners();

      print('✅ [endCall] 结束通话完成: call=$callId, user=${_currentUser?.id}, isInCall=$_isInCall');
      print('🔍 [endCall] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}');
      print('🔍 [endCall] ========== 主动结束通话完成 ==========');
    } catch (e, stackTrace) {
      print('❌ [endCall] 结束通话失败: $e');
      print('❌ [endCall] 错误堆栈: $stackTrace');
      print('🔍 [endCall] _localStream状态: ${_localStream != null ? "仍存在⚠️" : "已清空"}');
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
