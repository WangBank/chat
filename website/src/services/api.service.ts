import axios, { type AxiosInstance, type AxiosError } from 'axios';
import { APP_CONFIG } from '../config/app.config';

export interface ApiResponse<T = any> {
  success: boolean;
  message?: string;
  data?: T;
  errors?: string[];
}

class ApiService {
  private api: AxiosInstance;

  constructor() {
    this.api = axios.create({
      baseURL: APP_CONFIG.API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // 请求拦截器：添加token
    this.api.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('token');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // 响应拦截器：处理错误
    this.api.interceptors.response.use(
      (response) => response,
      (error: AxiosError<ApiResponse>) => {
        if (error.response?.status === 401) {
          // Token过期，清除本地存储并跳转到登录页
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  // 用户相关API
  async register(data: { username: string; email: string; password: string }) {
    const response = await this.api.post<ApiResponse<{ token: string; user: any }>>(
      '/api/auth/register',
      data
    );
    return response.data;
  }

  async login(data: { username: string; password: string }) {
    const response = await this.api.post<ApiResponse<{ token: string; user: any }>>(
      '/api/auth/login',
      data
    );
    return response.data;
  }

  async changePassword(data: { old_password: string; new_password: string }) {
    const response = await this.api.post<ApiResponse>('/api/auth/change-password', data);
    return response.data;
  }

  async getProfile() {
    const response = await this.api.get<ApiResponse<any>>('/api/auth/profile');
    return response.data;
  }

  async updateProfile(data: { display_name?: string; avatar_path?: string }) {
    const response = await this.api.put<ApiResponse<any>>('/api/auth/profile', data);
    return response.data;
  }

  async searchUsers(query: string, page: number = 1, pageSize: number = 20) {
    const response = await this.api.get<ApiResponse<any>>('/api/auth/search-users', {
      params: { query, page, page_size: pageSize },
    });
    return response.data;
  }

  // 联系人相关API
  async getContacts() {
    const response = await this.api.get<ApiResponse<any[]>>('/api/contacts');
    return response.data;
  }

  async addContact(data: { username: string; display_name?: string }) {
    const response = await this.api.post<ApiResponse<any>>('/api/contacts', data);
    return response.data;
  }

  async removeContact(contactId: number) {
    const response = await this.api.delete<ApiResponse>(`/api/contacts/${contactId}`);
    return response.data;
  }

  async updateContactDisplayName(contactId: number, displayName: string) {
    const response = await this.api.patch<ApiResponse<any>>(
      `/api/contacts/${contactId}/display-name`,
      displayName
    );
    return response.data;
  }

  // 聊天相关API
  async sendMessage(data: { receiver_id: number; content: string; type?: number }) {
    const response = await this.api.post<ApiResponse<any>>('/api/chat/send', data);
    return response.data;
  }

  async getChatHistory(contactId: number) {
    const response = await this.api.get<ApiResponse<any[]>>(`/api/chat/history/${contactId}`);
    return response.data;
  }

  async getChatHistoryList() {
    const response = await this.api.get<ApiResponse<any[]>>('/api/chat/chat-history');
    return response.data;
  }

  async markMessageAsRead(messageId: number) {
    const response = await this.api.patch<ApiResponse>(`/api/chat/messages/${messageId}/read`);
    return response.data;
  }

  // 管理员API
  async getOnlineUsers() {
    const response = await this.api.get<ApiResponse<any[]>>('/api/admin/online-users');
    return response.data;
  }

  async getAllUsers(page: number = 1, pageSize: number = 20) {
    const response = await this.api.get<ApiResponse<any>>('/api/admin/users', {
      params: { page, page_size: pageSize },
    });
    return response.data;
  }

  async adminChangeUserPassword(userId: number, newPassword: string) {
    const response = await this.api.post<ApiResponse>('/api/admin/change-user-password', {
      user_id: userId,
      new_password: newPassword,
    });
    return response.data;
  }
}

export const apiService = new ApiService();

