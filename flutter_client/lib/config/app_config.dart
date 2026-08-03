class AppConfig {
  static const String _defaultBaseUrl = 'https://chat.wangbank.top/api';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  static const String _configuredSignalRUrl = String.fromEnvironment(
    'SIGNALR_HUB_URL',
  );

  // 根据平台和环境自动选择服务器地址
  static String get baseUrl {
    return _configuredBaseUrl;
  }

  static String get serverUrl {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    if (normalizedBaseUrl.endsWith('/api')) {
      return normalizedBaseUrl.substring(0, normalizedBaseUrl.length - 4);
    }

    return normalizedBaseUrl;
  }

  static String? resolveMediaUrl(String? path) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '$serverUrl$value';
    }
    return '$serverUrl/$value';
  }

  static String get signalRUrl {
    if (_configuredSignalRUrl.isNotEmpty) {
      return _configuredSignalRUrl;
    }
    return '$serverUrl/videocallhub';
  }

  // 开发环境辅助方法
  static String getLocalNetworkUrl(String ipAddress) {
    return 'http://$ipAddress:17101/api';
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

2. 生产环境默认连接：
   https://chat.wangbank.top/api

3. 本地调试时确保防火墙允许端口17101的访问

4. 重新构建应用：
   flutter clean && flutter pub get && flutter run

5. 测试连接：
   在浏览器访问 http://你的IP:17101 确认服务器可访问

6. 如果在模拟器上测试本机后端：
   Android 使用 'http://10.0.2.2:17101/api'
   iOS 使用 'http://localhost:17101/api'
''';
}
