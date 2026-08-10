import { useEffect, useMemo } from 'react';
import { Button, Card, Spin } from 'antd';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import '../styles/common.css';

const APP_CALLBACK_SCHEME = 'lovechat';
const APP_CALLBACK_HOST = 'qq-callback';

const isMobileDevice = () => {
  if (typeof navigator === 'undefined') return false;
  return /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
};

const getCallbackValue = (params: URLSearchParams, key: string) => {
  return params.get(key) || params.get(`qq_${key}`) || '';
};

const buildLoginPath = (search: string) => `/login${search || ''}`;

const QQCallbackBridgePage = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const params = useMemo(() => new URLSearchParams(location.search), [location.search]);
  const mobile = useMemo(() => isMobileDevice(), []);
  const loginPath = buildLoginPath(location.search);

  const appCallbackUrl = useMemo(() => {
    const callbackParams = new URLSearchParams();
    const code = getCallbackValue(params, 'code');
    const state = getCallbackValue(params, 'state');
    const error = getCallbackValue(params, 'error');
    const errorDescription = getCallbackValue(params, 'error_description');

    if (code) callbackParams.set('code', code);
    if (state) callbackParams.set('state', state);
    if (error) callbackParams.set('error', error);
    if (errorDescription) callbackParams.set('error_description', errorDescription);

    return `${APP_CALLBACK_SCHEME}://${APP_CALLBACK_HOST}?${callbackParams.toString()}`;
  }, [params]);

  useEffect(() => {
    if (!mobile) {
      navigate(loginPath, { replace: true });
      return;
    }

    window.location.assign(appCallbackUrl);
  }, [appCallbackUrl, loginPath, mobile, navigate]);

  if (!mobile) {
    return <Navigate to={loginPath} replace />;
  }

  return (
    <div className="qq-login-page">
      <section className="qq-login-window" aria-label="QQ 登录回调">
        <div className="qq-login-titlebar">
          <span className="qq-login-avatar">Q</span>
          <span className="qq-login-account">Love Chat</span>
          <span className="qq-login-status">QQ 授权中</span>
        </div>
        <Card className="qq-login-card" bordered={false}>
          <div className="qq-login-heading">
            <Spin size="large" />
            <h1>正在返回 Love Chat</h1>
            <p>如果没有自动打开手机应用，请点击下方按钮。</p>
          </div>
          <Button type="primary" block size="large" onClick={() => window.location.assign(appCallbackUrl)}>
            打开 Love Chat
          </Button>
          <Button type="link" block onClick={() => navigate(loginPath, { replace: true })}>
            继续使用网页版登录
          </Button>
        </Card>
      </section>
    </div>
  );
};

export default QQCallbackBridgePage;
