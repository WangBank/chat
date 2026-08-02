import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import '../services/signalr_service.dart';
import '../config/app_config.dart';

class ChatPage extends StatefulWidget {
  final Contact contact;
  final ApiService apiService;
  final CallManager? callManager;

  const ChatPage({
    super.key,
    required this.contact,
    required this.apiService,
    this.callManager,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqBlueSoft = Color(0xFFE8F6FF);
  static const Color _qqChat = Color(0xFFEEF4F8);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);
  static const Color _qqSentBubble = Color(0xFF95EC69);

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploading = false;
  bool _showEmojiPanel = false;
  late Contact _contact;
  OnUserOnlineStatusChangedCallback? _onlineStatusListener;
  static const List<String> _emojiOptions = [
    '😀',
    '😃',
    '😄',
    '😁',
    '😆',
    '😂',
    '🤣',
    '🙂',
    '🙃',
    '😊',
    '😇',
    '😍',
    '🤩',
    '😘',
    '🥰',
    '😗',
    '😙',
    '😚',
    '😋',
    '😛',
    '😜',
    '🤪',
    '😝',
    '🤑',
    '🤔',
    '🤨',
    '😐',
    '😑',
    '😶',
    '🙄',
    '😏',
    '😴',
    '😪',
    '🤤',
    '😷',
    '🤒',
    '🤕',
    '😎',
    '🥳',
    '😳',
    '🥺',
    '😢',
    '😭',
    '😤',
    '😡',
    '🤯',
    '😱',
    '😨',
    '😰',
    '😥',
    '😓',
    '🤗',
    '🤭',
    '🤫',
    '🤥',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '👌',
    '✌️',
    '🤞',
    '🤟',
    '🤘',
    '👊',
    '✊',
    '👋',
    '🤚',
    '🖐️',
    '✋',
    '🖖',
    '👀',
    '🤝',
    '❤️',
    '🧡',
    '💛',
    '💚',
    '💙',
    '💜',
    '🖤',
    '🤍',
    '🤎',
    '💔',
    '💕',
    '💖',
    '💗',
    '💓',
    '💞',
    '💘',
    '💝',
    '💌',
    '🎉',
    '🎊',
    '🎁',
    '🎂',
    '🍰',
    '🍭',
    '🍬',
    '🍓',
    '🍒',
    '🍉',
    '🍎',
    '🍋',
    '🍔',
    '🍟',
    '🍕',
    '☕',
    '🍵',
    '🍻',
    '🔥',
    '🌹',
    '🌷',
    '🌸',
    '🌻',
    '⭐',
    '✨',
    '⚡',
    '☁️',
    '🌈',
    '☀️',
    '🌙',
    '💯',
    '✅',
    '❌',
    '❗',
    '❓',
  ];

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _loadMessages();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    // 监听新消息
    if (widget.callManager != null) {
      _onlineStatusListener = (userId, isOnline) {
        if (!mounted || userId != _contact.contactUser.id) return;
        setState(() {
          _contact = _contact.copyWith(
            contactUser: _contact.contactUser.copyWith(isOnline: isOnline),
          );
        });
      };
      widget.callManager!.webRTCService.signalRService.addOnlineStatusListener(
        _onlineStatusListener!,
      );

      widget.callManager!.webRTCService.signalRService.onNewMessage =
          (message) {
        print('📨 收到新消息: ${message.content}');
        // 检查消息是否属于当前聊天
        if (message.senderId == _contact.contactUser.id ||
            message.receiverId == _contact.contactUser.id) {
          setState(() {
            _messages.add(message);
            if (message.receiverId == widget.apiService.currentUser?.id) {
              _contact = _contact.copyWith(unreadCount: 0);
            }
          });

          if (message.receiverId == widget.apiService.currentUser?.id) {
            unawaited(_markIncomingMessagesAsRead([message]));
          }

          // 滚动到底部
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      };

      // 监听通话相关事件
      widget.callManager!.webRTCService.signalRService.onIncomingCall = (call) {
        print('📞 在聊天页面收到来电: ${call.caller.username}');
        // 这里不需要做任何处理，主应用会自动处理来电显示
      };
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    // 清理消息监听器
    if (widget.callManager != null) {
      widget.callManager!.webRTCService.signalRService.onNewMessage = null;
      if (_onlineStatusListener != null) {
        widget.callManager!.webRTCService.signalRService
            .removeOnlineStatusListener(_onlineStatusListener!);
      }
    }

    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await widget.apiService.getChatHistory(_contact.id);
      setState(() {
        _messages = messages;
        _contact = _contact.copyWith(unreadCount: 0);
        _isLoading = false;
      });

      await _markIncomingMessagesAsRead(messages);

      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载消息失败: $e')));
      }
    }
  }

