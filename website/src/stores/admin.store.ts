import { makeAutoObservable } from 'mobx';
import { apiService } from '../services/api.service';

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

class AdminStore {
  onlineUsers: User[] = [];
  allUsers: User[] = [];
  totalUsers: number = 0;
  currentPage: number = 1;
  pageSize: number = 20;
  isLoading: boolean = false;

  constructor() {
    makeAutoObservable(this);
  }

  async loadOnlineUsers(options: { silent?: boolean } = {}) {
    if (!options.silent) {
      this.isLoading = true;
    }
    try {
      const response = await apiService.getOnlineUsers();
      if (response.success && response.data) {
        this.onlineUsers = response.data;
      }
    } catch (error) {
      console.error('Failed to load online users:', error);
    } finally {
      if (!options.silent) {
        this.isLoading = false;
      }
    }
  }

  async loadAllUsers(page: number = 1, options: { silent?: boolean } = {}) {
    if (!options.silent) {
      this.isLoading = true;
    }
    this.currentPage = page;
    try {
      const response = await apiService.getAllUsers(page, this.pageSize);
      if (response.success && response.data) {
        this.allUsers = response.data.users || [];
        this.totalUsers = response.data.total_count || 0;
      }
    } catch (error) {
      console.error('Failed to load all users:', error);
    } finally {
      if (!options.silent) {
        this.isLoading = false;
      }
    }
  }
}

export const adminStore = new AdminStore();
