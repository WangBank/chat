import { useCallback, useEffect, useState } from 'react';
import { Alert, Badge, Button, Empty, Modal, Pagination, Spin, Tooltip } from 'antd';
import { NotificationOutlined, ReloadOutlined } from '@ant-design/icons';
import { apiService, type Announcement } from '../services/api.service';
import { signalRService } from '../services/signalr.service';
import { getApiErrorMessage } from '../utils/error-message';
import { useServerList } from './useServerList';

export default function AnnouncementInbox() {
  const [open, setOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [expanded, setExpanded] = useState<number>();
  const [readError, setReadError] = useState('');
  const { data, error, loading, refresh } = useServerList(useCallback(
    () => apiService.getAnnouncements(open ? page : 1, open ? 10 : 1), [page, open],
  ));
  useEffect(() => {
    const visible = () => { if (!document.hidden) refresh(); };
    const events = signalRService.announcementEvents;
    events.addEventListener('change', refresh);
    window.addEventListener('online', refresh);
    document.addEventListener('visibilitychange', visible);
    return () => {
      events.removeEventListener('change', refresh);
      window.removeEventListener('online', refresh);
      document.removeEventListener('visibilitychange', visible);
    };
  }, [refresh]);

  async function showAnnouncement(item: Announcement) {
    setExpanded(expanded === item.id ? undefined : item.id);
    setReadError('');
    if (item.is_read) return;
    try {
      const response = await apiService.readAnnouncement(item.id);
      if (!response.success) throw new Error(response.message || '标记已读失败');
      refresh();
    } catch (reason) {
      setReadError(getApiErrorMessage(reason, '标记已读失败'));
    }
  }

  return <>
    <Tooltip title="系统公告"><Button type="text" className="message-notice-button" aria-label="系统公告"
      onClick={() => { setPage(1); setExpanded(undefined); setReadError(''); setOpen(true); }}>
      <Badge count={data?.unread_count} size="small" offset={[-2, 4]}><NotificationOutlined /></Badge>
    </Button></Tooltip>
    <Modal title="系统公告" open={open} onCancel={() => setOpen(false)} footer={null} width={520}>
      <div className="announcement-toolbar">
        <span>{data ? `共 ${data.total} 条 · ${data.unread_count} 条未读` : ''}</span>
        <Button type="text" icon={<ReloadOutlined />} aria-label="刷新公告" onClick={refresh} loading={loading} />
      </div>
      {(error || readError) && <Alert type="error" showIcon title={error || readError} />}
      {loading && !data ? <Spin /> : data?.total === 0 && <Empty description="暂无系统公告" />}
      <ul className="announcement-list">
        {data?.items.map(item => <li key={item.id}>
          <button type="button" aria-expanded={expanded === item.id} onClick={() => void showAnnouncement(item)}>
            <span>{!item.is_read && <i aria-label="未读" />}{item.title}</span>
            <time dateTime={item.published_at}>{new Date(item.published_at).toLocaleString('zh-CN', { hour12: false })}</time>
          </button>
          {expanded === item.id && <p>{item.body}</p>}
        </li>)}
      </ul>
      {(data?.total ?? 0) > 10 && <Pagination current={page} pageSize={10} total={data?.total} showSizeChanger={false}
        onChange={next => { setExpanded(undefined); setPage(next); }} />}
    </Modal>
  </>;
}
