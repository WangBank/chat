import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import '../services/call_manager.dart';

class VideoCallPage extends StatefulWidget {
  final Call call;
  final CallManager callManager;

  const VideoCallPage({
    super.key,
    required this.call,
    required this.callManager,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isLocalVideoExpanded = false; // 新增：控制本地视频是否放大

  @override
  void initState() {
    super.initState();
    // 监听CallManager状态变化
    widget.callManager.addListener(_onCallManagerChanged);
  }

  @override
  void dispose() {
    // 移除监听器
    widget.callManager.removeListener(_onCallManagerChanged);
    super.dispose();
  }

  void _onCallManagerChanged() {
    // 如果通话结束，自动关闭页面
    if (widget.callManager.currentCall == null || !widget.callManager.isInCall) {
      print('📞 VideoCallPage: 检测到通话结束，自动关闭页面');
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 主视频流（根据状态显示本地或远程视频）
            _buildMainVideoStream(),

            // 小视频流（根据状态显示本地或远程视频）
            _buildSmallVideoStream(),

            // 顶部信息栏
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        try {
                          await widget.callManager.endCall();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          print('❌ 返回时结束通话失败: $e');
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.call.caller.nickname?.isNotEmpty == true
                                ? widget.call.caller.nickname!
                                : widget.call.caller.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '视频通话中...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 底部控制按钮
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 静音按钮
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.red : Colors.white,
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        // TODO: 实现静音功能
                      },
                    ),

                    // 摄像头开关按钮
                    _buildControlButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      color: _isCameraOff ? Colors.red : Colors.white,
                      onTap: () {
                        setState(() {
                          _isCameraOff = !_isCameraOff;
                        });
                        // TODO: 实现摄像头开关功能
                      },
                    ),

                    // 扬声器按钮
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: _isSpeakerOn ? Colors.white : Colors.grey,
                      onTap: () {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                        // TODO: 实现扬声器开关功能
                      },
                    ),

                    // 结束通话按钮
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onTap: () async {
                        try {
                          print('📞 用户点击结束通话');
                          await widget.callManager.endCall();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        } catch (e) {
                          print('❌ 结束通话失败: $e');
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
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

  // 构建主视频流
  Widget _buildMainVideoStream() {
    final isLocalMain = _isLocalVideoExpanded;
    final renderer = isLocalMain 
        ? widget.callManager.webRTCService.localRenderer
        : widget.callManager.webRTCService.remoteRenderer;

    if (renderer != null) {
      return RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    } else {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isLocalMain ? Icons.person : Icons.videocam_off,
                size: 80,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                isLocalMain ? '本地视频' : '等待对方视频...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // 构建小视频流
  Widget _buildSmallVideoStream() {
    final isLocalSmall = !_isLocalVideoExpanded;
    final renderer = isLocalSmall 
        ? widget.callManager.webRTCService.localRenderer
        : widget.callManager.webRTCService.remoteRenderer;

    return Positioned(
      top: 60,
      right: 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isLocalVideoExpanded = !_isLocalVideoExpanded;
          });
        },
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // 视频内容
                renderer != null
                    ? RTCVideoView(
                        renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            isLocalSmall ? Icons.person : Icons.videocam_off,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                
                // 点击提示覆盖层
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(
          icon,
          color: color,
          size: 28,
        ),
      ),
    );
  }
}
