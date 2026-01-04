import { makeAutoObservable } from 'mobx';
import { apiService } from '../services/api.service';
import { signalRService } from '../services/signalr.service';

export interface ChatMessage {
  id: number;
  sender_id: number;
  receiver_id: number;
  content: string;
  type: number;
  timestamp: string;
  is_read: boolean;
  file_path?: string;
  file_size?: number;
  duration?: number;
  created_at: string;
  sender: any;
  receiver: any;
}

export interface Contact {
  id: number;
  contact_user: any;
  display_name?: string;
  added_at: string;
  is_blocked: boolean;
  last_message_at?: string;
  unread_count: number;
}

class ChatStore {
  contacts: Contact[] = [];
  currentContact: Contact | null = null;
  messages: ChatMessage[] = [];
  isLoading: boolean = false;

  constructor() {
    makeAutoObservable(this);
    this.setupSignalRHandlers();
  }

  setupSignalRHandlers() {
    signalRService.onNewMessage = (message: ChatMessage) => {
      // 检查是否是当前联系人的消息
      const isCurrentContactMessage = 
        this.currentContact &&
        (message.sender_id === this.currentContact.contact_user.id ||
          message.receiver_id === this.currentContact.contact_user.id);

      if (isCurrentContactMessage) {
        // 避免重复添加消息
        if (!this.messages.find(m => m.id === message.id)) {
          this.messages.push(message);
          // 保持只显示最近100条
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
      }
      
      // 更新联系人的未读消息数和最后消息时间
      this.updateContactUnreadCount(message);
      
      // 如果收到新消息，重新加载联系人列表以更新未读计数
      this.loadContacts();
    };
  }

  updateContactUnreadCount(message: ChatMessage) {
    const contact = this.contacts.find(
      (c) =>
        c.contact_user.id === message.sender_id ||
        c.contact_user.id === message.receiver_id
    );
    if (contact) {
      contact.unread_count += 1;
      contact.last_message_at = message.created_at;
    }
  }

  async loadContacts() {
    this.isLoading = true;
    try {
      const response = await apiService.getContacts();
      if (response.success && response.data) {
        this.contacts = response.data;
      }
    } catch (error) {
      console.error('加载联系人失败:', error);
    } finally {
      this.isLoading = false;
    }
  }

  async loadMessages(contactId: number) {
    this.isLoading = true;
    try {
      const response = await apiService.getChatHistory(contactId);
      if (response.success && response.data) {
        // 只显示最近100条消息，并确保id唯一
        const messages = response.data || [];
        const uniqueMessages = messages.slice(-100).reduce((acc: ChatMessage[], msg) => {
          if (!acc.find(m => m.id === msg.id)) {
            acc.push(msg);
          }
          return acc;
        }, []);
        this.messages = uniqueMessages;
      }
    } catch (error) {
      console.error('加载消息失败:', error);
    } finally {
      this.isLoading = false;
    }
  }

  async sendMessage(receiverId: number, content: string) {
    try {
      const response = await apiService.sendMessage({
        receiver_id: receiverId,
        content,
        type: 0, // Text
      });
      if (response.success && response.data) {
        // 避免重复添加消息（SignalR也会收到）
        if (!this.messages.find(m => m.id === response.data.id)) {
          this.messages.push(response.data);
          // 保持只显示最近100条
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
        return { success: true };
      } else {
        return { success: false, message: response.message || '发送失败' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || '发送失败' };
    }
  }

  setCurrentContact(contact: Contact | null) {
    this.currentContact = contact;
    if (contact) {
      this.loadMessages(contact.id);
    } else {
      this.messages = [];
    }
  }

  async addContact(username: string, displayName?: string) {
    try {
      const response = await apiService.addContact({ username, display_name: displayName });
      if (response.success && response.data) {
        await this.loadContacts();
        return { success: true };
      } else {
        return { success: false, message: response.message || '添加联系人失败' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || '添加联系人失败' };
    }
  }

  async updateDisplayName(contactId: number, displayName: string) {
    try {
      const response = await apiService.updateContactDisplayName(contactId, displayName);
      if (response.success && response.data) {
        await this.loadContacts();
        if (this.currentContact?.id === contactId) {
          this.currentContact = response.data;
        }
        return { success: true };
      } else {
        return { success: false, message: response.message || '修改失败' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || '修改失败' };
    }
  }

  searchMessages(query: string, startDate?: string, endDate?: string) {
    // 过滤消息
    let filtered = this.messages.filter((msg) => {
      if (msg.sender_id !== this.currentContact?.contact_user.id &&
          msg.receiver_id !== this.currentContact?.contact_user.id) {
        return false;
      }

      // 内容搜索
      if (query && !msg.content.toLowerCase().includes(query.toLowerCase())) {
        return false;
      }

      // 日期搜索
      if (startDate || endDate) {
        const msgDate = new Date(msg.created_at);
        if (startDate && msgDate < new Date(startDate)) return false;
        if (endDate && msgDate > new Date(endDate)) return false;
      }

      return true;
    });

    // 如果搜索条件为空，显示所有消息
    if (!query && !startDate && !endDate) {
      filtered = this.messages;
    }

    this.messages = filtered;
  }
}

export const chatStore = new ChatStore();

