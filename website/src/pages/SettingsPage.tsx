import { useState, useEffect } from 'react';
import { Card, Form, Input, Button, Upload, Avatar, message, Space, Divider } from 'antd';
import { UserOutlined, LockOutlined, CameraOutlined, SaveOutlined, ArrowLeftOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { authStore } from '../stores/auth.store';
import { apiService } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import type { UploadProps } from 'antd';
import '../styles/common.css';

const SettingsPage = observer(() => {
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [passwordForm] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [avatarLoading, setAvatarLoading] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState<string>('');

  useEffect(() => {
    if (authStore.user) {
      form.setFieldsValue({
        display_name: authStore.user.display_name || '',
      });
      if (authStore.user.avatar_path) {
        setAvatarUrl(`${APP_CONFIG.API_BASE_URL}${authStore.user.avatar_path}?t=${Date.now()}`);
      }
    }
  }, [authStore.user, form]);

  const handleUpdateProfile = async (values: { display_name: string }) => {
    setLoading(true);
    try {
      const response = await apiService.updateProfile({ display_name: values.display_name });
      if (response.success && response.data) {
        authStore.user = response.data;
        localStorage.setItem('user', JSON.stringify(response.data));
        message.success('昵称更新成功');
      } else {
        message.error(response.message || '更新失败');
      }
    } catch (error: any) {
      message.error(error.response?.data?.message || '更新失败');
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async (values: { old_password: string; new_password: string; confirm_password: string }) => {
    if (values.new_password !== values.confirm_password) {
      message.error('两次输入的密码不一致');
      return;
    }

    setPasswordLoading(true);
    try {
      const response = await apiService.changePassword({
        old_password: values.old_password,
        new_password: values.new_password,
      });
      if (response.success) {
        message.success('密码修改成功');
        passwordForm.resetFields();
      } else {
        message.error(response.message || '密码修改失败');
      }
    } catch (error: any) {
      message.error(error.response?.data?.message || '密码修改失败');
    } finally {
      setPasswordLoading(false);
    }
  };

  const handleAvatarUpload: UploadProps['customRequest'] = async (options) => {
    const { file, onSuccess, onError } = options;
    setAvatarLoading(true);

    const formData = new FormData();
    formData.append('avatar', file as File);

    try {
      const response = await fetch(`${APP_CONFIG.API_BASE_URL}/api/auth/upload-avatar`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${authStore.token}`,
        },
        body: formData,
      });

      const result = await response.json();
      if (result.success && result.data) {
        // 更新用户信息
        authStore.user = result.data;
        localStorage.setItem('user', JSON.stringify(result.data));
        
        // 强制刷新头像URL
        const newAvatarUrl = result.data.avatar_path 
          ? `${APP_CONFIG.API_BASE_URL}${result.data.avatar_path}?t=${Date.now()}`
          : '';
        setAvatarUrl(newAvatarUrl);
        
        message.success('头像上传成功');
        onSuccess?.(result);
      } else {
        message.error(result.message || '头像上传失败');
        onError?.(new Error(result.message || '上传失败'));
      }
    } catch (error) {
      message.error('头像上传失败');
      onError?.(error as Error);
    } finally {
      setAvatarLoading(false);
    }
  };

  const getAvatarUrl = () => {
    // 优先使用本地状态的头像URL
    if (avatarUrl) return avatarUrl;
    // 其次使用store中的头像路径
    if (authStore.user?.avatar_path) {
      return `${APP_CONFIG.API_BASE_URL}${authStore.user.avatar_path}?t=${Date.now()}`;
    }
    return undefined;
  };

  return (
    <div style={{ padding: '24px', maxWidth: '800px', margin: '0 auto' }}>
      <Card 
        title={
          <Space>
            <Button 
              type="text" 
              icon={<ArrowLeftOutlined />} 
              onClick={() => navigate('/chat')}
            >
              返回
            </Button>
            <span>个人设置</span>
          </Space>
        }
        style={{ marginBottom: 24 }}
      >
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          <div>
            <div style={{ marginBottom: 16, textAlign: 'center' }}>
              <Avatar
                size={120}
                src={getAvatarUrl()}
                icon={<UserOutlined />}
                style={{ marginBottom: 16 }}
              />
              <div>
                <Upload
                  customRequest={handleAvatarUpload}
                  showUploadList={false}
                  accept="image/*"
                  beforeUpload={(file) => {
                    const isImage = file.type.startsWith('image/');
                    if (!isImage) {
                      message.error('只能上传图片文件');
                      return false;
                    }
                    const isLt5M = file.size / 1024 / 1024 < 5;
                    if (!isLt5M) {
                      message.error('图片大小不能超过 5MB');
                      return false;
                    }
                    return true;
                  }}
                >
                  <Button icon={<CameraOutlined />} loading={avatarLoading}>
                    更换头像
                  </Button>
                </Upload>
              </div>
            </div>
          </div>

          <Divider />

          <Form
            form={form}
            layout="vertical"
            onFinish={handleUpdateProfile}
            style={{ maxWidth: 400 }}
          >
            <Form.Item label="用户名">
              <Input value={authStore.user?.username} disabled />
            </Form.Item>
            <Form.Item label="邮箱">
              <Input value={authStore.user?.email} disabled />
            </Form.Item>
            <Form.Item
              label="昵称"
              name="display_name"
              rules={[{ max: 50, message: '昵称不能超过50个字符' }]}
            >
              <Input placeholder="请输入昵称" />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={loading}>
                保存昵称
              </Button>
            </Form.Item>
          </Form>
        </Space>
      </Card>

      <Card title="修改密码">
        <Form
          form={passwordForm}
          layout="vertical"
          onFinish={handleChangePassword}
          style={{ maxWidth: 400 }}
        >
          <Form.Item
            label="当前密码"
            name="old_password"
            rules={[{ required: true, message: '请输入当前密码' }]}
          >
            <Input.Password prefix={<LockOutlined />} placeholder="请输入当前密码" />
          </Form.Item>
          <Form.Item
            label="新密码"
            name="new_password"
            rules={[
              { required: true, message: '请输入新密码' },
              { min: 6, message: '密码至少6位' },
            ]}
          >
            <Input.Password prefix={<LockOutlined />} placeholder="请输入新密码（至少6位）" />
          </Form.Item>
          <Form.Item
            label="确认新密码"
            name="confirm_password"
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
            <Input.Password prefix={<LockOutlined />} placeholder="请再次输入新密码" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={passwordLoading}>
              修改密码
            </Button>
          </Form.Item>
        </Form>
      </Card>

      <div className="version-badge">
        简聊 v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default SettingsPage;
