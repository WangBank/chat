import axios, { type AxiosInstance, type AxiosError } from 'axios';
import { APP_CONFIG } from '../config/app.config';

export interface ApiResponse<T = unknown> {
  success: boolean;
  message?: string;
  data?: T;
  errors?: string[];
}

export interface UserSummaryResponse {
  id?: number;
  username?: string;
  email?: string;
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
  is_online?: boolean;
}

export interface UserApiResponse extends UserSummaryResponse {
  id: number;
  username: string;
  email: string;
  is_online: boolean;
  last_login_at?: string;
  created_at: string;
  updated_at: string;
}

export interface AuthApiResponse {
  token: string;
  user: UserApiResponse;
}

export interface QQLoginUrlApiResponse {
  auth_url: string;
  state: string;
  mode: 'login' | 'bind';
  configured: boolean;
  mock_available: boolean;
}

export interface UserSearchApiResponse {
  users: UserApiResponse[];
  total_count: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface FriendRequestApiResponse {
  id: number;
  requester: UserSummaryResponse;
  receiver: UserSummaryResponse;
  note?: string;
  source?: string;
  status: 'pending' | 'accepted' | 'rejected';
  direction: 'incoming' | 'outgoing';
  created_at: string;
  updated_at?: string;
}

export interface ChatUploadApiResponse {
  file_name: string;
  file_path: string;
  file_size: number;
  content_type: string;
}

export interface ContactApiResponse {
  id: number;
  contact_user: UserApiResponse;
  display_name?: string;
  added_at: string;
  is_blocked: boolean;
  last_message_at?: string;
  unread_count: number;
}

export interface ChatMessageApiResponse {
  id: number;
  sender_id: number;
  receiver_id: number;
  content: string;
  type: number | string;
  timestamp: string;
  is_read: boolean;
  file_path?: string;
  file_size?: number;
  duration?: number;
  created_at: string;
  sender: UserApiResponse;
  receiver: UserApiResponse;
}

export interface ChatHistoryApiResponse {
  contact_id: number;
  contact_name: string;
  last_message_at?: string;
  unread_count: number;
  messages: ChatMessageApiResponse[];
}

export interface ChatGroupApiResponse {
  id: number;
  name: string;
  category: string;
  member_ids: number[];
  members: UserSummaryResponse[];
  pinned?: boolean;
  owner_id?: number;
  announcement?: string;
  note?: string;
  created_at: string;
  updated_at?: string;
}

export interface GroupMessageApiResponse {
  id: number;
  group_id: number;
  sender_id: number;
  sender_name: string;
  content: string;
  type?: number | string;
  timestamp?: string;
  file_path?: string;
  file_size?: number;
  duration?: number;
  created_at: string;
  sender?: UserSummaryResponse;
}

export interface FavoriteItemApiResponse {
  id: number;
  content: string;
  type: 'chat' | 'media' | 'file' | 'link' | 'note';
  source_name: string;
  file_path?: string;
  file_size?: number;
  created_at: string;
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

    // Request interceptor: attach token
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

    // Response interceptor: handle errors
    this.api.interceptors.response.use(
      (response) => response,
      (error: AxiosError<ApiResponse>) => {
        if (error.response?.status === 401) {
          // Token expired, clear local storage and redirect to login
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          window.location.href = '/login';
        }
        return Promise.reject(error);
      }
    );
  }

  // User APIs
  async register(data: { username: string; email: string; password: string }) {
    const response = await this.api.post<ApiResponse<AuthApiResponse>>(
      '/api/auth/register',
      data
    );
    return response.data;
  }

  async login(data: { username: string; password: string }) {
    const response = await this.api.post<ApiResponse<AuthApiResponse>>(
      '/api/auth/login',
      data
    );
    return response.data;
  }

  async getQQLoginUrl(mode: 'login' | 'bind' = 'login') {
    const response = await this.api.get<ApiResponse<QQLoginUrlApiResponse>>('/api/auth/qq/login-url', {
      params: { mode },
    });
    return response.data;
  }

  async qqLogin(data: { code: string; state: string }) {
    const response = await this.api.post<ApiResponse<AuthApiResponse>>('/api/auth/qq/login', data);
    return response.data;
  }

  async qqBind(data: { code: string; state: string }) {
    const response = await this.api.post<ApiResponse<UserApiResponse>>('/api/auth/qq/bind', data);
    return response.data;
  }

  async qqDevLogin(data: { open_id?: string; nickname?: string; avatar_url?: string }) {
    const response = await this.api.post<ApiResponse<AuthApiResponse>>('/api/auth/qq/dev-login', data);
    return response.data;
  }

  async qqDevBind(data: { open_id?: string; nickname?: string; avatar_url?: string }) {
    const response = await this.api.post<ApiResponse<UserApiResponse>>('/api/auth/qq/dev-bind', data);
    return response.data;
  }

  async changePassword(data: { old_password: string; new_password: string }) {
    const response = await this.api.post<ApiResponse>('/api/auth/change-password', data);
    return response.data;
  }

  async getProfile() {
    const response = await this.api.get<ApiResponse<UserApiResponse>>('/api/auth/profile');
    return response.data;
  }

