import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ConfigProvider } from 'antd';
import enUS from 'antd/locale/en_US';
import { CssBaseline } from '@mui/material';
import { createTheme, ThemeProvider } from '@mui/material/styles';
import HomePage from './pages/HomePage';
import LoginPage from './pages/LoginPage';
import ChatPage from './pages/ChatPage';
import AdminPage from './pages/AdminPage';
import ForgotPasswordPage from './pages/ForgotPasswordPage';
import ResetPasswordPage from './pages/ResetPasswordPage';
import QQCallbackBridgePage from './pages/QQCallbackBridgePage';
import SettingsPage from './pages/SettingsPage';
import ContactsPage from './pages/ContactsPage';
import ChatHistoryPage from './pages/ChatHistoryPage';
import { observer } from 'mobx-react-lite';
import { authStore } from './stores/auth.store';
import './App.css';

const uiFontFamily = 'Inter, "PingFang SC", "Microsoft YaHei", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';

const muiTheme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#4a154b', dark: '#38103a', light: '#f7edf7', contrastText: '#ffffff' },
    secondary: { main: '#1264a3', dark: '#0c4f83', light: '#eaf4fb' },
    success: { main: '#007a5a', dark: '#005d45', light: '#e5f4ee' },
    error: { main: '#cc4117' },
    background: { default: '#f4ede4', paper: '#ffffff' },
    text: { primary: '#1d1d1d', secondary: '#696969' },
    divider: '#e6e6e6',
  },
  shape: { borderRadius: 8 },
  typography: {
    fontFamily: uiFontFamily,
    h1: { fontWeight: 700, letterSpacing: 0, lineHeight: 1.12 },
    h2: { fontWeight: 700, letterSpacing: 0, lineHeight: 1.16 },
    h3: { fontWeight: 700, letterSpacing: 0 },
    h4: { fontWeight: 700, letterSpacing: 0 },
    h5: { fontWeight: 700, letterSpacing: 0 },
    h6: { fontWeight: 700, letterSpacing: 0 },
    button: { fontWeight: 700, letterSpacing: 0 },
  },
  components: {
    MuiCssBaseline: { styleOverrides: { body: { backgroundColor: '#f4ede4' } } },
    MuiButton: {
      styleOverrides: {
        root: {
          minHeight: 44,
          borderRadius: 999,
          boxShadow: 'none',
          textTransform: 'none',
          '&.MuiButton-containedPrimary:hover': { backgroundColor: '#611f69', boxShadow: 'none' },
        },
      },
    },
    MuiPaper: { styleOverrides: { root: { boxShadow: 'none' } } },
    MuiCard: { styleOverrides: { root: { borderRadius: 8 } } },
  },
});

const antdTheme = {
  token: {
    colorPrimary: '#4a154b',
    colorInfo: '#1264a3',
    colorSuccess: '#007a5a',
    colorError: '#cc4117',
    colorText: '#1d1d1d',
    colorTextSecondary: '#696969',
    colorBorder: '#e6e6e6',
    colorBgLayout: '#f4ede4',
    colorBgContainer: '#ffffff',
    borderRadius: 8,
    fontFamily: uiFontFamily,
    controlHeight: 40,
  },
  components: {
    Button: { borderRadius: 8, primaryShadow: 'none' },
    Input: { activeBorderColor: '#4a154b', activeShadow: '0 0 0 2px rgba(74, 21, 75, 0.12)' },
    Modal: { borderRadiusLG: 8 },
  },
};

// Protected route component
const ProtectedRoute = observer(({ children }: { children: React.ReactNode }) => {
  if (!authStore.isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
});

const App = observer(() => {
  return (
    <ThemeProvider theme={muiTheme}>
      <CssBaseline />
      <ConfigProvider locale={enUS} theme={antdTheme}>
        <BrowserRouter>
          <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/qq-callback" element={<QQCallbackBridgePage />} />
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route path="/reset-password" element={<ResetPasswordPage />} />
          <Route
            path="/chat"
            element={
              <ProtectedRoute>
                <ChatPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/admin"
            element={
              <ProtectedRoute>
                <AdminPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/settings"
            element={
              <ProtectedRoute>
                <SettingsPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/contacts"
            element={
              <ProtectedRoute>
                <ContactsPage />
              </ProtectedRoute>
            }
          />
          <Route
            path="/chat-history/:contactId"
            element={
              <ProtectedRoute>
                <ChatHistoryPage />
              </ProtectedRoute>
            }
          />
          </Routes>
        </BrowserRouter>
      </ConfigProvider>
    </ThemeProvider>
  );
});

export default App;
