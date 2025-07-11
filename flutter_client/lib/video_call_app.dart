import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/signalr_service.dart';
import 'services/call_manager.dart';
import 'models/call.dart';
import 'pages/contacts_page.dart';
import 'pages/video_call_page.dart';
import 'pages/login_page.dart';

class VideoCallApp extends StatefulWidget {
  const VideoCallApp({super.key});

  @override
  State<VideoCallApp> createState() => _VideoCallAppState();
}

class _VideoCallAppState extends State<VideoCallApp> {
  late final ApiService _apiService;
  late final SignalRService _signalRService;
  late final CallManager _callManager;
  
  bool _isLoggedIn = false;
  String? _username;
  String? _email;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    _apiService = ApiService();
    _signalRService = SignalRService();
    _callManager = CallManager(_apiService, _signalRService);
    
    // 监听来电
    _callManager.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    if (_callManager.callState == CallState.ringing && 
        _callManager.currentCall != null &&
        _isLoggedIn) {
      // 显示来电界面
      _showIncomingCallDialog();
    }
  }

  void _showIncomingCallDialog() {
    final call = _callManager.currentCall!;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('来电'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: call.caller.avatarUrl != null
                  ? NetworkImage(call.caller.avatarUrl!)
                  : null,
              child: call.caller.avatarUrl == null
                  ? Text(
                      call.caller.username[0].toUpperCase(),
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            SizedBox(height: 16),
            Text(
              call.caller.username,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              call.callType == CallType.video ? '视频通话' : '语音通话',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 拒绝按钮
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _callManager.answerCall(false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Icon(Icons.call_end, size: 24),
              ),
              // 接受按钮
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _callManager.answerCall(true);
                  _showVideoCallPage(call, isIncoming: true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: CircleBorder(),
                  padding: EdgeInsets.all(16),
                ),
                child: Icon(Icons.call, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showVideoCallPage(call, {bool isIncoming = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoCallPage(
          call: call,
          callManager: _callManager,
          isIncoming: isIncoming,
        ),
      ),
    );
  }

  void _handleLoginResult(dynamic result) {
    if (result is Map && result['username'] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        setState(() {
          _isLoggedIn = true;
          _username = result['username'] as String?;
          _email = result['email'] as String?;
        });

        // 登录成功后连接SignalR
        if (_apiService.token != null) {
          try {
            await _signalRService.connect(_apiService.token!);
            print('SignalR connected successfully');
          } catch (e) {
            print('SignalR connection failed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('实时通信连接失败: $e')),
            );
          }
        }
      });
    }
  }

  void _handleLogout() async {
    // 断开SignalR连接
    await _signalRService.disconnect();
    
    // 清理API服务
    _apiService.logout();
    
    setState(() {
      _isLoggedIn = false;
      _username = null;
      _email = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forever Love Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.lightBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF6FB),
        useMaterial3: true,
      ),
      home: _isLoggedIn 
          ? ContactsPage(
              apiService: _apiService,
              callManager: _callManager,
            )
          : LoginPage(
              onLoginResult: _handleLoginResult,
            ),
    );
  }

  @override
  void dispose() {
    _callManager.removeListener(_onCallStateChanged);
    _callManager.dispose();
    _signalRService.dispose();
    super.dispose();
  }
}
