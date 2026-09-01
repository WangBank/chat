import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
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
  Future<void>? _callSetupFuture;
  Future<List<Map<String, dynamic>>>? _iceServersFuture;
  final Map<String, List<String>> _pendingIceCandidates = {};
  final Set<String> _remoteDescriptionsSet = {};
  final Set<String> _acceptedCallIds = {};
  final Set<String> _callerOfferStarted = {};
  final Set<String> _sfuOfferStarted = {};
  final Set<String> _offersBeingHandled = {};

  // 🔧 防重复处理：记录正在处理的通话结束事件
  final Set<String> _processingCallEnded = {};

  // 🔧 防竞态条件：标记是否正在释放摄像头
  bool _isReleasingCamera = false;

  // 视频渲染器
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;

  // 回调函数
  Function(Call)? onIncomingCall;
  Function(Call)? onCallInitiated;
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

  int? _peerUserIdFor(Call call) {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) return null;
    return currentUserId == call.caller.id ? call.receiver.id : call.caller.id;
  }

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
        final testConstraints = {'audio': true, 'video': false};
        final testStream = await navigator.mediaDevices.getUserMedia(
          testConstraints,
        );
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
      // 连接失败必须向上层传播，让界面进入“服务维护”状态，而不是误判为初始化成功。
      rethrow;
    }
  }

  Future<void> ensureSignalRConnection(String token, User user) async {
    try {
      _currentUser = user;
      await _signalRService.ensureConnectedAndAuthenticated(token, user.id);

      if (!_isInitialized) {
        _isInitialized = true;
        notifyListeners();
      }

      print('✅ SignalR在线状态已恢复: user=${user.id}');
    } catch (e) {
      print('❌ 恢复SignalR在线状态失败: $e');
      onError?.call('恢复SignalR在线状态失败: $e');
      rethrow;
    }
  }

  void updateCurrentUser(User user) {
    _currentUser = user;
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

    _signalRService.onCallInitiated = (Call call) {
      // 服务端生成的 call_id 是后续取消、接听和 WebRTC 信令的唯一标识。
      // 不能继续使用发起阶段的临时 ID。
      _currentCall = call;
      _isInCall = false;
      onCallInitiated?.call(call);
      notifyListeners();

      _signalRService.joinCall(call.callId).then((_) {
        print('🔗 已加入通话组(主叫发起): ${call.callId}, user=${_currentUser?.id}');
      }).catchError((e) {
        print('❌ 加入通话组失败(主叫发起): $e');
      });
    };

    _signalRService.onCallAccepted = (callId) {
      print('📞 WebRTCService收到通话接受事件: $callId');
      print(
        '📞 WebRTCService当前状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall',
      );

      final currentCall = _currentCall;
      if (currentCall != null && currentCall.callId == callId) {
        // 同一接听事件可能由重连中的旧 Hub 连接重复投递。状态与界面只需
        // 切换一次，更重要的是只能由主叫创建 Offer。
        if (!_acceptedCallIds.add(callId)) {
          print('⚠️ 忽略重复的通话接听事件: $callId');
          return;
        }

        _isInCall = true;

        _currentCall = Call(
          callId: callId,
          caller: currentCall.caller,
          receiver: currentCall.receiver,
          callType: currentCall.callType,
          status: CallStatus.inProgress,
          startTime: currentCall.startTime,
        );

        print(
          '📞 WebRTCService更新后状态: _currentCall=${_currentCall?.callId}, _isInCall=$_isInCall',
        );
        print('📞 WebRTCService准备调用onCallAccepted回调');

        onCallAccepted?.call(_currentCall!);
        notifyListeners();

        print('📞 WebRTCService已调用onCallAccepted和notifyListeners');

        if (_currentUser?.id == currentCall.caller.id) {
          _startCallerOffer(callId);
        } else {
          print('📞 被叫方已接听，等待主叫方发送Offer');
        }
      } else {
        print(
          '⚠️ WebRTCService: 当前通话与接听事件不匹配，忽略: current=${currentCall?.callId}, received=$callId',
        );
      }
    };

    _signalRService.onCallRejected = (callId) {
      print('🔍 [onCallRejected] ========== 开始处理通话拒绝事件 ==========');
      print('🔍 [onCallRejected] callId: $callId');
      print(
        '🔍 [onCallRejected] current_user: ${_currentUser?.id}/${_currentUser?.username}',
      );
      print(
        '🔍 [onCallRejected] _localStream状态: ${_localStream != null ? "存在" : "null"}',
      );
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

        print(
          '🔍 [onCallRejected] 状态已重置: currentCall=${_currentCall?.callId}, isInCall=$_isInCall',
        );
        print(
          '🔍 [onCallRejected] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}',
        );

        if (call != null) {
          onCallRejected?.call(call);
          print('🔍 [onCallRejected] 已触发 onCallRejected 回调');
        } else {
          print('⚠️ [onCallRejected] call 为 null，未触发回调');
        }

        try {
          await _signalRService.leaveCall(callId);
          print(
            '🔗 [onCallRejected] 已离开通话组(拒绝): $callId, user=${_currentUser?.id}',
          );
        } catch (e) {
          print('❌ [onCallRejected] 离开通话组失败(拒绝): $e');
        }

        print('🔍 [onCallRejected] ========== 通话拒绝事件处理完成 ==========');
      })();
    };

    _signalRService.onCallEnded = (callId) {
      print('🔍 [onCallEnded] ========== 开始处理通话结束事件 ==========');
      print('🔍 [onCallEnded] callId: $callId');
      print(
        '🔍 [onCallEnded] current_user: ${_currentUser?.id}/${_currentUser?.username}',
      );
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
        print(
          '⚠️ [onCallEnded] 通话ID不匹配（当前: ${_currentCall?.callId}, 事件: $callId），且无资源需要释放，跳过',
        );
        return;
      }

      // 标记为正在处理
      _processingCallEnded.add(callId);
      print('🔍 [onCallEnded] 已标记通话 $callId 为处理中');

      print(
        '🔍 [onCallEnded] _localStream状态: ${_localStream != null ? "存在" : "null"}',
      );
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [onCallEnded] _localStream轨道数: ${tracks.length}');
        for (var track in tracks) {
          print(
            '🔍 [onCallEnded] 轨道: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}',
          );
        }
      }
      print(
        '🔍 [onCallEnded] _peerConnection状态: ${_peerConnection != null ? "存在" : "null"}',
      );

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

          print(
            '🔍 [onCallEnded] 状态已重置: currentCall=${_currentCall?.callId}, isInCall=$_isInCall',
          );

          if (call != null) {
            onCallEnded?.call(call);
            print('🔍 [onCallEnded] 已触发 onCallEnded 回调');
          } else {
            print('⚠️ [onCallEnded] call 为 null，未触发回调');
          }
        } else {
          print('⚠️ [onCallEnded] 通话ID不匹配，仅释放资源，不更新状态');
        }

        print(
          '🔍 [onCallEnded] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}',
        );
        print('🔍 [onCallEnded] 通话结束事件处理完成');

        try {
          await _signalRService.leaveCall(callId);
          print(
            '🔗 [onCallEnded] 已离开通话组(被动结束): $callId, user=${_currentUser?.id}',
          );
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
    _signalRService.onSfuAnswerReceived = (callId, answer) {
      print('📥 收到 SFU Answer: $callId');
      _handleSfuAnswer(callId, answer);
    };
  }

  // 创建PeerConnection
  Future<RTCPeerConnection> _createPeerConnection() async {
    final configuration = {
      'iceServers': await _loadIceServers(),
    };

    final constraints = {
      'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': true},
      'optional': [],
    };

    final pc = await createPeerConnection(configuration, constraints);

    // 添加本地流
    final localStream = _localStream;
    if (localStream != null) {
      // `addTrack` is asynchronous on flutter_webrtc.  An answer generated
      // before these futures complete is receive-only, which leaves the web
      // peer without the mobile audio/video track.  Finish registering every
      // local track before returning the connection to the offer handler.
      for (final track in localStream.getTracks()) {
        await pc.addTrack(track, localStream);
      }
    } else {
      print('⚠️ 没有本地流，跳过添加本地轨道（模拟器环境）');
    }

    // 监听远程流。不同 Android WebRTC 原生版本可能走 Unified Plan 的
    // onTrack，也可能仍触发 Plan-B 的 onAddStream；两条路径都必须绑定到
    // 同一个 renderer，否则服务端已经转发 RTP 时客户端仍只看到自己。
    pc.onTrack = (RTCTrackEvent event) async {
      MediaStream? stream =
          event.streams.isNotEmpty ? event.streams.first : _remoteStream;
      if (stream == null) {
        stream = await createLocalMediaStream(
          'remote-${_currentCall?.callId ?? 'call'}',
        );
      }
      if (event.streams.isEmpty &&
          !stream.getTracks().any((track) => track.id == event.track.id)) {
        await stream.addTrack(event.track);
        print('📹 收到未携带媒体流的远程轨道，已附加: ${event.track.kind}');
      }
      _attachRemoteStream(stream, event.track.kind ?? 'track');
    };
    pc.onAddStream = (MediaStream stream) {
      _attachRemoteStream(stream, 'stream');
    };

    // 监听ICE候选
    pc.onIceCandidate = (RTCIceCandidate candidate) {
      print('📤 发送ICE候选');
      if (_currentCall != null) {
        if (_currentUser == null) {
          print('⚠️ 当前用户为空，无法发送ICE候选');
          return;
        }

        _signalRService.sendSfuIceCandidate(
          _currentCall!.callId,
          jsonEncode(candidate.toMap()),
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

  void _attachRemoteStream(MediaStream stream, String kind) {
    _remoteStream = stream;
    _safeSetRendererSrcObject(_remoteRenderer, stream);
    print('📹 收到远程媒体流: kind=$kind, tracks=${stream.getTracks().length}');
    notifyListeners();
  }

  void _startCallerOffer(String callId) {
    if (!_callerOfferStarted.add(callId)) {
      print('⚠️ 主叫Offer已在处理中，忽略重复接听事件: $callId');
      return;
    }

    () async {
      try {
        // PeerConnection 必须在 createOffer 前已挂载完整的本地音视频轨道；
        // 所有步骤顺序等待，避免首个 Offer 或其 ICE 候选落在未就绪窗口中。
        await _startVideoCall();
        await _signalRService.joinCall(callId);

        final call = _currentCall;
        final peerConnection = _peerConnection;
        if (call == null || call.callId != callId || peerConnection == null) {
          throw StateError('通话状态已变更，无法创建 Offer');
        }

        final offer = await peerConnection.createOffer();
        await peerConnection.setLocalDescription(offer);
        await _signalRService.sendSfuOffer(callId, jsonEncode(offer.toMap()));
        print('📤 主叫方已向 SFU 发送Offer');
      } catch (e) {
        _callerOfferStarted.remove(callId);
        print('❌ 主叫方创建/发送Offer失败: $e');
        onError?.call('建立通话连接失败: $e');
      }
    }();
  }

  Future<List<Map<String, dynamic>>> _loadIceServers() {
    return _iceServersFuture ??= _fetchIceServers();
  }

  Future<List<Map<String, dynamic>>> _fetchIceServers() async {
    const fallback = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/system/webrtc-config'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['ice_servers'] is! List) {
        return fallback;
      }

      final iceServers = <Map<String, dynamic>>[];
      for (final item in payload['ice_servers'] as List) {
        if (item is! Map) continue;
        final urls = item['urls'];
        final hasValidUrl = urls is String
            ? urls.isNotEmpty
            : urls is List &&
                urls.any((value) => value is String && value.isNotEmpty);
        if (!hasValidUrl) continue;

        iceServers.add(Map<String, dynamic>.from(item));
      }

      return iceServers.isEmpty ? fallback : iceServers;
    } catch (error) {
      print('⚠️ 获取ICE服务器配置失败，使用STUN回退: $error');
      return fallback;
    }
  }

  // 请求权限
  Future<bool> _requestPermissions(CallType callType) async {
    // Desktop and web implementations delegate camera/microphone permission to
    // flutter_webrtc/getUserMedia. permission_handler has no macOS channel in
    // this project, so requesting it here prevents every desktop call before
    // WebRTC gets a chance to ask the operating system for access.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      print('🔐 当前平台由 WebRTC 原生媒体请求处理权限');
      return true;
    }

    try {
      print('🔐 请求${callType == CallType.video ? '摄像头和' : ''}麦克风权限...');
      final microphoneStatus = await Permission.microphone.request();
      print('🎤 麦克风权限状态: $microphoneStatus');

      if (!microphoneStatus.isGranted) {
        print('❌ 权限被拒绝');
        return false;
      }

      if (callType == CallType.voice) {
        print('✅ 语音通话麦克风权限已授予');
        return true;
      }

      final cameraStatus = await Permission.camera.request();
      print('📷 摄像头权限状态: $cameraStatus');
      if (!cameraStatus.isGranted) {
        print('❌ 摄像头权限被拒绝');
        return false;
      }

      print('✅ 视频通话权限已授予');
      return true;
    } catch (e) {
      print('❌ 权限请求失败: $e');
      return false;
    }
  }

  // 获取本地媒体流
  Future<MediaStream> _getUserMedia(CallType callType) async {
    try {
      print('📹 请求${callType == CallType.video ? '摄像头和' : ''}麦克风权限...');
      print(
        '🔍 [_getUserMedia] 当前用户: ${_currentUser?.id}/${_currentUser?.username}',
      );

      // 先请求权限
      final hasPermissions = await _requestPermissions(callType);
      if (!hasPermissions) {
        throw Exception('缺少${callType == CallType.video ? '摄像头或' : ''}麦克风权限');
      }

      final constraints = {
        'audio': true,
        'video': callType == CallType.video
            ? {
                'mandatory': {
                  'minWidth': '640',
                  'minHeight': '480',
                  'minFrameRate': '30',
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      };

      print('🔍 [_getUserMedia] 开始调用 getUserMedia...');
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      print('✅ [_getUserMedia] 成功获取媒体流');
      final tracks = stream.getTracks();
      print('🔍 [_getUserMedia] 获取到的轨道数: ${tracks.length}');
      for (var track in tracks) {
        print('🔍 [_getUserMedia] 轨道: kind=${track.kind}, id=${track.id}');
      }
      if (!tracks.any((track) => track.kind == 'audio')) {
        stream.getTracks().forEach((track) => track.stop());
        throw Exception('未获取到麦克风音频轨道');
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

      rethrow;
    }
  }

  // 安全地设置渲染器的srcObject
  void _safeSetRendererSrcObject(
    RTCVideoRenderer? renderer,
    MediaStream? stream,
  ) {
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

  // 同一通话只允许一个初始化过程，避免 Offer 和接听流程并发创建两个 PeerConnection。
  Future<void> _startVideoCall() async {
    if (_peerConnection != null) return;
    final inFlight = _callSetupFuture;
    if (inFlight != null) return inFlight;

    final setup = _startVideoCallInternal();
    _callSetupFuture = setup;
    try {
      await setup;
    } finally {
      if (identical(_callSetupFuture, setup)) {
        _callSetupFuture = null;
      }
    }
  }

  // 开始视频或语音通话
  Future<void> _startVideoCallInternal() async {
    print('🔍 [_startVideoCall] ========== 开始视频通话 ==========');
    print('🔍 [_startVideoCall] call: ${_currentCall?.callId}');
    print(
      '🔍 [_startVideoCall] user: ${_currentUser?.id}/${_currentUser?.username}',
    );
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
      print(
        '🔍 [_startVideoCall] 检查 _localStream: ${_localStream != null ? "已存在" : "null"}',
      );
      if (_localStream == null) {
        print('🔍 [_startVideoCall] 开始获取媒体流...');
        final callType = _currentCall?.callType;
        if (callType == null) {
          throw Exception('通话信息不存在，无法获取媒体流');
        }
        _localStream = await _getUserMedia(callType);
        print(
          '🔍 [_startVideoCall] 获取媒体流结果: ${_localStream != null ? "成功" : "失败"}',
        );
        if (_localStream != null) {
          final tracks = _localStream!.getTracks();
          print('🔍 [_startVideoCall] 获取到的轨道数: ${tracks.length}');
          for (var i = 0; i < tracks.length; i++) {
            final track = tracks[i];
            print(
              '🔍 [_startVideoCall] 轨道[$i]: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}',
            );
          }
          _safeSetRendererSrcObject(_localRenderer, _localStream);
          print('🔍 [_startVideoCall] 已设置本地渲染器');
        }
      } else {
        print('⚠️ [_startVideoCall] _localStream 已存在，跳过获取');
        final tracks = _localStream!.getTracks();
        print('🔍 [_startVideoCall] 现有轨道数: ${tracks.length}');
      }

      // Put the native audio session in communication/speaker mode before the
      // remote track arrives.  Without this Android may keep the call audio on
      // the earpiece (or leave the media route muted) even though RTP is
      // connected successfully.
      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        // Web and desktop implementations may not expose native audio routing;
        // media negotiation must continue in those environments.
        print('⚠️ 设置扬声器输出失败，继续使用系统默认音频路由: $e');
      }

      // 创建PeerConnection
      print('🔍 [_startVideoCall] 开始创建 PeerConnection...');
      if (_peerConnection == null) {
        _peerConnection = await _createPeerConnection();
      }
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

  Future<void> setMuted(bool muted) async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      track.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final stream = _localStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks()) {
      track.enabled = enabled;
    }
    notifyListeners();
  }

  Future<void> setSpeakerphoneEnabled(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (e) {
      print('⚠️ 切换扬声器输出失败: $e');
    }
    notifyListeners();
  }

  // 结束视频通话
  Future<void> _endVideoCall() async {
    print('🔍 [_endVideoCall] ========== 开始结束视频通话 ==========');
    print('🔍 [_endVideoCall] call: ${_currentCall?.callId}');
    print(
      '🔍 [_endVideoCall] user: ${_currentUser?.id}/${_currentUser?.username}',
    );
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
      print(
        '🔍 [_endVideoCall] 检查 _localStream: ${_localStream != null ? "存在" : "null"}',
      );
      if (_localStream != null) {
        final tracks = _localStream!.getTracks();
        print('🔍 [_endVideoCall] 本地流轨道数: ${tracks.length}');
        for (var i = 0; i < tracks.length; i++) {
          final track = tracks[i];
          print(
            '🔍 [_endVideoCall] 轨道[$i]: kind=${track.kind}, id=${track.id}, enabled=${track.enabled}, muted=${track.muted}',
          );
        }
      } else {
        print('⚠️ [_endVideoCall] _localStream 为 null，可能已经释放或未初始化');
      }

      print(
        '🔍 [_endVideoCall] 检查 _peerConnection: ${_peerConnection != null ? "存在" : "null"}',
      );

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
            print(
              '🔍 [_endVideoCall] 停止本地轨道[$i]: kind=${track.kind}, id=${track.id}',
            );
            // 先禁用轨道
            track.enabled = false;
            // 然后停止轨道
            track.stop();
            print(
              '🛑 [_endVideoCall] 已停止本地轨道[$i]: ${track.kind}, enabled=${track.enabled}',
            );

            // 不调用 removeTrack：flutter_webrtc 在轨道 stop 后可能异步抛出
            // mediaStreamRemoveTrack 异常；停止轨道并清空流引用即可释放资源。
          } catch (e, stackTrace) {
            print('❌ [_endVideoCall] 停止本地轨道[$i]失败: $e');
            print('❌ [_endVideoCall] 错误堆栈: $stackTrace');
          }
        }

        // 记录仍挂在 MediaStream 上的轨道；轨道已停止，后续会清空流引用。
        final remainingTracks = _localStream!.getTracks();
        if (remainingTracks.isNotEmpty) {
          print(
            '🔍 [_endVideoCall] MediaStream 中仍有 ${remainingTracks.length} 个已停止轨道',
          );
        }

        // 清空本地流引用
        final streamToDispose = _localStream;
        _localStream = null;
        print('✅ [_endVideoCall] 本地流已释放，_localStream 已设为 null');

        if (streamToDispose != null) {
          print('✅ [_endVideoCall] MediaStream 已彻底清理');
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
            print(
              '🔍 [_endVideoCall] 发送器[$i]: track=${sender.track != null ? "存在" : "null"}',
            );
            if (sender.track != null) {
              print(
                '🔍 [_endVideoCall] 发送器[$i]轨道: kind=${sender.track!.kind}, id=${sender.track!.id}',
              );
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
            print(
              '🔍 [_endVideoCall] 停止远程轨道: kind=${track.kind}, id=${track.id}',
            );
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
      print(
        '✅ [_endVideoCall] 视频通话结束成功: user=${_currentUser?.id}, call_cleared=${_currentCall == null}, isInCall=$_isInCall',
      );
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
    if (_remoteDescriptionsSet.contains(callId)) {
      print('⚠️ 已处理过Offer，忽略重复信令: $callId');
      return;
    }
    if (!_offersBeingHandled.add(callId)) {
      print('⚠️ Offer正在处理，忽略重复信令: $callId');
      return;
    }

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
      _remoteDescriptionsSet.add(callId);
      await _flushPendingIceCandidates(callId);

      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      await _signalRService.sendAnswer(
        WebRTCAnswer(callId: callId, answer: jsonEncode(answer.toMap())),
        senderId,
      );

      print('✅ Offer处理成功');
    } catch (e) {
      print('❌ Offer处理失败: $e');
      onError?.call('Offer处理失败: $e');
    } finally {
      _offersBeingHandled.remove(callId);
    }
  }

  // 处理Answer
  Future<void> _handleAnswer(String callId, String answer, int senderId) async {
    if (_remoteDescriptionsSet.contains(callId)) {
      print('⚠️ 已处理过Answer，忽略重复信令: $callId');
      return;
    }

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
      _remoteDescriptionsSet.add(callId);
      await _flushPendingIceCandidates(callId);
      print('✅ Answer处理成功');
    } catch (e) {
      print('❌ Answer处理失败: $e');
      onError?.call('Answer处理失败: $e');
    }
  }

  Future<void> _handleSfuAnswer(String callId, String answer) async {
    if (_currentCall?.callId != callId || _peerConnection == null) {
      print('⚠️ 收到 SFU Answer 时本地通话或 PeerConnection 不存在: $callId');
      return;
    }

    try {
      dynamic decoded;
      try {
        decoded = jsonDecode(answer);
      } catch (_) {
        decoded = null;
      }
      final sdp = decoded is Map && decoded['sdp'] is String
          ? decoded['sdp'] as String
          : answer;
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
      _remoteDescriptionsSet.add(callId);
      await _flushPendingIceCandidates(callId);
      print('✅ SFU Answer处理成功: $callId');
    } catch (e) {
      print('❌ SFU Answer处理失败: $e');
      onError?.call('SFU媒体协商失败: $e');
    }
  }

  Future<void> _startSfuOffer(String callId) async {
    if (!_sfuOfferStarted.add(callId)) {
      print('⚠️ SFU Offer已在处理中，忽略重复请求: $callId');
      return;
    }

    try {
      await _startVideoCall();
      await _signalRService.joinCall(callId);
      final peerConnection = _peerConnection;
      if (peerConnection == null || _currentCall?.callId != callId) {
        throw StateError('通话状态已变更，无法创建 SFU Offer');
      }
      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      await _signalRService.sendSfuOffer(callId, jsonEncode(offer.toMap()));
      print('📤 已向 SFU 发送本地 Offer: $callId');
    } catch (e) {
      _sfuOfferStarted.remove(callId);
      print('❌ SFU Offer创建/发送失败: $e');
      onError?.call('建立SFU通话连接失败: $e');
      rethrow;
    }
  }

  // 处理ICE候选
  Future<void> _handleIceCandidate(
    String callId,
    String candidate,
    int senderId,
  ) async {
    if (_peerConnection == null || !_remoteDescriptionsSet.contains(callId)) {
      _pendingIceCandidates.putIfAbsent(callId, () => []).add(candidate);
      print('⏳ ICE候选已缓存，等待远端描述: call=$callId');
      return;
    }

    await _addIceCandidate(callId, candidate);
  }

  Future<void> _flushPendingIceCandidates(String callId) async {
    final candidates = _pendingIceCandidates.remove(callId);
    if (candidates == null || candidates.isEmpty) return;

    for (final candidate in candidates) {
      await _addIceCandidate(callId, candidate);
    }
  }

  Future<void> _addIceCandidate(String callId, String candidate) async {
    try {
      final peerConnection = _peerConnection;
      if (peerConnection == null) return;

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
        '🔧 解析ICE候选: call=$callId, mid=$sdpMid, index=$sdpMLineIndex, user=${_currentUser?.id}/${_currentUser?.username}',
      );

      final iceCandidate = RTCIceCandidate(candStr, sdpMid, sdpMLineIndex);
      await peerConnection.addCandidate(iceCandidate);
      print('✅ ICE候选处理成功: call=$callId');
    } catch (e) {
      // 打印原始数据片段便于调试
      final snippet = candidate.length > 120
          ? '${candidate.substring(0, 120)}...'
          : candidate;
      print(
        '❌ ICE候选处理失败: $e, user=${_currentUser?.id}/${_currentUser?.username}, raw="$snippet"',
      );
      onError?.call('ICE候选处理失败: $e');
    }
  }

  // 发起通话
  Future<void> initiateCall(User receiver, CallType callType) async {
    try {
      if (!_isInitialized) {
        throw Exception('WebRTC服务未初始化');
      }

      // Set a temporary call before signalling so a very fast accepted event
      // always has a peer/call type to work with.
      _currentCall = Call(
        callId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        caller: _currentUser!,
        receiver: receiver,
        callType: callType,
        status: CallStatus.initiated,
        startTime: DateTime.now(),
      );

      // 先获取本地媒体流，用于等待页面显示
      print('📹 发起通话时获取本地视频流...');

      // 确保渲染器已初始化
      await _ensureRenderersInitialized();

      _localStream = await _getUserMedia(callType);
      _safeSetRendererSrcObject(_localRenderer, _localStream);
      notifyListeners();
      print('✅ 本地媒体流已获取，可用于等待页面显示');

      // 通过SignalR发起通话
      await _signalRService.initiateCall(
        InitiateCallRequest(receiverId: receiver.id, callType: callType),
      );

      print('📞 发起通话: ${receiver.username}');
      print('📞 WebRTCService: 当前通话ID: ${_currentCall!.callId}');
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
    var acceptedBySignalR = false;
    try {
      if (!_isInitialized) {
        throw Exception('WebRTC服务未初始化');
      }

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

        // Prepare local media and the peer connection before notifying the
        // caller. Otherwise its Offer can arrive while this client has no PC.
        await _startVideoCall();
        await _signalRService.joinCall(callId);
        await _signalRService.answerCall(
          AnswerCallRequest(callId: callId, accept: true),
        );
        acceptedBySignalR = true;

        // 被叫也向 SFU 建立独立的媒体连接；不再等待主叫的 P2P Offer。
        await _startSfuOffer(callId);

        // 被叫方接听后，通知CallManager状态变化
        if (_currentCall != null) {
          onCallAccepted?.call(_currentCall!);
        }

        print('📞 已接听通话，已向 SFU 发送Offer');
      } else {
        await _signalRService.answerCall(
          AnswerCallRequest(callId: callId, accept: false),
        );
        // 🔧 修复：被叫方拒绝通话时，释放可能已获取的摄像头
        print('🔍 [answerCall] 被叫方拒绝通话，检查是否需要释放摄像头...');
        print(
          '🔍 [answerCall] _localStream状态: ${_localStream != null ? "存在" : "null"}',
        );
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
      try {
        await _endVideoCall();
      } catch (cleanupError) {
        print('⚠️ 应答失败后的媒体清理失败: $cleanupError');
      }

      try {
        if (acceptedBySignalR) {
          await _signalRService.endCall(callId);
        } else {
          await _signalRService.answerCall(
            AnswerCallRequest(callId: callId, accept: false),
          );
        }
      } catch (signalError) {
        print('⚠️ 应答失败后的信令清理失败: $signalError');
      }

      _currentCall = null;
      _isInCall = false;
      notifyListeners();
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
      print(
        '🔍 [endCall] _localStream状态: ${_localStream != null ? "存在" : "null"}',
      );
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

      print(
        '✅ [endCall] 结束通话完成: call=$callId, user=${_currentUser?.id}, isInCall=$_isInCall',
      );
      print(
        '🔍 [endCall] _localStream最终状态: ${_localStream != null ? "仍存在⚠️" : "已清空✅"}',
      );
      print('🔍 [endCall] ========== 主动结束通话完成 ==========');
    } catch (e, stackTrace) {
      print('❌ [endCall] 结束通话失败: $e');
      print('❌ [endCall] 错误堆栈: $stackTrace');
      print(
        '🔍 [endCall] _localStream状态: ${_localStream != null ? "仍存在⚠️" : "已清空"}',
      );
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
