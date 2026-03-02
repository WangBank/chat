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
    // If already logged in, redirect by user type
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
      message.success('Login successful');
      // Redirect admin to admin page; others to chat
      if (authStore.user?.username === APP_CONFIG.ADMIN_USERNAME) {
        navigate('/admin');
      } else {
        navigate('/chat');
      }
    } else {
      message.error(result.message || 'Login failed');
    }
  };

  const onRegister = async (values: any) => {
    const result = await authStore.register(values.username, values.email, values.password);
    if (result.success) {
      message.success('Registration successful');
      navigate('/chat');
    } else {
      message.error(result.message || 'Registration failed');
    }
  };

  const generateRandomAccount = () => {
    const account = authStore.generateRandomAccount();
    form.setFieldsValue({
      username: account.username,
      password: account.password,
    });
    message.info('Random username and password generated');
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
          <h1 style={{ fontSize: 32, margin: 0, color: '#1890ff' }}>SimpleChat</h1>
          <p style={{ color: '#666', marginTop: 8 }}>Make every conversation meaningful</p>
        </div>

        <Tabs
          activeKey={activeTab}
          onChange={setActiveTab}
          items={[
            {
              key: 'login',
              label: 'Login',
              children: (
                <Form form={form} onFinish={onLogin} layout="vertical">
                  <Form.Item
                    name="username"
                    rules={[{ required: true, message: 'Please enter your username' }]}
                  >
                    <Input
                      prefix={<UserOutlined />}
                      placeholder="Username"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="password"
                    rules={[{ required: true, message: 'Please enter your password' }]}
                  >
                    <Input.Password
                      prefix={<LockOutlined />}
                      placeholder="Password"
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
                      Login
                    </Button>
                  </Form.Item>
                  <div style={{ textAlign: 'center' }}>
                    <Button type="link" onClick={generateRandomAccount}>
                      Generate random account
                    </Button>
                    <span style={{ margin: '0 8px' }}>|</span>
                    <Link to="/forgot-password">Forgot password?</Link>
                  </div>
                </Form>
              ),
            },
            {
              key: 'register',
              label: 'Register',
              children: (
                <Form form={form} onFinish={onRegister} layout="vertical">
                  <Form.Item
                    name="username"
                    rules={[{ required: true, message: 'Please enter your username' }]}
                  >
                    <Input
                      prefix={<UserOutlined />}
                      placeholder="Username"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="email"
                    rules={[
                      { required: true, message: 'Please enter your email' },
                      { type: 'email', message: 'Please enter a valid email address' },
                    ]}
                  >
                    <Input
                      prefix={<MailOutlined />}
                      placeholder="Email"
                      size="large"
                    />
                  </Form.Item>
                  <Form.Item
                    name="password"
                    rules={[
                      { required: true, message: 'Please enter your password' },
                      { min: 6, message: 'Password must be at least 6 characters' },
                    ]}
                  >
                    <Input.Password
                      prefix={<LockOutlined />}
                      placeholder="Password (at least 6 characters)"
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
                      Register
                    </Button>
                  </Form.Item>
                  <div style={{ textAlign: 'center' }}>
                    <Button type="link" onClick={generateRandomAccount}>
                      Generate random account
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

