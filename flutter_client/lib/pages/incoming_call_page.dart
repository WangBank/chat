import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call_manager.dart';
import '../config/app_config.dart';

class IncomingCallPage extends StatelessWidget {
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _callBackground = Color(0xFF0B1118);
  static const Color _callDanger = Color(0xFFFF3B30);
  static const Color _callAccept = Color(0xFF20D67A);

  final Call call;
  final CallManager callManager;

  const IncomingCallPage({
    super.key,
    required this.call,
    required this.callManager,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AppConfig.resolveMediaUrl(call.caller.avatarPath);

    return Material(
      color: _callBackground,
      child: SafeArea(
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

            // 来电信息
            Text(
              call.caller.display_name?.isNotEmpty == true
                  ? call.caller.display_name!
                  : call.caller.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              call.callType == CallType.voice ? '语音通话' : '视频通话',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),

            const SizedBox(height: 16),

            Text(
              '来电...',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),

            const Spacer(),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 拒绝按钮
                  FloatingActionButton.large(
                    heroTag: 'incoming-call-reject',
                    backgroundColor: _callDanger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: () async {
                      print('📞 用户拒绝通话');
                      try {
                        await callManager.answerCall(call.callId, false);
                        // 拒绝通话后，CallManager会更新状态，主应用会自动隐藏来电界面
                      } catch (e) {
                        print('❌ 拒绝通话失败: $e');
                      }
                    },
                    child: const Icon(Icons.call_end, size: 36),
                  ),

                  // 接听按钮
                  FloatingActionButton.large(
                    heroTag: 'incoming-call-accept',
                    backgroundColor: _callAccept,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    onPressed: () async {
                      print('📞 用户接听通话');
                      try {
                        await callManager.answerCall(call.callId, true);
                        // 接听通话后，CallManager会更新状态，主应用会自动跳转到通话页面
                      } catch (e) {
                        print('❌ 接听通话失败: $e');
                      }
                    },
                    child: Icon(
                      call.callType == CallType.voice
                          ? Icons.call
                          : Icons.video_call,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInitial() {
    final initial = (call.caller.display_name?.isNotEmpty == true
            ? call.caller.display_name![0]
            : call.caller.username[0])
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
