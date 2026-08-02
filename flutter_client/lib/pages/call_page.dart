import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call_manager.dart';
import '../config/app_config.dart';

class CallPage extends StatefulWidget {
  final Call call;
  final CallManager callManager;

  const CallPage({super.key, required this.call, required this.callManager});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  static const Color _qqBlue = Color(0xFF12A8F4);
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
    print('📞 CallPage: 状态变化 - isInCall=${widget.callManager.isInCall}');

    // 如果通话已结束，关闭页面
    if (!widget.callManager.isInCall &&
        widget.callManager.currentCall == null) {
      print('📞 CallPage: 通话已结束，关闭页面');
      _safePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AppConfig.resolveMediaUrl(widget.call.caller.avatarPath);

    return Scaffold(
      backgroundColor: _callBackground,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // 头像
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.9),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _qqBlue.withValues(alpha: 0.28),
                    blurRadius: 36,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: _qqBlue,
                child: avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildInitial(),
                        ),
                      )
                    : _buildInitial(),
              ),
            ),
            const SizedBox(height: 32),
            // 通话信息
            Text(
              widget.call.caller.display_name?.isNotEmpty == true
                  ? widget.call.caller.display_name!
                  : widget.call.caller.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.call.callType == CallType.voice ? '语音通话' : '视频通话',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              '通话中...',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            // 结束通话按钮
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: FloatingActionButton.large(
                heroTag: 'voice-call-end',
                backgroundColor: _callDanger,
                foregroundColor: Colors.white,
                elevation: 0,
                onPressed: () async {
                  print('📞 用户结束通话');
                  try {
                    await widget.callManager.endCall();
                    // 不再在此直接 pop，交由监听器统一处理
                  } catch (e) {
                    print('❌ 结束通话失败: $e');
                    // 保持一致，不在此 pop，避免重复导航
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

  Widget _buildInitial() {
    final initial = (widget.call.caller.display_name?.isNotEmpty == true
            ? widget.call.caller.display_name![0]
            : widget.call.caller.username[0])
        .toUpperCase();

    return Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 48,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
