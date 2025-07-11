import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/call.dart';
import '../services/api_service.dart';
import '../services/call_manager.dart';
import 'video_call_page.dart';

class ContactsPage extends StatefulWidget {
  final ApiService apiService;
  final CallManager callManager;

  const ContactsPage({
    super.key,
    required this.apiService,
    required this.callManager,
  });

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<User> _contacts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _usernameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _setupCallListener();
  }

  void _setupCallListener() {
    widget.callManager.addListener(() {
      // 如果有来电，显示通话页面
      if (widget.callManager.callState == CallState.ringing && 
          widget.callManager.currentCall != null) {
        _showVideoCallPage(widget.callManager.currentCall!, isIncoming: true);
      }
    });
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final contacts = await widget.apiService.getContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addContact() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    try {
      final newContact = await widget.apiService.addContact(username: username);
      setState(() {
        _contacts.add(newContact);
      });
      _usernameController.clear();
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加联系人: ${newContact.username}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加联系人失败: $e')),
      );
    }
  }

  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加联系人'),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: '用户名',
            hintText: '请输入用户名',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: _addContact,
            child: Text('添加'),
          ),
        ],
      ),
    );
  }

  void _initiateCall(User contact, CallType callType) async {
    try {
      await widget.callManager.initiateCall(contact, callType);
      _showVideoCallPage(widget.callManager.currentCall!);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发起通话失败: $e')),
      );
    }
  }

  void _showVideoCallPage(Call call, {bool isIncoming = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VideoCallPage(
          call: call,
          callManager: widget.callManager,
          isIncoming: isIncoming,
        ),
      ),
    );
  }

  void _showCallOptions(User contact) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '选择通话方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.videocam, color: Colors.blue),
              title: Text('视频通话'),
              onTap: () {
                Navigator.of(context).pop();
                _initiateCall(contact, CallType.video);
              },
            ),
            ListTile(
              leading: Icon(Icons.call, color: Colors.green),
              title: Text('语音通话'),
              onTap: () {
                Navigator.of(context).pop();
                _initiateCall(contact, CallType.audio);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('联系人'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add),
            onPressed: _showAddContactDialog,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadContacts,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadContacts,
              child: Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '暂无联系人',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '点击右上角添加联系人',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddContactDialog,
              icon: Icon(Icons.person_add),
              label: Text('添加联系人'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: contact.avatarUrl != null
                  ? NetworkImage(contact.avatarUrl!)
                  : null,
              child: contact.avatarUrl == null
                  ? Text(
                      contact.username[0].toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              contact.username,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(contact.email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 在线状态指示器
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: contact.isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                // 通话按钮
                IconButton(
                  icon: Icon(Icons.call, color: Colors.blue),
                  onPressed: () => _showCallOptions(contact),
                ),
              ],
            ),
            onTap: () => _showCallOptions(contact),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}
