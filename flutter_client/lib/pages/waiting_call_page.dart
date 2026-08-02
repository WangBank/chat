import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/call.dart';
import '../services/call_manager.dart';

class WaitingCallPage extends StatefulWidget {
  final Call call;
  final CallManager callManager;

  const WaitingCallPage({
    super.key,
    required this.call,
    required this.callManager,
  });

  @override
  State<WaitingCallPage> createState() => _WaitingCallPageState();
}

class _WaitingCallPageState extends State<WaitingCallPage> {
  static const Color _callBackground = Color(0xFF0B1118);
  static const Color _callDanger = Color(0xFFFF3B30);

  bool _hasPopped = false;

  @override
  void initState() {
    super.initState();
    // 监听CallManager状态变化
    widget.callManager.addListener(_onCallManagerChanged);
  }

  @override
  void dispose() {
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
    print(
      '📞 WaitingCallPage收到状态变化: isInCall=${widget.callManager.isInCall}, isWaitingForAnswer=${widget.callManager.isWaitingForAnswer}',
    );

    // 如果通话已开始，等待MainApp处理页面跳转，不要主动pop
    if (widget.callManager.isInCall) {
      print('📞 WaitingCallPage: 通话已开始，等待MainApp处理页面跳转');
    } else if (!widget.callManager.isWaitingForAnswer &&
        widget.callManager.currentCall == null) {
      // 通话被拒绝或结束，关闭等待页面
      print('📞 WaitingCallPage: 通话结束或被拒绝，关闭等待页面');
      _safePop();
    } else {
      print('📞 WaitingCallPage: 继续等待');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _callBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // 本地视频流（呼叫者自己的视频）
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.callManager.webRTCService.localRenderer != null
                    ? RTCVideoView(
                        widget.callManager.webRTCService.localRenderer!,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Container(
                        color: Colors.grey[800],
                        child: const Center(
                          child: Icon(
                            Icons.videocam_off,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            // 通话信息
            Text(
              widget.call.receiver.display_name?.isNotEmpty == true
                  ? widget.call.receiver.display_name!
                  : widget.call.receiver.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.call.callType == CallType.voice ? '语音通话' : '视频通话',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '等待接听...',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 结束通话按钮
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: FloatingActionButton.large(
                heroTag: 'waiting-call-cancel',
                backgroundColor: _callDanger,
                foregroundColor: Colors.white,
                elevation: 0,
                onPressed: () async {
                  try {
                    await widget.callManager.endCall();
                    // 不在此 pop，交由监听器处理
                  } catch (e) {
                    print('❌ 取消通话失败: $e');
                    // 同样不在此 pop
                  }
                },
                child: const Icon(Icons.call_end, size: 36),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
