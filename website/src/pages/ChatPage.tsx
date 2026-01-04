import { useEffect, useState, useRef } from 'react';
import {
  Layout,
  List,
  Input,
  Button,
  Avatar,
  Badge,
  Drawer,
  Space,
  message,
  Modal,
  Form,
  Dropdown,
  type MenuProps,
} from 'antd';
import {
  MessageOutlined,
  PhoneOutlined,
  VideoCameraOutlined,
  UserAddOutlined,
  LogoutOutlined,
  SettingOutlined,
  EditOutlined,
  SearchOutlined,
  MoreOutlined,
  CloseOutlined,
} from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { chatStore } from '../stores/chat.store';
import { callStore } from '../stores/call.store';
import { authStore } from '../stores/auth.store';
import { CallType } from '../services/webrtc.service';
import { signalRService } from '../services/signalr.service';
import CallModal from '../components/CallModal';
import CallPage from './CallPage';
import { APP_CONFIG } from '../config/app.config';
import { formatTime } from '../utils/time.utils';
import '../styles/chat.css';
import '../styles/common.css';

const { Header, Content, Sider } = Layout;
const { TextArea } = Input;

const ChatPage = observer(() => {
  const navigate = useNavigate();
  const [messageText, setMessageText] = useState('');
  const [addContactVisible, setAddContactVisible] = useState(false);
  const [contactUsername, setContactUsername] = useState('');
  const [editDisplayNameVisible, setEditDisplayNameVisible] = useState(false);
  const [displayNameForm] = Form.useForm();
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!authStore.isAuthenticated) {
      navigate('/login');
      return;
    }

    // 确保SignalR连接
    const ensureSignalRConnection = async () => {
      if (!signalRService.isConnected && authStore.token && authStore.user) {
        try {
          await signalRService.connect(authStore.token);
          // authenticate会在connect后等待连接状态更新，所以这里直接调用
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR连接失败:', error);
          // 不显示错误，避免干扰用户，连接会在后台自动重试
        }
      } else if (signalRService.isConnected && authStore.user) {
        // 如果已连接但未认证，尝试认证
        try {
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR认证失败:', error);
        }
      }
    };

    ensureSignalRConnection();
    chatStore.loadContacts();
  }, [navigate]);

  useEffect(() => {
    // 当消息列表更新时，自动滚动到底部
    // 使用setTimeout确保DOM更新后再滚动
    const timer = setTimeout(() => {
      if (messagesEndRef.current) {
        messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
      }
    }, 100);
    return () => clearTimeout(timer);
  }, [chatStore.messages.length, messageText]);

  const handleSendMessage = async () => {
    console.log('chatStore.currentContact', chatStore.currentContact);
    if (!messageText.trim() || !chatStore.currentContact) return;

    const result = await chatStore.sendMessage(
      chatStore.currentContact.contact_user.id,
      messageText
    );
    if (result.success) {
      setMessageText('');
    } else {
      message.error(result.message || '发送失败');
    }
  };

  const handleAddContact = async () => {
    if (!contactUsername.trim()) {
      message.warning('请输入用户名');
      return;
    }

    const result = await chatStore.addContact(contactUsername);
    if (result.success) {
      message.success('添加联系人成功');
      setAddContactVisible(false);
      setContactUsername('');
    } else {
      message.error(result.message || '添加联系人失败');
    }
  };

  const handleInitiateCall = async (type: CallType) => {
    if (!chatStore.currentContact) return;

    // 检查对方是否在线
    if (!chatStore.currentContact.contact_user.is_online) {
      Modal.warning({
        title: '对方不在线',
        content: '对方当前不在线，无法发起通话。',
      });
      return;
    }

    try {
      await callStore.initiateCall(
        chatStore.currentContact.contact_user.id,
        type,
        chatStore.currentContact.contact_user // 传递接收者信息
      );
    } catch (error) {
      message.error('发起通话失败');
    }
  };

  const handleLogout = () => {
    Modal.confirm({
      title: '确认退出',
      content: '确定要退出登录吗？',
      okText: '确定',
      cancelText: '取消',
      onOk: async () => {
        await authStore.logout();
        navigate('/');
      },
    });
  };

  const handleCloseChat = () => {
    chatStore.setCurrentContact(null);
  };

  const handleUpdateDisplayName = async (values: { display_name: string }) => {
    if (!chatStore.currentContact) return;

    const result = await chatStore.updateDisplayName(
      chatStore.currentContact.id,
      values.display_name
    );
    if (result.success) {
      message.success('备注修改成功');
      setEditDisplayNameVisible(false);
      displayNameForm.resetFields();
    } else {
      message.error(result.message || '修改失败');
    }
  };



  const getAvatarUrl = (avatarPath?: string) => {
    if (avatarPath) {
      return `${APP_CONFIG.API_BASE_URL}${avatarPath}?t=${Date.now()}`;
    }
    return undefined;
  };

  const currentUserId = authStore.user?.id || 0;

  const contactMenuItems: MenuProps['items'] = [
    {
      key: 'edit-name',
      label: '修改备注',
      icon: <EditOutlined />,
      onClick: () => {
        if (chatStore.currentContact) {
          displayNameForm.setFieldsValue({
            display_name: chatStore.currentContact.display_name || '',
          });
          setEditDisplayNameVisible(true);
        }
      },
    },
    {
      key: 'search',
      label: '搜索聊天记录',
      icon: <SearchOutlined />,
      onClick: () => {
        if (chatStore.currentContact) {
          navigate(`/chat-history/${chatStore.currentContact.id}`);
        }
      },
    },
  ];

  return (
    <Layout style={{ height: '100vh' }}>
      <Sider width={300} theme="light" className="chat-sider">
        <div className="sider-header">
          <h2 style={{ margin: 0 }}>简聊</h2>
          <Space>
            <Button
              type="text"
              icon={<UserAddOutlined />}
              onClick={() => navigate('/contacts')}
              title="添加联系人"
            />
            <Button
              type="text"
              icon={<SettingOutlined />}
              onClick={() => navigate('/settings')}
              title="设置"
            />
            <Button type="text" icon={<LogoutOutlined />} onClick={handleLogout} title="退出" />
          </Space>
        </div>
        <div className="contacts-list-container">
          <List
            dataSource={chatStore.contacts}
            loading={chatStore.isLoading}
            renderItem={(contact) => (
              <List.Item
                className={`contact-item ${chatStore.currentContact?.id === contact.id ? 'active' : ''}`}
                onClick={() => chatStore.setCurrentContact(contact)}
              >
                <List.Item.Meta
                  avatar={
                    <Badge 
                      count={contact.unread_count} 
                      offset={[-5, 5]}
                      dot={contact.contact_user.is_online}
                    >
                      <Avatar src={getAvatarUrl(contact.contact_user.avatar_path)}>
                        {contact.contact_user.display_name?.[0] || contact.contact_user.username[0]}
                      </Avatar>
                    </Badge>
                  }
                  title={
                    <div className="contact-title">
                      {contact.display_name || contact.contact_user.display_name || contact.contact_user.username}
                    </div>
                  }
                  description={
                    <div className="contact-description">
                      {contact.last_message_at
                        ? formatTime(contact.last_message_at)
                        : '暂无消息'}
                    </div>
                  }
                />
              </List.Item>
            )}
            locale={{ emptyText: '暂无联系人' }}
          />
        </div>
      </Sider>

      <Layout>
        {chatStore.currentContact ? (
          <>
            <Header className="chat-header">
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <Space>
                  <Avatar src={getAvatarUrl(chatStore.currentContact.contact_user.avatar_path)}>
                    {chatStore.currentContact.contact_user.display_name?.[0] ||
                      chatStore.currentContact.contact_user.username[0]}
                  </Avatar>
                  <span>
                    {chatStore.currentContact.display_name ||
                      chatStore.currentContact.contact_user.display_name ||
                      chatStore.currentContact.contact_user.username}
                  </span>
                  {chatStore.currentContact.contact_user.is_online && (
                    <span style={{ color: '#52c41a', fontSize: '12px' }}>在线</span>
                  )}
                </Space>
                <Space>
                  <Button
                    type="text"
                    icon={<PhoneOutlined />}
                    onClick={() => handleInitiateCall(CallType.Voice)}
                    disabled={!chatStore.currentContact.contact_user.is_online}
                    title={chatStore.currentContact.contact_user.is_online ? '语音通话' : '对方不在线'}
                  />
                  <Button
                    type="text"
                    icon={<VideoCameraOutlined />}
                    onClick={() => handleInitiateCall(CallType.Video)}
                    disabled={!chatStore.currentContact.contact_user.is_online}
                    title={chatStore.currentContact.contact_user.is_online ? '视频通话' : '对方不在线'}
                  />
                  <Dropdown menu={{ items: contactMenuItems }} trigger={['click']}>
                    <Button type="text" icon={<MoreOutlined />} />
                  </Dropdown>
                  <Button
                    type="text"
                    icon={<CloseOutlined />}
                    onClick={handleCloseChat}
                    title="关闭聊天"
                  />
                </Space>
              </div>
            </Header>
            <Content className="chat-content">
              <div className="messages-container">
                {chatStore.messages.map((msg) => (
                  <div
                    key={msg.id}
                    className={`message-item ${msg.sender_id === currentUserId ? 'sent' : 'received'}`}
                  >
                    <div className="message-content">
                      <div className="message-text">{msg.content}</div>
                      <div className="message-time">{formatTime(msg.created_at)}</div>
                    </div>
                  </div>
                ))}
                <div ref={messagesEndRef} />
              </div>
              <div className="message-input">
                <TextArea
                  value={messageText}
                  onChange={(e) => setMessageText(e.target.value)}
                  onPressEnter={(e) => {
                    if (!e.shiftKey) {
                      e.preventDefault();
                      handleSendMessage();
                    }
                  }}
                  placeholder="输入消息..."
                  autoSize={{ minRows: 1, maxRows: 4 }}
                />
                <Button type="primary" onClick={handleSendMessage}>
                  发送
                </Button>
              </div>
            </Content>
          </>
        ) : (
          <div className="empty-chat">
            <MessageOutlined style={{ fontSize: 64, color: '#d9d9d9' }} />
            <p>选择一个联系人开始聊天</p>
          </div>
        )}
      </Layout>

      <Drawer
        title="添加联系人"
        open={addContactVisible}
        onClose={() => setAddContactVisible(false)}
      >
        <Input
          placeholder="输入用户名"
          value={contactUsername}
          onChange={(e) => setContactUsername(e.target.value)}
          onPressEnter={handleAddContact}
        />
        <Button type="primary" block style={{ marginTop: 16 }} onClick={handleAddContact}>
          添加
        </Button>
      </Drawer>

      <Modal
        title="修改备注"
        open={editDisplayNameVisible}
        onCancel={() => {
          setEditDisplayNameVisible(false);
          displayNameForm.resetFields();
        }}
        onOk={() => displayNameForm.submit()}
      >
        <Form form={displayNameForm} onFinish={handleUpdateDisplayName} layout="vertical">
          <Form.Item
            name="display_name"
            label="备注名称"
            rules={[{ max: 50, message: '备注名称不能超过50个字符' }]}
          >
            <Input placeholder="请输入备注名称" />
          </Form.Item>
        </Form>
      </Modal>


      <CallModal />
      <CallPage />

      {/* 版本号 */}
      <div className="version-badge">
        简聊 v{APP_CONFIG.VERSION}
      </div>
    </Layout>
  );
});

export default ChatPage;
