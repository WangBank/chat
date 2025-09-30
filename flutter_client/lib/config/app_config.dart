class AppConfig {
  // 根据平台和环境自动选择服务器地址
  static String get baseUrl {
    // 手机访问时需要使用电脑的实际IP地址
    // 步骤1: 运行 `ifconfig | grep inet` 查找你的IP地址
    // 步骤2: 将下面的 49.235.52.76 替换为你的IP地址
    
    // 示例：如果你的IP是 192.168.1.100，则改为：
    // return 'http://192.168.1.100:7001/api';
    
    // 如果在模拟器上测试，使用localhost
    // return 'http://localhost:7001/api';
    
    return 'http://49.235.52.76:7001/api'; // 使用127.0.0.1，适用于Android模拟器
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

2. 更新 AppConfig.baseUrl：
   将 'http://49.235.52.76:7001/api' 
   改为 'http://192.168.1.100:7001/api'

3. 确保防火墙允许端口7001的访问

4. 重新构建应用：
   flutter clean && flutter pub get && flutter run

5. 测试连接：
   在浏览器访问 http://你的IP:7001 确认服务器可访问

6. 如果在模拟器上测试：
   使用 'http://localhost:7001/api'
''';
}
