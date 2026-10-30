import { useEffect } from 'react';
import {
  AppBar,
  Avatar,
  Box,
  Button,
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
  ArrowOutward,
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
import BrandMark from '../components/BrandMark';
import '../styles/home.css';

const PRODUCT_NAME = 'Love Chat';

const featureItems = [
  { icon: <Message />, title: '完整聊天', text: '会话、表情、图片、文件、语音和未读状态在同一个清晰的工作台中处理。' },
  { icon: <SupervisorAccount />, title: '好友管理', text: '搜索添加好友、处理申请、维护备注、头像和个性签名，无需离开当前会话。' },
  { icon: <VideoCall />, title: '音视频通话', text: '从聊天和联系人列表直接发起语音或视频通话，覆盖网页、平板和移动场景。' },
  { icon: <History />, title: '历史记录', text: '按会话、图片、文件和链接回看关键内容，长期聊天也能快速找到上下文。' },
  { icon: <CloudSync />, title: '实时在线', text: '在线状态、已读回执、头像和资料随账号同步，让每个终端保持一致。' },
  { icon: <Security />, title: '安全防护', text: '敏感词过滤、防注入和账号安全能力为日常沟通提供基础防护。' },
];

const deviceItems = [
  { icon: <Web />, name: '桌面浏览器', status: '推荐', text: '完整使用聊天、好友、群聊和管理控制台。' },
  { icon: <TabletMac />, name: 'iPad 浏览器', status: '已支持', text: '横竖屏都保留聊天、联系人、资料和历史记录入口。' },
  { icon: <Android />, name: 'Android 客户端', status: '可下载', text: '安装 APK 后使用移动端聊天、联系人、资料和通话。' },
];

const metricItems = [
  ['Web', '浏览器入口'],
  ['APK', '移动端下载'],
  ['IM', '即时消息'],
  ['RTC', '实时通话'],
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
    <Box className="home-page">
      <AppBar className="home-nav" position="sticky" elevation={0}>
        <Toolbar className="home-nav-inner">
          <BrandMark className="home-brand-mark" size={38} />
          <Box sx={{ minWidth: 0, flex: 1 }}>
            <Typography className="home-brand-name" noWrap>{PRODUCT_NAME}</Typography>
            <Typography className="home-brand-caption" noWrap>网页端 · iPad · Android</Typography>
          </Box>
          <Chip className="home-version" size="small" label={`v${APP_CONFIG.VERSION}`} variant="outlined" />
        </Toolbar>
      </AppBar>

      <main>
        <section className="home-hero">
          <Container maxWidth="xl" className="home-hero-inner">
            <Grid container spacing={{ xs: 4, md: 7 }} sx={{ alignItems: 'center' }}>
              <Grid size={{ xs: 12, md: 7 }}>
                <Box className="home-hero-copy">
                  <Chip className="home-eyebrow" label="实时通信工作台" size="small" />
                  <Typography component="h1" className="home-title">让每一次回应，都清澈抵达</Typography>
                  <Typography className="home-lead">
                    Love Chat 将账号、聊天、联系人、历史记录与音视频通话放进统一界面，跨设备衔接仍然清晰可靠。
                  </Typography>
                  <Stack className="home-actions" direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
                    <Button className="home-primary-action" variant="contained" size="large" startIcon={<Login />} onClick={() => navigate('/login')}>
                      进入网页版
                    </Button>
                    <Button className="home-secondary-action" variant="outlined" size="large" startIcon={<Download />} onClick={handleDownload}>
                      下载 Android
                    </Button>
                  </Stack>
                </Box>
              </Grid>
              <Grid size={{ xs: 12, md: 5 }}>
                <Box className="home-product-stage" aria-label="Love Chat 产品能力概览">
                  <Box className="home-product-heading">
                    <Box>
                      <Typography className="home-product-kicker">LOVE CHAT</Typography>
                      <Typography className="home-product-title">沟通状态</Typography>
                    </Box>
                    <Chip className="home-status-chip" size="small" label="服务可用" />
                  </Box>
                  <Divider />
                  <Grid container className="home-metric-grid">
                    {metricItems.map(([value, label]) => (
                      <Grid size={{ xs: 6 }} key={value}>
                        <Box className="home-metric">
                          <Typography className="home-metric-value">{value}</Typography>
                          <Typography className="home-metric-label">{label}</Typography>
                        </Box>
                      </Grid>
                    ))}
                  </Grid>
                  <Box className="home-product-footer">
                    <BrandMark className="home-product-art" size={68} decorative />
                    <Typography>消息、资料与通话入口保持在一个连续的工作流中。</Typography>
                  </Box>
                </Box>
              </Grid>
            </Grid>
          </Container>
        </section>

        <section className="home-section">
          <Container maxWidth="xl">
            <Box className="home-section-heading">
              <Typography component="h2" variant="h4">围绕日常沟通的核心能力</Typography>
              <Typography>以可扫描的信息层级组织每次联系、每一条消息和每个通话入口。</Typography>
            </Box>
            <Grid container spacing={2}>
              {featureItems.map((item) => (
                <Grid size={{ xs: 12, sm: 6, lg: 4 }} key={item.title}>
                  <Paper className="home-feature" variant="outlined">
                    <Avatar className="home-feature-icon">{item.icon}</Avatar>
                    <Typography component="h3" variant="h6">{item.title}</Typography>
                    <Typography>{item.text}</Typography>
                  </Paper>
                </Grid>
              ))}
            </Grid>
          </Container>
        </section>

        <section className="home-devices-section">
          <Container maxWidth="xl">
            <Grid container spacing={{ xs: 3, md: 6 }} sx={{ alignItems: 'flex-start' }}>
              <Grid size={{ xs: 12, md: 4 }}>
                <Box className="home-section-heading home-devices-heading">
                  <Typography component="h2" variant="h4">在你正在使用的设备上继续对话</Typography>
                  <Typography>界面针对桌面、平板和移动端的阅读及触控方式收紧布局。</Typography>
                </Box>
              </Grid>
              <Grid size={{ xs: 12, md: 8 }}>
                <List className="home-device-list" disablePadding>
                  {deviceItems.map((item, index) => (
                    <ListItem key={item.name} divider={index < deviceItems.length - 1} className="home-device-row">
                      <ListItemAvatar><Avatar className="home-device-icon">{item.icon}</Avatar></ListItemAvatar>
                      <ListItemText primary={<Typography variant="h6">{item.name}</Typography>} secondary={item.text} />
                      <Chip className="home-device-status" label={item.status} size="small" />
                    </ListItem>
                  ))}
                </List>
              </Grid>
            </Grid>
          </Container>
        </section>

        <section className="home-cta-section">
          <Container maxWidth="xl">
            <Box className="home-cta-content">
              <Box>
                <Typography component="h2" variant="h4">回到正在进行的对话</Typography>
                <Typography>登录网页端，或在 Android 设备上继续使用 Love Chat。</Typography>
              </Box>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
                <Button className="home-cta-primary" variant="contained" endIcon={<ArrowOutward />} onClick={() => navigate('/login')}>打开网页版</Button>
                <Button className="home-cta-secondary" variant="outlined" startIcon={<Download />} onClick={handleDownload}>下载 Android</Button>
              </Stack>
            </Box>
          </Container>
        </section>
      </main>
    </Box>
  );
};

export default HomePage;
