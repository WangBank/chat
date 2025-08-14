import 'package:flutter/material.dart';
import 'models/user.dart';
import 'models/call.dart';
import 'services/api_service.dart';
import 'services/signalr_service.dart';
import 'services/webrtc_video_service.dart';
import 'services/call_manager.dart';
import 'pages/login_page.dart';
import 'pages/chat_history_page.dart';
import 'pages/contacts_page.dart';
import 'pages/profile_page.dart';
import 'pages/incoming_call_page.dart';
import 'pages/call_page.dart';
import 'pages/waiting_call_page.dart';
import 'pages/video_call_page.dart';
import 'services/storage_service.dart';

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
  late WebRTCVideoService _webRTCService;
  late CallManager _callManager;
  
  User? _currentUser;
  int _currentIndex = 1; // 默认显示联系人页面
  bool _showingIncomingCall = false; // 防止重复显示来电界面
  
  // 全局NavigatorKey，用于在MaterialApp外部进行导航
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkStoredCredentials();
  }

  void _initializeServices() {
    _apiService = ApiService();
    _signalRService = SignalRService();
    _webRTCService = WebRTCVideoService(_signalRService);
    _callManager = CallManager(_webRTCService);
    
    // 监听CallManager状态变化
    _callManager.addListener(_onCallManagerChanged);
  }

  // 检查存储的登录凭据
  Future<void> _checkStoredCredentials() async {
    try {
      final hasCredentials = await StorageService.hasStoredCredentials();
      if (hasCredentials) {
        final user = await StorageService.getUser();
        final token = await StorageService.getToken();
        
        if (user != null && token != null) {
          print('🔍 发现存储的登录信息，尝试自动登录');
          // 设置API服务的token和用户
          _apiService.setToken(token);
          _apiService.setCurrentUser(user);
          
          // 尝试自动登录
          setState(() {
            _currentUser = user;
          });
          
          // 初始化WebRTC服务
          _callManager.initialize(token, user);
        }
      }
    } catch (e) {
      print('❌ 检查存储凭据失败: $e');
    }
  }

  void _onLoginSuccess(User user) async {
    setState(() {
      _currentUser = user;
    });
    
    // 设置API服务的用户
    _apiService.setCurrentUser(user);
    
    // 保存登录信息到本地存储
    try {
      await StorageService.saveLoginInfo(user, _apiService.token ?? '');
    } catch (e) {
      print('❌ 保存登录信息失败: $e');
    }
    
    // 初始化WebRTC服务
    _callManager.initialize(_apiService.token ?? '', user);
  }

  void _onCallManagerChanged() {
    print('🔄 CallManager状态变化: currentCall=${_callManager.currentCall?.callId}, isInCall=${_callManager.isInCall}, isWaitingForAnswer=${_callManager.isWaitingForAnswer}');
    
    // 当CallManager状态变化时，检查是否有来电
    if (_callManager.currentCall != null && !_callManager.isInCall && !_callManager.isWaitingForAnswer && !_showingIncomingCall) {
      print('📞 检测到来电，准备显示来电界面');
      _showingIncomingCall = true;
      setState(() {
        // 触发重建以显示来电界面
      });
    } else if (_callManager.currentCall == null) {
      // 通话结束，隐藏所有通话相关界面
      if (_showingIncomingCall) {
        print('📞 通话结束，隐藏来电界面');
        _showingIncomingCall = false;
        setState(() {
          // 触发重建以隐藏来电界面
        });
      }
    }
    
    // 检查是否需要显示通话页面
    if (_callManager.currentCall != null && _callManager.isInCall) {
      print('📞 显示通话页面');
      _showCallPage();
    }
    
    // 检查是否需要显示等待接听页面
    if (_callManager.currentCall != null && _callManager.isWaitingForAnswer) {
      print('📞 显示等待接听页面');
      _showWaitingCallPage();
    }
  }

  void _showCallPage() {
    if (_callManager.currentCall != null) {
      // 根据通话类型显示不同的页面
      if (_callManager.currentCall!.callType == CallType.video) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => VideoCallPage(
              call: _callManager.currentCall!,
              callManager: _callManager,
            ),
          ),
        );
      } else {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => CallPage(
              call: _callManager.currentCall!,
              callManager: _callManager,
            ),
          ),
        );
      }
    }
  }

  void _showWaitingCallPage() {
    if (_callManager.currentCall != null) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => WaitingCallPage(
            call: _callManager.currentCall!,
            callManager: _callManager,
          ),
        ),
      );
    }
  }



  void _onLogout() async {
    setState(() {
      _currentUser = null;
    });
    
    // 清除本地存储的登录信息
    try {
      await StorageService.clearAll();
    } catch (e) {
      print('❌ 清除本地存储失败: $e');
    }
    
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
      navigatorKey: _navigatorKey, // 添加全局NavigatorKey
      title: '聊天应用',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
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
            // 来电界面覆盖层
            if (_showingIncomingCall && _callManager.currentCall != null)
              IncomingCallPage(
                call: _callManager.currentCall!,
                callManager: _callManager,
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
    _callManager.removeListener(_onCallManagerChanged);
    _callManager.disconnect();
    super.dispose();
  }
} 