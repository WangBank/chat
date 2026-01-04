import { Button, Card, Typography, Space, Row, Col } from 'antd';
import { DownloadOutlined, MessageOutlined, PhoneOutlined, VideoCameraOutlined, LockOutlined, TeamOutlined } from '@ant-design/icons';
import { useNavigate } from 'react-router-dom';
import { APP_CONFIG } from '../config/app.config';
import '../styles/home.css';

const { Title, Paragraph } = Typography;

const HomePage = () => {
  const navigate = useNavigate();

  const handleDownload = () => {
    window.open(APP_CONFIG.APK_DOWNLOAD_URL, '_blank');
  };

  return (
    <div className="home-page">
      {/* Hero Section */}
      <section className="hero-section">
        <div className="hero-content">
          <Title level={1} className="hero-title">
            让每一次沟通更有意义
          </Title>
          <Paragraph className="hero-description">
            简聊 - 安全、私密、便捷的即时通讯应用
          </Paragraph>
          <Space size="large">
            <Button
              type="primary"
              size="large"
              icon={<DownloadOutlined />}
              onClick={handleDownload}
            >
              下载 Android 应用
            </Button>
            <Button
              size="large"
              onClick={() => navigate('/login')}
            >
              立即使用
            </Button>
          </Space>
        </div>
        <div className="hero-image">
          <img src="/phone-mockup.png" alt="简聊应用" style={{ maxWidth: '100%', height: 'auto' }} />
        </div>
      </section>

      {/* Features Section */}
      <section className="features-section">
        <Title level={2} style={{ textAlign: 'center', marginBottom: 48 }}>
          功能特点
        </Title>
        <Row gutter={[32, 32]}>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <MessageOutlined style={{ fontSize: 48, color: '#1890ff', marginBottom: 16 }} />
              <Title level={4}>即时消息</Title>
              <Paragraph>
                快速发送文字、图片、语音消息，让沟通更便捷
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <PhoneOutlined style={{ fontSize: 48, color: '#52c41a', marginBottom: 16 }} />
              <Title level={4}>语音通话</Title>
              <Paragraph>
                高清语音通话，随时随地与朋友家人保持联系
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <VideoCameraOutlined style={{ fontSize: 48, color: '#ff4d4f', marginBottom: 16 }} />
              <Title level={4}>视频通话</Title>
              <Paragraph>
                流畅的视频通话体验，面对面交流更真实
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <LockOutlined style={{ fontSize: 48, color: '#722ed1', marginBottom: 16 }} />
              <Title level={4}>端到端加密</Title>
              <Paragraph>
                所有消息和通话都经过端到端加密，保护您的隐私
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <TeamOutlined style={{ fontSize: 48, color: '#fa8c16', marginBottom: 16 }} />
              <Title level={4}>联系人管理</Title>
              <Paragraph>
                轻松管理您的联系人，随时添加和查找好友
              </Paragraph>
            </Card>
          </Col>
        </Row>
      </section>

      {/* CTA Section */}
      <section className="cta-section">
        <Card>
          <div style={{ textAlign: 'center' }}>
            <Title level={2}>开始使用简聊</Title>
            <Paragraph style={{ fontSize: 16, marginBottom: 24 }}>
              立即下载应用或登录网页版，体验安全便捷的通讯服务
            </Paragraph>
            <Space size="large">
              <Button
                type="primary"
                size="large"
                icon={<DownloadOutlined />}
                onClick={handleDownload}
              >
                下载 Android 应用
              </Button>
              <Button
                size="large"
                onClick={() => navigate('/login')}
              >
                登录网页版
              </Button>
            </Space>
          </div>
        </Card>
      </section>

      {/* Footer */}
      <footer className="home-footer">
        <div className="version-info">
          <span>简聊 v{APP_CONFIG.VERSION}</span>
        </div>
        <div className="footer-links">
          <a href="/privacy">隐私政策</a>
          <a href="/terms">服务条款</a>
        </div>
      </footer>
    </div>
  );
};

export default HomePage;

