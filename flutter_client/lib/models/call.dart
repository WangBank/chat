import 'user.dart';

enum CallType {
  video,
  audio,
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
      callId: json['callId'] as String,
      caller: User.fromJson(json['caller'] as Map<String, dynamic>),
      receiver: User.fromJson(json['receiver'] as Map<String, dynamic>),
      callType: _parseCallType(json['callType'] as String),
      status: _parseCallStatus(json['status'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'callId': callId,
      'caller': caller.toJson(),
      'receiver': receiver.toJson(),
      'callType': _callTypeToString(callType),
      'status': _callStatusToString(status),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration,
    };
  }

  static CallType _parseCallType(String value) {
    switch (value.toLowerCase()) {
      case 'video':
        return CallType.video;
      case 'audio':
        return CallType.audio;
      default:
        return CallType.video;
    }
  }

  static CallStatus _parseCallStatus(String value) {
    switch (value.toLowerCase()) {
      case 'initiated':
        return CallStatus.initiated;
      case 'ringing':
        return CallStatus.ringing;
      case 'inprogress':
        return CallStatus.inProgress;
      case 'ended':
        return CallStatus.ended;
      case 'missed':
        return CallStatus.missed;
      case 'rejected':
        return CallStatus.rejected;
      default:
        return CallStatus.initiated;
    }
  }

  static String _callTypeToString(CallType type) {
    switch (type) {
      case CallType.video:
        return 'Video';
      case CallType.audio:
        return 'Audio';
    }
  }

  static String _callStatusToString(CallStatus status) {
    switch (status) {
      case CallStatus.initiated:
        return 'Initiated';
      case CallStatus.ringing:
        return 'Ringing';
      case CallStatus.inProgress:
        return 'InProgress';
      case CallStatus.ended:
        return 'Ended';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.rejected:
        return 'Rejected';
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
      'receiverId': receiverId,
      'callType': Call._callTypeToString(callType),
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
      'callId': callId,
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
