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

  void _onCallManagerChanged() {
    print('📞 WaitingCallPage收到状态变化: isInCall=${widget.callManager.isInCall}, isWaitingForAnswer=${widget.callManager.isWaitingForAnswer}');
    
    // 如果通话已开始，等待MainApp处理页面跳转，不要主动pop
    if (widget.callManager.isInCall) {
      print('📞 WaitingCallPage: 通话已开始，等待MainApp处理页面跳转');
      // 不要主动pop，让MainApp的pushReplacement来处理
    } else if (!widget.callManager.isWaitingForAnswer && widget.callManager.currentCall == null) {
      // 通话被拒绝或结束，关闭等待页面
      print('📞 WaitingCallPage: 通话结束或被拒绝，关闭等待页面');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      print('📞 WaitingCallPage: 继续等待');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
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
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
              widget.call.receiver.nickname?.isNotEmpty == true
                  ? widget.call.receiver.nickname!
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
              child: GestureDetector(
                onTap: () async {
                  print('📞 用户取消通话');
                  try {
                    await widget.callManager.endCall();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('❌ 取消通话失败: $e');
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
