import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ConfigProvider } from 'antd';
import enUS from 'antd/locale/en_US';
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

// Protected route component
const ProtectedRoute = observer(({ children }: { children: React.ReactNode }) => {
  if (!authStore.isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
});

const App = observer(() => {
  return (
    <ConfigProvider locale={enUS}>
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
  );
});

export default App;
