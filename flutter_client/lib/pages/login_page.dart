import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../services/storage_service.dart';

class LoginPage extends StatefulWidget {
  final Function(User user)? onLoginSuccess;
  final ApiService? apiService;

  const LoginPage({
    super.key,
    this.onLoginSuccess,
    this.apiService,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final ApiService _apiService;
  
  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
  }
  
  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true; // 记住登录状态
  String? _errorMessage;

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    print('🔐 开始${_isLogin ? '登录' : '注册'}流程...');
    print(' 用户名: $username');
    print('📧 邮箱: $email');

    if (username.isEmpty || password.isEmpty || (!_isLogin && email.isEmpty)) {
      setState(() {
        _errorMessage = '请填写所有必填字段';
      });
      return;
    }

    // 防止重复提交
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> result;
      
      if (_isLogin) {
        print('🚀 调用登录API...');
        result = await _apiService.login(
          username: username,
          password: password,
        );
        print('✅ 登录API调用完成');
      } else {
        print('🚀 调用注册API...');
        result = await _apiService.register(
          username: username,
          email: email,
          password: password,
        );
        print('✅ 注册API调用完成');
      }

      // 处理成功响应
      if (result['success'] == true && result['data'] != null) {
        if (_isLogin) {
          // 登录成功：获取token和用户信息
          final data = result['data'];
          if (data['user'] != null) {
            final user = User.fromJson(data['user']);
            
            // 如果选择记住登录状态，保存到本地存储
            if (_rememberMe) {
              try {
                await StorageService.saveLoginInfo(user, _apiService.token ?? '');
              } catch (e) {
                print('❌ 保存登录信息失败: $e');
              }
            }
            
            widget.onLoginSuccess?.call(user);
          }
        } else {
          // 注册成功：显示成功消息并切换到登录模式
          setState(() {
            _isLoading = false;
            _errorMessage = null;
          });
          
          // 显示成功消息
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('注册成功！请使用新账号登录'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // 清空密码字段，切换到登录模式
          _passwordController.clear();
          setState(() {
            _isLogin = true;
          });
        }
      } else {
        // 处理响应格式错误
        setState(() {
          _errorMessage = '操作失败，请重试';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ ${_isLogin ? '登录' : '注册'}失败: $e');
      setState(() {
        // 移除Exception前缀，只显示错误信息
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo 和标题
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.video_call,
                      size: 64,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Forever Love Chat',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '高质量视频通话应用',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // 登录/注册表单
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isLogin ? '登录' : '注册',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // 用户名输入框
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: '用户名',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 邮箱输入框（仅注册时显示）
                    if (!_isLogin)
                      Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: '邮箱',
                              prefixIcon: const Icon(Icons.email),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // 密码输入框
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),

                    // 错误消息
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 记住登录状态（仅登录时显示）
                    if (_isLogin)
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? true;
                              });
                            },
                          ),
                          const Text('记住登录状态'),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // 提交按钮
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isLogin ? '登录' : '注册',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // 切换登录/注册模式
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        });
                      },
                      child: Text(
                        _isLogin ? '没有账号？点击注册' : '已有账号？点击登录',
                        style: TextStyle(color: Colors.blue[600]),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 测试账号提示
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '测试账号',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'testuser1 / 123\ntestuser2 / 123',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
