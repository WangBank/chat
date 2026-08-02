import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../services/signalr_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class ProfilePage extends StatefulWidget {
  final ApiService apiService;
  final CallManager callManager;
  final VoidCallback onLogout;

  const ProfilePage({
    super.key,
    required this.apiService,
    required this.callManager,
    required this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqShell = Color(0xFFEFF7FC);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);

  User? _currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();
  late final OnUserOnlineStatusChangedCallback _onlineStatusListener;

  @override
  void initState() {
    super.initState();
    _onlineStatusListener = _handleOnlineStatusChanged;
    widget.callManager.webRTCService.signalRService.addOnlineStatusListener(
      _onlineStatusListener,
    );
    _loadUserProfile();
  }

  void _handleOnlineStatusChanged(int userId, bool isOnline) {
    if (!mounted) return;
    final currentUser = _currentUser ?? widget.apiService.currentUser;
    if (currentUser == null || currentUser.id != userId) return;

    final updatedUser = currentUser.copyWith(isOnline: isOnline);
    setState(() {
      _setCurrentUser(updatedUser, persist: false);
    });
  }

  void _setCurrentUser(User user, {bool persist = true}) {
    _currentUser = user;
    widget.apiService.setCurrentUser(user);
    widget.callManager.updateCurrentUser(user);
    if (persist) {
      unawaited(StorageService.saveUser(user));
    }
  }

  @override
  void dispose() {
    widget.callManager.webRTCService.signalRService.removeOnlineStatusListener(
      _onlineStatusListener,
    );
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = await widget.apiService.getUserProfile();
      setState(() {
        _setCurrentUser(user);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
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
        _setCurrentUser(updatedUser);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('头像上传成功')));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('头像上传失败: $e')));
      }
    }
  }

  Future<void> _updateProfile() async {
    final displayNamecontroller = TextEditingController(
      text: _currentUser?.display_name ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: displayNamecontroller,
          decoration: const InputDecoration(labelText: '昵称', hintText: '请输入昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(displayNamecontroller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    displayNamecontroller.dispose();

    if (result != null && result.isNotEmpty) {
      try {
        final updatedUser = await widget.apiService.updateProfile(
          display_name: result,
        );

        setState(() {
          _setCurrentUser(updatedUser);
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('昵称更新成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
        }
      }
    }
  }

  Future<void> _updateSignature() async {
    final signatureController = TextEditingController(
      text: _currentUser?.signature ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改个性签名'),
        content: TextField(
          controller: signatureController,
          maxLength: 100,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '个性签名',
            hintText: '写一句个性签名',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(signatureController.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    signatureController.dispose();

    if (result != null) {
      try {
        final updatedUser = await widget.apiService.updateProfile(
          signature: result,
        );
        if (!mounted) return;

        setState(() {
          _setCurrentUser(updatedUser);
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('个性签名更新成功')));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('更新失败: $e')));
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('密码修改成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('修改失败: $e')));
        }
      }
    }
  }

  Future<void> _bindQQ() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final updatedUser = await widget.apiService.qqDevBind(
        openId: 'dev_qq_profile_${user.id}',
        nickname: user.display_name?.isNotEmpty == true
            ? user.display_name
            : user.username,
      );

      if (!mounted) return;
      setState(() {
        _setCurrentUser(updatedUser);
        _isLoading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('QQ绑定成功')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('QQ绑定失败: $e')));
    }
  }

  Future<void> _updateAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
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
    final avatarUrl = AppConfig.resolveMediaUrl(
      _currentUser?.avatarPath ?? _currentUser?.qqAvatarUrl,
    );
    final displayName = _currentUser?.display_name?.trim().isNotEmpty == true
        ? _currentUser!.display_name!.trim()
        : _currentUser?.username ?? '';
    final signature = _currentUser?.signature?.trim().isNotEmpty == true
        ? _currentUser!.signature!.trim()
        : '未设置个性签名';

    return Scaffold(
      backgroundColor: _qqShell,
      appBar: AppBar(
        title: const Text('个人资料'),
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
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Colors.white,
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 18, 18, 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 38,
                                        backgroundColor: _qqBlue,
                                        backgroundImage: avatarUrl != null
                                            ? NetworkImage(avatarUrl)
                                            : null,
                                        child: avatarUrl == null
                                            ? Text(
                                                displayName.isNotEmpty
                                                    ? displayName[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: _currentUser!.isOnline
                                                ? _qqOnline
                                                : _qqOffline,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _qqText,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentUser!.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(color: _qqMuted),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          signature,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _qqText,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: _updateAvatar,
                                    icon:
                                        const Icon(Icons.photo_camera_outlined),
                                    tooltip: '修改头像',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            color: Colors.white,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit_outlined),
                                  title: const Text('修改昵称'),
                                  subtitle:
                                      Text(_currentUser!.display_name ?? '未设置'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _updateProfile,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      const Icon(Icons.format_quote_outlined),
                                  title: const Text('修改个性签名'),
                                  subtitle: Text(
                                    _currentUser!.signature
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? _currentUser!.signature!.trim()
                                        : '未设置',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _updateSignature,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: const Text('修改密码'),
                                  subtitle: const Text('点击修改登录密码'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _changePassword,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _qqBlue,
                                    backgroundImage:
                                        _currentUser!.qqAvatarUrl != null
                                            ? NetworkImage(
                                                AppConfig.resolveMediaUrl(
                                                      _currentUser!.qqAvatarUrl,
                                                    ) ??
                                                    _currentUser!.qqAvatarUrl!,
                                              )
                                            : null,
                                    child: _currentUser!.qqAvatarUrl == null
                                        ? const Text(
                                            'Q',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : null,
                                  ),
                                  title: const Text('QQ绑定'),
                                  subtitle: Text(
                                    _currentUser!.qqBound
                                        ? (_currentUser!.qqNickname
                                                    ?.trim()
                                                    .isNotEmpty ==
                                                true
                                            ? _currentUser!.qqNickname!.trim()
                                            : '已绑定 QQ')
                                        : '未绑定，绑定后可用 QQ 登录',
                                  ),
                                  trailing: TextButton(
                                    onPressed: _isLoading ? null : _bindQQ,
                                    child: Text(
                                      _currentUser!.qqBound ? '重新绑定' : '绑定',
                                    ),
                                  ),
                                  onTap: _isLoading ? null : _bindQQ,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      const Icon(Icons.photo_camera_outlined),
                                  title: const Text('修改头像'),
                                  subtitle: const Text('上传新的头像'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _updateAvatar,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            color: Colors.white,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.person_outline),
                                  title: const Text('用户名'),
                                  subtitle: Text(_currentUser!.username),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.email_outlined),
                                  title: const Text('邮箱'),
                                  subtitle: Text(_currentUser!.email),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: Icon(
                                    Icons.circle,
                                    color: _currentUser!.isOnline
                                        ? _qqOnline
                                        : _qqOffline,
                                    size: 18,
                                  ),
                                  title: const Text('在线状态'),
                                  subtitle: Text(
                                      _currentUser!.isOnline ? '在线' : '离线'),
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading:
                                      const Icon(Icons.access_time_outlined),
                                  title: const Text('注册时间'),
                                  subtitle: Text(
                                      _formatDate(_currentUser!.createdAt)),
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
