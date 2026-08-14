import { useMemo, useState } from 'react';
import { Form, Input, Button, message, Card } from 'antd';
import { LockOutlined } from '@ant-design/icons';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { apiService, getApiErrorMessage } from '../services/api.service';
import '../styles/common.css';

const ResetPasswordPage = () => {
  const [form] = Form.useForm();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [loading, setLoading] = useState(false);
  const token = useMemo(() => searchParams.get('token')?.trim() || '', [searchParams]);
  const tokenMissing = token.length === 0;

  const onFinish = async (values: { new_password: string; confirm_password: string }) => {
    if (tokenMissing) {
      message.error('重置链接无效，请重新申请邮件');
      return;
    }

    setLoading(true);
    try {
      const response = await apiService.resetPassword({
        token,
        new_password: values.new_password,
      });

      if (response.success) {
        message.success(response.message || '密码重置成功，请重新登录');
        navigate('/login', { replace: true });
        return;
      }

      message.error(response.message || '密码重置失败');
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, '密码重置失败'));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="qq-login-page">
      <section className="qq-login-window" aria-label="重置密码窗口">
        <div className="qq-login-titlebar">
          <span className="qq-login-avatar">Q</span>
          <span className="qq-login-account">Love Chat</span>
          <span className="qq-login-status">密码重置</span>
        </div>
        <Card className="qq-login-card" bordered={false}>
          <div className="qq-login-heading">
            <h1>设置新密码</h1>
            <p>{tokenMissing ? '重置链接无效，请重新申请邮件' : '输入新密码后返回登录'}</p>
          </div>

          <Form form={form} onFinish={onFinish} layout="vertical">
            <Form.Item
              name="new_password"
              rules={[
                { required: true, message: '请输入新密码' },
                { min: 6, message: '密码至少 6 位' },
              ]}
            >
              <Input.Password
                prefix={<LockOutlined />}
                placeholder="新密码（至少 6 位）"
                size="large"
                disabled={tokenMissing}
              />
            </Form.Item>
            <Form.Item
              name="confirm_password"
              dependencies={['new_password']}
              rules={[
                { required: true, message: '请再次输入新密码' },
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
              <Input.Password
                prefix={<LockOutlined />}
                placeholder="确认新密码"
                size="large"
                disabled={tokenMissing}
              />
            </Form.Item>
            <Form.Item>
              <Button
                type="primary"
                htmlType="submit"
                block
                size="large"
                loading={loading}
                disabled={tokenMissing}
              >
                重置密码
              </Button>
            </Form.Item>
            <div className="qq-login-links">
              <Link to="/login">返回登录</Link>
              <span>|</span>
              <Link to="/forgot-password">重新发送邮件</Link>
            </div>
          </Form>
        </Card>
      </section>
    </div>
  );
};

export default ResetPasswordPage;
