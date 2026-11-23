import { useCallback, useState } from 'react';
import { Alert, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle, Divider,
  IconButton, MenuItem, Pagination, Paper, Stack, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, TextField, Tooltip, Typography } from '@mui/material';
import { BackupOutlined, CampaignOutlined, Refresh, Restore } from '@mui/icons-material';
import { apiService, type DatabaseBackup } from '../services/api.service';
import { getApiErrorMessage } from '../utils/error-message';
import { useServerList } from './useServerList';

const localTime = (time: string) => new Date(time).toLocaleString('zh-CN', { hour12: false });
const loadBackups = () => apiService.listBackups();
type Feedback = { severity: 'success' | 'error'; text: string };

function RefreshButton({ onClick, disabled }: { onClick: () => void; disabled: boolean }) {
  return <Tooltip title="刷新列表"><span><IconButton aria-label="刷新列表" disabled={disabled} onClick={onClick}>
    <Refresh />
  </IconButton></span></Tooltip>;
}

function ListStatus({ loading, error, empty, emptyText }: {
  loading: boolean; error?: string; empty: boolean; emptyText: string;
}) {
  if (error) return <Alert severity="error">{error}</Alert>;
  if (loading || empty) return <Typography role="status" color="text.secondary">{loading ? '正在加载…' : emptyText}</Typography>;
  return null;
}

export function BackupPanel() {
  const list = useServerList(loadBackups);
  const [selected, setSelected] = useState<DatabaseBackup>();
  const [busy, setBusy] = useState('');
  const [feedback, setFeedback] = useState<Feedback>();

  async function run(backup?: DatabaseBackup) {
    setFeedback(undefined);
    setBusy(backup ? '正在还原数据库…' : '正在创建备份…');
    setSelected(undefined);
    try {
      const result = backup ? await apiService.restoreBackup(backup.id) : await apiService.createBackup();
      if (!result.success || !result.data) throw new Error(result.message || '操作失败');
      setFeedback({ severity: 'success', text: backup
        ? `数据库已还原。还原前的保护备份创建于 ${localTime(result.data.createdAt)}。`
        : '数据库备份已创建。' });
    } catch (error) {
      setFeedback({ severity: 'error', text: getApiErrorMessage(error, '数据库操作失败，请刷新列表后检查结果') });
    } finally {
      setBusy('');
      list.refresh();
    }
  }

  return <Paper className="admin-operation-panel"><Stack spacing={2}>
    <div className="admin-operation-heading"><Typography variant="h6">数据库备份</Typography>
      <Stack direction="row" spacing={1}><RefreshButton onClick={list.refresh} disabled={!!busy || list.loading} />
        <Button variant="contained" startIcon={<BackupOutlined />} disabled={!!busy} onClick={() => void run()}>创建备份</Button>
      </Stack>
    </div>
    {busy && <Alert severity="info" role="status">{busy}</Alert>}
    {feedback && <Alert severity={feedback.severity}>{feedback.text}</Alert>}
    <ListStatus {...list} empty={!list.data?.length} emptyText="尚无数据库备份" />
    {!!list.data?.length && <TableContainer><Table size="small" aria-label="数据库备份列表">
      <TableHead><TableRow>{['备份时间', '类型', '大小', '操作'].map(label => <TableCell key={label}>{label}</TableCell>)}</TableRow></TableHead>
      <TableBody>{list.data.map(backup => <TableRow key={backup.id}>
        <TableCell>{localTime(backup.createdAt)}</TableCell>
        <TableCell>{backup.kind === 'before-restore' ? '还原前保护备份' : '手动备份'}</TableCell>
        <TableCell>{(backup.sizeBytes / 1024 / 1024).toLocaleString('zh-CN', { maximumFractionDigits: 2 })} MB</TableCell>
        <TableCell><Button size="small" startIcon={<Restore />} disabled={!!busy} onClick={() => setSelected(backup)}>还原</Button></TableCell>
      </TableRow>)}</TableBody></Table></TableContainer>}
    <Dialog open={!!selected} onClose={() => setSelected(undefined)} aria-labelledby="restore-backup-title">
      <DialogTitle id="restore-backup-title">还原数据库？</DialogTitle>
      <DialogContent>将用 {selected && localTime(selected.createdAt)} 的备份覆盖当前数据库。请先暂停业务写入。系统会先备份当前数据，上传文件不随数据库还原。</DialogContent>
      <DialogActions><Button autoFocus onClick={() => setSelected(undefined)}>取消</Button>
        <Button color="error" variant="contained" onClick={() => selected && void run(selected)}>确认还原</Button></DialogActions>
    </Dialog>
  </Stack></Paper>;
}

