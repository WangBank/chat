import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class ProfilePage extends StatefulWidget {
  final ApiService apiService;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.apiService,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await widget.apiService.getUserProfile();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadAvatar(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        await _uploadAvatar(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    }
  }

  Future<void> _uploadAvatar(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final updatedUser = await widget.apiService.uploadAvatar(imageFile);
      
      setState(() {
        _currentUser = updatedUser;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传成功')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    final nicknameController = TextEditingController(text: _currentUser?.nickname ?? '');
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入昵称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(nicknameController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final updatedUser = await widget.apiService.updateProfile(
          nickname: result,
        );
        
        setState(() {
          _currentUser = updatedUser;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('昵称更新成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPasswordController,
              decoration: const InputDecoration(
                labelText: '当前密码',
                hintText: '请输入当前密码',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(
                labelText: '新密码',
                hintText: '请输入新密码',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop({
              'oldPassword': oldPasswordController.text,
              'newPassword': newPasswordController.text,
            }),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await widget.apiService.changePassword(
          oldPassword: result['oldPassword']!,
          newPassword: result['newPassword']!,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码修改成功')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('修改失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _updateAvatar() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.of(context).pop();
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onLogout();
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showLogoutDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('加载失败: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserProfile,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _currentUser == null
                  ? const Center(child: Text('用户信息为空'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // 头像和基本信息
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _currentUser!.avatarPath != null
                                        ? NetworkImage('${AppConfig.baseUrl}${_currentUser!.avatarPath!}')
                                        : null,
                                    child: _currentUser!.avatarPath == null
                                        ? Text(
                                            (_currentUser!.nickname?.isNotEmpty == true
                                                ? _currentUser!.nickname![0]
                                                : _currentUser!.username[0]).toUpperCase(),
                                            style: const TextStyle(fontSize: 32),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _currentUser!.nickname ?? _currentUser!.username,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _currentUser!.email,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 功能列表
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('修改昵称'),
                                  subtitle: Text(_currentUser!.nickname ?? '未设置'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: _updateProfile,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock),
                                  title: const Text('修改密码'),
                                  subtitle: const Text('点击修改登录密码'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: _changePassword,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.photo_camera),
                                  title: const Text('修改头像'),
                                  subtitle: const Text('上传新的头像'),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: _updateAvatar,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // 账户信息
                          Card(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person),
                                  title: const Text('用户名'),
                                  subtitle: Text(_currentUser!.username),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.email),
                                  title: const Text('邮箱'),
                                  subtitle: Text(_currentUser!.email),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.circle),
                                  title: const Text('在线状态'),
                                  subtitle: Text(_currentUser!.isOnline ? '在线' : '离线'),
                                  trailing: Icon(
                                    Icons.circle,
                                    color: _currentUser!.isOnline ? Colors.green : Colors.grey,
                                    size: 16,
                                  ),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.access_time),
                                  title: const Text('注册时间'),
                                  subtitle: Text(_formatDate(_currentUser!.createdAt)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 