  async updateProfile(data: {
    display_name?: string;
    avatar_path?: string;
    signature?: string;
    gender?: string;
    birthday?: string;
    country?: string;
    province?: string;
    region?: string;
  }) {
    const response = await this.api.put<ApiResponse<UserApiResponse>>('/api/auth/profile', data);
    return response.data;
  }

  async searchUsers(query: string, page: number = 1, pageSize: number = 20) {
    const response = await this.api.get<ApiResponse<UserSearchApiResponse>>('/api/auth/search-users', {
      params: { query, page, page_size: pageSize },
    });
    return response.data;
  }

  // Contact APIs
  async getContacts() {
    const response = await this.api.get<ApiResponse<ContactApiResponse[]>>('/api/contacts');
    return response.data;
  }

  async addContact(data: { username: string; display_name?: string }) {
    return this.createFriendRequest({
      username: data.username,
      note: data.display_name,
      source: '联系人添加',
    });
  }

  async getFriendRequests() {
    const response = await this.api.get<ApiResponse<FriendRequestApiResponse[]>>('/api/contacts/friend-requests');
    return response.data;
  }

  async createFriendRequest(data: { username: string; note?: string; source?: string }) {
    const response = await this.api.post<ApiResponse<FriendRequestApiResponse>>('/api/contacts/friend-requests', data);
    return response.data;
  }

  async respondFriendRequest(requestId: number, status: 'accepted' | 'rejected') {
    const response = await this.api.patch<ApiResponse<FriendRequestApiResponse>>(`/api/contacts/friend-requests/${requestId}`, {
      status,
    });
    return response.data;
  }

  async clearHandledFriendRequests() {
    const response = await this.api.delete<ApiResponse>('/api/contacts/friend-requests/handled');
    return response.data;
  }

  async removeContact(contactId: number) {
    const response = await this.api.delete<ApiResponse>(`/api/contacts/${contactId}`);
    return response.data;
  }

  async updateContactDisplayName(contactId: number, displayName: string) {
    const response = await this.api.patch<ApiResponse<ContactApiResponse>>(
      `/api/contacts/${contactId}/display-name`,
      displayName
    );
    return response.data;
  }

  // Chat APIs
  async sendMessage(data: {
    receiver_id: number;
    content: string;
    type?: number;
    file_path?: string;
    file_size?: number;
    duration?: number;
  }) {
    const response = await this.api.post<ApiResponse<ChatMessageApiResponse>>('/api/chat/send', data);
    return response.data;
  }

  async uploadChatFile(file: File) {
    const formData = new FormData();
    formData.append('file', file);
    const response = await this.api.post<ApiResponse<ChatUploadApiResponse>>('/api/chat/upload', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return response.data;
  }

  async getChatHistory(contactId: number) {
    const response = await this.api.get<ApiResponse<ChatMessageApiResponse[]>>(`/api/chat/history/${contactId}`);
    return response.data;
  }

  async getChatHistoryList() {
    const response = await this.api.get<ApiResponse<ChatHistoryApiResponse[]>>('/api/chat/chat-history');
    return response.data;
  }

  async markMessageAsRead(messageId: number) {
    const response = await this.api.patch<ApiResponse>(`/api/chat/messages/${messageId}/read`);
    return response.data;
  }

  // Group chat APIs
  async getChatGroups() {
    const response = await this.api.get<ApiResponse<ChatGroupApiResponse[]>>('/api/groups');
    return response.data;
  }

  async createChatGroup(data: {
    name?: string;
    category?: string;
    member_ids: number[];
    pinned?: boolean;
  }) {
    const response = await this.api.post<ApiResponse<ChatGroupApiResponse>>('/api/groups', data);
    return response.data;
  }

  async getGroupMessages(groupId: number) {
    const response = await this.api.get<ApiResponse<GroupMessageApiResponse[]>>(`/api/groups/${groupId}/messages`);
    return response.data;
  }

  async sendGroupMessage(groupId: number, data: {
    content: string;
    type?: number;
    file_path?: string;
    file_size?: number;
    duration?: number;
  }) {
    const response = await this.api.post<ApiResponse<GroupMessageApiResponse>>(`/api/groups/${groupId}/messages`, data);
    return response.data;
  }

  // Favorite APIs
  async getFavorites(params?: { type?: string; query?: string }) {
    const response = await this.api.get<ApiResponse<FavoriteItemApiResponse[]>>('/api/favorites', {
      params,
    });
    return response.data;
  }

  async createFavorite(data: {
    content: string;
    type: 'chat' | 'media' | 'file' | 'link' | 'note';
    source_name?: string;
    file_path?: string;
    file_size?: number;
  }) {
    const response = await this.api.post<ApiResponse<FavoriteItemApiResponse>>('/api/favorites', data);
    return response.data;
  }

  async deleteFavorite(favoriteId: number) {
    const response = await this.api.delete<ApiResponse>(`/api/favorites/${favoriteId}`);
    return response.data;
  }

  // Admin APIs
  async getOnlineUsers() {
    const response = await this.api.get<ApiResponse<UserApiResponse[]>>('/api/admin/online-users');
    return response.data;
  }

  async getAllUsers(page: number = 1, pageSize: number = 20) {
    const response = await this.api.get<ApiResponse<UserSearchApiResponse>>('/api/admin/users', {
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
