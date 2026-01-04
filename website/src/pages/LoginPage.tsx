import { useState, useEffect } from 'react';
import { Form, Input, Button, message, Card, Tabs } from 'antd';
import { UserOutlined, LockOutlined, MailOutlined } from '@ant-design/icons';
import { useNavigate, Link } from 'react-router-dom';
import { observer } from 'mobx-react-lite';
import { authStore } from '../stores/auth.store';
import { APP_CONFIG } from '../config/app.config';

const LoginPage = observer(() => {
  const [form] = Form.useForm();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState('login');

  useEffect(() => {
    // 如果已经登录，根据用户类型跳转
    if (authStore.isAuthenticated) {
      if (authStore.user?.username === APP_CONFIG.ADMIN_USERNAME) {
        navigate('/admin');
      } else {
        navigate('/chat');
      }
    }
  }, [navigate]);

  const onLogin = async (values: any) => {
    const result = await authStore.login(values.username, values.password);
    if (result.success) {
      message.success('登录成功');
      // 如果是admin用户，跳转到admin页面，否则跳转到chat页面
      if (authStore.user?.username === APP_CONFIG.ADMIN_USERNAME) {
        navigate('/admin');
      } else {
        navigate('/chat');
      }
    } else {
      message.error(result.message || '登录失败');
    }
  };

  const onRegister = async (values: any) => {
    const result = await authStore.register(values.username, values.email, values.password);
    if (result.success) {
      message.success('注册成功');
      navigate('/chat');
    } else {
      message.error(result.message || '注册失败');
    }
  };

  const generateRandomAccount = () => {
    const account = authStore.generateRandomAccount();
    form.setFieldsValue({
      username: account.username,
      password: account.password,
    });
    message.info('已生成随机账号和密码');
  };

  return (
    <div style={{ 
      minHeight: '100vh', 
      display: 'flex', 
      alignItems: 'center', 
      justifyContent: 'center',
      background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
    }}>
      <Card style={{ width: 400, borderRadius: 12, boxShadow: '0 4px 12px rgba(0,0,0,0.15)' }}>
        <div style={{ textAlign: 'center', marginBottom: 24 }}>
          <h1 style={{ fontSize: 32, margin: 0, color: '#1890ff' }}>简聊</h1>
          <p style={{ color: '#666', marginTop: 8 }}>让每一次沟通更有意义</p>
        </div>

        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          items={[
            {
              key: 'login',
              label: '登录',
              children: (
                <Form form={form} onFinish={onLogin} layout="vertical">
                  <Form.Item
                    name="username"
                    rules={[{ required: true, message: '请输入用户名' }]}
                  >
                    <Input
                      prefix={<UserOutlined />}
                      placeholder="用户名"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="password"
                    rules={[{ required: true, message: '请输入密码' }]}
                  >
                    <Input.Password
                      prefix={<LockOutlined />}
                      placeholder="密码"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item>
                    <Button
                      type="primary"
                      htmlType="submit"
                      block
                      size="large"
                      loading={authStore.isLoading}
                    >
                      登录
                    </Button>
                  </Form.Item>
                  <div style={{ textAlign: 'center' }}>
                    <Button type="link" onClick={generateRandomAccount}>
                      随机生成账号密码
                    </Button>
                    <span style={{ margin: '0 8px' }}>|</span>
                    <Link to="/forgot-password">忘记密码？</Link>
                  </div>
                </Form>
              ),
            },
            {
              key: 'register',
              label: '注册',
              children: (
                <Form form={form} onFinish={onRegister} layout="vertical">
                  <Form.Item
                    name="username"
                    rules={[{ required: true, message: '请输入用户名' }]}
                  >
                    <Input
                      prefix={<UserOutlined />}
                      placeholder="用户名"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="email"
                    rules={[
                      { required: true, message: '请输入邮箱' },
                      { type: 'email', message: '请输入有效的邮箱地址' },
                    ]}
                  >
                    <Input
                      prefix={<MailOutlined />}
                      placeholder="邮箱"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="password"
                    rules={[
                      { required: true, message: '请输入密码' },
                      { min: 6, message: '密码至少6位' },
                    ]}
                  >
                    <Input.Password
                      prefix={<LockOutlined />}
                      placeholder="密码（至少6位）"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item>
                    <Button
                      type="primary"
                      htmlType="submit"
                      block
                      size="large"
                      loading={authStore.isLoading}
                    >
                      注册
                    </Button>
                  </Form.Item>
                  <div style={{ textAlign: 'center' }}>
                    <Button type="link" onClick={generateRandomAccount}>
                      随机生成账号密码
                    </Button>
                  </div>
                </Form>
              ),
            },
          ]}
        />
      </Card>
    </div>
  );
});

export default LoginPage;

