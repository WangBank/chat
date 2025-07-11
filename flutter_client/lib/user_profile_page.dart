import 'package:flutter/material.dart';

class UserProfilePage extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? email;
  final String? avatarPath;
  const UserProfilePage({super.key, this.isLoggedIn = false, this.username, this.email, this.avatarPath});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  String? _avatarPath;
  final List<String> _defaultAvatars = [
    'assets/avatar1.png',
    'assets/avatar2.png',
    'assets/avatar3.png',
    'assets/avatar4.png',
    'assets/avatar5.png',
    'assets/avatar6.png',
    'assets/avatar7.png',
    'assets/avatar8.png',
    'assets/avatar9.png',
    'assets/avatar10.png',
  ];

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.avatarPath;
  }

  void _pickAvatar() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 120),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择头像', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: _defaultAvatars.map((path) => GestureDetector(
                  onTap: () {
                    Navigator.pop(context, path);
                  },
                  child: CircleAvatar(
                    radius: 32,
                    backgroundImage: AssetImage(path),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('上传头像'),
                onPressed: () {
                  // 这里可集成 image_picker，演示用占位符
                  Navigator.pop(context, null);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _avatarPath = result;
      });
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人信息')),
      body: Center(
        child: widget.isLoggedIn
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.lightBlue[100],
                      backgroundImage: _avatarPath != null
                          ? AssetImage(_avatarPath!)
                          : null,
                      child: _avatarPath == null
                          ? const Icon(Icons.account_circle, size: 80, color: Colors.blueGrey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('昵称: ${widget.username ?? "未命名"}', style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 12),
                  Text('邮箱: ${widget.email ?? "未设置"}', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: context,
                        builder: (context) => const ChangePasswordDialog(),
                      );
                      if (result == 'changed') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改')));
                      }
                    },
                    child: const Text('修改密码'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, 'logout');
                    },
                    child: const Text('退出登录'),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_circle, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (context) => const LoginRegisterDialog(),
                      );
                      if (result != null && result['username'] != null) {
                        Navigator.pop(context, result);
                      }
                    },
                    child: const Text('登录/注册'),
                  ),
                ],
              ),
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _oldPwdController = TextEditingController();
  final TextEditingController _newPwdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _oldPwdController,
            decoration: const InputDecoration(labelText: '原密码'),
            obscureText: true,
          ),
          TextField(
            controller: _newPwdController,
            decoration: const InputDecoration(labelText: '新密码'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_oldPwdController.text.isNotEmpty && _newPwdController.text.isNotEmpty) {
              Navigator.pop(context, 'changed');
            }
          },
          child: const Text('确认修改'),
        ),
      ],
    );
  }
}

class LoginRegisterDialog extends StatefulWidget {
  const LoginRegisterDialog({super.key});

  @override
  State<LoginRegisterDialog> createState() => _LoginRegisterDialogState();
}

class _LoginRegisterDialogState extends State<LoginRegisterDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isLogin ? '登录' : '注册'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(labelText: '昵称'),
          ),
          if (!_isLogin)
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: '密码'),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          child: Text(_isLogin ? '去注册' : '去登录'),
        ),
        TextButton(
          onPressed: () {
            if (_usernameController.text.trim().isNotEmpty) {
              Navigator.pop(context, {
                'username': _usernameController.text.trim(),
                'email': _isLogin ? null : _emailController.text.trim(),
              });
            }
          },
          child: Text(_isLogin ? '登录' : '注册'),
        ),
      ],
    );
  }
}
