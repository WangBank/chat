import 'package:flutter/material.dart';
import 'models/user.dart';
import 'services/api_service.dart';
import 'services/signalr_service.dart';
import 'services/webrtc_service.dart';
import 'services/call_manager.dart';
import 'pages/login_page.dart';
import 'pages/chat_history_page.dart';
import 'pages/contacts_page.dart';
import 'pages/profile_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late ApiService _apiService;
  late SignalRService _signalRService;
  late WebRTCService _webRTCService;
  late CallManager _callManager;
  
  User? _currentUser;
  int _currentIndex = 1; // 默认显示联系人页面

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _apiService = ApiService();
    _signalRService = SignalRService();
    _webRTCService = WebRTCService(_signalRService);
    _callManager = CallManager(_webRTCService);
  }

  void _onLoginSuccess(User user) {
    setState(() {
      _currentUser = user;
    });
    
    // 初始化WebRTC服务
    _callManager.initialize(_apiService.token ?? '', user);
  }

  void _onLogout() {
    setState(() {
      _currentUser = null;
    });
    
    // 断开WebRTC连接
    _callManager.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return MaterialApp(
        title: '聊天应用',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: LoginPage(
          apiService: _apiService,
          onLoginSuccess: _onLoginSuccess,
        ),
      );
    }

    return MaterialApp(
      title: '聊天应用',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            // 聊天历史页面
            ChatHistoryPage(
              apiService: _apiService,
              callManager: _callManager,
            ),
            // 联系人页面
            ContactsPage(
              apiService: _apiService,
              callManager: _callManager,
            ),
            // 个人资料页面
            ProfilePage(
              apiService: _apiService,
              onLogout: _onLogout,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label: '聊天',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: '联系人',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callManager.disconnect();
    super.dispose();
  }
} 