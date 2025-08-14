import 'user.dart';

enum CallType {
  voice,
  video,
}

enum CallStatus {
  initiated,
  ringing,
  inProgress,
  ended,
  missed,
  rejected,
}

class Call {
  final String callId;
  final User caller;
  final User receiver;
  final CallType callType;
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int? duration;

  Call({
    required this.callId,
    required this.caller,
    required this.receiver,
    required this.callType,
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      callId: json['call_id'] as String,
      caller: User.fromJson(json['caller'] as Map<String, dynamic>),
      receiver: User.fromJson(json['receiver'] as Map<String, dynamic>),
      callType: _parseCallType(json['call_type'] as int),
      status: _parseCallStatusFromDynamic(json['status']),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'caller': caller.toJson(),
      'receiver': receiver.toJson(),
      'call_type': _callTypeToInt(callType),
      'status': _callStatusToInt(status),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration': duration,
    };
  }

  static CallType _parseCallType(int value) {
    switch (value) {
      case 2:
        return CallType.video;
      case 1:
        return CallType.voice;
      default:
        return CallType.video;
    }
  }

  static CallStatus _parseCallStatus(int value) {
    switch (value) {
      case 1:
        return CallStatus.initiated;
      case 2:
        return CallStatus.ringing;
      case 3:
        return CallStatus.inProgress; // Answered in backend
      case 4:
        return CallStatus.rejected;
      case 5:
        return CallStatus.missed;
      case 6:
        return CallStatus.ended;
      case 7:
        return CallStatus.initiated; // Failed in backend, map to initiated
      default:
        return CallStatus.initiated;
    }
  }

  static CallStatus _parseCallStatusFromDynamic(dynamic value) {
    if (value is int) {
      return _parseCallStatus(value);
    } else if (value is String) {
      // 处理字符串类型的status（向后兼容）
      switch (value.toLowerCase()) {
        case 'initiated':
          return CallStatus.initiated;
        case 'ringing':
          return CallStatus.ringing;
        case 'answered':
        case 'inprogress':
          return CallStatus.inProgress;
        case 'rejected':
          return CallStatus.rejected;
        case 'missed':
          return CallStatus.missed;
        case 'ended':
          return CallStatus.ended;
        case 'failed':
          return CallStatus.initiated;
        default:
          return CallStatus.initiated;
      }
    } else {
      return CallStatus.initiated;
    }
  }

  static int _callTypeToInt(CallType type) {
    switch (type) {
      case CallType.video:
        return 2;
      case CallType.voice:
        return 1;
    }
  }

  static int _callStatusToInt(CallStatus status) {
    switch (status) {
      case CallStatus.initiated:
        return 1;
      case CallStatus.ringing:
        return 2;
      case CallStatus.inProgress:
        return 3;
      case CallStatus.rejected:
        return 4;
      case CallStatus.missed:
        return 5;
      case CallStatus.ended:
        return 6;
    }
  }



  Call copyWith({
    String? callId,
    User? caller,
    User? receiver,
    CallType? callType,
    CallStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? duration,
  }) {
    return Call(
      callId: callId ?? this.callId,
      caller: caller ?? this.caller,
      receiver: receiver ?? this.receiver,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }
}

class InitiateCallRequest {
  final int receiverId;
  final CallType callType;

  InitiateCallRequest({
    required this.receiverId,
    required this.callType,
  });

  Map<String, dynamic> toJson() {
    return {
      'receiver_id': receiverId,
      'call_type': Call._callTypeToInt(callType),
    };
  }
}

class AnswerCallRequest {
  final String callId;
  final bool accept;

  AnswerCallRequest({
    required this.callId,
    required this.accept,
  });

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'accept': accept,
    };
  }
}

class WebRTCOffer {
  final String callId;
  final String offer;

  WebRTCOffer({
    required this.callId,
    required this.offer,
  });

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'offer': offer,
    };
  }
}

class WebRTCAnswer {
  final String callId;
  final String answer;

  WebRTCAnswer({
    required this.callId,
    required this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'answer': answer,
    };
  }
}

class WebRTCCandidate {
  final String callId;
  final String candidate;

  WebRTCCandidate({
    required this.callId,
    required this.candidate,
  });

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'candidate': candidate,
    };
  }
}