  Future<void> _markIncomingMessagesAsRead(List<ChatMessage> messages) async {
    final currentUserId = widget.apiService.currentUser?.id;
    if (currentUserId == null) return;

    final unreadIncomingMessages = messages
        .where(
          (message) => message.receiverId == currentUserId && !message.isRead,
        )
        .toList();
    if (unreadIncomingMessages.isEmpty) return;

    try {
      await Future.wait(
        unreadIncomingMessages.map(
          (message) => widget.apiService.markMessageAsRead(message.id),
        ),
      );
    } catch (_) {
      return;
    }

    if (!mounted) return;
    final readMessageIds =
        unreadIncomingMessages.map((message) => message.id).toSet();
    setState(() {
      _messages = _messages
          .map(
            (message) => readMessageIds.contains(message.id)
                ? message.copyWith(isRead: true)
                : message,
          )
          .toList();
      _contact = _contact.copyWith(unreadCount: 0);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _insertEmoji(String emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final nextText = text.replaceRange(start, end, emoji);
    final nextOffset = start + emoji.length;

    _messageController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }

  Future<void> _pickAndSendImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    await _uploadAndSendAttachment(
      File(image.path),
      preferredName: image.name,
      messageType: MessageType.image,
    );
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    final path = pickedFile.path;
    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法读取所选文件')));
      return;
    }

    final type = _isImageFileName(pickedFile.name)
        ? MessageType.image
        : MessageType.file;
    await _uploadAndSendAttachment(
      File(path),
      preferredName: pickedFile.name,
      messageType: type,
    );
  }

  Future<void> _uploadAndSendAttachment(
    File file, {
    required String preferredName,
    required MessageType messageType,
  }) async {
    if (_isUploading || _isSending) return;

    setState(() {
      _isUploading = true;
      _showEmojiPanel = false;
    });

    try {
      final upload = await widget.apiService.uploadChatFile(file);
      final content = preferredName.trim().isNotEmpty
          ? preferredName.trim()
          : upload.fileName;
      final newMessage = await widget.apiService.sendMessage(
        _contact.contactUser.id,
        content,
        messageType,
        filePath: upload.filePath,
        fileSize: upload.fileSize,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(newMessage);
        _isUploading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传发送失败: $e')));
    }
  }

  bool _isImageFileName(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.bmp');
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
      _showEmojiPanel = false;
    });

    try {
      print('📤 发送消息: $message 给用户: ${_contact.contactUser.id}');
      final newMessage = await widget.apiService.sendMessage(
        _contact.contactUser.id,
        message,
        MessageType.text,
      );

      print(
        '✅ 消息发送成功: senderId=${newMessage.senderId}, currentUserId=${widget.apiService.currentUser?.id}',
      );

      setState(() {
        _messages.add(newMessage);
        _isSending = false;
      });

      _messageController.clear();

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送消息失败: $e')));
      }
    }
  }

  String _displayName() {
    if (_contact.displayName?.isNotEmpty == true) {
      return _contact.displayName!;
    }
    if (_contact.contactUser.display_name?.isNotEmpty == true) {
      return _contact.contactUser.display_name!;
    }
    return _contact.contactUser.username;
  }

  String _initialForName(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildAvatar({
    required String name,
    String? avatarPath,
    bool isOnline = false,
    double radius = 20,
    bool showPresence = true,
  }) {
    final avatarUrl = AppConfig.resolveMediaUrl(avatarPath);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _qqBlue,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(
                  _initialForName(name),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.72,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : null,
        ),
        if (showPresence)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: isOnline ? _qqOnline : _qqOffline,
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComposerButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: active ? _qqBlue : const Color(0xFF4B5A68),
        style: IconButton.styleFrom(
          backgroundColor: active ? _qqBlueSoft : const Color(0xFFF1F5F8),
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signature = _contact.contactUser.signature?.trim();
    final displayName = _displayName();

    return Scaffold(
      backgroundColor: _qqChat,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(
              name: displayName,
              avatarPath: _contact.contactUser.avatarPath,
              isOnline: _contact.contactUser.isOnline,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle,
                          size: 8,
                          color: _contact.contactUser.isOnline
                              ? _qqOnline
                              : Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        _contact.contactUser.isOnline ? '在线' : '离线',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      if (signature?.isNotEmpty == true) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            signature!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              if (widget.callManager != null) {
                widget.callManager!.initiateCall(
                  _contact.contactUser,
                  CallType.voice,
                );
              }
            },
            tooltip: '语音通话',
          ),
          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {
              if (widget.callManager != null) {
                widget.callManager!.initiateCall(
                  _contact.contactUser,
                  CallType.video,
                );
              }
            },
            tooltip: '视频通话',
          ),
        ],
      ),
      body: Container(
        color: _qqChat,
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无消息',
                            style: TextStyle(
                              fontSize: 15,
                              color: _qqMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message.senderId ==
                                widget.apiService.currentUser?.id;
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top:
                        BorderSide(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_showEmojiPanel) _buildEmojiPanel(),
                    if (_isUploading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    Row(
                      children: [
                        _buildComposerButton(
                          icon: Icons.emoji_emotions_outlined,
                          tooltip: '表情',
                          active: _showEmojiPanel,
                          onPressed: _isUploading || _isSending
                              ? null
                              : () {
                                  setState(() {
                                    _showEmojiPanel = !_showEmojiPanel;
                                  });
                                },
                        ),
                        const SizedBox(width: 6),
                        _buildComposerButton(
                          icon: Icons.image_outlined,
                          tooltip: '发送图片',
                          onPressed: _isUploading || _isSending
                              ? null
                              : _pickAndSendImage,
                        ),
                        const SizedBox(width: 6),
                        _buildComposerButton(
                          icon: Icons.attach_file,
                          tooltip: '发送文件',
                          onPressed: _isUploading || _isSending
                              ? null
                              : _pickAndSendFile,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: '输入消息',
                              fillColor: Color(0xFFF3F6F9),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onTap: () {
                              if (_showEmojiPanel) {
                                setState(() {
                                  _showEmojiPanel = false;
                                });
                              }
                            },
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSending || _isUploading
                            ? const SizedBox(
                                width: 36,
                                height: 36,
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : SizedBox(
                                width: 38,
                                height: 38,
                                child: IconButton(
                                  onPressed: _sendMessage,
                                  icon:
                                      const Icon(Icons.send_rounded, size: 20),
                                  color: Colors.white,
                                  style: IconButton.styleFrom(
                                    backgroundColor: _qqBlue,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPanel() {
    return Container(
      height: 214,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        itemCount: _emojiOptions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemBuilder: (context, index) {
          final emoji = _emojiOptions[index];
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _insertEmoji(emoji),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final currentUser = widget.apiService.currentUser;
    final bubbleColor = isMe ? _qqSentBubble : Colors.white;
    final messageName = isMe
        ? (currentUser?.display_name?.isNotEmpty == true
            ? currentUser!.display_name!
            : currentUser?.username ?? '我')
        : _displayName();
    final avatarPath =
        isMe ? currentUser?.avatarPath : _contact.contactUser.avatarPath;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            _buildAvatar(
              name: messageName,
              avatarPath: avatarPath,
              isOnline: _contact.contactUser.isOnline,
              radius: 18,
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.68,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(message, isMe),
                      const SizedBox(height: 5),
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(color: _qqMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            _buildAvatar(
              name: messageName,
              avatarPath: avatarPath,
              isOnline: true,
              radius: 18,
              showPresence: false,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    if (message.type == MessageType.image && message.filePath != null) {
      return _buildImageContent(message, isMe);
    }

    if (message.type == MessageType.file && message.filePath != null) {
      return _buildFileContent(message, isMe);
    }

    return Text(
      message.content,
      style: const TextStyle(color: _qqText, fontSize: 16, height: 1.35),
    );
  }

  Widget _buildImageContent(ChatMessage message, bool isMe) {
    final imageUrl = AppConfig.resolveMediaUrl(message.filePath);
    if (imageUrl == null) {
      return _buildFileContent(message, isMe);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 220,
            height: 180,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox(
                width: 220,
                height: 180,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return SizedBox(
                width: 220,
                height: 120,
                child: Center(
                  child: Text(
                    '图片加载失败',
                    style: const TextStyle(color: _qqText),
                  ),
                ),
              );
            },
          ),
        ),
        if (message.content.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              message.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _qqText, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _buildFileContent(ChatMessage message, bool isMe) {
    final fileUrl = AppConfig.resolveMediaUrl(message.filePath);
    const textColor = _qqText;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: fileUrl == null
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: fileUrl));
              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('文件链接已复制')));
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: TextStyle(
                      color: _qqMuted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.month}-${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
