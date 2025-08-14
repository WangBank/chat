import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call_manager.dart';

class CallPage extends StatelessWidget {
  final Call call;
  final CallManager callManager;

  const CallPage({
    super.key,
    required this.call,
    required this.callManager,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // 头像
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: call.caller.avatarPath != null
                  ? ClipOval(
                      child: Image.network(
                        call.caller.avatarPath!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              (call.caller.nickname?.isNotEmpty == true
                                      ? call.caller.nickname![0]
                                      : call.caller.username[0])
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : Center(
                      child: Text(
                        (call.caller.nickname?.isNotEmpty == true
                                ? call.caller.nickname![0]
                                : call.caller.username[0])
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
            // 通话信息
            Text(
              call.caller.nickname?.isNotEmpty == true
                  ? call.caller.nickname!
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
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '通话中...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // 结束通话按钮
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: GestureDetector(
                onTap: () async {
                  print('📞 用户结束通话');
                  try {
                    await callManager.endCall();
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
