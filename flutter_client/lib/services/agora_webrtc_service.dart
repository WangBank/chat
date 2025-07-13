import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class AgoraWebRTCService {
  static AgoraWebRTCService? _instance;
  static AgoraWebRTCService get instance => _instance ??= AgoraWebRTCService._internal();
  AgoraWebRTCService._internal();

  RtcEngine? _rtcEngine;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  String? _currentChannelId;
  List<int> _remoteUids = [];
  
  Function(int userId)? onUserJoined;
  Function(int userId)? onUserLeft;
  Function()? onCallEnded;
  Function(String error)? onError;

  // Agora App ID - 需要替换为实际的 App ID
  static const String agoraAppId = "YOUR_AGORA_APP_ID";

  Future<void> initialize() async {
    if (_rtcEngine != null) return;

    // 请求权限
    await _requestPermissions();

    // 初始化 Agora RTC Engine
    _rtcEngine = createAgoraRtcEngine();
    await _rtcEngine!.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // 设置事件处理器
    _rtcEngine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print('本地用户加入频道成功: ${connection.channelId}');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print('远程用户加入: $remoteUid');
          _remoteUids.add(remoteUid);
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          print('远程用户离开: $remoteUid, 原因: $reason');
          _remoteUids.remove(remoteUid);
          onUserLeft?.call(remoteUid);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          print('离开频道');
          _isInCall = false;
          _currentChannelId = null;
          _remoteUids.clear();
          onCallEnded?.call();
        },
        onError: (ErrorCodeType err, String msg) {
          print('Agora错误: $err, 消息: $msg');
          onError?.call('$err: $msg');
        },
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          print('连接状态变化: $state, 原因: $reason');
        },
      ),
    );

    // 启用视频和音频模块
    await _rtcEngine!.enableVideo();
    await _rtcEngine!.enableAudio();
    
    // 设置视频编码配置
    await _rtcEngine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 480),
        frameRate: 15,
        bitrate: 0,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final permissions = [Permission.microphone, Permission.camera];
    final statuses = await permissions.request();
    
    for (var permission in permissions) {
      if (statuses[permission] != PermissionStatus.granted) {
        throw Exception('需要${permission == Permission.microphone ? "麦克风" : "摄像头"}权限');
      }
    }
  }

  Future<void> startCall(String channelId, {int? userId}) async {
    if (_rtcEngine == null) {
      await initialize();
    }

    try {
      _currentChannelId = channelId;
      
      // 加入频道
      await _rtcEngine!.joinChannel(
        token: '', // 在生产环境中需要使用 token
        channelId: channelId,
        uid: userId ?? 0,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
      
      _isInCall = true;
      print('开始通话，频道: $channelId');
    } catch (e) {
      print('加入频道失败: $e');
      throw Exception('启动通话失败: $e');
    }
  }

  Future<void> endCall() async {
    try {
      if (_rtcEngine != null) {
        await _rtcEngine!.leaveChannel();
      }
      _isInCall = false;
      _currentChannelId = null;
      _remoteUids.clear();
      print('通话结束');
    } catch (e) {
      print('结束通话失败: $e');
    }
  }

  Future<void> toggleMicrophone() async {
    if (_rtcEngine == null) return;
    
    _isMuted = !_isMuted;
    await _rtcEngine!.muteLocalAudioStream(_isMuted);
    print('麦克风${_isMuted ? "静音" : "取消静音"}');
  }

  Future<void> toggleCamera() async {
    if (_rtcEngine == null) return;
    
    _isVideoEnabled = !_isVideoEnabled;
    await _rtcEngine!.muteLocalVideoStream(!_isVideoEnabled);
    print('摄像头${_isVideoEnabled ? "开启" : "关闭"}');
  }

  Future<void> switchCamera() async {
    if (_rtcEngine == null) return;
    
    await _rtcEngine!.switchCamera();
    print('切换摄像头');
  }

  Future<void> enableSpeakerphone(bool enabled) async {
    if (_rtcEngine == null) return;
    
    await _rtcEngine!.setEnableSpeakerphone(enabled);
    print('扬声器${enabled ? "开启" : "关闭"}');
  }

  // Getters
  bool get isInCall => _isInCall;
  bool get isMuted => _isMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  String? get currentChannelId => _currentChannelId;
  List<int> get remoteUids => List.unmodifiable(_remoteUids);
  RtcEngine? get rtcEngine => _rtcEngine;

  // 创建本地视频视图
  Widget createLocalVideoView() {
    if (_rtcEngine == null) {
      return const Center(child: Text('引擎未初始化'));
    }
    
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _rtcEngine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  // 创建远程视频视图
  Widget createRemoteVideoView(int uid) {
    if (_rtcEngine == null) {
      return const Center(child: Text('引擎未初始化'));
    }
    
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _rtcEngine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _currentChannelId ?? ""),
      ),
    );
  }

  Future<void> dispose() async {
    try {
      if (_isInCall) {
        await endCall();
      }
      await _rtcEngine?.release();
      _rtcEngine = null;
      _remoteUids.clear();
      print('Agora WebRTC服务已释放');
    } catch (e) {
      print('释放Agora WebRTC服务失败: $e');
    }
  }
}
