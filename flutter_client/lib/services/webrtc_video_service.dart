import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../models/call.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'signalr_service.dart';

/// The historical name is kept because the application state and routes use it.
/// Media signaling, ICE and SFU forwarding are handled exclusively by LiveKit.
class WebRTCVideoService extends ChangeNotifier {
  final SignalRService _signalRService;
  final ApiService _apiService;

  bool _isInitialized = false;
  bool _isInCall = false;
  Call? _currentCall;
  User? _currentUser;
  Room? _room;
  VoidCallback? _roomListener;

  Function(Call)? onIncomingCall;
  Function(Call)? onCallInitiated;
  Function(Call)? onCallAccepted;
  Function(Call)? onCallRejected;
  Function(Call)? onCallEnded;
  Function(String)? onError;

  WebRTCVideoService(this._signalRService, this._apiService) {
    _setupSignalRHandlers();
  }

  bool get isInitialized => _isInitialized;
  bool get isInCall => _isInCall;
  Call? get currentCall => _currentCall;
  SignalRService get signalRService => _signalRService;
  int get signalRSessionGeneration => _signalRService.sessionGeneration;

  VideoTrack? get localVideoTrack {
    final participant = _room?.localParticipant;
    if (participant == null) return null;
    return _firstVideoTrack(participant.videoTrackPublications);
  }

  VideoTrack? get remoteVideoTrack {
    final room = _room;
    if (room == null) return null;
    for (final participant in room.remoteParticipants.values) {
      final track = _firstVideoTrack(participant.videoTrackPublications);
      if (track != null) return track;
    }
    return null;
  }

  VideoTrack? _firstVideoTrack(Iterable<TrackPublication> publications) {
    for (final publication in publications) {
      final track = publication.track;
      if (track is VideoTrack) return track;
    }
    return null;
  }

  Future<void> initialize(
    String token,
    User user, {
    int? expectedSignalRSessionGeneration,
  }) async {
    _currentUser = user;
    _setupSignalRHandlers();
    await ensureSignalRConnection(
      token,
      user,
      expectedSignalRSessionGeneration: expectedSignalRSessionGeneration,
    );
    _isInitialized = true;
  }

  Future<void> ensureSignalRConnection(
    String token,
    User user, {
    bool forceReconnect = false,
    int? expectedSignalRSessionGeneration,
  }) {
    _currentUser = user;
    return _signalRService.ensureConnectedAndAuthenticated(
      token,
      user.id,
      forceReconnect: forceReconnect,
      expectedSessionGeneration: expectedSignalRSessionGeneration,
    );
  }

  void updateCurrentUser(User user) {
    _currentUser = user;
  }

  void _setupSignalRHandlers() {
    _signalRService.onIncomingCall = (call) {
      _currentCall = call;
      _isInCall = false;
      onIncomingCall?.call(call);
      notifyListeners();
    };
    _signalRService.onCallInitiated = (call) {
      _currentCall = call;
      _isInCall = false;
      onCallInitiated?.call(call);
      notifyListeners();
    };
    _signalRService.onCallAccepted = (callId) {
      final call = _currentCall;
      if (call == null || call.callId != callId) return;
      unawaited(_connectCaller(call));
    };
    _signalRService.onCallRejected = (callId) {
      final call = _currentCall;
      if (call == null || call.callId != callId) return;
      unawaited(_leaveRoom());
      _currentCall = null;
      _isInCall = false;
      onCallRejected?.call(call);
      notifyListeners();
    };
    _signalRService.onCallEnded = (callId) {
      final call = _currentCall;
      if (call == null || call.callId != callId) return;
      unawaited(_leaveRoom());
      _currentCall = null;
      _isInCall = false;
      onCallEnded?.call(call);
      notifyListeners();
    };
  }

  Future<void> initiateCall(User receiver, CallType callType) async {
    if (!_isInitialized || _currentUser == null) {
      throw Exception('通话服务未初始化');
    }

    _currentCall = Call(
      callId: '',
      caller: _currentUser!,
      receiver: receiver,
      callType: callType,
      status: CallStatus.initiated,
      startTime: DateTime.now(),
    );
    try {
      await _signalRService.initiateCall(
        InitiateCallRequest(receiverId: receiver.id, callType: callType),
      );
    } catch (_) {
      _currentCall = null;
      rethrow;
    }
  }

  Future<void> answerCall(String callId, bool accept) async {
    final call = _currentCall;
    if (call == null || call.callId != callId) {
      throw Exception('通话不存在');
    }

    if (!accept) {
      await _signalRService.answerCall(
        AnswerCallRequest(callId: callId, accept: false),
      );
      _currentCall = null;
      _isInCall = false;
      notifyListeners();
      return;
    }

    await _signalRService.answerCall(
      AnswerCallRequest(callId: callId, accept: true),
    );
    await _connectToRoom(call);
    _isInCall = true;
    onCallAccepted?.call(call);
    notifyListeners();
  }

  Future<void> _connectCaller(Call call) async {
    try {
      await _connectToRoom(call);
      _isInCall = true;
      onCallAccepted?.call(call);
      notifyListeners();
    } catch (error) {
      _isInCall = false;
      onError?.call('连接媒体服务失败: $error');
      notifyListeners();
    }
  }

  Future<void> _connectToRoom(Call call) async {
    await _leaveRoom();
    final connection = await _apiService.createLiveKitToken(call.callId);
    await _signalRService.joinCall(call.callId);

    // Calls are strictly one-to-one, so both peers should subscribe to the
    // full remote media stream as soon as they join the room.
    final room = Room(
      roomOptions: const RoomOptions(adaptiveStream: false, dynacast: false),
    );
    _room = room;
    _roomListener = () {
      if (identical(_room, room)) notifyListeners();
    };
    room.addListener(_roomListener!);

    try {
      await room.connect(connection.url, connection.token);
      final participant = room.localParticipant;
      if (participant == null) throw Exception('媒体服务未返回本地参与者');
      await participant.setMicrophoneEnabled(true);
      if (call.callType == CallType.video) {
        await participant.setCameraEnabled(true);
      }
      notifyListeners();
    } catch (_) {
      await _leaveRoom();
      rethrow;
    }
  }

  Future<void> setMuted(bool muted) async {
    final participant = _room?.localParticipant;
    if (participant != null) await participant.setMicrophoneEnabled(!muted);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant != null) await participant.setCameraEnabled(enabled);
  }

  Future<void> setSpeakerphoneEnabled(bool enabled) {
    return Hardware.instance.setSpeakerphoneOn(enabled);
  }

  Future<void> endCall() async {
    final callId = _currentCall?.callId;
    await _leaveRoom();
    if (callId != null && callId.isNotEmpty) {
      await _signalRService.endCall(callId);
    }
    _currentCall = null;
    _isInCall = false;
    notifyListeners();
  }

  Future<void> _leaveRoom() async {
    final room = _room;
    final listener = _roomListener;
    _room = null;
    _roomListener = null;
    if (room == null) return;
    if (listener != null) room.removeListener(listener);
    await room.disconnect();
    room.dispose();
  }

  Future<void> disconnect() async {
    await _leaveRoom();
    await _signalRService.disconnect();
    _currentCall = null;
    _isInCall = false;
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_leaveRoom());
    super.dispose();
  }
}