export function OperationLogPanel() {
  const [page, setPage] = useState(1);
  const [outcome, setOutcome] = useState('all');
  const [userId, setUserId] = useState('');
  const load = useCallback(() => apiService.getOperationLogs(page, {
    userId: userId ? Number(userId) : undefined,
    success: outcome === 'all' ? undefined : outcome === 'success',
  }), [page, outcome, userId]);
  const list = useServerList(load);
  return <Paper className="admin-operation-panel"><Stack spacing={2}>
    <div className="admin-operation-heading"><Typography variant="h6">用户操作日志</Typography>
      <Stack direction="row" spacing={1} sx={{ alignItems: 'center', flexWrap: 'wrap' }}>
        <TextField size="small" label="用户 ID" value={userId} sx={{ width: 102 }}
          slotProps={{ htmlInput: { inputMode: 'numeric' } }}
          onChange={event => {
            const value = event.target.value;
            if (/^\d*$/.test(value) && Number(value) <= 2147483647) {
              setUserId(value); setPage(1);
            }
          }} />
        <TextField select size="small" label="结果" value={outcome} onChange={e => { setOutcome(e.target.value); setPage(1); }}>
          <MenuItem value="all">全部结果</MenuItem><MenuItem value="success">成功</MenuItem><MenuItem value="failure">失败</MenuItem>
        </TextField>
        <RefreshButton onClick={list.refresh} disabled={list.loading} />
      </Stack>
    </div>
    <ListStatus {...list} empty={!list.data?.items.length} emptyText="暂无符合条件的操作记录" />
    {!!list.data?.items.length && <TableContainer><Table aria-label="用户操作日志" size="small">
      <TableHead><TableRow>{['时间', '用户', '操作', '来源', '结果'].map(label => <TableCell key={label}>{label}</TableCell>)}</TableRow></TableHead>
      <TableBody>{list.data.items.map(row => <TableRow key={row.id}>
        <TableCell>{localTime(row.createdAt)}</TableCell><TableCell>{row.username || (row.userId ? '用户' : '未登录用户')}{row.userId && ` #${row.userId}`}</TableCell>
        <TableCell>{row.operation}</TableCell><TableCell>{row.source}</TableCell>
        <TableCell><Chip size="small" color={row.success ? 'success' : 'error'} variant="outlined"
          label={[row.success ? '成功' : '失败', row.statusCode].filter(Boolean).join(' · ')} /></TableCell>
      </TableRow>)}</TableBody></Table></TableContainer>}
    {(list.data?.total ?? 0) > 25 && <Pagination page={page} count={Math.ceil(list.data!.total / 25)} onChange={(_, next) => setPage(next)} />}
  </Stack></Paper>;
}

export function PublishAnnouncementPanel() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState<Feedback>();
  const [page, setPage] = useState(1);
  const list = useServerList(useCallback(() => apiService.getAnnouncements(page), [page]));
  async function publish() {
    setSaving(true);
    setFeedback(undefined);
    try {
      const result = await apiService.publishAnnouncement(title.trim(), body.trim());
      if (!result.success) throw new Error(result.message || '发布失败');
      setTitle(''); setBody(''); setPage(1); list.refresh();
      setFeedback({ severity: 'success', text: '公告已发布给全体用户。' });
    } catch (error) {
      setFeedback({ severity: 'error', text: getApiErrorMessage(error, '公告发布失败') });
    } finally { setSaving(false); }
  }
  return <Paper className="admin-operation-panel"><Stack spacing={2}>
    <Typography variant="h6">发布公告</Typography>
    <Stack component="form" spacing={2} onSubmit={event => { event.preventDefault(); void publish(); }}>
      <TextField required label="公告标题" value={title} disabled={saving}
        onChange={e => setTitle(e.target.value)} slotProps={{ htmlInput: { maxLength: 120 } }} />
      <TextField required label="公告正文" multiline minRows={3} maxRows={12} value={body} disabled={saving}
        onChange={e => setBody(e.target.value)} slotProps={{ htmlInput: { maxLength: 4000 } }} />
      <Button type="submit" variant="contained" sx={{ alignSelf: 'flex-start' }} startIcon={<CampaignOutlined />}
        disabled={saving || !title.trim() || !body.trim()}>{saving ? '正在发布…' : '发布给全体用户'}</Button>
    </Stack>
    {feedback && <Alert severity={feedback.severity}>{feedback.text}</Alert>}
    <Divider />
    <div className="admin-operation-heading"><Typography variant="h6">已发布公告</Typography>
      <RefreshButton onClick={list.refresh} disabled={list.loading} /></div>
    <ListStatus {...list} empty={!list.data?.items.length} emptyText="尚未发布公告" />
    {list.data?.items.map(item => <Stack key={item.id} spacing={0.5}>
      <Typography component="h3" variant="subtitle1" sx={{ fontWeight: 700 }}>{item.title}</Typography>
      <Typography variant="caption" color="text.secondary">{localTime(item.published_at)}</Typography>
      <Typography sx={{ whiteSpace: 'pre-wrap' }}>{item.body}</Typography><Divider />
    </Stack>)}
    {(list.data?.total ?? 0) > 10 && <Pagination page={page} count={Math.ceil(list.data!.total / 10)} onChange={(_, next) => setPage(next)} />}
  </Stack></Paper>;
}
