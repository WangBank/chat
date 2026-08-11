import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _qqLinkSubscription;
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const String _qqCallbackScheme = 'lovechat';
  static const String _qqCallbackHost = 'qq-callback';
  static const String _qqHttpsCallbackHost = 'chat.wangbank.top';
  static const String _qqHttpsCallbackPath = '/qq-callback';
  static const MethodChannel _qqChannel = MethodChannel('top.wangbank.chat/qq');

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _appLinks = AppLinks();
    _listenForQQCallbackLinks();
  }

  bool _isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true; // 记住登录状态
  String? _errorMessage;

  void _listenForQQCallbackLinks() {
    _qqLinkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingQQLink,
      onError: (error) {
        print('❌ QQ回调监听失败: $error');
      },
    );

    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleIncomingQQLink(uri);
      }
    }).catchError((error) {
      print('❌ 获取QQ初始回调失败: $error');
    });
  }

  void _handleIncomingQQLink(Uri uri) {
    final isCustomSchemeCallback =
        uri.scheme == _qqCallbackScheme && uri.host == _qqCallbackHost;
    final isHttpsAppLinkCallback = uri.scheme == 'https' &&
        uri.host == _qqHttpsCallbackHost &&
        uri.path == _qqHttpsCallbackPath;
    if (!isCustomSchemeCallback && !isHttpsAppLinkCallback) {
      return;
    }

    final error = uri.queryParameters['error_description'] ??
        uri.queryParameters['error'];
    if (error != null && error.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'QQ授权失败：$error';
        _isLoading = false;
      });
      return;
    }

    final code = uri.queryParameters['code'] ?? uri.queryParameters['qq_code'];
    final state =
        uri.queryParameters['state'] ?? uri.queryParameters['qq_state'];
    if (code == null || code.isEmpty || state == null || state.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'QQ授权回调缺少必要参数';
        _isLoading = false;
      });
      return;
    }

    _completeQQLogin(code: code, state: state);
  }

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final email = _emailController.text.trim();

    print('🔐 开始${_isLogin ? '登录' : '注册'}流程...');
    print(' 账号: $username');
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

          if (!_isLogin && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('注册成功，已自动登录'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }

          widget.onLoginSuccess?.call(user);
        } else {
          setState(() {
            _errorMessage = '登录信息缺失，请重试';
            _isLoading = false;
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

  Future<void> _handleQQLogin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loginUrlResponse = await _apiService.getQQLoginUrl();
      final loginUrlData = loginUrlResponse['data'];
      if (loginUrlResponse['success'] == true &&
          loginUrlData is Map<String, dynamic> &&
          loginUrlData['configured'] == true &&
          (loginUrlData['auth_url']?.toString().isNotEmpty ?? false)) {
        final authUrl = _withMobileQQHints(
          Uri.parse(loginUrlData['auth_url'].toString()),
        );
        final launched = await _launchQQAuthUrl(authUrl);
        if (!launched) {
          throw Exception('无法打开QQ授权页，请检查浏览器或QQ是否可用');
        }

        if (!mounted) return;
        setState(() {
          _errorMessage = '请在QQ授权页完成登录，授权完成后会自动返回 Love Chat。';
          _isLoading = false;
        });
        return;
      }

      if (loginUrlResponse['success'] != true ||
          loginUrlData is! Map<String, dynamic> ||
          loginUrlData['mock_available'] != true) {
        throw Exception(loginUrlResponse['message'] ?? 'QQ登录尚未配置');
      }

      final result = await _apiService.qqDevLogin();
      if (result['success'] == true && result['data']?['user'] != null) {
        final user = User.fromJson(result['data']['user']);
        if (_rememberMe) {
          await StorageService.saveLoginInfo(user, _apiService.token ?? '');
        }
        widget.onLoginSuccess?.call(user);
        return;
      }

      setState(() {
        _errorMessage = result['message'] ?? 'QQ登录失败';
        _isLoading = false;
      });
    } catch (e) {
      print('❌ QQ登录失败: $e');
      setState(() {
        var errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        }
        _errorMessage = errorMsg;
        _isLoading = false;
      });
    }
  }

  Uri _withMobileQQHints(Uri authUrl) {
    final query = Map<String, String>.from(authUrl.queryParameters);
    query.putIfAbsent('display', () => 'mobile');
    return authUrl.replace(queryParameters: query);
  }

  Future<bool> _launchQQAuthUrl(Uri authUrl) async {
    try {
      final launchedInNativeQQ = await _qqChannel.invokeMethod<bool>(
        'openQQAuthUrl',
        {'url': authUrl.toString()},
      );
      if (launchedInNativeQQ == true) {
        return true;
      }
    } catch (e) {
      print('⚠️ 手机QQ原生唤起不可用，继续尝试系统应用: $e');
    }

    try {
      final launchedInQQ = await launchUrl(
        authUrl,
        mode: LaunchMode.externalNonBrowserApplication,
      );
      if (launchedInQQ) {
        return true;
      }
    } catch (e) {
      print('⚠️ 未能直接唤起手机QQ，改用浏览器授权: $e');
    }

    return launchUrl(
      authUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _completeQQLogin({
    required String code,
    required String state,
  }) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.qqLogin(code: code, state: state);
      if (result['success'] == true && result['data']?['user'] != null) {
        final user = User.fromJson(result['data']['user']);
        if (_rememberMe) {
          await StorageService.saveLoginInfo(user, _apiService.token ?? '');
        }
        widget.onLoginSuccess?.call(user);
        return;
      }

      setState(() {
        _errorMessage = result['message'] ?? 'QQ登录失败';
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 完成QQ登录失败: $e');
      setState(() {
        var errorMsg = e.toString();
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
      backgroundColor: _qqShell,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                      decoration: const BoxDecoration(
                        color: _qqBlue,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Center(
                              child: Text(
                                'Q',
                                style: TextStyle(
                                  color: _qqBlue,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Love Chat',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '消息、好友和通话',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildModeButton('登录', true),
                                ),
                                Expanded(
                                  child: _buildModeButton('注册', false),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: _isLogin ? '用户名或邮箱' : '用户名',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            keyboardType: _isLogin
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                          ),
                          const SizedBox(height: 14),
                          if (!_isLogin) ...[
                            TextField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: '邮箱',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 14),
                          ],
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: '密码',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 10),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFFC4C4),
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(color: Color(0xFFD93025)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_isLogin)
                            CheckboxListTile(
                              value: _rememberMe,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                '保持登录',
                                style: TextStyle(color: _qqText, fontSize: 14),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _rememberMe = value ?? true;
                                });
                              },
                            ),
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: _qqBlue,
                              foregroundColor: Colors.white,
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isLogin ? '登录' : '注册',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                                _errorMessage = null;
                              });
                            },
                            child: Text(
                              _isLogin ? '没有账号？注册' : '已有账号？登录',
                              style: const TextStyle(
                                color: _qqBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_isLogin) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '其他登录方式',
                                    style: TextStyle(
                                      color: _qqMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withValues(alpha: 0.08),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: IconButton(
                                      tooltip: 'QQ登录',
                                      onPressed:
                                          _isLoading ? null : _handleQQLogin,
                                      icon: const Text(
                                        'Q',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      color: _qqBlue,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Color(0xFFDCE9F2),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'QQ',
                                    style: TextStyle(
                                      color: _qqMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, bool isLoginMode) {
    final active = _isLogin == isLoginMode;
    return TextButton(
      onPressed: () {
        setState(() {
          _isLogin = isLoginMode;
          _errorMessage = null;
        });
      },
      style: TextButton.styleFrom(
        backgroundColor: active ? Colors.white : Colors.transparent,
        foregroundColor: active ? _qqBlue : _qqMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  void dispose() {
    _qqLinkSubscription?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
