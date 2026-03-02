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
      // Check whether message belongs to current contact
      const isCurrentContactMessage = 
        this.currentContact &&
        (message.sender_id === this.currentContact.contact_user.id ||
          message.receiver_id === this.currentContact.contact_user.id);

      if (isCurrentContactMessage) {
        // Avoid adding duplicate messages
        if (!this.messages.find(m => m.id === message.id)) {
          this.messages.push(message);
          // Keep only the most recent 100 messages
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
      }
      
      // Update contact unread count and last message time
      this.updateContactUnreadCount(message);
      
      // Reload contacts when a new message arrives to refresh unread count
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
      console.error('Failed to load contacts:', error);
    } finally {
      this.isLoading = false;
    }
  }

  async loadMessages(contactId: number) {
    this.isLoading = true;
    try {
      const response = await apiService.getChatHistory(contactId);
      if (response.success && response.data) {
        // Keep only recent 100 messages and ensure unique IDs
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
      console.error('Failed to load messages:', error);
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
        // Avoid adding duplicate messages (also received from SignalR)
        if (!this.messages.find(m => m.id === response.data.id)) {
          this.messages.push(response.data);
          // Keep only the most recent 100 messages
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
        return { success: true };
      } else {
        return { success: false, message: response.message || 'Failed to send message' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'Failed to send message' };
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
        return { success: false, message: response.message || 'Failed to add contact' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'Failed to add contact' };
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
        return { success: false, message: response.message || 'Update failed' };
      }
    } catch (error: any) {
      return { success: false, message: error.response?.data?.message || 'Update failed' };
    }
  }

  searchMessages(query: string, startDate?: string, endDate?: string) {
    // Filter messages
    let filtered = this.messages.filter((msg) => {
      if (msg.sender_id !== this.currentContact?.contact_user.id &&
          msg.receiver_id !== this.currentContact?.contact_user.id) {
        return false;
      }

      // Content search
      if (query && !msg.content.toLowerCase().includes(query.toLowerCase())) {
        return false;
      }

      // Date range search
      if (startDate || endDate) {
        const msgDate = new Date(msg.created_at);
        if (startDate && msgDate < new Date(startDate)) return false;
        if (endDate && msgDate > new Date(endDate)) return false;
      }

      return true;
    });

    // Show all messages when no search conditions are set
    if (!query && !startDate && !endDate) {
      filtered = this.messages;
    }

    this.messages = filtered;
  }
}

export const chatStore = new ChatStore();

