import { useState, useEffect, useRef } from 'react';
import { Form, Input, Button, message, Card, Tabs, Tooltip } from 'antd';
import { UserOutlined, LockOutlined, MailOutlined, QqOutlined } from '@ant-design/icons';
import { useNavigate, Link, useLocation } from 'react-router-dom';
import { observer } from 'mobx-react-lite';
import { authStore } from '../stores/auth.store';
import { apiService } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import '../styles/common.css';

const LoginPage = observer(() => {
  const [form] = Form.useForm();
  const navigate = useNavigate();
  const location = useLocation();
  const [activeTab, setActiveTab] = useState('login');
  const qqCallbackHandledRef = useRef(false);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const hasQQCallback = Boolean(params.get('code') || params.get('qq_code'));

    // If already logged in, redirect by user type
    if (authStore.isAuthenticated && !hasQQCallback) {
      if (authStore.user?.username === APP_CONFIG.ADMIN_USERNAME) {
        navigate('/admin');
      } else {
        navigate('/chat');
      }
    }
  }, [location.search, navigate]);

  useEffect(() => {
    const params = new URLSearchParams(location.search);
    const code = params.get('code') || params.get('qq_code');
    const state = params.get('state') || params.get('qq_state');

    if (!code || !state || qqCallbackHandledRef.current) {
      return;
    }

    qqCallbackHandledRef.current = true;
    const completeQQCallback = async () => {
      if (authStore.isAuthenticated) {
        try {
          const response = await apiService.qqBind({ code, state });
          if (response.success && response.data) {
            authStore.user = response.data;
            localStorage.setItem('user', JSON.stringify(response.data));
            message.success('QQ绑定成功');
            navigate('/chat', { replace: true });
            return;
          }

          message.error(response.message || 'QQ绑定失败');
        } catch (error: any) {
          message.error(error.response?.data?.message || 'QQ绑定失败');
        }
        navigate('/login', { replace: true });
        return;
      }

      const result = await authStore.loginWithQQCode(code, state);
      if (!result.success) {
        message.error(result.message || 'QQ登录失败');
        navigate('/login', { replace: true });
        return;
      }

      message.success('QQ登录成功');
      navigate('/chat', { replace: true });
    };

    void completeQQCallback();
  }, [location.search, navigate]);

  const onLogin = async (values: any) => {
    const result = await authStore.login(values.username, values.password);
    if (result.success) {
      message.success('登录成功');
      // Redirect admin to admin page; others to chat
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

  const handleQQLogin = async () => {
    try {
      const response = await apiService.getQQLoginUrl('login');
      const loginUrl = response.data;

      if (response.success && loginUrl?.configured && loginUrl.auth_url) {
        window.location.assign(loginUrl.auth_url);
        return;
      }

      if (response.success && loginUrl?.mock_available) {
        const result = await authStore.loginWithQQDev();
        if (result.success) {
          message.success('QQ测试登录成功');
          navigate('/chat');
        } else {
          message.error(result.message || 'QQ测试登录失败');
        }
        return;
      }

      message.warning(response.message || 'QQ登录尚未配置');
    } catch (error: any) {
      message.error(error.response?.data?.message || 'QQ登录失败');
    }
  };

  return (
    <div className="qq-login-page">
      <section className="qq-login-window" aria-label="登录窗口">
        <div className="qq-login-titlebar">
          <span className="qq-login-avatar">Q</span>
          <span className="qq-login-account">Forever Love</span>
          <span className="qq-login-status">网页版登录</span>
        </div>
        <Card className="qq-login-card" bordered={false}>
          <div className="qq-login-heading">
            <h1>聊天登录</h1>
            <p>登录后进入消息、好友和群聊</p>
        </div>

        <Tabs
          centered
          className="qq-login-tabs"
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
                  <div className="qq-login-links">
                    <Button type="link" onClick={generateRandomAccount}>
                      随机账号
                    </Button>
                    <span>|</span>
                    <Link to="/forgot-password">忘记密码</Link>
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
                      { type: 'email', message: '请输入有效邮箱' },
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
                      { min: 6, message: '密码至少 6 位' },
                    ]}
                  >
                    <Input.Password
                      prefix={<LockOutlined />}
                      placeholder="密码（至少 6 位）"
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
                  <div className="qq-login-links">
                    <Button type="link" onClick={generateRandomAccount}>
                      随机账号
                    </Button>
                  </div>
                </Form>
              ),
            },
          ]}
        />
          <div className="qq-login-divider">
            <span>其他登录方式</span>
          </div>
          <div className="qq-third-party-row">
            <Tooltip title="QQ 登录">
              <Button
                className="qq-social-button qq"
                shape="circle"
                icon={<QqOutlined />}
                loading={authStore.isLoading}
                onClick={() => void handleQQLogin()}
                aria-label="QQ 登录"
              />
            </Tooltip>
            <span>QQ</span>
          </div>
        </Card>
      </section>
    </div>
  );
});

export default LoginPage;
