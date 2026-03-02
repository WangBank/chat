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

    // Ensure SignalR connection
    const ensureSignalRConnection = async () => {
      if (!signalRService.isConnected && authStore.token && authStore.user) {
        try {
          await signalRService.connect(authStore.token);
          // authenticate waits for connection state after connect, so call directly here
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR connection failed:', error);
          // Keep silent to avoid disturbing users; reconnect will retry in background
        }
      } else if (signalRService.isConnected && authStore.user) {
        // Try authenticate if connected but not authenticated yet
        try {
          await signalRService.authenticate(authStore.user.id);
        } catch (error) {
          console.error('SignalR authentication failed:', error);
        }
      }
    };

    ensureSignalRConnection();
    chatStore.loadContacts();
  }, [navigate]);

  useEffect(() => {
    // Auto-scroll to bottom when message list updates
    // Use setTimeout to wait for DOM updates
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
      message.error(result.message || 'Failed to send');
    }
  };

  const handleAddContact = async () => {
    if (!contactUsername.trim()) {
      message.warning('Please enter a username');
      return;
    }

    const result = await chatStore.addContact(contactUsername);
    if (result.success) {
      message.success('Contact added successfully');
      setAddContactVisible(false);
      setContactUsername('');
    } else {
      message.error(result.message || 'Failed to add contact');
    }
  };

  const handleInitiateCall = async (type: CallType) => {
    if (!chatStore.currentContact) return;

    // Check whether recipient is online
    if (!chatStore.currentContact.contact_user.is_online) {
      Modal.warning({
        title: 'User Offline',
        content: 'The user is currently offline and cannot receive calls.',
      });
      return;
    }

    try {
      await callStore.initiateCall(
        chatStore.currentContact.contact_user.id,
        type,
        chatStore.currentContact.contact_user // Pass receiver info
      );
    } catch (error) {
      message.error('Failed to initiate call');
    }
  };

  const handleLogout = () => {
    Modal.confirm({
      title: 'Confirm Logout',
      content: 'Are you sure you want to log out?',
      okText: 'Confirm',
      cancelText: 'Cancel',
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
      message.success('Display name updated');
      setEditDisplayNameVisible(false);
      displayNameForm.resetFields();
    } else {
      message.error(result.message || 'Update failed');
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
      label: 'Edit Display Name',
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
      label: 'Search Chat History',
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
          <h2 style={{ margin: 0 }}>SimpleChat</h2>
          <Space>
            <Button
              type="text"
              icon={<UserAddOutlined />}
              onClick={() => navigate('/contacts')}
              title="Add Contact"
            />
            <Button
              type="text"
              icon={<SettingOutlined />}
              onClick={() => navigate('/settings')}
              title="Settings"
            />
            <Button type="text" icon={<LogoutOutlined />} onClick={handleLogout} title="Logout" />
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
                        : 'No messages yet'}
                    </div>
                  }
                />
              </List.Item>
            )}
            locale={{ emptyText: 'No contacts' }}
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
                    <span style={{ color: '#52c41a', fontSize: '12px' }}>Online</span>
                  )}
                </Space>
                <Space>
                  <Button
                    type="text"
                    icon={<PhoneOutlined />}
                    onClick={() => handleInitiateCall(CallType.Voice)}
                    disabled={!chatStore.currentContact.contact_user.is_online}
                    title={chatStore.currentContact.contact_user.is_online ? 'Voice Call' : 'User Offline'}
                  />
                  <Button
                    type="text"
                    icon={<VideoCameraOutlined />}
                    onClick={() => handleInitiateCall(CallType.Video)}
                    disabled={!chatStore.currentContact.contact_user.is_online}
                    title={chatStore.currentContact.contact_user.is_online ? 'Video Call' : 'User Offline'}
                  />
                  <Dropdown menu={{ items: contactMenuItems }} trigger={['click']}>
                    <Button type="text" icon={<MoreOutlined />} />
                  </Dropdown>
                  <Button
                    type="text"
                    icon={<CloseOutlined />}
                    onClick={handleCloseChat}
                    title="Close Chat"
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
                  placeholder="Type a message..."
                  autoSize={{ minRows: 1, maxRows: 4 }}
                />
                <Button type="primary" onClick={handleSendMessage}>
                  Send
                </Button>
              </div>
            </Content>
          </>
        ) : (
          <div className="empty-chat">
            <MessageOutlined style={{ fontSize: 64, color: '#d9d9d9' }} />
            <p>Select a contact to start chatting</p>
          </div>
        )}
      </Layout>

      <Drawer
        title="Add Contact"
        open={addContactVisible}
        onClose={() => setAddContactVisible(false)}
      >
        <Input
          placeholder="Enter username"
          value={contactUsername}
          onChange={(e) => setContactUsername(e.target.value)}
          onPressEnter={handleAddContact}
        />
        <Button type="primary" block style={{ marginTop: 16 }} onClick={handleAddContact}>
          Add
        </Button>
      </Drawer>

      <Modal
        title="Edit Display Name"
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
            label="Display Name"
            rules={[{ max: 50, message: 'Display name cannot exceed 50 characters' }]}
          >
            <Input placeholder="Enter display name" />
          </Form.Item>
        </Form>
      </Modal>


      <CallModal />
      <CallPage />

      {/* Version */}
      <div className="version-badge">
        SimpleChat v{APP_CONFIG.VERSION}
      </div>
    </Layout>
  );
});

export default ChatPage;
