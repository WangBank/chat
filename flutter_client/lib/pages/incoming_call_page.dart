import 'package:flutter/material.dart';
import '../models/call.dart';
import '../services/call_manager.dart';

class IncomingCallPage extends StatelessWidget {
  final Call call;
  final CallManager callManager;

  const IncomingCallPage({
    super.key,
    required this.call,
    required this.callManager,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: SafeArea(
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
            
            // 来电信息
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
              '来电...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            
            const Spacer(),
            
            // 操作按钮
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 拒绝按钮
                  GestureDetector(
                    onTap: () async {
                      print('📞 用户拒绝通话');
                      try {
                        await callManager.answerCall(call.callId, false);
                        // 拒绝通话后，CallManager会更新状态，主应用会自动隐藏来电界面
                      } catch (e) {
                        print('❌ 拒绝通话失败: $e');
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
                  
                  // 接听按钮
                  GestureDetector(
                    onTap: () async {
                      print('📞 用户接听通话');
                      try {
                        await callManager.answerCall(call.callId, true);
                        // 接听通话后，CallManager会更新状态，主应用会自动跳转到通话页面
                      } catch (e) {
                        print('❌ 接听通话失败: $e');
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: Icon(
                        call.callType == CallType.voice
                            ? Icons.call
                            : Icons.video_call,
                        color: Colors.white,
                        size: 40,
                      ),
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
}
