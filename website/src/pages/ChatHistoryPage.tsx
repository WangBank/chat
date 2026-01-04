import { useEffect, useState } from 'react';
import { Card, List, Input, Button, Space, DatePicker, Empty, message } from 'antd';
import { ArrowLeftOutlined, SearchOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate, useParams } from 'react-router-dom';
import { chatStore } from '../stores/chat.store';
import { apiService } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import { formatFullTime } from '../utils/time.utils';
import dayjs from 'dayjs';
import '../styles/common.css';

const { RangePicker } = DatePicker;

const ChatHistoryPage = observer(() => {
  const navigate = useNavigate();
  const { contactId } = useParams<{ contactId: string }>();
  const [messages, setMessages] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [dateRange, setDateRange] = useState<[dayjs.Dayjs, dayjs.Dayjs] | null>(null);

  useEffect(() => {
    if (contactId) {
      loadMessages();
    }
  }, [contactId]);

  const loadMessages = async () => {
    if (!contactId) return;

    setLoading(true);
    try {
      const response = await apiService.getChatHistory(Number(contactId));
      if (response.success && response.data) {
        let filteredMessages = response.data || [];

        // 按内容搜索
        if (searchQuery.trim()) {
          filteredMessages = filteredMessages.filter((msg: any) =>
            msg.content.toLowerCase().includes(searchQuery.toLowerCase())
          );
        }

        // 按日期范围搜索
        if (dateRange && dateRange[0] && dateRange[1]) {
          const startDate = dateRange[0].startOf('day').toDate();
          const endDate = dateRange[1].endOf('day').toDate();
          filteredMessages = filteredMessages.filter((msg: any) => {
            const msgDate = new Date(msg.created_at);
            return msgDate >= startDate && msgDate <= endDate;
          });
        }

        setMessages(filteredMessages);
      }
    } catch (error) {
      console.error('加载消息失败:', error);
      message.error('加载消息失败');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = () => {
    loadMessages();
  };


  const contact = chatStore.contacts.find((c) => c.id === Number(contactId));

  return (
    <div style={{ padding: '24px', maxWidth: '1000px', margin: '0 auto' }}>
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
            <span>
              {contact
                ? `${contact.display_name || contact.contact_user.display_name || contact.contact_user.username} - 聊天记录`
                : '聊天记录'}
            </span>
          </Space>
        }
      >
        <Space direction="vertical" style={{ width: '100%', marginBottom: 16 }}>
          <Input
            placeholder="搜索消息内容"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onPressEnter={handleSearch}
            suffix={
              <Button
                type="text"
                icon={<SearchOutlined />}
                onClick={handleSearch}
              />
            }
          />
          <RangePicker
            value={dateRange}
            onChange={(dates) => setDateRange(dates as [dayjs.Dayjs, dayjs.Dayjs] | null)}
            style={{ width: '100%' }}
            placeholder={['开始日期', '结束日期']}
          />
          <Button type="primary" onClick={handleSearch} loading={loading}>
            搜索
          </Button>
        </Space>

        <List
          loading={loading}
          dataSource={messages}
          locale={{ emptyText: <Empty description="暂无消息" /> }}
          renderItem={(msg, index) => {
            // 简单的判断：如果当前联系人是接收者，那么发送的消息就是sent
            const currentUserId = contact?.contact_user.id;
            const isCurrentUserMessage = msg.sender_id !== currentUserId;

            return (
              <List.Item
                key={`${msg.id}-${index}`}
                style={{
                  justifyContent: isCurrentUserMessage ? 'flex-start' : 'flex-end',
                }}
              >
                <div
                  style={{
                    maxWidth: '70%',
                    background: isCurrentUserMessage ? '#f0f0f0' : '#1890ff',
                    color: isCurrentUserMessage ? '#000' : '#fff',
                    padding: '12px 16px',
                    borderRadius: '8px',
                    wordWrap: 'break-word',
                  }}
                >
                  <div>{msg.content}</div>
                  <div
                    style={{
                      fontSize: '12px',
                      marginTop: '4px',
                      opacity: 0.7,
                    }}
                  >
                    {formatFullTime(msg.created_at)}
                  </div>
                </div>
              </List.Item>
            );
          }}
        />
      </Card>

      <div className="version-badge">
        简聊 v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default ChatHistoryPage;

