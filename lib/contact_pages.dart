import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'user_profile_page.dart';

class Contact {
  final String name;
  final String phone;
  final String email;

  Contact({required this.name, required this.phone, required this.email});
}

final List<Contact> demoContacts = [
  Contact(name: '张三', phone: '13800138000', email: 'zhangsan@example.com'),
  Contact(name: '李四', phone: '13900139000', email: 'lisi@example.com'),
  Contact(name: '王五', phone: '13700137000', email: 'wangwu@example.com'),
];

class ContactListPage extends StatefulWidget {
  final bool isLoggedIn;
  final String? username;
  final String? email;
  final VoidCallback? onLogout;
  final String? avatarPath;
  const ContactListPage({super.key, this.isLoggedIn = false, this.username, this.email, this.onLogout, this.avatarPath});

  @override
  State<ContactListPage> createState() => _ContactListPageState();
}

class _ContactListPageState extends State<ContactListPage> {
  String _searchText = '';
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    _avatarPath = widget.avatarPath;
  }

  void _updateAvatar(String? newAvatar) {
    setState(() {
      _avatarPath = newAvatar;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = demoContacts.where((c) =>
      c.name.contains(_searchText) ||
      c.phone.contains(_searchText) ||
      c.email.contains(_searchText)
    ).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('love is life'),
        leading: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(
                  isLoggedIn: widget.isLoggedIn,
                  username: widget.username,
                  email: widget.email,
                  avatarPath: _avatarPath,
                ),
              ),
            );
            if (result is String && result.startsWith('assets/avatar')) {
              _updateAvatar(result);
            } else if (result == 'logout' && widget.onLogout != null) {
              widget.onLogout!();
            }
          },
          child: _avatarPath != null
              ? CircleAvatar(
                  backgroundImage: AssetImage(_avatarPath!),
                  radius: 20,
                )
              : const Icon(Icons.account_circle, size: 32, color: Colors.lightBlue),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索联系人',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim();
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredContacts.length,
              itemBuilder: (context, index) {
                final contact = filteredContacts[index];
                return ListTile(
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactDetailPage(contact: contact),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showDialog<Contact>(
            context: context,
            builder: (context) => const AddContactDialog(),
          );
          if (result != null) {
            setState(() {
              demoContacts.add(result);
            });
          }
        },
        tooltip: '新增联系人',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class ContactDetailPage extends StatelessWidget {
  final Contact contact;
  const ContactDetailPage({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(contact.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('姓名: ${contact.name}', style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 12),
                Text('电话: ${contact.phone}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                Text('邮箱: ${contact.email}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.video_call),
                  label: const Text('视频通话'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoCallPage(channelId: contact.phone),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(child: ChatBox(contact: contact)),
        ],
      ),
    );
  }
}

class ChatBox extends StatefulWidget {
  final Contact contact;
  const ChatBox({super.key, required this.contact});

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> {
  final List<String> _messages = [];
  final TextEditingController _controller = TextEditingController();
  String _searchText = '';

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _messages.add(text);
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredMessages = _searchText.isEmpty
        ? _messages
        : _messages.where((msg) => msg.contains(_searchText)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '搜索聊天记录',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value.trim();
              });
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: filteredMessages.length,
            itemBuilder: (context, index) {
              final msg = filteredMessages[filteredMessages.length - 1 - index];
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(msg),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 视频通话页面（agora演示）
class VideoCallPage extends StatefulWidget {
  final String channelId;
  const VideoCallPage({super.key, required this.channelId});

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  static const String appId = 'YOUR_AGORA_APP_ID'; // 替换为你的 Agora App ID
  static const String token = ""; // 若开启安全模式请填写 Token，否则留空字符串
  bool _joined = false;
  late RtcEngine _engine;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: appId));
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          setState(() {
            _joined = true;
          });
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          setState(() {});
        },
        onUserOffline: (connection, remoteUid, reason) {
          setState(() {});
        },
      ),
    );
    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.joinChannel(token: token, channelId: widget.channelId, uid: 0, options: const ChannelMediaOptions());
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('视频通话')),
      body: Center(
        child: _joined
            ? AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增联系人'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '姓名'),
          ),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: '电话'),
            keyboardType: TextInputType.phone,
          ),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: '邮箱'),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_nameController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty) {
              Navigator.pop(context, Contact(
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                email: _emailController.text.trim(),
              ));
            }
          },
          child: const Text('添加'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
