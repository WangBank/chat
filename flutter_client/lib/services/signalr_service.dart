import 'package:signalr_netcore/signalr_client.dart';
import '../models/call.dart';
import '../models/chat_message.dart';
import '../config/app_config.dart';
import 'dart:convert';

typedef OnIncomingCallCallback = void Function(Call call);
typedef OnCallAcceptedCallback = void Function(String callId);
typedef OnCallRejectedCallback = void Function(String callId);
typedef OnCallEndedCallback = void Function(String callId);
typedef OnOfferReceivedCallback = void Function(String callId, String offer, int senderId);
typedef OnAnswerReceivedCallback = void Function(String callId, String answer, int senderId);
typedef OnIceCandidateReceivedCallback = void Function(String callId, String candidate, int senderId);
typedef OnNewMessageCallback = void Function(ChatMessage message);

class SignalRService {
  static String get hubUrl => AppConfig.signalRUrl;
  
  HubConnection? _connection;
  int? _currentUserId; // 当前用户ID（用于日志）
  
  // 回调函数
  OnIncomingCallCallback? onIncomingCall;
  OnCallAcceptedCallback? onCallAccepted;
  OnCallRejectedCallback? onCallRejected;
  OnCallEndedCallback? onCallEnded;
  OnOfferReceivedCallback? onOfferReceived;
  OnAnswerReceivedCallback? onAnswerReceived;
  OnIceCandidateReceivedCallback? onIceCandidateReceived;
  OnNewMessageCallback? onNewMessage;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  // 连接到SignalR Hub
  Future<void> connect(String token) async {
    if (_connection != null && isConnected) {
      print('SignalR already connected');
      return;
    }

    try {
      _connection = HubConnectionBuilder()
          .withUrl(hubUrl, options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ))
          .withAutomaticReconnect()
          .build();

      // 新增：重连相关事件，确保重认证并恢复组关系
      _connection!.onreconnecting(({Exception? error}) {
        print('🔄 SignalR正在重连: $error');
      });
      _connection!.onreconnected(({String? connectionId}) {
        print('✅ SignalR重连成功: connectionId=$connectionId, 当前用户=$_currentUserId');
        final uid = _currentUserId;
        if (uid != null) {
          authenticate(uid).then((_) {
            print('🔐 重连后已重新认证用户: $uid');
          }).catchError((e) {
            print('❌ 重连后重新认证失败: $e');
          });
        } else {
          print('⚠️ 重连后无法重新认证：当前用户ID为空');
        }
      });
      _connection!.onclose(({Exception? error}) {
        print('🛑 SignalR连接关闭: $error');
      });

      // 设置事件监听器
      _setupEventListeners();

      await _connection!.start();
      print('SignalR connected successfully');
    } catch (e) {
      print('SignalR connection failed: $e');
      throw Exception('SignalR连接失败: $e');
    }
  }

  // 用户认证
  Future<void> authenticate(int userId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('Authenticate', args: [userId]);
      _currentUserId = userId;
      print('User authenticated: $userId');
    } catch (e) {
      print('Error authenticating user: $e');
      throw Exception('用户认证失败: $e');
    }
  }

  // 设置事件监听器
  void _setupEventListeners() {
    if (_connection == null) return;

    // 接收来电
    _connection!.on('IncomingCall', (arguments) {
      print('IncomingCall: $arguments');
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final call = Call.fromJson(data);
        print('Incoming call from: ${call.caller.username}');
        onIncomingCall?.call(call);
      } catch (e) {
        print('Error parsing incoming call: $e');
      }
    });

    // 通话被接受
    _connection!.on('CallAccepted', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        print('Call accepted: $callId');
        onCallAccepted?.call(callId);
      } catch (e) {
        print('Error parsing call accepted: $e');
      }
    });

    // 通话被拒绝
    _connection!.on('CallRejected', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
        print('Call rejected: $callId');
        onCallRejected?.call(callId);
      } catch (e) {
        print('Error parsing call rejected: $e');
      }
    });

    // 通话结束
    _connection!.on('CallEnded', (arguments) {
      print('CallEnded 11: $arguments');
      try {
        final dynamic arg0 = arguments?[0];
    
        String? callId;
        int? endedBy;
    
        Map<String, dynamic>? dataMap;
        if (arg0 is Map) {
          dataMap = Map<String, dynamic>.from(arg0 as Map);
        } else if (arg0 is String) {
          dataMap = Map<String, dynamic>.from(jsonDecode(arg0) as Map);
        }
    
        if (dataMap != null) {
          callId = dataMap['call_id'] as String?;
          final dynamic endedRaw = dataMap['endedBy'] ?? dataMap['EndedBy'] ?? dataMap['ended_by'];
          if (endedRaw is int) {
            endedBy = endedRaw;
          } else if (endedRaw is num) {
            endedBy = endedRaw.toInt();
          } else if (endedRaw is String) {
            endedBy = int.tryParse(endedRaw);
          }
        }
    
        print('📨 CallEnded事件: call_id=$callId, current_user=$_currentUserId, ended_by=$endedBy, raw=$arg0');
    
        if (callId != null) {
          onCallEnded?.call(callId);
        } else {
          print('⚠️ CallEnded负载缺少call_id，无法触发回调');
        }
      } catch (e) {
        print('❌ 解析CallEnded事件失败: $e, arguments=$arguments');
      }
    });

    // 接收WebRTC消息
    _connection!.on('WebRTCMessage', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        final callId = data['call_id'] as String;
    
        final dynamic typeVal = data['type'];
        final String type = typeVal is String
            ? typeVal
            : _webRTCTypeIntToString((typeVal as num).toInt());
    
        final messageData = data['data'] as String;
        final senderId = data['sender_id'] as int;
        
        print('Received WebRTC message: call=$callId, type=$type, sender_id=$senderId, current_user=$_currentUserId');
        
        switch (type) {
          case 'Offer':
            onOfferReceived?.call(callId, messageData, senderId);
            break;
          case 'Answer':
            onAnswerReceived?.call(callId, messageData, senderId);
            break;
          case 'IceCandidate':
            onIceCandidateReceived?.call(callId, messageData, senderId);
            break;
          default:
            print('Unknown WebRTC message type: $type');
        }
      } catch (e) {
        print('Error parsing WebRTC message: $e');
      }
    });

    // 接收新消息
    _connection!.on('NewMessage', (arguments) {
      try {
        final data = arguments?[0] as Map<String, dynamic>;
        print('Received new message: $data');
        
        final message = ChatMessage.fromJson(data);
        onNewMessage?.call(message);
      } catch (e) {
        print('Error parsing new message: $e');
      }
    });
  }

  // 发起通话
  Future<void> initiateCall(InitiateCallRequest request) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      final requestData = request.toJson();
      print('📤 发送InitiateCall请求: $requestData');
      await _connection!.invoke('InitiateCall', args: [requestData]);
      print('✅ Call initiated to user: ${request.receiverId}');
    } catch (e) {
      print('❌ Error initiating call: $e');
      throw Exception('发起通话失败: $e');
    }
  }

  // 应答通话
  Future<void> answerCall(AnswerCallRequest request) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('AnswerCall', args: [request.toJson()]);
      print('Call answered: ${request.callId}, accepted: ${request.accept}');
    } catch (e) {
      print('Error answering call: $e');
      throw Exception('应答通话失败: $e');
    }
  }

  // 结束通话
  Future<void> endCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('EndCall', args: [callId]);
      print('Call ended: $callId');
    } catch (e) {
      print('Error ending call: $e');
      throw Exception('结束通话失败: $e');
    }
  }

  // 发送WebRTC消息
  Future<void> sendWebRTCMessage(String callId, String type, String data, int receiverId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      final message = {
        'call_id': callId,
        // 用枚举数值发送，满足后端的绑定要求
        'type': _webRTCTypeToInt(type),
        'data': data,
        'receiver_id': receiverId,
      };
      await _connection!.invoke('SendWebRTCMessage', args: [message]);
      print('WebRTC message sent for call: $callId, type: $type');
    } catch (e) {
      print('Error sending WebRTC message: $e');
      throw Exception('发送WebRTC消息失败: $e');
    }
  }

  // 发送WebRTC Offer
  Future<void> sendOffer(WebRTCOffer offer, int receiverId) async {
    await sendWebRTCMessage(offer.callId, 'Offer', offer.offer, receiverId);
  }

  // 发送WebRTC Answer
  Future<void> sendAnswer(WebRTCAnswer answer, int receiverId) async {
    await sendWebRTCMessage(answer.callId, 'Answer', answer.answer, receiverId);
  }

  // 发送ICE Candidate
  Future<void> sendIceCandidate(WebRTCCandidate candidate, int receiverId) async {
    await sendWebRTCMessage(candidate.callId, 'IceCandidate', candidate.candidate, receiverId);
  }

  // 加入通话
  Future<void> joinCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('JoinCall', args: [callId]);
      print('Joined call: $callId');
    } catch (e) {
      print('Error joining call: $e');
      throw Exception('加入通话失败: $e');
    }
  }

  // 离开通话
  Future<void> leaveCall(String callId) async {
    if (!isConnected) throw Exception('SignalR未连接');
    
    try {
      await _connection!.invoke('LeaveCall', args: [callId]);
      print('Left call: $callId');
    } catch (e) {
      print('Error leaving call: $e');
      throw Exception('离开通话失败: $e');
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    try {
      if (_connection != null) {
        await _connection!.stop();
        _connection = null;
        print('SignalR disconnected');
      }
    } catch (e) {
      print('Error disconnecting SignalR: $e');
    }
  }

  // 清理资源
  void dispose() {
    disconnect();
    onIncomingCall = null;
    onCallAccepted = null;
    onCallRejected = null;
    onCallEnded = null;
    onOfferReceived = null;
    onAnswerReceived = null;
    onIceCandidateReceived = null;
    onNewMessage = null;
  }

  int _webRTCTypeToInt(String type) {
    switch (type) {
      case 'Offer':
        return 0;
      case 'Answer':
        return 1;
      case 'IceCandidate':
        return 2;
      case 'CallRequest':
        return 3;
      case 'CallResponse':
        return 4;
      case 'CallEnd':
        return 5;
      default:
        return 0;
    }
  }

  String _webRTCTypeIntToString(int value) {
    switch (value) {
      case 0:
        return 'Offer';
      case 1:
        return 'Answer';
      case 2:
        return 'IceCandidate';
      case 3:
        return 'CallRequest';
      case 4:
        return 'CallResponse';
      case 5:
        return 'CallEnd';
      default:
        return 'Offer';
    }
  }
}
