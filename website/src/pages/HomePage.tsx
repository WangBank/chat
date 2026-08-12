import { useEffect } from 'react';
import {
  AppBar,
  Avatar,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Container,
  Divider,
  Grid,
  List,
  ListItem,
  ListItemAvatar,
  ListItemText,
  Paper,
  Stack,
  Toolbar,
  Typography,
} from '@mui/material';
import {
  Android,
  CloudSync,
  Download,
  History,
  Login,
  Message,
  Security,
  SupervisorAccount,
  TabletMac,
  VideoCall,
  Web,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { APP_CONFIG } from '../config/app.config';

const PRODUCT_NAME = 'Love Chat';

const featureItems = [
  {
    icon: <Message />,
    title: '完整聊天',
    text: '会话列表、消息气泡、表情、图片、文件、语音和未读状态集中在同一个聊天工作台。',
  },
  {
    icon: <SupervisorAccount />,
    title: '好友管理',
    text: '支持搜索添加好友、好友申请处理、备注名、自定义头像和个性签名展示。',
  },
  {
    icon: <VideoCall />,
    title: '音视频通话',
    text: '在聊天和联系人页保留语音、视频通话入口，适合网页端、平板和移动端快速发起沟通。',
  },
  {
    icon: <History />,
    title: '历史记录',
    text: '按聊天、图片、文件和链接回看关键内容，便于从长期会话中快速定位信息。',
  },
  {
    icon: <CloudSync />,
    title: '实时在线',
    text: '在线状态、消息已读、头像和资料通过账号体系同步，减少多端状态不一致。',
  },
  {
    icon: <Security />,
    title: '安全防护',
    text: '保留敏感词过滤、防注入和账号安全能力，为真实使用场景提供基础防线。',
  },
];

const deviceItems = [
  {
    icon: <Web />,
    name: '桌面浏览器',
    status: '推荐',
    text: '打开网页即可使用完整聊天、好友、群聊和管理控制台。',
  },
  {
    icon: <TabletMac />,
    name: 'iPad 浏览器',
    status: '已支持',
    text: 'iPad 横屏和竖屏下都可以直接使用网页版，聊天、好友、群组、历史记录和资料入口保持完整。',
  },
  {
    icon: <Android />,
    name: 'Android 客户端',
    status: '可下载',
    text: '安装 APK 后可使用移动端聊天、联系人、资料和通话功能。',
  },
];

const metricItems = [
  ['Web', '网页版入口'],
  ['APK', '移动端下载'],
  ['IM', '即时消息'],
  ['RTC', '音视频通话'],
];

const HomePage = () => {
  const navigate = useNavigate();

  useEffect(() => {
    document.title = PRODUCT_NAME;
  }, []);

  const handleDownload = () => {
    window.open(APP_CONFIG.APK_DOWNLOAD_URL, '_blank');
  };

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#eef5fb', color: '#111820' }}>
      <AppBar position="sticky" elevation={0} sx={{ bgcolor: '#12a8f4' }}>
        <Toolbar sx={{ gap: 1.5, minHeight: 58 }}>
          <Avatar sx={{ bgcolor: 'white', color: '#078fdb', width: 34, height: 34, fontWeight: 900 }}>
            Q
          </Avatar>
          <Box sx={{ minWidth: 0, flex: 1 }}>
            <Typography variant="subtitle1" noWrap sx={{ fontWeight: 900, lineHeight: 1.2 }}>
              {PRODUCT_NAME}
            </Typography>
            <Typography variant="caption" noWrap sx={{ display: 'block', color: 'rgba(255,255,255,0.82)' }}>
              网页版 · iPad · Android · 实时通信系统
            </Typography>
          </Box>
          <Chip
            size="small"
            label={`v${APP_CONFIG.VERSION}`}
            sx={{ bgcolor: 'rgba(255,255,255,0.16)', color: 'white', borderColor: 'rgba(255,255,255,0.24)' }}
            variant="outlined"
          />
        </Toolbar>
      </AppBar>

      <Container maxWidth="xl" sx={{ py: { xs: 2, sm: 3, lg: 4 } }}>
        <Stack spacing={3}>
          <Paper
            sx={{
              overflow: 'hidden',
              borderRadius: 2.5,
              boxShadow: '0 18px 42px rgba(16,42,70,0.12)',
            }}
          >
            <Grid container>
              <Grid size={{ xs: 12, md: 7 }}>
                <Box sx={{ p: { xs: 3, sm: 4, lg: 5 } }}>
                  <Chip label="实时通信系统" color="primary" sx={{ mb: 2, fontWeight: 800 }} />
                  <Typography
                    variant="h2"
                    sx={{
                      maxWidth: 680,
                      fontSize: { xs: 34, sm: 42, md: 46, lg: 54 },
                      lineHeight: 1.04,
                      fontWeight: 950,
                      letterSpacing: 0,
                      mb: 2,
                      overflowWrap: 'break-word',
                    }}
                  >
                    Love Chat 通讯系统
                  </Typography>
                  <Typography
                    variant="body1"
                    color="text.secondary"
                    sx={{ maxWidth: 720, lineHeight: 1.8, mb: 3, overflowWrap: 'break-word' }}
                  >
                    面向桌面浏览器、iPad 和 Android 的即时通信应用，覆盖账号登录、聊天、好友、群组、历史记录、个性资料、表情和音视频通话等核心能力。
                  </Typography>
                  <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
                    <Button variant="contained" size="large" startIcon={<Login />} onClick={() => navigate('/login')}>
                      进入网页版
                    </Button>
                    <Button variant="outlined" size="large" startIcon={<Download />} onClick={handleDownload}>
                      下载 Android
                    </Button>
                  </Stack>
                </Box>
              </Grid>
              <Grid size={{ xs: 12, md: 5 }}>
                <Box
                  sx={{
                    height: '100%',
                    minHeight: { xs: 300, sm: 360 },
                    p: { xs: 2, sm: 2.5, lg: 3 },
                    bgcolor: '#f8fbfd',
                    borderLeft: { md: '1px solid #e5edf3' },
                    borderTop: { xs: '1px solid #e5edf3', md: 'none' },
                  }}
                >
                  <Card sx={{ height: '100%', borderRadius: 2, boxShadow: 'none', border: '1px solid #e5edf3' }}>
                    <CardContent>
                      <Stack direction="row" spacing={1.25} sx={{ mb: 2, alignItems: 'center' }}>
                        <Security color="primary" />
                        <Typography variant="subtitle1" sx={{ fontWeight: 900, flex: 1 }}>
                          系统状态
                        </Typography>
                        <Chip size="small" color="success" label="Ready" />
                      </Stack>
                      <Divider sx={{ mb: 2 }} />
                      <Grid container spacing={1.25}>
                        {metricItems.map(([value, label]) => (
                          <Grid size={{ xs: 6 }} key={value}>
                            <Paper variant="outlined" sx={{ p: 2, textAlign: 'center', borderRadius: 2 }}>
                              <Typography variant="h5" sx={{ fontWeight: 950 }}>
                                {value}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                {label}
                              </Typography>
                            </Paper>
                          </Grid>
                        ))}
                      </Grid>
                      <Box
                        component="img"
                        src="/chat.svg"
                        alt="Love Chat"
                        sx={{
                          display: 'block',
                          width: 124,
                          height: 124,
                          mx: 'auto',
                          mt: 3,
                          opacity: 0.9,
                        }}
                      />
                    </CardContent>
                  </Card>
                </Box>
              </Grid>
            </Grid>
          </Paper>

          <Box>
            <Typography variant="h5" sx={{ fontWeight: 950, mb: 0.5 }}>
              系统功能
            </Typography>
            <Grid container spacing={2} sx={{ mt: 1.75 }}>
              {featureItems.map((item) => (
                <Grid size={{ xs: 12, sm: 6, md: 4 }} key={item.title}>
                  <Card sx={{ height: '100%', borderRadius: 2.5, boxShadow: 'none', border: '1px solid #e5edf3' }}>
                    <CardContent>
                      <Avatar sx={{ bgcolor: '#e8f6ff', color: '#078fdb', mb: 1.5 }}>{item.icon}</Avatar>
                      <Typography variant="h6" sx={{ fontWeight: 900, mb: 0.75 }}>
                        {item.title}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.7 }}>
                        {item.text}
                      </Typography>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </Box>

          <Paper sx={{ borderRadius: 2.5, overflow: 'hidden' }}>
            <Box sx={{ p: { xs: 2, sm: 2.5 }, borderBottom: '1px solid #e5edf3' }}>
              <Typography variant="h5" sx={{ fontWeight: 950 }}>
                支持设备
              </Typography>
              <Typography variant="body2" color="text.secondary">
                根据使用场景选择桌面浏览器、iPad 网页版或 Android 客户端。
              </Typography>
            </Box>
            <List disablePadding>
              {deviceItems.map((item, index) => (
                <ListItem
                  key={item.name}
                  divider={index < deviceItems.length - 1}
                  secondaryAction={<Chip size="small" label={item.status} color={index === 0 ? 'primary' : 'success'} />}
                  sx={{
                    py: { xs: 1.5, sm: 2 },
                    pr: { xs: 11, sm: 14 },
                    alignItems: 'flex-start',
                  }}
                >
                  <ListItemAvatar>
                    <Avatar sx={{ bgcolor: '#e8f6ff', color: '#078fdb' }}>{item.icon}</Avatar>
                  </ListItemAvatar>
                  <ListItemText
                    primary={<Typography sx={{ fontWeight: 900 }}>{item.name}</Typography>}
                    secondary={item.text}
                    slotProps={{ secondary: { sx: { color: 'text.secondary' } } }}
                  />
                </ListItem>
              ))}
            </List>
          </Paper>

          <Paper
            sx={{
              p: 2.5,
              borderRadius: 2.5,
              display: 'flex',
              gap: 2,
              alignItems: { xs: 'stretch', md: 'center' },
              justifyContent: 'space-between',
              flexDirection: { xs: 'column', md: 'row' },
            }}
          >
            <Box>
              <Typography variant="h5" sx={{ fontWeight: 950 }}>
                开始使用
              </Typography>
              <Typography color="text.secondary">使用网页端登录已有账号，iPad 可直接打开网页版，Android 可下载 APK 使用。</Typography>
            </Box>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
              <Button variant="contained" startIcon={<Login />} onClick={() => navigate('/login')}>
                打开网页版
              </Button>
              <Button variant="outlined" startIcon={<Download />} onClick={handleDownload}>
                下载 APK
              </Button>
            </Stack>
          </Paper>
        </Stack>
      </Container>
    </Box>
  );
};

export default HomePage;
