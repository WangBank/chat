import { useEffect, useState } from 'react';
import { Card, List, Avatar, Button, Input, Space, message, Empty, Tag } from 'antd';
import { UserAddOutlined, SearchOutlined, UserOutlined, ArrowLeftOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { chatStore } from '../stores/chat.store';
import { apiService } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import '../styles/common.css';

const { Search } = Input;

const ContactsPage = observer(() => {
  const navigate = useNavigate();
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    loadUsers();
  }, []);

  const loadUsers = async (query: string = '') => {
    setLoading(true);
    try {
      const response = await apiService.searchUsers(query, 1, 10);
      if (response.success && response.data) {
        setUsers(response.data.users || []);
      }
    } catch (error) {
      console.error('加载用户失败:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = (value: string) => {
    setSearchQuery(value);
    loadUsers(value);
  };

  const handleAddContact = async (username: string) => {
    const result = await chatStore.addContact(username);
    if (result.success) {
      message.success('添加联系人成功');
      loadUsers(searchQuery);
    } else {
      message.error(result.message || '添加联系人失败');
    }
  };

  const getAvatarUrl = (avatarPath?: string) => {
    if (avatarPath) {
      return `${APP_CONFIG.API_BASE_URL}${avatarPath}?t=${Date.now()}`;
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
            <span>添加联系人</span>
          </Space>
        }
        extra={
          <Search
            placeholder="搜索用户名、昵称或邮箱"
            allowClear
            enterButton={<SearchOutlined />}
            onSearch={handleSearch}
            style={{ width: 300 }}
          />
        }
      >
        {users.length === 0 ? (
          <Empty description={searchQuery ? '未找到匹配的用户' : '暂无推荐用户'} />
        ) : (
          <List
            loading={loading}
            dataSource={users}
            renderItem={(user) => (
              <List.Item
                actions={[
                  <Button
                    type="primary"
                    icon={<UserAddOutlined />}
                    onClick={() => handleAddContact(user.username)}
                  >
                    添加
                  </Button>,
                ]}
              >
                <List.Item.Meta
                  avatar={
                    <Avatar src={getAvatarUrl(user.avatar_path)} icon={<UserOutlined />}>
                      {user.display_name?.[0] || user.username[0]}
                    </Avatar>
                  }
                  title={
                    <Space>
                      <span>{user.display_name || user.username}</span>
                      {user.display_name && <Tag color="blue">@{user.username}</Tag>}
                    </Space>
                  }
                  description={
                    <div>
                      <div>{user.email}</div>
                      {user.is_online && <Tag color="success">在线</Tag>}
                    </div>
                  }
                />
              </List.Item>
            )}
          />
        )}
      </Card>

      <div className="version-badge">
        简聊 v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default ContactsPage;
