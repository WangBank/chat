import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'signalr_service.dart';
import '../models/call.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final SignalRService _signalRService;
  String? _currentCallId;
  
  // 视频渲染器
  RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  
  // 回调函数
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function()? onConnectionEstablished;
  Function()? onConnectionLost;

  WebRTCService(this._signalRService);

  // 初始化
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    
    // 设置SignalR回调
    _signalRService.onOfferReceived = _handleOfferReceived;
    _signalRService.onAnswerReceived = _handleAnswerReceived;
    _signalRService.onIceCandidateReceived = _handleIceCandidateReceived;
  }

  // 请求权限
  Future<bool> requestPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.microphone,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  // 创建PeerConnection
  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    final constraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ]
    };

    _peerConnection = await createPeerConnection(configuration, constraints);

    // 设置事件监听器
    _peerConnection!.onIceCandidate = (candidate) {
      if (_currentCallId != null) {
        _signalRService.sendIceCandidate(WebRTCCandidate(
          callId: _currentCallId!,
          candidate: jsonEncode(candidate.toMap()),
        ));
      }
    };

    _peerConnection!.onAddStream = (stream) {
      _remoteStream = stream;
      remoteRenderer.srcObject = stream;
      onRemoteStream?.call(stream);
    };

    _peerConnection!.onRemoveStream = (stream) {
      _remoteStream = null;
      remoteRenderer.srcObject = null;
    };

    _peerConnection!.onConnectionState = (state) {
      print('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnectionEstablished?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionLost?.call();
      }
    };
  }

  // 获取本地媒体流
  Future<void> _getUserMedia({bool video = true, bool audio = true}) async {
    final constraints = {
      'audio': audio,
      'video': video ? {
        'width': {'min': 640, 'ideal': 1280},
        'height': {'min': 480, 'ideal': 720},
        'facingMode': 'user',
      } : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      localRenderer.srcObject = _localStream;
      onLocalStream?.call(_localStream!);
      
      if (_peerConnection != null) {
        await _peerConnection!.addStream(_localStream!);
      }
    } catch (e) {
      print('Error getting user media: $e');
      throw Exception('无法获取摄像头/麦克风权限');
    }
  }

  // 发起通话
  Future<void> initiateCall(String callId, CallType callType) async {
    _currentCallId = callId;
    
    // 请求权限
    if (!await requestPermissions()) {
      throw Exception('需要摄像头和麦克风权限');
    }

    await _createPeerConnection();
    await _getUserMedia(
      video: callType == CallType.video,
      audio: true,
    );

    // 创建offer
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // 发送offer
    await _signalRService.sendOffer(WebRTCOffer(
      callId: callId,
      offer: jsonEncode(offer.toMap()),
    ));
  }

  // 应答通话
  Future<void> answerCall(String callId, CallType callType) async {
    _currentCallId = callId;
    
    // 请求权限
    if (!await requestPermissions()) {
      throw Exception('需要摄像头和麦克风权限');
    }

    await _createPeerConnection();
    await _getUserMedia(
      video: callType == CallType.video,
      audio: true,
    );
  }

  // 处理接收到的offer
  Future<void> _handleOfferReceived(String callId, String offer, int senderId) async {
    if (_currentCallId != callId) return;

    try {
      final offerDescription = RTCSessionDescription(
        jsonDecode(offer)['sdp'],
        jsonDecode(offer)['type'],
      );

      await _peerConnection!.setRemoteDescription(offerDescription);

      // 创建answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // 发送answer
      await _signalRService.sendAnswer(WebRTCAnswer(
        callId: callId,
        answer: jsonEncode(answer.toMap()),
      ));
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  // 处理接收到的answer
  Future<void> _handleAnswerReceived(String callId, String answer, int senderId) async {
    if (_currentCallId != callId) return;

    try {
      final answerDescription = RTCSessionDescription(
        jsonDecode(answer)['sdp'],
        jsonDecode(answer)['type'],
      );

      await _peerConnection!.setRemoteDescription(answerDescription);
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  // 处理接收到的ICE candidate
  Future<void> _handleIceCandidateReceived(String callId, String candidate, int senderId) async {
    if (_currentCallId != callId) return;

    try {
      final candidateMap = jsonDecode(candidate);
      final iceCandidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      await _peerConnection!.addCandidate(iceCandidate);
    } catch (e) {
      print('Error handling ICE candidate: $e');
    }
  }

  // 切换摄像头
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  // 切换麦克风
  void toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  // 切换摄像头开关
  void toggleCamera() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  // 结束通话
  Future<void> endCall() async {
    // 停止本地流
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        track.stop();
      });
      _localStream = null;
    }

    // 关闭peer connection
    if (_peerConnection != null) {
      await _peerConnection!.close();
      _peerConnection = null;
    }

    // 清理渲染器
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;

    _currentCallId = null;
  }

  // 销毁资源
  Future<void> dispose() async {
    await endCall();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }

  // 获取当前状态
  bool get isInCall => _currentCallId != null;
  String? get currentCallId => _currentCallId;
  bool get hasLocalStream => _localStream != null;
  bool get hasRemoteStream => _remoteStream != null;
}
