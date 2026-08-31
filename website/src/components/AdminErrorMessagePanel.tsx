import {
  Alert,
  Box,
  Button,
  Chip,
  Divider,
  Paper,
  Stack,
  Typography,
} from '@mui/material';
import { DeleteSweepOutlined, Refresh } from '@mui/icons-material';
import type { ErrorMessageEntry } from '../stores/error-message.store';
import { formatFullTime } from '../utils/time.utils';

interface AdminErrorMessagePanelProps {
  messages: ErrorMessageEntry[];
  onClear: () => void;
  onRefresh: () => void;
}

export default function AdminErrorMessagePanel({ messages, onClear, onRefresh }: AdminErrorMessagePanelProps) {
  return (
    <Paper sx={{ borderRadius: 2.5, overflow: 'hidden' }}>
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.5}
        sx={{ p: 2.25, alignItems: { xs: 'stretch', sm: 'center' }, justifyContent: 'space-between' }}
      >
        <Box>
          <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
            <Typography variant="h6" sx={{ fontWeight: 900 }}>
              系统错误消息
            </Typography>
            {messages.length > 0 && <Chip size="small" color="error" label={`${messages.length} 条`} />}
          </Stack>
          <Typography variant="body2" color="text.secondary">
            显示当前管理员会话中捕获的接口错误和操作提示，便于定位具体原因。
          </Typography>
        </Box>
        <Stack direction="row" spacing={1} sx={{ justifyContent: 'flex-end' }}>
          <Button size="small" startIcon={<Refresh />} onClick={onRefresh}>重试请求</Button>
          <Button size="small" color="inherit" startIcon={<DeleteSweepOutlined />} onClick={onClear} disabled={messages.length === 0}>
            清空记录
          </Button>
        </Stack>
      </Stack>
      <Divider />
      <Box sx={{ p: 2.25 }}>
        {messages.length === 0 ? (
          <Alert severity="success" variant="outlined">暂无错误消息</Alert>
        ) : (
          <Stack spacing={1} sx={{ maxHeight: 280, overflowY: 'auto' }}>
            {messages.map((entry) => (
              <Alert key={entry.id} severity={entry.severity} variant="outlined" sx={{ alignItems: 'flex-start' }}>
                <Stack spacing={0.25}>
                  <Typography variant="body2" sx={{ whiteSpace: 'pre-line', fontWeight: 700 }}>
                    {entry.message}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {entry.scope} · {formatFullTime(entry.occurredAt)}
                  </Typography>
                </Stack>
              </Alert>
            ))}
          </Stack>
        )}
      </Box>
    </Paper>
  );
}

