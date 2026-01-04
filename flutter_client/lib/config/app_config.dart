class AppConfig {
  // 根据平台和环境自动选择服务器地址
  static String get baseUrl {
    return 'http://common.wangbank.top:7001/api'; // 使用127.0.0.1，适用于Android模拟器
  }
  
  static String get signalRUrl {
    return baseUrl.replaceAll('/api', '/videocallhub');
  }
  
  
  // 开发环境辅助方法
  static String getLocalNetworkUrl(String ipAddress) {
    return 'http://$ipAddress:7001/api';
  }
  
}

// 使用示例和说明
class ConfigurationInstructions {
  static const String instructions = '''
手机应用访问配置说明：

1. 查找你的电脑IP地址：
   - macOS/Linux: 运行 `ifconfig | grep inet`
   - Windows: 运行 `ipconfig`
   - 例如：192.168.1.100

2. 确保防火墙允许端口7001的访问

3. 重新构建应用：
   flutter clean && flutter pub get && flutter run

4. 测试连接：
   在浏览器访问 http://你的IP:7001 确认服务器可访问

5. 如果在模拟器上测试：
   使用 'http://localhost:7001/api'
''';
}
