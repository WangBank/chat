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
  EditOutlined,
  InfoOutlined,
  KeyOutlined,
  Logout,
  PeopleAltOutlined,
  PersonAddAltOutlined,
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
import { isAdminUser } from '../utils/admin.utils';
import { formatFullTime, formatTime } from '../utils/time.utils';

type AdminTab = 'all' | 'online';
type UserDialogMode = 'create' | 'edit';
type UserFormState = {
  username: string;
  email: string;
  display_name: string;
  password: string;
};
type UserFormErrors = Partial<Record<keyof UserFormState, string>>;
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
const emptyUserForm: UserFormState = {
  username: '',
  email: '',
  display_name: '',
  password: '',
};
const duplicateIdentityMessage = '当前用户名或者邮箱被使用请重新输入';
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const usernamePattern = /^[A-Za-z0-9_-]+$/;

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

function getApiErrorMessage(error: unknown, fallback: string) {
  const apiError = error as { response?: { data?: { message?: unknown; errors?: unknown[] } }; message?: unknown };
  if (typeof apiError.response?.data?.message === 'string') {
    return apiError.response.data.message;
  }
  if (Array.isArray(apiError.response?.data?.errors) && typeof apiError.response.data.errors[0] === 'string') {
    return apiError.response.data.errors[0];
  }
  if (typeof apiError.message === 'string') {
    return apiError.message;
  }
  return fallback;
}

