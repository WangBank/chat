import { useCallback, useEffect, useState } from 'react';
import { Card, List, Input, Button, Space, DatePicker, Empty, message } from 'antd';
import { ArrowLeftOutlined, SearchOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { useNavigate, useParams } from 'react-router-dom';
import { chatStore } from '../stores/chat.store';
import { apiService, type ChatMessageApiResponse } from '../services/api.service';
import { APP_CONFIG } from '../config/app.config';
import { formatFullTime } from '../utils/time.utils';
import dayjs from 'dayjs';
import '../styles/common.css';

const { RangePicker } = DatePicker;
type MessageDateRange = [dayjs.Dayjs, dayjs.Dayjs] | null;

const ChatHistoryPage = observer(() => {
  const navigate = useNavigate();
  const { contactId } = useParams<{ contactId: string }>();
  const [messages, setMessages] = useState<ChatMessageApiResponse[]>([]);
  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [dateRange, setDateRange] = useState<MessageDateRange>(null);

  const loadMessages = useCallback(async (query: string = '', range: MessageDateRange = null) => {
    if (!contactId) return;

    setLoading(true);
    try {
      const response = await apiService.getChatHistory(Number(contactId));
      if (response.success && response.data) {
        let filteredMessages = response.data;

        // Search by content
        if (query.trim()) {
          const normalizedQuery = query.toLowerCase();
          filteredMessages = filteredMessages.filter((msg) =>
            msg.content.toLowerCase().includes(normalizedQuery)
          );
        }

        // Search by date range
        if (range && range[0] && range[1]) {
          const startDate = range[0].startOf('day').toDate();
          const endDate = range[1].endOf('day').toDate();
          filteredMessages = filteredMessages.filter((msg) => {
            const msgDate = new Date(msg.created_at);
            return msgDate >= startDate && msgDate <= endDate;
          });
        }

        setMessages(filteredMessages);
      }
    } catch (error) {
      console.error('Failed to load messages:', error);
      message.error('Failed to load messages');
    } finally {
      setLoading(false);
    }
  }, [contactId]);

  useEffect(() => {
    if (contactId) {
      loadMessages();
    }
  }, [contactId, loadMessages]);

  const handleSearch = () => {
    loadMessages(searchQuery, dateRange);
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
              Back
            </Button>
            <span>
              {contact
                ? `${contact.display_name || contact.contact_user.display_name || contact.contact_user.username} - Chat History`
                : 'Chat History'}
            </span>
          </Space>
        }
      >
        <Space direction="vertical" style={{ width: '100%', marginBottom: 16 }}>
          <Input
            placeholder="Search message content"
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
            onChange={(dates) => setDateRange(dates as MessageDateRange)}
            style={{ width: '100%' }}
            placeholder={['Start date', 'End date']}
          />
          <Button type="primary" onClick={handleSearch} loading={loading}>
            Search
          </Button>
        </Space>

        <List
          loading={loading}
          dataSource={messages}
          locale={{ emptyText: <Empty description="No messages yet" /> }}
          renderItem={(msg, index) => {
            // Simple rule: if current contact is receiver, sent messages belong to current user
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
        Love Chat v{APP_CONFIG.VERSION}
      </div>
    </div>
  );
});

export default ChatHistoryPage;
