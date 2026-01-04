import { useState } from 'react';
import { Form, Input, Button, message, Card } from 'antd';
import { MailOutlined } from '@ant-design/icons';
import { Link } from 'react-router-dom';

const ForgotPasswordPage = () => {
  const [form] = Form.useForm();
  const [loading, setLoading] = useState(false);

  const onFinish = async () => {
    setLoading(true);
    try {
      // 这里应该调用忘记密码的API，但后端可能还没有实现
      // 暂时显示提示信息
      message.info('忘记密码功能开发中，请联系管理员');
    } catch (error) {
      message.error('操作失败');
    } finally {
      setLoading(false);
    }
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
          <p style={{ color: '#666', marginTop: 8 }}>找回密码</p>
        </div>

        <Form form={form} onFinish={onFinish} layout="vertical">
          <Form.Item
            name="email"
            rules={[
              { required: true, message: '请输入邮箱' },
              { type: 'email', message: '请输入有效的邮箱地址' },
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
              发送重置链接
            </Button>
          </Form.Item>
          <div style={{ textAlign: 'center' }}>
            <Link to="/login">返回登录</Link>
          </div>
        </Form>
      </Card>
    </div>
  );
};

export default ForgotPasswordPage;

