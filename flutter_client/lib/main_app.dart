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

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  static const String _voiceCallRouteName = '/call/voice';
  static const String _videoCallRouteName = '/call/video';
  static const String _waitingCallRouteName = '/call/waiting';
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqBlueDark = Color(0xFF078FDB);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);

  late ApiService _apiService;
  late SignalRService _signalRService;
  late WebRTCVideoService _webRTCService;
  late CallManager _callManager;

  User? _currentUser;
  int _currentIndex = 1; // 默认显示联系人页面
  int _contactsRefreshToken = 0; // 新增：联系人刷新令牌
  int _chatRefreshToken = 0; // 新增：聊天刷新令牌
  bool _showingIncomingCall = false; // 防止重复显示来电界面
  bool _restoringOnlinePresence = false;
  String? _visibleCallRouteName;
  String? _visibleCallId;

  // 全局NavigatorKey，用于在MaterialApp外部进行导航
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _checkStoredCredentials();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _restoreOnlinePresence();
    }
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

  Future<void> _restoreOnlinePresence() async {
    if (_restoringOnlinePresence || _currentUser == null) {
      return;
    }

    _restoringOnlinePresence = true;
    try {
      final token = _apiService.token ?? await StorageService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _callManager.ensureOnline(token);
      if (mounted) {
        setState(() {
          _contactsRefreshToken++;
          _chatRefreshToken++;
        });
      }
      print('✅ App回到前台，在线状态已恢复');
    } catch (e) {
      print('❌ App回到前台恢复在线状态失败: $e');
    } finally {
      _restoringOnlinePresence = false;
    }
  }

  void _onCallManagerChanged() {
    print(
      '🔄 MainApp收到CallManager状态变化: currentCall=${_callManager.currentCall?.callId}, isInCall=${_callManager.isInCall}, isWaitingForAnswer=${_callManager.isWaitingForAnswer}',
    );

    final currentCall = _callManager.currentCall;

    if (currentCall == null) {
      // 通话结束，隐藏所有通话相关界面
      if (_showingIncomingCall) {
        print('📞 通话结束，隐藏来电界面');
        _showingIncomingCall = false;
        setState(() {
          // 触发重建以隐藏来电界面
        });
      }

      // 关闭所有通话相关页面
      if (_navigatorKey.currentState != null) {
        print('📞 关闭所有通话相关页面');
        try {
          // 延迟执行，确保状态更新完成
          Future.delayed(const Duration(milliseconds: 200), () {
            _popVisibleCallRoutes();
          });
        } catch (e) {
          print('⚠️ 关闭通话页面时出错: $e');
        }
      }
      return;
    }

    if (_callManager.isInCall) {
      print(
        '📞 MainApp: 准备显示通话页面 - 当前状态: isInCall=${_callManager.isInCall}, isWaitingForAnswer=${_callManager.isWaitingForAnswer}',
      );
      if (_showingIncomingCall) {
        _showingIncomingCall = false;
        setState(() {
          // 触发重建以隐藏来电界面
        });
      }
      print('📞 MainApp: 立即执行显示通话页面');
      _showCallPage();
      return;
    }

    // 检查是否需要显示等待接听页面 (只有在不是通话中的情况下)
    if (_callManager.isWaitingForAnswer) {
      if (_showingIncomingCall) {
        _showingIncomingCall = false;
        setState(() {
          // 触发重建以隐藏来电界面
        });
      }
      print('📞 显示等待接听页面');
      _showWaitingCallPage();
      return;
    }

    // 当CallManager状态变化时，检查是否有来电
    if (!_showingIncomingCall) {
      print('📞 检测到来电，准备显示来电界面');
      _showingIncomingCall = true;
      setState(() {
        // 触发重建以显示来电界面
      });
    }
  }

  void _showCallPage() {
    final currentCall = _callManager.currentCall;
    if (currentCall != null) {
      print('📞 MainApp: 准备跳转到通话页面，通话类型: ${currentCall.callType}');

      // 根据通话类型显示不同的页面
      if (currentCall.callType == CallType.video) {
        print('📞 MainApp: 跳转到视频通话页面');
        _showUniqueCallRoute(
          routeName: _videoCallRouteName,
          callId: currentCall.callId,
          route: MaterialPageRoute(
            settings: const RouteSettings(name: _videoCallRouteName),
            builder: (context) =>
                VideoCallPage(call: currentCall, callManager: _callManager),
          ),
        );
      } else {
        print('📞 MainApp: 跳转到语音通话页面');
        _showUniqueCallRoute(
          routeName: _voiceCallRouteName,
          callId: currentCall.callId,
          route: MaterialPageRoute(
            settings: const RouteSettings(name: _voiceCallRouteName),
            builder: (context) =>
                CallPage(call: currentCall, callManager: _callManager),
          ),
        );
      }
    } else {
      print('⚠️ MainApp: 当前通话为null，无法跳转');
    }
  }

  void _showWaitingCallPage() {
    final currentCall = _callManager.currentCall;
    if (currentCall != null) {
      _showUniqueCallRoute(
        routeName: _waitingCallRouteName,
        callId: currentCall.callId,
        route: MaterialPageRoute(
          settings: const RouteSettings(name: _waitingCallRouteName),
          builder: (context) =>
              WaitingCallPage(call: currentCall, callManager: _callManager),
        ),
      );
    }
  }

  void _showUniqueCallRoute({
    required String routeName,
    required String callId,
    required Route<dynamic> route,
  }) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (_visibleCallRouteName == routeName && _visibleCallId == callId) {
      print('📞 MainApp: 通话页面已显示，跳过重复跳转: $routeName/$callId');
      return;
    }

    _visibleCallRouteName = routeName;
    _visibleCallId = callId;

    navigator.pushAndRemoveUntil(route, (route) => !_isCallRoute(route)).then(
      (_) {
        if (_visibleCallRouteName == routeName && _visibleCallId == callId) {
          _visibleCallRouteName = null;
          _visibleCallId = null;
        }
      },
    );
  }

  void _popVisibleCallRoutes() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    navigator.popUntil((route) => !_isCallRoute(route));
    _visibleCallRouteName = null;
    _visibleCallId = null;
  }

  bool _isCallRoute(Route<dynamic> route) {
    final routeName = route.settings.name;
    return routeName == _voiceCallRouteName ||
        routeName == _videoCallRouteName ||
        routeName == _waitingCallRouteName;
  }

  ThemeData _buildQqTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _qqBlue,
      primary: _qqBlue,
      secondary: _qqBlueDark,
      surface: Colors.white,
      error: const Color(0xFFFF3B30),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _qqShell,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _qqBlue,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _qqBlue,
        unselectedItemColor: Color(0xFF8C96A3),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700),
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F6FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? _qqBlue : const Color(0xFF8C96A3),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? _qqBlue : const Color(0xFF8C96A3),
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _qqBlue, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _qqBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _qqBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFF26323F),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: _qqText,
            displayColor: _qqText,
            fontFamily: 'Roboto',
          ),
    );
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
        theme: _buildQqTheme(),
        home: LoginPage(
          apiService: _apiService,
          onLoginSuccess: _onLoginSuccess,
        ),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey, // 添加全局NavigatorKey
      title: '聊天应用',
      theme: _buildQqTheme(),
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
                  refreshToken: _chatRefreshToken,
                ),
                // 联系人页面
                ContactsPage(
                  apiService: _apiService,
                  callManager: _callManager,
                  refreshToken: _contactsRefreshToken,
                ),
                // 个人资料页面
                ProfilePage(
                  apiService: _apiService,
                  callManager: _callManager,
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              // 新增：在切换到对应标签时递增令牌以触发刷新
              if (index == 1) {
                _contactsRefreshToken++; // 点击「联系人」令牌+1
              } else if (index == 0) {
                _chatRefreshToken++; // 点击「聊天」令牌+1
              }
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: '聊天',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: '联系人',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callManager.removeListener(_onCallManagerChanged);
    _callManager.disconnect();
    super.dispose();
  }
}
