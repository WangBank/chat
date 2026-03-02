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
            Make every conversation meaningful
          </Title>
          <Paragraph className="hero-description">
            SimpleChat - secure, private, and convenient messaging
          </Paragraph>
          <Space size="large">
            <Button
              type="primary"
              size="large"
              icon={<DownloadOutlined />}
              onClick={handleDownload}
            >
              Download Android App
            </Button>
            <Button
              size="large"
              onClick={() => navigate('/login')}
            >
              Get Started
            </Button>
          </Space>
        </div>
        <div className="hero-image">
          <img src="/phone-mockup.png" alt="SimpleChat App" style={{ maxWidth: '100%', height: 'auto' }} />
        </div>
      </section>

      {/* Features Section */}
      <section className="features-section">
        <Title level={2} style={{ textAlign: 'center', marginBottom: 48 }}>
          Features
        </Title>
        <Row gutter={[32, 32]}>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <MessageOutlined style={{ fontSize: 48, color: '#1890ff', marginBottom: 16 }} />
              <Title level={4}>Instant Messaging</Title>
              <Paragraph>
                Send text, image, and voice messages quickly and smoothly
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <PhoneOutlined style={{ fontSize: 48, color: '#52c41a', marginBottom: 16 }} />
              <Title level={4}>Voice Calls</Title>
              <Paragraph>
                High-quality voice calls to stay connected anywhere
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <VideoCameraOutlined style={{ fontSize: 48, color: '#ff4d4f', marginBottom: 16 }} />
              <Title level={4}>Video Calls</Title>
              <Paragraph>
                Smooth video calls for a more natural face-to-face experience
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <LockOutlined style={{ fontSize: 48, color: '#722ed1', marginBottom: 16 }} />
              <Title level={4}>End-to-End Encryption</Title>
              <Paragraph>
                All messages and calls are protected with end-to-end encryption
              </Paragraph>
            </Card>
          </Col>
          <Col xs={24} sm={12} md={8}>
            <Card className="feature-card">
              <TeamOutlined style={{ fontSize: 48, color: '#fa8c16', marginBottom: 16 }} />
              <Title level={4}>Contact Management</Title>
              <Paragraph>
                Easily manage contacts and find friends anytime
              </Paragraph>
            </Card>
          </Col>
        </Row>
      </section>

      {/* CTA Section */}
      <section className="cta-section">
        <Card>
          <div style={{ textAlign: 'center' }}>
            <Title level={2}>Start Using SimpleChat</Title>
            <Paragraph style={{ fontSize: 16, marginBottom: 24 }}>
              Download the app or use web login to get started
            </Paragraph>
            <Space size="large">
              <Button
                type="primary"
                size="large"
                icon={<DownloadOutlined />}
                onClick={handleDownload}
              >
                Download Android App
              </Button>
              <Button
                size="large"
                onClick={() => navigate('/login')}
              >
                Open Web App
              </Button>
            </Space>
          </div>
        </Card>
      </section>

      {/* Footer */}
      <footer className="home-footer">
        <div className="version-info">
          <span>SimpleChat v{APP_CONFIG.VERSION}</span>
        </div>
        <div className="footer-links">
          <a href="/privacy">Privacy Policy</a>
          <a href="/terms">Terms of Service</a>
        </div>
      </footer>
    </div>
  );
};

export default HomePage;

