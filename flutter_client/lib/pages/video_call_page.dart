import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import '../services/call_manager.dart';
import '../models/user.dart';

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
  bool _hasPopped = false;

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

  void _safePop() {
    if (!mounted || _hasPopped) return;
    _hasPopped = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rootNav = Navigator.of(context, rootNavigator: true);
      if (rootNav.canPop()) {
        rootNav.pop();
      } else {
        rootNav.popUntil((route) => route.isFirst);
      }
    });
  }

  void _onCallManagerChanged() {
    // 如果通话结束，自动关闭页面
    if (widget.callManager.currentCall == null || !widget.callManager.isInCall) {
      print('📞 VideoCallPage: 检测到通话结束，自动关闭页面');
      _safePop();
    }
  }

  // 辅助：判断当前是否为主叫方、获取自己与对方的用户信息
  bool get _isCaller => widget.callManager.currentUser?.id == widget.call.caller.id;
  User get _selfUser => widget.callManager.currentUser ?? widget.call.caller;
  User get _otherUser => _isCaller ? widget.call.receiver : widget.call.caller;

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
                          // 不在此 pop，避免与监听器重复
                        } catch (e) {
                          print('❌ 结束通话失败: $e');
                          // 同样不在此 pop
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

  // 构建主视频流（根据_isLocalVideoExpanded切换本地/远端）
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
      // 视频未就绪时显示对应用户头像/首字母
      final user = isLocalMain ? _selfUser : _otherUser;
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user.avatarPath != null && user.avatarPath!.isNotEmpty)
                ClipOval(
                  child: Image.network(
                    user.avatarPath!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialAvatar(user);
                    },
                  ),
                )
              else
                _buildInitialAvatar(user),
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

  // 构建小视频流（显示与主视频相反的流，点击切换大小）
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
                renderer != null
                    ? RTCVideoView(
                        renderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: _buildInitialAvatar(isLocalSmall ? _selfUser : _otherUser),
                        ),
                      ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
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

  // 辅助：构建首字母头像
  Widget _buildInitialAvatar(User user) {
    final String initial = (user.nickname?.isNotEmpty == true
            ? user.nickname![0]
            : user.username.isNotEmpty
                ? user.username[0]
                : '?')
        .toUpperCase();
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
