import { makeAutoObservable } from 'mobx';
import { apiService } from '../services/api.service';
import { signalRService } from '../services/signalr.service';

export interface User {
  id: number;
  username: string;
  email: string;
  display_name?: string;
  avatar_path?: string;
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
        this.token = response.data.token;
        this.user = response.data.user;
        this.isAuthenticated = true;

        localStorage.setItem('token', this.token);
        localStorage.setItem('user', JSON.stringify(this.user));

        // 连接SignalR
        await signalRService.connect(this.token);
        if (this.user) {
          await signalRService.authenticate(this.user.id);
        }

        return { success: true };
      } else {
        return { success: false, message: response.message || '登录失败' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || '登录失败' };
    } finally {
      this.isLoading = false;
    }
  }

  async register(username: string, email: string, password: string) {
    this.isLoading = true;
    try {
      const response = await apiService.register({ username, email, password });
      if (response.success && response.data) {
        this.token = response.data.token;
        this.user = response.data.user;
        this.isAuthenticated = true;

        localStorage.setItem('token', this.token);
        localStorage.setItem('user', JSON.stringify(this.user));

        // 连接SignalR
        await signalRService.connect(this.token);
        if (this.user) {
          await signalRService.authenticate(this.user.id);
        }

        return { success: true };
      } else {
        return { success: false, message: response.message || '注册失败' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || '注册失败' };
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

  // 生成随机账号和密码
  generateRandomAccount() {
    const randomUsername = `user_${Math.random().toString(36).substring(2, 10)}`;
    const randomPassword = Math.random().toString(36).substring(2, 12);
    return { username: randomUsername, password: randomPassword };
  }
}

export const authStore = new AuthStore();

