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
    // 检查是否是管理员
    if (!authStore.isAuthenticated) {
      message.error('请先登录');
      navigate('/login');
      return;
    }

    if (authStore.user?.username !== APP_CONFIG.ADMIN_USERNAME) {
      message.warning('无权访问管理员页面');
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
    message.success('刷新成功');
  };

  const handleChangePassword = (user: any) => {
    // 不允许修改admin用户的密码
    if (user.username === APP_CONFIG.ADMIN_USERNAME) {
      message.warning('不允许修改管理员密码');
      return;
    }
    setSelectedUser(user);
    setChangePasswordModalVisible(true);
    changePasswordForm.resetFields();
  };

  const renderUserDetail = (user: any) => {
    return (
      <Descriptions column={1} size="small" style={{ width: 300 }}>
        <Descriptions.Item label="用户ID">{user.id}</Descriptions.Item>
        <Descriptions.Item label="用户名">{user.username}</Descriptions.Item>
        <Descriptions.Item label="邮箱">{user.email}</Descriptions.Item>
        <Descriptions.Item label="昵称">{user.display_name || '-'}</Descriptions.Item>
        <Descriptions.Item label="在线状态">
          <Tag color={user.is_online ? 'success' : 'default'}>
            {user.is_online ? '在线' : '离线'}
          </Tag>
        </Descriptions.Item>
        <Descriptions.Item label="最后登录">
          {user.last_login_at ? formatFullTime(user.last_login_at) : '-'}
        </Descriptions.Item>
        <Descriptions.Item label="注册时间">
          {formatFullTime(user.created_at)}
        </Descriptions.Item>
        <Descriptions.Item label="更新时间">
          {formatFullTime(user.updated_at)}
        </Descriptions.Item>
        {user.avatar_path && (
          <Descriptions.Item label="头像">
            <img
              src={`${APP_CONFIG.API_BASE_URL}${user.avatar_path}`}
              alt="头像"
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
        message.success('密码修改成功');
        setChangePasswordModalVisible(false);
        changePasswordForm.resetFields();
      } else {
        message.error(response.message || '密码修改失败');
      }
    } catch (error: any) {
      message.error(error.message || '密码修改失败');
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
      title: '用户名',
      dataIndex: 'username',
      key: 'username',
    },
    {
      title: '邮箱',
      dataIndex: 'email',
      key: 'email',
    },
    {
      title: '昵称',
      dataIndex: 'display_name',
      key: 'display_name',
    },
    {
      title: '在线状态',
      dataIndex: 'is_online',
      key: 'is_online',
      render: (isOnline: boolean) => (
        <span style={{ color: isOnline ? '#52c41a' : '#999' }}>
          {isOnline ? '在线' : '离线'}
        </span>
      ),
    },
    {
      title: '最后登录',
      dataIndex: 'last_login_at',
      key: 'last_login_at',
      render: (time: string) => (time ? formatTime(time) : '-'),
    },
    {
      title: '注册时间',
      dataIndex: 'created_at',
      key: 'created_at',
      render: (time: string) => formatTime(time),
    },
    ...(showActions ? [{
      title: '操作',
      key: 'action',
      width: 180,
      render: (_: any, record: any) => (
        <Space>
          <Popover
            content={renderUserDetail(record)}
            title="用户详情"
            trigger="click"
            placement="left"
          >
            <Button
              type="link"
              icon={<InfoCircleOutlined />}
              size="small"
            >
              详情
            </Button>
          </Popover>
          {record.username !== APP_CONFIG.ADMIN_USERNAME && (
            <Button
              type="link"
              icon={<KeyOutlined />}
              onClick={() => handleChangePassword(record)}
              size="small"
            >
              修改密码
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
        <h2 style={{ color: 'white', margin: 0 }}>简聊 - 管理后台</h2>
        <Button 
          icon={<LogoutOutlined />} 
          onClick={handleLogout}
          style={{ 
            borderColor: 'rgba(255, 255, 255, 0.3)'
          }}
        >
          退出登录
        </Button>
      </Header>
      <Content style={{ padding: '24px' }}>
        <Row gutter={[16, 16]} style={{ marginBottom: 24 }}>
          <Col xs={24} sm={12} md={6}>
            <Card>
              <Statistic
                title="在线用户"
                value={adminStore.onlineUsers.length}
                prefix={<UserOutlined />}
                valueStyle={{ color: '#52c41a' }}
              />
            </Card>
          </Col>
          <Col xs={24} sm={12} md={6}>
            <Card>
              <Statistic
                title="总用户数"
                value={adminStore.totalUsers}
                prefix={<UserOutlined />}
              />
            </Card>
          </Col>
        </Row>

        <Card
          title="用户管理"
          extra={
            <Space>
              <Search
                placeholder="搜索用户"
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                style={{ width: 200 }}
              />
              <Button icon={<ReloadOutlined />} onClick={handleRefresh}>
                刷新
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
                label: `所有用户 (${adminStore.totalUsers})`,
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
                label: `在线用户 (${adminStore.onlineUsers.length})`,
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

        {/* 修改密码Modal */}
        <Modal
          title={`修改用户密码 - ${selectedUser?.username}`}
          open={changePasswordModalVisible}
          onOk={handleChangePasswordSubmit}
          onCancel={() => {
            setChangePasswordModalVisible(false);
            changePasswordForm.resetFields();
          }}
          okText="确定"
          cancelText="取消"
        >
          <Form form={changePasswordForm} layout="vertical">
            <Form.Item
              name="new_password"
              label="新密码"
              rules={[
                { required: true, message: '请输入新密码' },
                { min: 6, message: '密码至少6位' },
              ]}
            >
              <Input.Password placeholder="请输入新密码" />
            </Form.Item>
            <Form.Item
              name="confirm_password"
              label="确认密码"
              dependencies={['new_password']}
              rules={[
                { required: true, message: '请确认新密码' },
                ({ getFieldValue }) => ({
                  validator(_, value) {
                    if (!value || getFieldValue('new_password') === value) {
                      return Promise.resolve();
                    }
                    return Promise.reject(new Error('两次输入的密码不一致'));
                  },
                }),
              ]}
            >
              <Input.Password placeholder="请再次输入新密码" />
            </Form.Item>
          </Form>
        </Modal>

        {/* 版本号 */}
        <div className="version-badge">
          简聊 v{APP_CONFIG.VERSION}
        </div>
      </Content>
    </Layout>
  );
});

export default AdminPage;

