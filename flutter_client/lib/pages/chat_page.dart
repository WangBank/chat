import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../models/chat_message.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
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
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupMessageListener();
  }

  void _setupMessageListener() {
    // 监听新消息
    if (widget.callManager != null) {
      widget.callManager!.webRTCService.signalRService.onNewMessage = (message) {
        print('📨 收到新消息: ${message.content}');
        // 检查消息是否属于当前聊天
        if (message.senderId == widget.contact.contactUser.id || 
            message.receiverId == widget.contact.contactUser.id) {
          setState(() {
            _messages.add(message);
          });
          
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
    }
    
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final messages = await widget.apiService.getChatHistory(widget.contact.id);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载消息失败: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      print('📤 发送消息: $message 给用户: ${widget.contact.contactUser.id}');
      final newMessage = await widget.apiService.sendMessage(
        widget.contact.contactUser.id,
        message,
        MessageType.text,
      );

      print('✅ 消息发送成功: senderId=${newMessage.senderId}, currentUserId=${widget.apiService.currentUser?.id}');

      setState(() {
        _messages.add(newMessage);
        _isSending = false;
      });

      _messageController.clear();

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
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送消息失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              backgroundImage: widget.contact.contactUser.avatarPath != null
                  ? NetworkImage('${AppConfig.baseUrl}${widget.contact.contactUser.avatarPath!}')
                  : null,
              child: widget.contact.contactUser.avatarPath == null
                  ? Text(
                      (widget.contact.displayName?.isNotEmpty == true
                              ? widget.contact.displayName![0]
                              : (widget.contact.contactUser.nickname?.isNotEmpty == true
                                  ? widget.contact.contactUser.nickname![0]
                                  : widget.contact.contactUser.username[0]))
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contact.displayName?.isNotEmpty == true
                        ? widget.contact.displayName!
                        : (widget.contact.contactUser.nickname?.isNotEmpty == true
                            ? widget.contact.contactUser.nickname!
                            : widget.contact.contactUser.username),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: widget.contact.contactUser.isOnline ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.contact.contactUser.isOnline ? '在线' : '离线',
                        style: TextStyle(
                          color: widget.contact.contactUser.isOnline ? Colors.green : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              if (widget.callManager != null) {
                widget.callManager!.initiateCall(
                  widget.contact.contactUser,
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
                  widget.contact.contactUser,
                  CallType.video,
                );
              }
            },
            tooltip: '视频通话',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无消息',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == widget.apiService.currentUser?.id;
                          
                          // 调试信息
                          print('📱 消息显示: senderId=${message.senderId}, currentUserId=${widget.apiService.currentUser?.id}, isMe=$isMe');
                          
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
          ),
          
          // 输入框
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send),
                        color: Colors.blue,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    print('🎨 构建消息气泡: isMe=$isMe, content=${message.content}');
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
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