const AdminPage = observer(() => {
  const navigate = useNavigate();
  const [searchText, setSearchText] = useState('');
  const [activeTab, setActiveTab] = useState<AdminTab>('all');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [detailUser, setDetailUser] = useState<User | null>(null);
  const [userDialogMode, setUserDialogMode] = useState<UserDialogMode | null>(null);
  const [editingUser, setEditingUser] = useState<User | null>(null);
  const [userForm, setUserForm] = useState<UserFormState>(emptyUserForm);
  const [userFormErrors, setUserFormErrors] = useState<UserFormErrors>({});
  const [userSaving, setUserSaving] = useState(false);
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

    if (!isAdminUser(authStore.user)) {
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
  const isUserDialogOpen = Boolean(userDialogMode);
  const isEditingAdmin = userDialogMode === 'edit' && isAdminUser(editingUser);

  const openPasswordDialog = (user: User) => {
    if (isAdminUser(user)) {
      notify('管理员账号不允许在这里修改密码', 'warning');
      return;
    }

    setSelectedUser(user);
    setNewPassword('');
    setConfirmPassword('');
  };

  const openCreateUserDialog = () => {
    setUserDialogMode('create');
    setEditingUser(null);
    setUserForm(emptyUserForm);
    setUserFormErrors({});
  };

  const openEditUserDialog = (user: User) => {
    setUserDialogMode('edit');
    setEditingUser(user);
    setUserForm({
      username: user.username,
      email: user.email,
      display_name: user.display_name || '',
      password: '',
    });
    setUserFormErrors({});
  };

  const closeUserDialog = () => {
    setUserDialogMode(null);
    setEditingUser(null);
    setUserForm(emptyUserForm);
    setUserFormErrors({});
  };

  const updateUserForm = (field: keyof UserFormState, value: string) => {
    setUserForm((current) => ({ ...current, [field]: value }));
    setUserFormErrors((current) => ({ ...current, [field]: undefined }));
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

  const validateUserForm = () => {
    const errors: UserFormErrors = {};
    const username = userForm.username.trim();
    const email = userForm.email.trim();

    if (!username) {
      errors.username = '请输入用户名';
    } else if (username.length < 3) {
      errors.username = '用户名至少 3 位';
    } else if (username.length > 50) {
      errors.username = '用户名不能超过 50 位';
    } else if (!usernamePattern.test(username)) {
      errors.username = '仅支持英文字母、数字、下划线或短横线';
    }

    if (!email) {
      errors.email = '请输入邮箱';
    } else if (email.length > 100) {
      errors.email = '邮箱不能超过 100 个字符';
    } else if (!emailPattern.test(email)) {
      errors.email = '请输入有效邮箱';
    }

    if (userDialogMode === 'create' && userForm.password.length < 6) {
      errors.password = '密码至少 6 位';
    }

    setUserFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const reloadUserData = async () => {
    await Promise.all([
      adminStore.loadAllUsers(adminStore.currentPage, { silent: true }),
      adminStore.loadOnlineUsers({ silent: true }),
    ]);
  };

  const handleSaveUser = async () => {
    if (!userDialogMode || !validateUserForm()) return;

    setUserSaving(true);
    try {
      const payload = {
        username: userForm.username.trim(),
        email: userForm.email.trim().toLowerCase(),
        display_name: userForm.display_name.trim() || undefined,
      };
      const response =
        userDialogMode === 'create'
          ? await apiService.adminCreateUser({
              ...payload,
              password: userForm.password,
            })
          : editingUser
            ? await apiService.adminUpdateUser(editingUser.id, payload)
            : null;

      if (!response) return;

      if (response.success) {
        notify(userDialogMode === 'create' ? '用户已创建' : '用户已更新', 'success');
        closeUserDialog();
        await reloadUserData();
        return;
      }

      const message = response.message || (userDialogMode === 'create' ? '创建用户失败' : '修改用户失败');
      if (message.includes('用户名') || message.includes('邮箱')) {
        setUserFormErrors((current) => ({ ...current, username: message, email: message }));
      }
      notify(message, 'error');
    } catch (error) {
      const message = getApiErrorMessage(error, userDialogMode === 'create' ? '创建用户失败' : '修改用户失败');
      if (message.includes('用户名') || message.includes('邮箱')) {
        setUserFormErrors((current) => ({ ...current, username: message, email: message }));
      }
      notify(message, 'error');
    } finally {
      setUserSaving(false);
    }
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
      notify(getApiErrorMessage(error, '修改密码失败'), 'error');
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
	                  每 5 秒自动同步在线状态，可新建账号、编辑资料或为普通账号重置密码。
	                </Typography>
	              </Box>
	              <Stack
	                direction={{ xs: 'column', sm: 'row' }}
	                spacing={1.25}
	                sx={{ alignItems: { xs: 'stretch', sm: 'center' } }}
	              >
	                <Button
	                  variant="contained"
	                  startIcon={<PersonAddAltOutlined />}
	                  onClick={openCreateUserDialog}
	                  sx={{ bgcolor: '#12a8f4', boxShadow: 'none', '&:hover': { bgcolor: '#078fdb', boxShadow: 'none' } }}
	                >
	                  新建用户
	                </Button>
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
	                            <Tooltip title="编辑用户">
	                              <IconButton size="small" onClick={() => openEditUserDialog(user)}>
	                                <EditOutlined fontSize="small" />
	                              </IconButton>
	                            </Tooltip>
	                            {!isAdminUser(user) && (
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

      <Dialog open={isUserDialogOpen} onClose={closeUserDialog} maxWidth="sm" fullWidth>
        <DialogTitle>
          <Stack direction="row" spacing={1.25} sx={{ alignItems: 'center' }}>
            <Avatar sx={{ bgcolor: '#e8f6ff', color: '#078fdb', width: 34, height: 34 }}>
              {userDialogMode === 'create' ? <PersonAddAltOutlined fontSize="small" /> : <EditOutlined fontSize="small" />}
            </Avatar>
            <Box>
              <Typography variant="h6" sx={{ fontWeight: 900 }}>
                {userDialogMode === 'create' ? '新建用户' : '编辑用户'}
              </Typography>
              <Typography variant="body2" color="text.secondary">
                {userDialogMode === 'create' ? '创建可登录的聊天账号' : editingUser ? `正在编辑 @${editingUser.username}` : '编辑账号信息'}
              </Typography>
            </Box>
          </Stack>
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ pt: 1 }}>
            <TextField
              label="用户名"
              value={userForm.username}
              onChange={(event) => updateUserForm('username', event.target.value)}
              error={Boolean(userFormErrors.username)}
              helperText={userFormErrors.username || '3-50 位，支持英文字母、数字、下划线或短横线'}
              autoFocus
              fullWidth
            />
            <TextField
              label="邮箱"
              value={userForm.email}
              onChange={(event) => updateUserForm('email', event.target.value)}
              error={Boolean(userFormErrors.email)}
              helperText={
                userFormErrors.email ||
                (isEditingAdmin ? `管理员邮箱固定为 ${APP_CONFIG.ADMIN_EMAILS.join('、') || '配置的管理员邮箱'}` : '用于登录身份和管理员权限识别')
              }
              disabled={isEditingAdmin}
              fullWidth
            />
            <TextField
              label="昵称"
              value={userForm.display_name}
              onChange={(event) => updateUserForm('display_name', event.target.value)}
              error={Boolean(userFormErrors.display_name)}
              helperText={userFormErrors.display_name || '可留空'}
              fullWidth
            />
            {userDialogMode === 'create' && (
              <TextField
                label="初始密码"
                type="password"
                value={userForm.password}
                onChange={(event) => updateUserForm('password', event.target.value)}
                error={Boolean(userFormErrors.password)}
                helperText={userFormErrors.password || '至少 6 位'}
                fullWidth
              />
            )}
            {(userFormErrors.username === duplicateIdentityMessage || userFormErrors.email === duplicateIdentityMessage) && (
              <Alert severity="warning" variant="outlined">
                {duplicateIdentityMessage}
              </Alert>
            )}
          </Stack>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={closeUserDialog} disabled={userSaving}>
            取消
          </Button>
          <Button variant="contained" onClick={handleSaveUser} disabled={userSaving}>
            {userSaving ? '保存中' : userDialogMode === 'create' ? '创建' : '保存'}
          </Button>
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
