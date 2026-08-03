import { makeAutoObservable } from 'mobx';
import { apiService, type UserSummaryResponse } from '../services/api.service';
import { signalRService } from '../services/signalr.service';
import { authStore } from './auth.store';

type ChatUserSummary = UserSummaryResponse & { id: number };

export interface ChatMessage {
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
  sender: ChatUserSummary;
  receiver: ChatUserSummary;
}

export interface Contact {
  id: number;
  contact_user: ChatUserSummary;
  display_name?: string;
  added_at: string;
  is_blocked: boolean;
  last_message_at?: string;
  unread_count: number;
}

function getApiErrorMessage(error: unknown, fallback: string) {
  const maybeError = error as { response?: { data?: { message?: unknown } } };
  return typeof maybeError.response?.data?.message === 'string'
    ? maybeError.response.data.message
    : fallback;
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

  get totalUnreadCount() {
    return this.contacts.reduce((sum, contact) => sum + (contact.unread_count || 0), 0);
  }

  setupSignalRHandlers() {
    signalRService.onNewMessage = (message: ChatMessage) => {
      const currentUserId = authStore.user?.id;
      const peerUserId = this.getPeerUserId(message, currentUserId);
      const contact = this.findContactByPeerId(peerUserId);
      const isIncomingMessage = currentUserId !== undefined && message.receiver_id === currentUserId;
      const isCurrentContactMessage = Boolean(contact && this.currentContact?.id === contact.id);
      const visibleMessage = isIncomingMessage && isCurrentContactMessage
        ? { ...message, is_read: true }
        : message;

      if (isCurrentContactMessage) {
        // Avoid adding duplicate messages
        if (!this.messages.find(m => m.id === message.id)) {
          this.messages.push(visibleMessage);
          // Keep only the most recent 100 messages
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
      }

      if (contact) {
        this.updateContactForMessage(contact.id, visibleMessage, isIncomingMessage && !isCurrentContactMessage);
        if (isIncomingMessage && isCurrentContactMessage) {
          this.markContactAsRead(contact.id);
          void this.markMessagesAsRead([message.id], contact.id);
        }
      }

      if (!contact || (isIncomingMessage && !isCurrentContactMessage)) {
        void this.loadContacts(false);
      }
    };

    signalRService.onUserOnlineStatusChanged = (userId: number, isOnline: boolean) => {
      this.updateUserOnlineStatus(userId, isOnline);
    };
  }

  private getPeerUserId(message: ChatMessage, currentUserId?: number) {
    if (currentUserId !== undefined) {
      if (message.sender_id === currentUserId) return message.receiver_id;
      if (message.receiver_id === currentUserId) return message.sender_id;
    }
    return message.sender_id;
  }

  private findContactByPeerId(peerUserId?: number) {
    if (peerUserId === undefined) return undefined;
    return this.contacts.find((contact) => contact.contact_user?.id === peerUserId);
  }

  private updateContactForMessage(contactId: number, message: ChatMessage, incrementUnread: boolean) {
    const nextContacts = this.contacts.map((contact) => {
      if (contact.id !== contactId) return contact;
      return {
        ...contact,
        unread_count: incrementUnread ? (contact.unread_count || 0) + 1 : contact.unread_count,
        last_message_at: message.created_at || message.timestamp || contact.last_message_at,
      };
    });

    this.contacts = nextContacts;
    if (this.currentContact?.id === contactId) {
      const nextCurrentContact = nextContacts.find((contact) => contact.id === contactId);
      if (nextCurrentContact) {
        this.currentContact = nextCurrentContact;
      }
    }
  }

  private updateUserOnlineStatus(userId: number, isOnline: boolean) {
    const nextContacts = this.contacts.map((contact) => {
      if (contact.contact_user?.id !== userId) return contact;
      return {
        ...contact,
        contact_user: {
          ...contact.contact_user,
          is_online: isOnline,
        },
      };
    });

    this.contacts = nextContacts;
    if (this.currentContact?.contact_user?.id === userId) {
      const nextCurrentContact = nextContacts.find((contact) => contact.id === this.currentContact?.id);
      if (nextCurrentContact) {
        this.currentContact = nextCurrentContact;
      }
    }
  }

  markContactAsRead(contactId: number) {
    const nextContacts = this.contacts.map((contact) =>
      contact.id === contactId ? { ...contact, unread_count: 0 } : contact
    );

    this.contacts = nextContacts;
    if (this.currentContact?.id === contactId) {
      const nextCurrentContact = nextContacts.find((contact) => contact.id === contactId);
      if (nextCurrentContact) {
        this.currentContact = nextCurrentContact;
      }
    }
  }

  private async markMessagesAsRead(messageIds: number[], contactId?: number) {
    const uniqueMessageIds = Array.from(new Set(messageIds));
    if (uniqueMessageIds.length === 0) return;

    this.messages = this.messages.map((message) =>
      uniqueMessageIds.includes(message.id) ? { ...message, is_read: true } : message
    );
    if (contactId !== undefined) {
      this.markContactAsRead(contactId);
    }

    try {
      await Promise.all(uniqueMessageIds.map((messageId) => apiService.markMessageAsRead(messageId)));
    } catch (error) {
      console.error('Failed to mark messages as read:', error);
    } finally {
      void this.loadContacts(false);
    }
  }

  async loadContacts(showLoading = true) {
    if (showLoading) {
      this.isLoading = true;
    }
    try {
      const response = await apiService.getContacts();
      if (response.success && response.data) {
        this.contacts = response.data;
        if (this.currentContact) {
          const nextCurrentContact = response.data.find((contact) => contact.id === this.currentContact?.id);
          if (nextCurrentContact) {
            this.currentContact = nextCurrentContact;
          }
        }
      }
    } catch (error) {
      console.error('Failed to load contacts:', error);
    } finally {
      if (showLoading) {
        this.isLoading = false;
      }
    }
  }

  async loadMessages(contactId: number) {
    this.isLoading = true;
    this.markContactAsRead(contactId);
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
        this.markContactAsRead(contactId);
        void this.loadContacts(false);
      }
    } catch (error) {
      console.error('Failed to load messages:', error);
      void this.loadContacts(false);
    } finally {
      this.isLoading = false;
    }
  }

  async sendMessage(
    receiverId: number,
    content: string,
    options?: { type?: number; file_path?: string; file_size?: number; duration?: number }
  ) {
    try {
      const response = await apiService.sendMessage({
        receiver_id: receiverId,
        content,
        type: options?.type ?? 1,
        file_path: options?.file_path,
        file_size: options?.file_size,
        duration: options?.duration,
      });
      if (response.success && response.data) {
        const sentMessage = response.data;
        // Avoid adding duplicate messages (also received from SignalR)
        if (!this.messages.find(m => m.id === sentMessage.id)) {
          this.messages.push(sentMessage);
          // Keep only the most recent 100 messages
          if (this.messages.length > 100) {
            this.messages = this.messages.slice(-100);
          }
        }
        return { success: true };
      } else {
        return { success: false, message: response.message || 'Failed to send message' };
      }
    } catch (error: unknown) {
      return { success: false, message: getApiErrorMessage(error, 'Failed to send message') };
    }
  }

  setCurrentContact(contact: Contact | null) {
    this.currentContact = contact;
    if (contact) {
      this.markContactAsRead(contact.id);
      void this.loadMessages(contact.id);
    } else {
      this.messages = [];
    }
  }

  async addContact(username: string, displayName?: string) {
    try {
      const response = await apiService.addContact({ username, display_name: displayName });
      if (response.success && response.data) {
        return { success: true, message: response.message || 'Friend request sent' };
      } else {
        return { success: false, message: response.message || 'Failed to send friend request' };
      }
    } catch (error: unknown) {
      return { success: false, message: getApiErrorMessage(error, 'Failed to send friend request') };
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
    } catch (error: unknown) {
      return { success: false, message: getApiErrorMessage(error, 'Update failed') };
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
