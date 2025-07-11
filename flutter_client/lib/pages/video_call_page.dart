import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/call_manager.dart';
import '../models/call.dart';

class VideoCallPage extends StatefulWidget {
  final Call call;
  final CallManager callManager;
  final bool isIncoming;

  const VideoCallPage({
    super.key,
    required this.call,
    required this.callManager,
    this.isIncoming = false,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    
    // 监听通话管理器状态变化
    widget.callManager.addListener(_onCallStateChanged);
    
    // 如果是来电，显示接听界面
    if (widget.isIncoming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncomingCallDialog();
      });
    }
  }

  @override
  void dispose() {
    widget.callManager.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    if (mounted) {
      setState(() {});
      
      // 如果通话结束，关闭页面
      if (widget.callManager.callState == CallState.idle) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showIncomingCallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('来电'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: widget.call.caller.avatarUrl != null
                  ? NetworkImage(widget.call.caller.avatarUrl!)
                  : null,
              child: widget.call.caller.avatarUrl == null
                  ? Text(
                      widget.call.caller.username[0].toUpperCase(),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            SizedBox(height: 16),
            Text(
              widget.call.caller.username,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              widget.call.callType == CallType.video ? '视频通话' : '语音通话',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 拒绝按钮
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.callManager.answerCall(false);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Icon(Icons.call_end, size: 24),
              ),
              // 接受按钮
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.callManager.answerCall(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Icon(Icons.call, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 远程视频（全屏）
            if (widget.call.callType == CallType.video)
              Positioned.fill(
                child: Container(
                  child: widget.callManager.webRTCService.hasRemoteStream
                      ? RTCVideoView(widget.callManager.webRTCService.remoteRenderer)
                      : Container(
                          color: Colors.grey[900],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundImage: widget.call.receiver.avatarUrl != null
                                      ? NetworkImage(widget.call.receiver.avatarUrl!)
                                      : null,
                                  child: widget.call.receiver.avatarUrl == null
                                      ? Text(
                                          widget.call.receiver.username[0].toUpperCase(),
                                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  widget.call.receiver.username,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _getCallStatusText(widget.callManager.callState),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),

            // 本地视频（小窗口）
            if (widget.call.callType == CallType.video && widget.callManager.webRTCService.hasLocalStream)
              Positioned(
                top: 50,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: RTCVideoView(
                      widget.callManager.webRTCService.localRenderer,
                      mirror: true,
                    ),
                  ),
                ),
              ),

            // 顶部信息栏
            Positioned(
              top: 20,
              left: 20,
              right: widget.call.callType == CallType.video ? 160 : 20,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.call.receiver.avatarUrl != null
                          ? NetworkImage(widget.call.receiver.avatarUrl!)
                          : null,
                      child: widget.call.receiver.avatarUrl == null
                          ? Text(
                              widget.call.receiver.username[0].toUpperCase(),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.call.receiver.username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getCallStatusText(widget.callManager.callState),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部控制栏
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 麦克风开关
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        widget.callManager.toggleMicrophone();
                      },
                      backgroundColor: _isMuted ? Colors.red : Colors.white24,
                    ),

                    // 摄像头开关（仅视频通话）
                    if (widget.call.callType == CallType.video)
                      _buildControlButton(
                        icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                        onPressed: () {
                          setState(() {
                            _isCameraOff = !_isCameraOff;
                          });
                          widget.callManager.toggleCamera();
                        },
                        backgroundColor: _isCameraOff ? Colors.red : Colors.white24,
                      ),

                    // 切换摄像头（仅视频通话）
                    if (widget.call.callType == CallType.video)
                      _buildControlButton(
                        icon: Icons.flip_camera_ios,
                        onPressed: () {
                          widget.callManager.switchCamera();
                        },
                        backgroundColor: Colors.white24,
                      ),

                    // 扬声器开关
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      onPressed: () {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                        // TODO: 实现扬声器切换
                      },
                      backgroundColor: _isSpeakerOn ? Colors.blue : Colors.white24,
                    ),

                    // 挂断
                    _buildControlButton(
                      icon: Icons.call_end,
                      onPressed: () {
                        widget.callManager.endCall();
                        Navigator.of(context).pop();
                      },
                      backgroundColor: Colors.red,
                      size: 60,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    double size = 50,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }

  String _getCallStatusText(CallState state) {
    switch (state) {
      case CallState.initiating:
        return '正在发起通话...';
      case CallState.ringing:
        return '等待接听...';
      case CallState.connecting:
        return '正在连接...';
      case CallState.connected:
        return '通话中';
      case CallState.ending:
        return '正在结束通话...';
      default:
        return '';
    }
  }
}
