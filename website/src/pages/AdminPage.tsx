import { useEffect, useState } from 'react';
import { Layout, Table, Card, Statistic, Row, Col, Button, message, Input, Tabs, Modal, Form, Space, Popover, Descriptions, Tag } from 'antd';
import { UserOutlined, LogoutOutlined, ReloadOutlined, KeyOutlined, InfoCircleOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { adminStore } from '../stores/admin.store';
import { authStore } from '../stores/auth.store';
import { APP_CONFIG } from '../config/app.config';
import { apiService } from '../services/api.service';
import { formatTime, formatFullTime } from '../utils/time.utils';
import '../styles/common.css';

const { Header, Content } = Layout;
const { Search } = Input;

const AdminPage = observer(() => {
  const navigate = useNavigate();
  const [searchText, setSearchText] = useState('');
  const [activeTab, setActiveTab] = useState('all');
  const [changePasswordModalVisible, setChangePasswordModalVisible] = useState(false);
  const [selectedUser, setSelectedUser] = useState<any>(null);
  const [changePasswordForm] = Form.useForm();

  useEffect(() => {
    // Check admin access
    if (!authStore.isAuthenticated) {
      message.error('Please log in first');
      navigate('/login');
      return;
    }

    if (authStore.user?.username !== APP_CONFIG.ADMIN_USERNAME) {
      message.warning('You do not have permission to access admin page');
      navigate('/chat');
      return;
    }

    adminStore.loadOnlineUsers();
    adminStore.loadAllUsers();
  }, [navigate]);

  const handleLogout = async () => {
    await authStore.logout();
    navigate('/');
  };

  const handleRefresh = () => {
    if (activeTab === 'online') {
      adminStore.loadOnlineUsers();
    } else {
      adminStore.loadAllUsers();
    }
    message.success('Refreshed successfully');
  };

  const handleChangePassword = (user: any) => {
    // Do not allow changing admin password
    if (user.username === APP_CONFIG.ADMIN_USERNAME) {
      message.warning('Changing admin password is not allowed');
      return;
    }
    setSelectedUser(user);
    setChangePasswordModalVisible(true);
    changePasswordForm.resetFields();
  };

  const renderUserDetail = (user: any) => {
    return (
      <Descriptions column={1} size="small" style={{ width: 300 }}>
        <Descriptions.Item label="User ID">{user.id}</Descriptions.Item>
        <Descriptions.Item label="Username">{user.username}</Descriptions.Item>
        <Descriptions.Item label="Email">{user.email}</Descriptions.Item>
        <Descriptions.Item label="Nickname">{user.display_name || '-'}</Descriptions.Item>
        <Descriptions.Item label="Status">
          <Tag color={user.is_online ? 'success' : 'default'}>
            {user.is_online ? 'Online' : 'Offline'}
          </Tag>
        </Descriptions.Item>
        <Descriptions.Item label="Last Login">
          {user.last_login_at ? formatFullTime(user.last_login_at) : '-'}
        </Descriptions.Item>
        <Descriptions.Item label="Created At">
          {formatFullTime(user.created_at)}
        </Descriptions.Item>
        <Descriptions.Item label="Updated At">
          {formatFullTime(user.updated_at)}
        </Descriptions.Item>
        {user.avatar_path && (
          <Descriptions.Item label="Avatar">
            <img
              src={`${APP_CONFIG.API_BASE_URL}${user.avatar_path}`}
              alt="Avatar"
              style={{ width: 50, height: 50, borderRadius: 4 }}
            />
          </Descriptions.Item>
        )}
      </Descriptions>
    );
  };

  const handleChangePasswordSubmit = async () => {
    try {
      const values = await changePasswordForm.validateFields();
      const response = await apiService.adminChangeUserPassword(selectedUser.id, values.new_password);
      if (response.success) {
        message.success('Password changed successfully');
        setChangePasswordModalVisible(false);
        changePasswordForm.resetFields();
      } else {
        message.error(response.message || 'Failed to change password');
      }
    } catch (error: any) {
      message.error(error.message || 'Failed to change password');
    }
  };

  const createColumns = (showActions: boolean = true) => [
    {
      title: 'ID',
      dataIndex: 'id',
      key: 'id',
      width: 80,
    },
    {
      title: 'Username',
      dataIndex: 'username',
      key: 'username',
    },
    {
      title: 'Email',
      dataIndex: 'email',
      key: 'email',
    },
    {
      title: 'Nickname',
      dataIndex: 'display_name',
      key: 'display_name',
    },
    {
      title: 'Status',
      dataIndex: 'is_online',
      key: 'is_online',
      render: (isOnline: boolean) => (
        <span style={{ color: isOnline ? '#52c41a' : '#999' }}>
          {isOnline ? 'Online' : 'Offline'}
        </span>
      ),
    },
    {
      title: 'Last Login',
      dataIndex: 'last_login_at',
      key: 'last_login_at',
      render: (time: string) => (time ? formatTime(time) : '-'),
    },
    {
      title: 'Created At',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time: string) => formatTime(time),
    },
    ...(showActions ? [{
      title: 'Actions',
      key: 'action',
      width: 180,
      render: (_: any, record: any) => (
        <Space>
          <Popover
            content={renderUserDetail(record)}
            title="User Details"
            trigger="click"
            placement="left"
          >
            <Button
              type="link"
              icon={<InfoCircleOutlined />}
              size="small"
            >
              Details
            </Button>
          </Popover>
          {record.username !== APP_CONFIG.ADMIN_USERNAME && (
            <Button
              type="link"
              icon={<KeyOutlined />}
              onClick={() => handleChangePassword(record)}
              size="small"
            >
              Change Password
            </Button>
          )}
        </Space>
      ),
    }] : []),
  ];

  const filteredAllUsers = adminStore.allUsers.filter((user) => {
    if (!searchText) return true;
    const searchLower = searchText.toLowerCase();
    return (
      user.username.toLowerCase().includes(searchLower) ||
      user.email.toLowerCase().includes(searchLower) ||
      (user.display_name && user.display_name.toLowerCase().includes(searchLower))
    );
  });

  const filteredOnlineUsers = adminStore.onlineUsers.filter((user) => {
    if (!searchText) return true;
    const searchLower = searchText.toLowerCase();
    return (
      user.username.toLowerCase().includes(searchLower) ||
      user.email.toLowerCase().includes(searchLower) ||
      (user.display_name && user.display_name.toLowerCase().includes(searchLower))
    );
  });

  return (
    <Layout style={{ minHeight: '100vh' }}>
      <Header className="admin-header">
        <h2 style={{ color: 'white', margin: 0 }}>SimpleChat - Admin Console</h2>
        <Button 
          icon={<LogoutOutlined />} 
          onClick={handleLogout}
          style={{ 
            borderColor: 'rgba(255, 255, 255, 0.3)'
          }}
        >
          Logout
        </Button>
      </Header>
      <Content style={{ padding: '24px' }}>
        <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
          <Col xs={24} sm={12} md={6}>
            <Card>
              <Statistic
                title="Online Users"
                value={adminStore.onlineUsers.length}
                prefix={<UserOutlined />}
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} md={6}>
            <Card>
              <Statistic
                title="Total Users"
                value={adminStore.totalUsers}
                prefix={<UserOutlined />}
              />
            </Card>
          </Col>
        </Row>

        <Card
          title="User Management"
          extra={
            <Space>
              <Search
                placeholder="Search users"
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                style={{ width: 200 }}
              />
              <Button icon={<ReloadOutlined />} onClick={handleRefresh}>
                Refresh
              </Button>
            </Space>
          }
        >
          <Tabs
            activeKey={activeTab}
            onChange={(key) => {
              setActiveTab(key);
              setSearchText('');
              if (key === 'online') {
                adminStore.loadOnlineUsers();
              } else {
                adminStore.loadAllUsers();
              }
            }}
            items={[
              {
                key: 'all',
                label: `All Users (${adminStore.totalUsers})`,
                children: (
                  <Table
                    columns={createColumns(true)}
                    dataSource={filteredAllUsers}
                    rowKey="id"
                    loading={adminStore.isLoading}
                    pagination={{
                      current: adminStore.currentPage,
                      pageSize: adminStore.pageSize,
                      total: adminStore.totalUsers,
                      onChange: (page) => adminStore.loadAllUsers(page),
                    }}
                  />
                ),
              },
              {
                key: 'online',
                label: `Online Users (${adminStore.onlineUsers.length})`,
                children: (
                  <Table
                    columns={createColumns(true)}
                    dataSource={filteredOnlineUsers}
                    rowKey="id"
                    loading={adminStore.isLoading}
                    pagination={false}
                  />
                ),
              },
            ]}
          />
        </Card>

        {/* Change password modal */}
        <Modal
          title={`Change Password - ${selectedUser?.username}`}
          open={changePasswordModalVisible}
          onOk={handleChangePasswordSubmit}
          onCancel={() => {
            setChangePasswordModalVisible(false);
            changePasswordForm.resetFields();
          }}
          okText="Confirm"
          cancelText="Cancel"
        >
          <Form form={changePasswordForm} layout="vertical">
            <Form.Item
              name="new_password"
              label="New Password"
              rules={[
                { required: true, message: 'Please enter new password' },
                { min: 6, message: 'Password must be at least 6 characters' },
              ]}
            >
              <Input.Password placeholder="Enter new password" />
            </Form.Item>
            <Form.Item
              name="confirm_password"
              label="Confirm Password"
              dependencies={['new_password']}
              rules={[
                { required: true, message: 'Please confirm the new password' },
                ({ getFieldValue }) => ({
                  validator(_, value) {
                    if (!value || getFieldValue('new_password') === value) {
                      return Promise.resolve();
                    }
                    return Promise.reject(new Error('The two passwords do not match'));
                  },
                }),
              ]}
            >
              <Input.Password placeholder="Enter new password again" />
            </Form.Item>
          </Form>
        </Modal>

        {/* Version */}
        <div className="version-badge">
          SimpleChat v{APP_CONFIG.VERSION}
        </div>
      </Content>
    </Layout>
  );
});

export default AdminPage;

