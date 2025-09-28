import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCDebug {
  static void logRendererState(String name, RTCVideoRenderer? renderer) {
    if (renderer == null) {
      print('🔍 $name: 渲染器为null');
      return;
    }
    
    try {
      final srcObject = renderer.srcObject;
      print('🔍 $name: 渲染器状态 - srcObject: ${srcObject != null ? "已设置" : "未设置"}');
    } catch (e) {
      print('🔍 $name: 渲染器状态检查失败 - $e');
    }
  }
  
  static void safeDisposeRenderer(String name, RTCVideoRenderer? renderer) {
    if (renderer == null) {
      print('🔍 $name: 渲染器已为null，无需释放');
      return;
    }
    
    try {
      // 先清除srcObject
      renderer.srcObject = null;
      
      // 等待一小段时间再释放
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          renderer.dispose();
          print('✅ $name: 渲染器释放成功');
        } catch (e) {
          print('❌ $name: 渲染器释放失败 - $e');
        }
      });
    } catch (e) {
      print('❌ $name: 渲染器释放失败 - $e');
    }
  }
  
  static Future<RTCVideoRenderer?> safeCreateRenderer(String name) async {
    try {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      print('✅ $name: 渲染器创建成功');
      return renderer;
    } catch (e) {
      print('❌ $name: 渲染器创建失败 - $e');
      return null;
    }
  }
}
