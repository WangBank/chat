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

const uiFontFamily = 'Manrope, Inter, "PingFang SC", "Microsoft YaHei", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif';

const muiTheme = createTheme({
  palette: {
    mode: 'light',
    primary: { main: '#197fb8', dark: '#0f6fa9', light: '#e5f5ff', contrastText: '#ffffff' },
    secondary: { main: '#4aaedc', dark: '#197fb8', light: '#eaf8ff' },
    success: { main: '#007a5a', dark: '#005d45', light: '#e5f4ee' },
    error: { main: '#cc4117' },
    background: { default: '#f4faff', paper: '#ffffff' },
    text: { primary: '#0d2742', secondary: '#54748a' },
    divider: '#d7e9f4',
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
    MuiCssBaseline: { styleOverrides: { body: { backgroundColor: '#f4faff' } } },
    MuiButton: {
      styleOverrides: {
        root: {
          minHeight: 44,
          borderRadius: 8,
          boxShadow: 'none',
          textTransform: 'none',
          '&.MuiButton-containedPrimary:hover': { backgroundColor: '#0f6fa9', boxShadow: 'none' },
        },
      },
    },
    MuiPaper: { styleOverrides: { root: { boxShadow: 'none' } } },
    MuiCard: { styleOverrides: { root: { borderRadius: 8 } } },
  },
});

const antdTheme = {
  token: {
    colorPrimary: '#197fb8',
    colorInfo: '#237fb1',
    colorSuccess: '#007a5a',
    colorError: '#cc4117',
    colorText: '#0d2742',
    colorTextSecondary: '#54748a',
    colorBorder: '#d7e9f4',
    colorBgLayout: '#f4faff',
    colorBgContainer: '#ffffff',
    borderRadius: 8,
    fontFamily: uiFontFamily,
    controlHeight: 40,
  },
  components: {
    Button: { borderRadius: 8, primaryShadow: 'none' },
    Input: { activeBorderColor: '#197fb8', activeShadow: '0 0 0 2px rgba(25, 127, 184, 0.16)' },
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
