import { useState, useEffect } from 'react';
import { Card, Form, Input, Button, Upload, Avatar, message, Space, Divider, Radio } from 'antd';
import { UserOutlined, LockOutlined, CameraOutlined, SaveOutlined, ArrowLeftOutlined, QqOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { authStore } from '../stores/auth.store';
import { apiService } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import { cropAvatarIfNeeded } from '../utils/avatar';
import type { UploadProps } from 'antd';
import '../styles/common.css';

const SettingsPage = observer(() => {
  const navigate = useNavigate();
  const [form] = Form.useForm();
  const [passwordForm] = Form.useForm();
  const [emailForm] = Form.useForm();
  const [loading, setLoading] = useState(false);
  const [passwordLoading, setPasswordLoading] = useState(false);
  const [passwordCodeLoading, setPasswordCodeLoading] = useState(false);
  const [passwordVerificationMethod, setPasswordVerificationMethod] = useState<'old_password' | 'email_code'>('old_password');
  const [emailCodeLoading, setEmailCodeLoading] = useState(false);
  const [emailChangeLoading, setEmailChangeLoading] = useState(false);
  const [avatarLoading, setAvatarLoading] = useState(false);
  const [qqBindingLoading, setQqBindingLoading] = useState(false);
  const [avatarUrl, setAvatarUrl] = useState<string>('');
  const currentUser = authStore.user;

  useEffect(() => {
    if (currentUser) {
      form.setFieldsValue({
        display_name: currentUser.display_name || '',
        signature: currentUser.signature || '',
      });
      emailForm.setFieldsValue({ email: currentUser.email, verification_code: '' });
      if (currentUser.avatar_path) {
        setAvatarUrl(resolveAvatarUrl(currentUser.avatar_path));
      }
    }
  }, [currentUser, emailForm, form]);

  const getErrorMessage = (error: unknown, fallback: string) => {
    const maybeError = error as { response?: { data?: { message?: unknown } } };
    return typeof maybeError.response?.data?.message === 'string'
      ? maybeError.response.data.message
      : fallback;
  };

  const handleUpdateProfile = async (values: { display_name: string; signature: string }) => {
    setLoading(true);
    try {
      const response = await apiService.updateProfile({
        display_name: values.display_name,
        signature: values.signature,
      });
      if (response.success && response.data) {
        authStore.user = response.data;
        localStorage.setItem('user', JSON.stringify(response.data));
        message.success('Profile updated successfully');
      } else {
        message.error(response.message || 'Update failed');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, 'Update failed'));
    } finally {
      setLoading(false);
    }
  };

  const handleChangePassword = async (values: {
    old_password?: string;
    verification_code?: string;
    new_password: string;
    confirm_password: string;
  }) => {
    if (values.new_password !== values.confirm_password) {
      message.error('The two passwords do not match');
      return;
    }

    setPasswordLoading(true);
    try {
      const response = await apiService.changePassword({
        old_password: passwordVerificationMethod === 'old_password' ? values.old_password : undefined,
        verification_code: passwordVerificationMethod === 'email_code' ? values.verification_code : undefined,
        new_password: values.new_password,
      });
      if (response.success) {
        message.success('Password changed successfully');
        passwordForm.resetFields();
      } else {
        message.error(response.message || 'Failed to change password');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, 'Failed to change password'));
    } finally {
      setPasswordLoading(false);
    }
  };

  const handleRequestPasswordChangeCode = async () => {
    setPasswordCodeLoading(true);
    try {
      const response = await apiService.requestPasswordChangeCode();
      if (response.success) {
        message.success(response.message || '验证码已发送，5分钟内有效');
      } else {
        message.error(response.message || '发送验证码失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '发送验证码失败'));
    } finally {
      setPasswordCodeLoading(false);
    }
  };

  const handleRequestEmailChangeCode = async () => {
    try {
      const { email } = await emailForm.validateFields(['email']);
      setEmailCodeLoading(true);
      const response = await apiService.requestEmailChangeCode({ email: email.trim() });
      if (response.success) {
        message.success(response.message || '验证码已发送，5分钟内有效');
      } else {
        message.error(response.message || '发送验证码失败');
      }
    } catch (error: unknown) {
      const validationError = error as { errorFields?: unknown[] };
      if (!validationError.errorFields) {
        message.error(getErrorMessage(error, '发送验证码失败'));
      }
    } finally {
      setEmailCodeLoading(false);
    }
  };

  const handleChangeEmail = async (values: { email: string; verification_code: string }) => {
    setEmailChangeLoading(true);
    try {
      const response = await apiService.changeEmail({
        email: values.email.trim(),
        verification_code: values.verification_code,
      });
      if (response.success && response.data) {
        authStore.user = response.data;
        localStorage.setItem('user', JSON.stringify(response.data));
        emailForm.setFieldsValue({ email: response.data.email, verification_code: '' });
        message.success(response.message || '邮箱修改成功');
      } else {
        message.error(response.message || '邮箱修改失败');
      }
    } catch (error: unknown) {
      message.error(getErrorMessage(error, '邮箱修改失败'));
    } finally {
      setEmailChangeLoading(false);
    }
  };

  const handleAvatarUpload: UploadProps['customRequest'] = async (options) => {
    const { file, onSuccess, onError } = options;
    setAvatarLoading(true);

    try {
      const sourceFile = file as File;
      const avatarFile = await cropAvatarIfNeeded(sourceFile);
      const formData = new FormData();
      formData.append('avatar', avatarFile);
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
          ? resolveAvatarUrl(result.data.avatar_path)
          : '';
        setAvatarUrl(newAvatarUrl);
        
        if (avatarFile !== sourceFile) {
          message.info('头像已自动裁剪压缩至 100KB 以内');
        }
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
      return resolveAvatarUrl(authStore.user.avatar_path);
    }
    return undefined;
  };

  const resolveAvatarUrl = (avatarPath: string) => {
    if (/^https?:\/\//i.test(avatarPath)) {
      return avatarPath;
    }
    return `${APP_CONFIG.API_BASE_URL}${avatarPath}?t=${Date.now()}`;
  };

  const handleQQBind = async () => {
    setQqBindingLoading(true);
    try {
      const response = await apiService.getQQLoginUrl('bind');
      const loginUrl = response.data;

      if (response.success && loginUrl?.configured && loginUrl.auth_url) {
        window.location.assign(loginUrl.auth_url);
        return;
      }

      if (response.success && loginUrl?.mock_available) {
        const bindResponse = await apiService.qqDevBind({
          open_id: `dev_qq_bind_${authStore.user?.id || 'web'}`,
          nickname: authStore.user?.display_name || authStore.user?.username || 'QQ测试用户',
        });

        if (bindResponse.success && bindResponse.data) {
          authStore.user = bindResponse.data;
          localStorage.setItem('user', JSON.stringify(bindResponse.data));
          message.success('QQ测试绑定成功');
        } else {
          message.error(bindResponse.message || 'QQ绑定失败');
        }
        return;
      }

      message.warning(response.message || 'QQ登录尚未配置');
    } catch (error: unknown) {
      message.error(getErrorMessage(error, 'QQ绑定失败'));
    } finally {
      setQqBindingLoading(false);
    }
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
            <Form.Item
              label="个性签名"
              name="signature"
              rules={[{ max: 100, message: '个性签名不能超过 100 个字符' }]}
            >
              <Input.TextArea
                placeholder="写一句个性签名，别人可以在你的资料卡看到"
                maxLength={100}
                showCount
                autoSize={{ minRows: 3, maxRows: 5 }}
              />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" icon={<SaveOutlined />} loading={loading}>
                Save Profile
              </Button>
            </Form.Item>
          </Form>

          <Divider />

          <Form form={emailForm} layout="vertical" onFinish={handleChangeEmail} style={{ maxWidth: 400 }}>
            <div
              role="status"
              style={{
                marginBottom: 16,
                padding: '10px 12px',
                borderRadius: 8,
                color: authStore.user?.email_verified ? '#237804' : '#ad6800',
                background: authStore.user?.email_verified ? '#f6ffed' : '#fffbe6',
              }}
            >
              {authStore.user?.email_verified
                ? `当前邮箱已认证：${authStore.user.email}`
                : '当前邮箱未认证。填写新邮箱并验证验证码后即可完成邮箱认证。'}
            </div>
            <Form.Item
              label="修改邮箱"
              name="email"
              rules={[
                { required: true, message: '请输入邮箱' },
                { type: 'email', message: '请输入有效邮箱' },
              ]}
            >
              <Input placeholder="请输入新邮箱" />
            </Form.Item>
            <Form.Item
              label="邮箱验证码"
              name="verification_code"
              rules={[
                { required: true, message: '请输入邮箱验证码' },
                { pattern: /^\d{6}$/, message: '邮箱验证码为 6 位数字' },
              ]}
            >
              <Input
                placeholder="请输入 6 位验证码"
                maxLength={6}
                suffix={
                  <Button
                    type="link"
                    size="small"
                    loading={emailCodeLoading}
                    onClick={() => void handleRequestEmailChangeCode()}
                  >
                    获取验证码
                  </Button>
                }
              />
            </Form.Item>
            <Form.Item>
              <Button type="primary" htmlType="submit" loading={emailChangeLoading}>
                保存邮箱
              </Button>
            </Form.Item>
          </Form>
        </Space>
      </Card>

      <Card title="QQ 绑定" style={{ marginBottom: 24 }}>
        <Space align="center" size="middle" wrap>
          <Avatar
            size={48}
            src={authStore.user?.qq_avatar_url || (authStore.user?.avatar_path ? resolveAvatarUrl(authStore.user.avatar_path) : undefined)}
            icon={<QqOutlined />}
            style={{ background: '#12A8F4' }}
          />
          <div>
            <div style={{ fontWeight: 700 }}>
              {authStore.user?.qq_bound ? authStore.user.qq_nickname || '已绑定 QQ' : '未绑定 QQ'}
            </div>
            <div style={{ color: '#8c96a3', fontSize: 13 }}>
              {authStore.user?.qq_bound ? '可使用 QQ 登录当前账号' : '绑定后可用 QQ 快速登录'}
            </div>
          </div>
          <Button
            type={authStore.user?.qq_bound ? 'default' : 'primary'}
            icon={<QqOutlined />}
            loading={qqBindingLoading}
            onClick={() => void handleQQBind()}
          >
            {authStore.user?.qq_bound ? '重新绑定' : '绑定 QQ'}
          </Button>
        </Space>
      </Card>

      <Card title="Change Password">
        <Form
          form={passwordForm}
          layout="vertical"
          onFinish={handleChangePassword}
          style={{ maxWidth: 400 }}
        >
          <Form.Item label="验证方式">
            <Radio.Group
              value={passwordVerificationMethod}
              onChange={(event) => {
                setPasswordVerificationMethod(event.target.value);
                passwordForm.setFieldsValue({ old_password: undefined, verification_code: undefined });
              }}
            >
              <Radio value="old_password">旧密码</Radio>
              <Radio value="email_code" disabled={!authStore.user?.email_verified}>
                邮箱验证码{authStore.user?.email_verified ? '' : '（请先认证邮箱）'}
              </Radio>
            </Radio.Group>
          </Form.Item>
          {passwordVerificationMethod === 'old_password' ? (
            <Form.Item
              label="Current Password"
              name="old_password"
              preserve={false}
              rules={[{ required: true, message: 'Please enter current password' }]}
            >
              <Input.Password prefix={<LockOutlined />} placeholder="Enter current password" />
            </Form.Item>
          ) : (
            <>
              <div style={{ marginBottom: 12, color: '#667085', fontSize: 13 }}>
                验证码会发送到当前邮箱：{authStore.user?.email}
              </div>
              <Form.Item
                label="邮箱验证码"
                name="verification_code"
                preserve={false}
                rules={[
                  { required: true, message: '请输入邮箱验证码' },
                  { pattern: /^\d{6}$/, message: '邮箱验证码为 6 位数字' },
                ]}
              >
                <Input
                  placeholder="请输入 6 位验证码"
                  maxLength={6}
                  suffix={
                    <Button
                      type="link"
                      size="small"
                      loading={passwordCodeLoading}
                      onClick={() => void handleRequestPasswordChangeCode()}
                    >
                      获取验证码
                    </Button>
                  }
                />
              </Form.Item>
            </>
          )}
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
        Love Chat v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default SettingsPage;
