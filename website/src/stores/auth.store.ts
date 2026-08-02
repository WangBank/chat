import { makeAutoObservable } from 'mobx';
import { apiService, type AuthApiResponse } from '../services/api.service';
import { signalRService } from '../services/signalr.service';

export interface User {
  id: number;
  username: string;
  email: string;
  display_name?: string;
  signature?: string;
  gender?: string;
  birthday?: string;
  country?: string;
  province?: string;
  region?: string;
  avatar_path?: string;
  qq_bound?: boolean;
  qq_nickname?: string;
  qq_avatar_url?: string;
  qq_bound_at?: string;
  is_online: boolean;
  last_login_at?: string;
  created_at: string;
  updated_at: string;
}

class AuthStore {
  user: User | null = null;
  token: string = '';
  isAuthenticated: boolean = false;
  isLoading: boolean = false;

  constructor() {
    makeAutoObservable(this);
    this.loadFromStorage();
  }

  loadFromStorage() {
    const token = localStorage.getItem('token');
    const userStr = localStorage.getItem('user');

    if (token && userStr) {
      this.token = token;
      this.user = JSON.parse(userStr);
      this.isAuthenticated = true;
    }
  }

  async login(username: string, password: string) {
    this.isLoading = true;
    try {
      const response = await apiService.login({ username, password });
      if (response.success && response.data) {
        await this.applyAuthResponse(response.data);
        return { success: true };
      } else {
        return { success: false, message: response.message || 'Login failed' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'Login failed' };
    } finally {
      this.isLoading = false;
    }
  }

  async register(username: string, email: string, password: string) {
    this.isLoading = true;
    try {
      const response = await apiService.register({ username, email, password });
      if (response.success && response.data) {
        await this.applyAuthResponse(response.data);
        return { success: true };
      } else {
        return { success: false, message: response.message || 'Registration failed' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'Registration failed' };
    } finally {
      this.isLoading = false;
    }
  }

  async loginWithQQCode(code: string, state: string) {
    this.isLoading = true;
    try {
      const response = await apiService.qqLogin({ code, state });
      if (response.success && response.data) {
        await this.applyAuthResponse(response.data);
        return { success: true };
      }
      return { success: false, message: response.message || 'QQ login failed' };
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'QQ login failed' };
    } finally {
      this.isLoading = false;
    }
  }

  async loginWithQQDev() {
    this.isLoading = true;
    try {
      const response = await apiService.qqDevLogin({
        open_id: 'dev_qq_web',
        nickname: 'QQ测试用户',
      });
      if (response.success && response.data) {
        await this.applyAuthResponse(response.data);
        return { success: true };
      }
      return { success: false, message: response.message || 'QQ test login failed' };
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'QQ test login failed' };
    } finally {
      this.isLoading = false;
    }
  }

  async logout() {
    await signalRService.disconnect();
    this.user = null;
    this.token = '';
    this.isAuthenticated = false;
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }

  async ensureSignalRConnection() {
    if (!this.token || !this.user) {
      return;
    }

    if (!signalRService.isConnected) {
      await signalRService.connect(this.token);
    }

    await signalRService.authenticate(this.user.id);
  }

  private async applyAuthResponse(data: AuthApiResponse) {
    this.token = data.token;
    this.user = data.user;
    this.isAuthenticated = true;

    localStorage.setItem('token', this.token);
    localStorage.setItem('user', JSON.stringify(this.user));

    await this.ensureSignalRConnection();
  }

  // Generate random username and password
  generateRandomAccount() {
    const randomUsername = `user_${Math.random().toString(36).substring(2, 10)}`;
    const randomPassword = Math.random().toString(36).substring(2, 12);
    return { username: randomUsername, password: randomPassword };
  }
}

export const authStore = new AuthStore();
