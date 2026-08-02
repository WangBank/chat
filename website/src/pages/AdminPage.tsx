import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  AppBar,
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  Container,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Grid,
  IconButton,
  InputAdornment,
  Paper,
  Snackbar,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Toolbar,
  Tooltip,
  Tabs,
  Typography,
} from '@mui/material';
import {
  AdminPanelSettings,
  Badge,
  InfoOutlined,
  KeyOutlined,
  Logout,
  PeopleAltOutlined,
  Refresh,
  Search,
  WifiTethering,
} from '@mui/icons-material';
import { observer } from 'mobx-react-lite';
import { useNavigate } from 'react-router-dom';
import { adminStore, type User } from '../stores/admin.store';
import { authStore } from '../stores/auth.store';
import { APP_CONFIG } from '../config/app.config';
import { apiService } from '../services/api.service';
import { formatFullTime, formatTime } from '../utils/time.utils';

type AdminTab = 'all' | 'online';
type NoticeState = {
  open: boolean;
  severity: 'success' | 'info' | 'warning' | 'error';
  message: string;
};

const adminShell = {
  minHeight: '100vh',
  bgcolor: '#eef5fb',
  color: '#111820',
};

function getAvatarUrl(path?: string) {
  if (!path) return undefined;
  if (/^https?:\/\//i.test(path)) return path;
  return `${APP_CONFIG.API_BASE_URL}${path}`;
}

function getDisplayName(user: User) {
  return user.display_name || user.username;
}

function filterUsers(users: User[], searchText: string) {
  const keyword = searchText.trim().toLowerCase();
  if (!keyword) return users;

  return users.filter((user) =>
    [user.username, user.email, user.display_name]
      .filter(Boolean)
      .some((value) => value!.toLowerCase().includes(keyword))
  );
}

const AdminPage = observer(() => {
  const navigate = useNavigate();
  const [searchText, setSearchText] = useState('');
  const [activeTab, setActiveTab] = useState<AdminTab>('all');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [detailUser, setDetailUser] = useState<User | null>(null);
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordSaving, setPasswordSaving] = useState(false);
  const [notice, setNotice] = useState<NoticeState>({
    open: false,
    severity: 'info',
    message: '',
  });

  const notify = (message: string, severity: NoticeState['severity'] = 'info') => {
    setNotice({ open: true, severity, message });
  };

  useEffect(() => {
    if (!authStore.isAuthenticated) {
      notify('请先登录', 'warning');
      navigate('/login');
      return;
    }

    if (authStore.user?.username !== APP_CONFIG.ADMIN_USERNAME) {
      notify('当前账号没有管理员权限', 'warning');
      navigate('/chat');
      return;
    }

    authStore.ensureSignalRConnection().catch((error) => {
      console.error('SignalR connection failed:', error);
    });

    void adminStore.loadOnlineUsers();
    void adminStore.loadAllUsers();

    const refreshTimer = window.setInterval(() => {
      void adminStore.loadOnlineUsers({ silent: true });
      void adminStore.loadAllUsers(adminStore.currentPage, { silent: true });
    }, 5000);

    return () => window.clearInterval(refreshTimer);
  }, [navigate]);

  const filteredAllUsers = useMemo(
    () => filterUsers(adminStore.allUsers, searchText),
    [adminStore.allUsers, searchText]
  );
  const filteredOnlineUsers = useMemo(
    () => filterUsers(adminStore.onlineUsers, searchText),
    [adminStore.onlineUsers, searchText]
  );
  const visibleUsers = activeTab === 'online' ? filteredOnlineUsers : filteredAllUsers;

  const openPasswordDialog = (user: User) => {
    if (user.username === APP_CONFIG.ADMIN_USERNAME) {
      notify('管理员账号不允许在这里修改密码', 'warning');
      return;
    }

    setSelectedUser(user);
    setNewPassword('');
    setConfirmPassword('');
  };

  const handleRefresh = () => {
    if (activeTab === 'online') {
      void adminStore.loadOnlineUsers();
    } else {
      void adminStore.loadAllUsers(adminStore.currentPage);
    }
    notify('已刷新用户数据', 'success');
  };

  const handleLogout = async () => {
    await authStore.logout();
    navigate('/');
  };

  const handleChangePassword = async () => {
    if (!selectedUser) return;
    if (newPassword.length < 6) {
      notify('密码至少 6 位', 'warning');
      return;
    }
    if (newPassword !== confirmPassword) {
      notify('两次输入的密码不一致', 'warning');
      return;
    }

    setPasswordSaving(true);
    try {
      const response = await apiService.adminChangeUserPassword(selectedUser.id, newPassword);
      if (response.success) {
        notify('密码已修改', 'success');
        setSelectedUser(null);
        setNewPassword('');
        setConfirmPassword('');
      } else {
        notify(response.message || '修改密码失败', 'error');
      }
    } catch (error) {
      notify(error instanceof Error ? error.message : '修改密码失败', 'error');
    } finally {
      setPasswordSaving(false);
    }
  };

  return (
    <Box sx={adminShell}>
      <AppBar position="sticky" elevation={0} sx={{ bgcolor: '#12a8f4' }}>
        <Toolbar sx={{ gap: 2, minHeight: 62 }}>
          <Avatar sx={{ bgcolor: 'white', color: '#078fdb', width: 34, height: 34 }}>
            <AdminPanelSettings fontSize="small" />
          </Avatar>
          <Box sx={{ minWidth: 0, flex: 1 }}>
            <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.2 }}>
              管理控制台
            </Typography>
            <Typography variant="caption" sx={{ color: 'rgba(255,255,255,0.82)' }}>
              Love Chat 用户、在线状态和账号安全
            </Typography>
          </Box>
          <Tooltip title="刷新">
            <IconButton color="inherit" onClick={handleRefresh}>
              <Refresh />
            </IconButton>
          </Tooltip>
          <Button color="inherit" startIcon={<Logout />} onClick={handleLogout}>
            退出
          </Button>
        </Toolbar>
      </AppBar>

      <Container maxWidth="xl" sx={{ py: { xs: 2, md: 3 } }}>
        <Stack spacing={3}>
          <Grid container spacing={2}>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2.25, borderRadius: 2.5 }}>
                <Stack direction="row" spacing={1.5} sx={{ alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: '#e8f8ef', color: '#1d8d4d' }}>
                    <WifiTethering />
                  </Avatar>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      在线用户
                    </Typography>
                    <Typography variant="h4" sx={{ fontWeight: 900 }}>
                      {adminStore.onlineUsers.length}
                    </Typography>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, sm: 6, md: 3 }}>
              <Paper sx={{ p: 2.25, borderRadius: 2.5 }}>
                <Stack direction="row" spacing={1.5} sx={{ alignItems: 'center' }}>
                  <Avatar sx={{ bgcolor: '#e8f6ff', color: '#078fdb' }}>
                    <PeopleAltOutlined />
                  </Avatar>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      全部用户
                    </Typography>
                    <Typography variant="h4" sx={{ fontWeight: 900 }}>
                      {adminStore.totalUsers}
                    </Typography>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
            <Grid size={{ xs: 12, md: 6 }}>
              <Paper
                sx={{
                  p: 2.25,
                  borderRadius: 2.5,
                  height: '100%',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <Stack direction="row" spacing={1.5} sx={{ minWidth: 0, alignItems: 'center' }}>
                  <Badge sx={{ color: '#078fdb' }} />
                  <Box sx={{ minWidth: 0 }}>
                    <Typography variant="body2" color="text.secondary">
                      当前管理员
                    </Typography>
                    <Typography variant="h6" noWrap sx={{ fontWeight: 800 }}>
                      {authStore.user?.display_name || authStore.user?.username || 'admin'}
                    </Typography>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
          </Grid>

          <Paper sx={{ borderRadius: 2.5, overflow: 'hidden' }}>
            <Stack
              direction={{ xs: 'column', md: 'row' }}
              spacing={2}
              sx={{
                p: 2.25,
                borderBottom: '1px solid #e5edf3',
                alignItems: { xs: 'stretch', md: 'center' },
                justifyContent: 'space-between',
              }}
            >
              <Box>
                <Typography variant="h6" sx={{ fontWeight: 900 }}>
                  用户管理
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  每 5 秒自动同步在线状态，可手动刷新或为普通账号重置密码。
                </Typography>
              </Box>
              <TextField
                value={searchText}
                onChange={(event) => setSearchText(event.target.value)}
                placeholder="搜索用户名、邮箱或昵称"
                size="small"
                sx={{ minWidth: { xs: '100%', md: 320 } }}
                slotProps={{
                  input: {
                    startAdornment: (
                      <InputAdornment position="start">
                        <Search fontSize="small" />
                      </InputAdornment>
                    ),
                  },
                }}
              />
            </Stack>

            <Tabs
              value={activeTab}
              onChange={(_, value: AdminTab) => {
                setActiveTab(value);
                setSearchText('');
                if (value === 'online') {
                  void adminStore.loadOnlineUsers();
                } else {
                  void adminStore.loadAllUsers(adminStore.currentPage);
                }
              }}
              sx={{ px: 2.25, borderBottom: '1px solid #e5edf3' }}
            >
              <Tab value="all" label={`全部用户 (${adminStore.totalUsers})`} />
              <Tab value="online" label={`在线用户 (${adminStore.onlineUsers.length})`} />
            </Tabs>

            <TableContainer sx={{ maxHeight: 'calc(100vh - 360px)' }}>
              <Table stickyHeader size="medium" aria-label="用户列表">
                <TableHead>
                  <TableRow>
                    <TableCell width={76}>ID</TableCell>
                    <TableCell>用户</TableCell>
                    <TableCell>邮箱</TableCell>
                    <TableCell>状态</TableCell>
                    <TableCell>最后登录</TableCell>
                    <TableCell>创建时间</TableCell>
                    <TableCell align="right" width={190}>操作</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {adminStore.isLoading && (
                    <TableRow>
                      <TableCell colSpan={7}>
                        <Stack sx={{ py: 4, alignItems: 'center' }}>
                          <CircularProgress size={28} />
                        </Stack>
                      </TableCell>
                    </TableRow>
                  )}
                  {!adminStore.isLoading && visibleUsers.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={7}>
                        <Box sx={{ py: 6, textAlign: 'center', color: 'text.secondary' }}>
                          没有匹配的用户
                        </Box>
                      </TableCell>
                    </TableRow>
                  )}
                  {!adminStore.isLoading &&
                    visibleUsers.map((user) => (
                      <TableRow hover key={user.id}>
                        <TableCell>{user.id}</TableCell>
                        <TableCell>
                          <Stack direction="row" spacing={1.25} sx={{ alignItems: 'center' }}>
                            <Avatar src={getAvatarUrl(user.avatar_path)} sx={{ bgcolor: '#12a8f4' }}>
                              {getDisplayName(user).slice(0, 1).toUpperCase()}
                            </Avatar>
                            <Box sx={{ minWidth: 0 }}>
                              <Typography variant="body2" noWrap sx={{ fontWeight: 800 }}>
                                {getDisplayName(user)}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" noWrap>
                                @{user.username}
                              </Typography>
                            </Box>
                          </Stack>
                        </TableCell>
                        <TableCell>{user.email}</TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={user.is_online ? '在线' : '离线'}
                            color={user.is_online ? 'success' : 'default'}
                            variant={user.is_online ? 'filled' : 'outlined'}
                          />
                        </TableCell>
                        <TableCell>{user.last_login_at ? formatTime(user.last_login_at) : '-'}</TableCell>
                        <TableCell>{formatTime(user.created_at)}</TableCell>
                        <TableCell align="right">
                          <Stack direction="row" spacing={0.5} sx={{ justifyContent: 'flex-end' }}>
                            <Tooltip title="查看资料">
                              <IconButton size="small" onClick={() => setDetailUser(user)}>
                                <InfoOutlined fontSize="small" />
                              </IconButton>
                            </Tooltip>
                            {user.username !== APP_CONFIG.ADMIN_USERNAME && (
                              <Tooltip title="修改密码">
                                <IconButton size="small" onClick={() => openPasswordDialog(user)}>
                                  <KeyOutlined fontSize="small" />
                                </IconButton>
                              </Tooltip>
                            )}
                          </Stack>
                        </TableCell>
                      </TableRow>
                    ))}
                </TableBody>
              </Table>
            </TableContainer>

            {activeTab === 'all' && (
              <TablePagination
                component="div"
                count={adminStore.totalUsers}
                page={Math.max(adminStore.currentPage - 1, 0)}
                rowsPerPage={adminStore.pageSize}
                rowsPerPageOptions={[adminStore.pageSize]}
                onPageChange={(_, page) => void adminStore.loadAllUsers(page + 1)}
              />
            )}
          </Paper>
        </Stack>
      </Container>

      <Dialog open={Boolean(detailUser)} onClose={() => setDetailUser(null)} maxWidth="xs" fullWidth>
        <DialogTitle>用户资料</DialogTitle>
        <DialogContent>
          {detailUser && (
            <Stack spacing={1.25} sx={{ pt: 1 }}>
              <Stack direction="row" spacing={1.5} sx={{ alignItems: 'center' }}>
                <Avatar src={getAvatarUrl(detailUser.avatar_path)} sx={{ bgcolor: '#12a8f4', width: 52, height: 52 }}>
                  {getDisplayName(detailUser).slice(0, 1).toUpperCase()}
                </Avatar>
                <Box>
                  <Typography variant="h6" sx={{ fontWeight: 900 }}>
                    {getDisplayName(detailUser)}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    @{detailUser.username}
                  </Typography>
                </Box>
              </Stack>
              <Divider />
              <Typography variant="body2">用户 ID：{detailUser.id}</Typography>
              <Typography variant="body2">邮箱：{detailUser.email}</Typography>
              <Typography variant="body2">
                状态：{detailUser.is_online ? '在线' : '离线'}
              </Typography>
              <Typography variant="body2">
                最后登录：{detailUser.last_login_at ? formatFullTime(detailUser.last_login_at) : '-'}
              </Typography>
              <Typography variant="body2">创建时间：{formatFullTime(detailUser.created_at)}</Typography>
              <Typography variant="body2">更新时间：{formatFullTime(detailUser.updated_at)}</Typography>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailUser(null)}>关闭</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={Boolean(selectedUser)} onClose={() => setSelectedUser(null)} maxWidth="xs" fullWidth>
        <DialogTitle>修改密码</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <Typography variant="body2" color="text.secondary">
              为 {selectedUser?.username} 设置新密码。
            </Typography>
            <TextField
              label="新密码"
              type="password"
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              autoFocus
              fullWidth
            />
            <TextField
              label="确认密码"
              type="password"
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              fullWidth
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setSelectedUser(null)}>取消</Button>
          <Button variant="contained" onClick={handleChangePassword} disabled={passwordSaving}>
            {passwordSaving ? '保存中' : '保存'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={notice.open}
        autoHideDuration={2600}
        onClose={() => setNotice((current) => ({ ...current, open: false }))}
        anchorOrigin={{ vertical: 'top', horizontal: 'center' }}
      >
        <Alert
          severity={notice.severity}
          variant="filled"
          onClose={() => setNotice((current) => ({ ...current, open: false }))}
        >
          {notice.message}
        </Alert>
      </Snackbar>
    </Box>
  );
});

export default AdminPage;
