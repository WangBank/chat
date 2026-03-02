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
        message.success('Nickname updated successfully');
      } else {
        message.error(response.message || 'Update failed');
      }
    } catch (error: any) {
      message.error(error.response?.data?.message || 'Update failed');
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async (values: { old_password: string; new_password: string; confirm_password: string }) => {
    if (values.new_password !== values.confirm_password) {
      message.error('The two passwords do not match');
      return;
    }

    setPasswordLoading(true);
    try {
      const response = await apiService.changePassword({
        old_password: values.old_password,
        new_password: values.new_password,
      });
      if (response.success) {
        message.success('Password changed successfully');
        passwordForm.resetFields();
      } else {
        message.error(response.message || 'Failed to change password');
      }
    } catch (error: any) {
      message.error(error.response?.data?.message || 'Failed to change password');
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
        // Update user info
        authStore.user = result.data;
        localStorage.setItem('user', JSON.stringify(result.data));
        
        // Force-refresh avatar URL
        const newAvatarUrl = result.data.avatar_path 
          ? `${APP_CONFIG.API_BASE_URL}${result.data.avatar_path}?t=${Date.now()}`
          : '';
        setAvatarUrl(newAvatarUrl);
        
        message.success('Avatar uploaded successfully');
        onSuccess?.(result);
      } else {
        message.error(result.message || 'Failed to upload avatar');
        onError?.(new Error(result.message || 'Upload failed'));
      }
    } catch (error) {
      message.error('Failed to upload avatar');
      onError?.(error as Error);
    } finally {
      setAvatarLoading(false);
    }
  };

  const getAvatarUrl = () => {
    // Prefer local state avatar URL first
    if (avatarUrl) return avatarUrl;
    // Fallback to avatar path from store
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
              Back
            </Button>
            <span>Profile Settings</span>
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
                      message.error('Only image files are allowed');
                      return false;
                    }
                    const isLt5M = file.size / 1024 / 1024 < 5;
                    if (!isLt5M) {
                      message.error('Image size cannot exceed 5MB');
                      return false;
                    }
                    return true;
                  }}
                >
                  <Button icon={<CameraOutlined />} loading={avatarLoading}>
                    Change Avatar
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
            <Form.Item label="Username">
              <Input value={authStore.user?.username} disabled />
            </Form.Item>
            <Form.Item label="Email">
              <Input value={authStore.user?.email} disabled />
            </Form.Item>
            <Form.Item
              label="Nickname"
              name="display_name"
              rules={[{ max: 50, message: 'Nickname cannot exceed 50 characters' }]}
            >
              <Input placeholder="Enter nickname" />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={loading}>
                Save Nickname
              </Button>
            </Form.Item>
          </Form>
        </Space>
      </Card>

      <Card title="Change Password">
        <Form
          form={passwordForm}
          layout="vertical"
          onFinish={handleChangePassword}
          style={{ maxWidth: 400 }}
        >
          <Form.Item
            label="Current Password"
            name="old_password"
            rules={[{ required: true, message: 'Please enter current password' }]}
          >
            <Input.Password prefix={<LockOutlined />} placeholder="Enter current password" />
          </Form.Item>
          <Form.Item
            label="New Password"
            name="new_password"
            rules={[
              { required: true, message: 'Please enter new password' },
              { min: 6, message: 'Password must be at least 6 characters' },
            ]}
          >
            <Input.Password prefix={<LockOutlined />} placeholder="Enter new password (min 6 chars)" />
          </Form.Item>
          <Form.Item
            label="Confirm New Password"
            name="confirm_password"
            rules={[
              { required: true, message: 'Please confirm new password' },
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
            <Input.Password prefix={<LockOutlined />} placeholder="Enter new password again" />
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={passwordLoading}>
              Change Password
            </Button>
          </Form.Item>
        </Form>
      </Card>

      <div className="version-badge">
        SimpleChat v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default SettingsPage;
