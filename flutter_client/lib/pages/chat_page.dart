import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const Color _qqBlue = Color(0xFF12A8F4);
  static const Color _qqBlueSoft = Color(0xFFE8F6FF);
  static const Color _qqChat = Color(0xFFEEF4F8);
  static const Color _qqText = Color(0xFF111820);
  static const Color _qqMuted = Color(0xFF8C96A3);
  static const Color _qqOnline = Color(0xFF20D67A);
  static const Color _qqOffline = Color(0xFFB8C0CB);
  static const Color _qqSentBubble = Color(0xFF95EC69);
  static const Duration _emojiTapDebounce = Duration(milliseconds: 250);
  static const Duration _sendDebounce = Duration(milliseconds: 800);
  static const Duration _messageMergeWindow = Duration(milliseconds: 1200);

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploading = false;
  bool _isRecordingVoice = false;
  bool _showEmojiPanel = false;
  int _voiceRecordSeconds = 0;
  ChatMessage? _replyingToMessage;
  late Contact _contact;
  OnUserOnlineStatusChangedCallback? _onlineStatusListener;
  Timer? _voiceTimer;
  DateTime? _voiceStartedAt;
  StreamSubscription<void>? _audioCompleteSubscription;
  String? _playingAudioUrl;
  String? _lastInsertedEmoji;
  DateTime? _lastEmojiInsertedAt;
  String? _lastSendSignature;
  DateTime? _lastSendStartedAt;
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
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playingAudioUrl = null;
      });
    });
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
          var added = false;
          setState(() {
            added = _upsertMessage(message);
            if (message.receiverId == widget.apiService.currentUser?.id) {
              _contact = _contact.copyWith(unreadCount: 0);
            }
          });

          if (message.receiverId == widget.apiService.currentUser?.id) {
            unawaited(_markIncomingMessagesAsRead([message]));
          }

          if (added) {
            _scrollToBottom();
          }
        }
      };

      // 通话事件由 WebRTCVideoService/CallManager 统一处理，聊天页不覆盖来电回调。
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _voiceTimer?.cancel();
    unawaited(_audioRecorder.dispose());
    unawaited(_audioCompleteSubscription?.cancel());
    unawaited(_audioPlayer.dispose());

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

  bool _upsertMessage(ChatMessage message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex >= 0) {
      _messages[existingIndex] = message;
      return false;
    }

    final duplicateIndex =
        _messages.indexWhere((item) => _isSameMessageDelivery(item, message));
    if (duplicateIndex >= 0) {
      _messages[duplicateIndex] = _preferMessageForDisplay(
        _messages[duplicateIndex],
        message,
      );
      return false;
    }

    _messages.add(message);
    return true;
  }

  bool _isSameMessageDelivery(ChatMessage existing, ChatMessage incoming) {
    final currentUserId = widget.apiService.currentUser?.id;
    if (currentUserId == null ||
        existing.senderId != currentUserId ||
        incoming.senderId != currentUserId) {
      return false;
    }

    if (existing.senderId != incoming.senderId ||
        existing.receiverId != incoming.receiverId ||
        existing.type != incoming.type ||
        existing.content != incoming.content ||
        existing.filePath != incoming.filePath ||
        existing.fileSize != incoming.fileSize ||
        existing.duration != incoming.duration) {
      return false;
    }

    final deltaMs =
        existing.timestamp.difference(incoming.timestamp).inMilliseconds.abs();
    return deltaMs <= _messageMergeWindow.inMilliseconds;
  }

  ChatMessage _preferMessageForDisplay(
    ChatMessage existing,
    ChatMessage incoming,
  ) {
    if (incoming.isRead && !existing.isRead) return incoming;
    if (incoming.timestamp.isAfter(existing.timestamp)) return incoming;
    return existing;
  }

  void _insertEmoji(String emoji) {
    final now = DateTime.now();
    final lastInsertedAt = _lastEmojiInsertedAt;
    if (_lastInsertedEmoji == emoji &&
        lastInsertedAt != null &&
        now.difference(lastInsertedAt) < _emojiTapDebounce) {
      return;
    }
    _lastInsertedEmoji = emoji;
    _lastEmojiInsertedAt = now;

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
    final pickedFile = await FilePicker.pickFile();
    if (pickedFile == null) return;

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

  Future<void> _toggleVoiceRecording() async {
    if (_isRecordingVoice) {
      await _stopAndSendVoiceRecording();
      return;
    }

    if (_isUploading || _isSending) return;

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请开启麦克风权限后再发送语音')));
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final filePath =
          '${tempDir.path}/voice_${now.millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      _voiceTimer?.cancel();
      _voiceStartedAt = now;
      setState(() {
        _isRecordingVoice = true;
        _voiceRecordSeconds = 0;
        _showEmojiPanel = false;
      });
      _voiceTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        final startedAt = _voiceStartedAt;
        if (!mounted || startedAt == null) return;
        setState(() {
          _voiceRecordSeconds =
              DateTime.now().difference(startedAt).inSeconds.clamp(1, 3600);
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _voiceRecordSeconds = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('录音失败: $e')));
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final startedAt = _voiceStartedAt;
    _voiceStartedAt = null;

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _voiceRecordSeconds = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('停止录音失败: $e')));
      return;
    }

    final duration = startedAt == null
        ? _voiceRecordSeconds.clamp(1, 3600)
        : DateTime.now().difference(startedAt).inSeconds.clamp(1, 3600);

    if (!mounted) return;
    setState(() {
      _isRecordingVoice = false;
      _voiceRecordSeconds = duration;
    });

    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有录到声音')));
      return;
    }

    await _uploadAndSendAttachment(
      File(path),
      preferredName: '语音消息 ${duration}s',
      messageType: MessageType.audio,
      duration: duration,
    );
  }

  Future<void> _playVoiceMessage(ChatMessage message) async {
    final audioUrl = AppConfig.resolveMediaUrl(message.filePath);
    if (audioUrl == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('语音文件不可用')));
      return;
    }

    try {
      if (_playingAudioUrl == audioUrl) {
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() {
          _playingAudioUrl = null;
        });
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(audioUrl));
      if (!mounted) return;
      setState(() {
        _playingAudioUrl = audioUrl;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _playingAudioUrl = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('语音播放失败: $e')));
    }
  }

  Future<void> _uploadAndSendAttachment(
    File file, {
    required String preferredName,
    required MessageType messageType,
    int? duration,
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
      final replyToMessageId = _replyingToMessage == null
          ? null
          : int.tryParse(_replyingToMessage!.id);
      final newMessage = await widget.apiService.sendMessage(
        _contact.contactUser.id,
        content,
        messageType,
        filePath: upload.filePath,
        fileSize: upload.fileSize,
        duration: duration,
        replyToMessageId: replyToMessageId,
      );

      if (!mounted) return;
      setState(() {
        _upsertMessage(newMessage);
        _replyingToMessage = null;
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

  Future<void> _showMessageActions(ChatMessage message) async {
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD6DCE2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('复制'),
              onTap: () => Navigator.of(context).pop('copy'),
            ),
            ListTile(
              leading: const Icon(Icons.shortcut_outlined),
              title: const Text('转发'),
              onTap: () => Navigator.of(context).pop('forward'),
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('引用'),
              onTap: () => Navigator.of(context).pop('reply'),
            ),
          ],
        ),
      ),
    );

    if (selectedAction == 'copy') {
      await _copyMessageContent(message);
    } else if (selectedAction == 'forward') {
      await _showForwardDialog(message);
    } else if (selectedAction == 'reply') {
      _startReply(message);
    }
  }

  Future<void> _copyMessageContent(ChatMessage message) async {
    final mediaUrl = AppConfig.resolveMediaUrl(message.filePath);
    final content = mediaUrl == null
        ? message.content
        : '${message.content.trim().isEmpty ? _messageTypeText(message.type) : message.content}\n$mediaUrl';
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有可复制的内容')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: trimmedContent));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制')));
  }

  void _startReply(ChatMessage message) {
    setState(() {
      _replyingToMessage = message;
      _showEmojiPanel = false;
    });
  }

  ReplyMessageSnapshot _replySnapshotForMessage(ChatMessage message) {
    return ReplyMessageSnapshot(
      id: int.tryParse(message.id),
      senderName: _messageSenderName(message),
      content: _replyPreviewText(message.content, message.type),
      type: message.type,
      filePath: message.filePath,
    );
  }

  String _messageSenderName(ChatMessage message) {
    final currentUser = widget.apiService.currentUser;
    if (message.senderId == currentUser?.id) {
      return currentUser?.display_name?.isNotEmpty == true
          ? currentUser!.display_name!
          : currentUser?.username ?? '我';
    }
    return _displayName();
  }

  String _replyPreviewText(String content, MessageType type) {
    final value = content.trim();
    switch (type) {
      case MessageType.image:
        return value.startsWith('[图片]') ? value : '[图片]';
      case MessageType.video:
        return value.startsWith('[视频]') ? value : '[视频]';
      case MessageType.audio:
        return value.startsWith('[语音]')
            ? value
            : value.isNotEmpty
                ? '[语音] $value'
                : '[语音]';
      case MessageType.file:
        return value.startsWith('[文件]')
            ? value
            : value.isNotEmpty
                ? '[文件] $value'
                : '[文件]';
      case MessageType.text:
        return value.isNotEmpty ? value : '[消息]';
    }
  }

  Future<void> _showForwardDialog(ChatMessage originalMessage) async {
    late final List<Contact> contacts;
    try {
      contacts = await widget.apiService.getContacts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载联系人失败: $e')));
      return;
    }

    if (!mounted) return;

    final selectedContactIds = <int>{};
    final searchController = TextEditingController();
    final noteController = TextEditingController();

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          var keyword = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredContacts = contacts.where((contact) {
                if (contact.isBlocked) return false;
                final query = keyword.trim().toLowerCase();
                if (query.isEmpty) return true;
                return contact.displayNameOrUsername
                        .toLowerCase()
                        .contains(query) ||
                    contact.contactUser.username.toLowerCase().contains(query);
              }).toList();

              return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 620),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '转发给',
                                style: TextStyle(
                                  color: _qqText,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '已选 ${selectedContactIds.length}',
                              style: const TextStyle(
                                color: _qqMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: '搜索联系人',
                            fillColor: Color(0xFFF3F6F9),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              keyword = value;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F8FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _forwardPreviewText(originalMessage),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _qqText,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: filteredContacts.isEmpty
                            ? const Center(
                                child: Text(
                                  '没有匹配联系人',
                                  style: TextStyle(color: _qqMuted),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: filteredContacts.length,
                                itemBuilder: (context, index) {
                                  final contact = filteredContacts[index];
                                  final selected =
                                      selectedContactIds.contains(contact.id);
                                  return CheckboxListTile(
                                    value: selected,
                                    onChanged: (_) {
                                      setDialogState(() {
                                        if (selected) {
                                          selectedContactIds.remove(contact.id);
                                        } else {
                                          selectedContactIds.add(contact.id);
                                        }
                                      });
                                    },
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    secondary: _buildAvatar(
                                      name: contact.displayNameOrUsername,
                                      avatarPath:
                                          contact.contactUser.avatarPath,
                                      isOnline: contact.contactUser.isOnline,
                                      radius: 18,
                                    ),
                                    title: Text(
                                      contact.displayNameOrUsername,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '@${contact.contactUser.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                        child: TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            hintText: '留言',
                            fillColor: Color(0xFFF3F6F9),
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: selectedContactIds.isEmpty
                                    ? null
                                    : () => Navigator.of(context).pop(true),
                                child: const Text('转发'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (confirmed == true) {
        await _forwardMessageToContacts(
          originalMessage,
          selectedContactIds,
          noteController.text.trim(),
          contacts,
        );
      }
    } finally {
      searchController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _forwardMessageToContacts(
    ChatMessage originalMessage,
    Set<int> selectedContactIds,
    String note,
    List<Contact> contacts,
  ) async {
    if (selectedContactIds.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _showEmojiPanel = false;
    });

    var successCount = 0;
    try {
      for (final contact in contacts) {
        if (!selectedContactIds.contains(contact.id)) continue;

        final forwardedMessage = await widget.apiService.sendMessage(
          contact.contactUser.id,
          _forwardContent(originalMessage),
          originalMessage.type,
          filePath: originalMessage.filePath,
          fileSize: originalMessage.fileSize,
          duration: originalMessage.duration,
        );
        successCount += 1;

        if (contact.id == _contact.id) {
          _upsertMessage(forwardedMessage);
        }

        if (note.isNotEmpty) {
          final noteMessage = await widget.apiService.sendMessage(
            contact.contactUser.id,
            note,
            MessageType.text,
          );
          if (contact.id == _contact.id) {
            _upsertMessage(noteMessage);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已转发给 $successCount 个联系人')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('转发失败: $e')));
    }
  }

  String _forwardContent(ChatMessage message) {
    final content = message.content.trim();
    return content.isNotEmpty ? content : _messageTypeText(message.type);
  }

  String _forwardPreviewText(ChatMessage message) {
    final content = _forwardContent(message);
    if (message.filePath == null) return content;
    return '$content\n${AppConfig.resolveMediaUrl(message.filePath) ?? message.filePath}';
  }

  String _messageTypeText(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.audio:
        return '[语音]';
      case MessageType.file:
        return '[文件]';
      case MessageType.text:
        return '';
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
    if (_isSending || _isUploading) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final sendSignature =
        '${_contact.contactUser.id}|text|${_replyingToMessage?.id ?? ''}|$message';
    final now = DateTime.now();
    final lastSendStartedAt = _lastSendStartedAt;
    if (_lastSendSignature == sendSignature &&
        lastSendStartedAt != null &&
        now.difference(lastSendStartedAt) < _sendDebounce) {
      return;
    }
    _lastSendSignature = sendSignature;
    _lastSendStartedAt = now;

    setState(() {
      _isSending = true;
      _showEmojiPanel = false;
    });

    try {
      print('📤 发送消息: $message 给用户: ${_contact.contactUser.id}');
      final replyToMessageId = _replyingToMessage == null
          ? null
          : int.tryParse(_replyingToMessage!.id);
      final newMessage = await widget.apiService.sendMessage(
        _contact.contactUser.id,
        message,
        MessageType.text,
        replyToMessageId: replyToMessageId,
      );

      print(
        '✅ 消息发送成功: senderId=${newMessage.senderId}, currentUserId=${widget.apiService.currentUser?.id}',
      );

      if (!mounted) return;
      setState(() {
        _upsertMessage(newMessage);
        _replyingToMessage = null;
        _isSending = false;
      });

      _messageController.clear();

      // 滚动到底部
      _scrollToBottom();
    } catch (e) {
      if (_lastSendSignature == sendSignature) {
        _lastSendSignature = null;
        _lastSendStartedAt = null;
      }
      if (!mounted) return;
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

  Widget _buildReplyCard(
    ReplyMessageSnapshot snapshot, {
    bool composer = false,
    VoidCallback? onClose,
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: composer ? 8 : 7),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: composer
            ? const Color(0xFFF3F7FA)
            : Colors.white.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: _qqBlue,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF176B9F),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyPreviewText(snapshot.content, snapshot.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF5F6975), fontSize: 12),
                ),
              ],
            ),
          ),
          if (onClose != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                tooltip: '取消引用',
                onPressed: onClose,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, size: 16),
                color: _qqMuted,
              ),
            ),
        ],
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
                    if (_isRecordingVoice)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _qqBlueSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: _qqBlue, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '正在录音 ${_voiceRecordSeconds.clamp(1, 3600)}"',
                                style: const TextStyle(
                                  color: _qqText,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => unawaited(
                                  _stopAndSendVoiceRecording()),
                              child: const Text('停止并发送'),
                            ),
                          ],
                        ),
                      ),
                    if (_replyingToMessage != null)
                      _buildReplyCard(
                        _replySnapshotForMessage(_replyingToMessage!),
                        composer: true,
                        onClose: () {
                          setState(() {
                            _replyingToMessage = null;
                          });
                        },
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
                        const SizedBox(width: 6),
                        _buildComposerButton(
                          icon: _isRecordingVoice
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_outlined,
                          tooltip: _isRecordingVoice ? '停止并发送语音' : '发送语音',
                          active: _isRecordingVoice,
                          onPressed: _isUploading || _isSending
                              ? null
                              : _toggleVoiceRecording,
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: () => _showMessageActions(message),
                  child: Container(
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
                        if (message.replyTo != null)
                          _buildReplyCard(message.replyTo!),
                        _buildMessageContent(message, isMe),
                        const SizedBox(height: 5),
                        Text(
                          _formatTime(message.timestamp),
                          style: const TextStyle(color: _qqMuted, fontSize: 11),
                        ),
                      ],
                    ),
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

    if (message.type == MessageType.audio && message.filePath != null) {
      return _buildVoiceContent(message, isMe);
    }

    return Text(
      message.content,
      style: const TextStyle(color: _qqText, fontSize: 16, height: 1.35),
    );
  }

  Widget _buildVoiceContent(ChatMessage message, bool isMe) {
    final audioUrl = AppConfig.resolveMediaUrl(message.filePath);
    final isPlaying = audioUrl != null && _playingAudioUrl == audioUrl;
    final duration = message.duration ?? 1;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => unawaited(_playVoiceMessage(message)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPlaying ? Icons.stop_circle_outlined : Icons.play_arrow_rounded,
            color: _qqBlue,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.graphic_eq, color: _qqBlue, size: 20),
          const SizedBox(width: 8),
          Text(
            '${duration.clamp(1, 3600)}"',
            style: const TextStyle(
              color: _qqText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
