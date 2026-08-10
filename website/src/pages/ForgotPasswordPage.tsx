import { useState } from 'react';
import { Form, Input, Button, message, Card } from 'antd';
import { MailOutlined } from '@ant-design/icons';
import { Link } from 'react-router-dom';
import { apiService } from '../services/api.service';
import '../styles/common.css';

const ForgotPasswordPage = () => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  const onFinish = async (values: { email: string }) => {
    setLoading(true);
    try {
      const response = await apiService.forgotPassword({ email: values.email });
      if (response.success) {
        message.success(response.message || '如果邮箱存在，重置邮件已发送，请检查邮箱');
        form.resetFields();
        return;
      }

      message.error(response.message || '发送重置邮件失败');
    } catch (error: any) {
      message.error(error.response?.data?.message || '发送重置邮件失败');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="qq-login-page">
      <section className="qq-login-window" aria-label="找回密码窗口">
        <div className="qq-login-titlebar">
          <span className="qq-login-avatar">Q</span>
          <span className="qq-login-account">Love Chat</span>
          <span className="qq-login-status">密码找回</span>
        </div>
        <Card className="qq-login-card" bordered={false}>
          <div className="qq-login-heading">
            <h1>找回密码</h1>
            <p>输入注册邮箱接收重置链接</p>
          </div>

          <Form form={form} onFinish={onFinish} layout="vertical">
            <Form.Item
              name="email"
              rules={[
                { required: true, message: '请输入邮箱' },
                { type: 'email', message: '请输入有效邮箱' },
              ]}
            >
              <Input
                prefix={<MailOutlined />}
                placeholder="请输入注册邮箱"
                size="large"
              />
            </Form.Item>
            <Form.Item>
              <Button
                type="primary"
                htmlType="submit"
                block
                size="large"
                loading={loading}
              >
                发送重置邮件
              </Button>
            </Form.Item>
            <div className="qq-login-links">
              <Link to="/login">返回登录</Link>
            </div>
          </Form>
        </Card>
      </section>
    </div>
  );
};

export default ForgotPasswordPage;
