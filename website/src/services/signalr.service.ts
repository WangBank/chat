import * as signalR from '@microsoft/signalr';
import { APP_CONFIG } from '../config/app.config';
import type { ChatMessageApiResponse, UserSummaryResponse } from './api.service';

type SignalRUser = UserSummaryResponse & {
  id: number;
  username: string;
  created_at?: string;
  updated_at?: string;
  last_login_at?: string;
};

export interface IncomingCall {
  call_id: string;
  caller: SignalRUser;
  receiver: SignalRUser;
  call_type: number; // 1: voice, 2: video
  status: number;
  start_time: string;
}

export interface WebRTCMessage {
  call_id: string;
  type: number; // 1: Offer, 2: Answer, 3: ICE Candidate
  data: string;
  sender_id: number;
  receiver_id: number;
}

class SignalRService {
  private connection: signalR.HubConnection | null = null;
  private currentUserId: number | null = null;
  private heartbeatTimer: number | null = null;
  private heartbeatInFlight = false;

  // Callbacks
  onIncomingCall?: (call: IncomingCall) => void;
  onCallInitiated?: (call: IncomingCall) => void; // Caller receives call-init notification
  onCallAccepted?: (callId: string, receiverId: number) => void;
  onCallRejected?: (callId: string, receiverId: number) => void;
  onCallEnded?: (callId: string, endedBy: number) => void;
  onWebRTCMessage?: (message: WebRTCMessage) => void;
  onNewMessage?: (message: ChatMessageApiResponse) => void;
  onError?: (error: string) => void;

  get isConnected(): boolean {
    return this.connection?.state === signalR.HubConnectionState.Connected;
  }

  async connect(token: string): Promise<void> {
    // Return immediately if already connected
    if (this.connection && this.isConnected) {
      return;
    }

    // Stop old connection if it exists but is not connected
    if (this.connection) {
      try {
        await this.connection.stop();
      } catch (error) {
        console.warn('Failed to stop previous connection:', error);
      }
      this.connection = null;
    }

    this.connection = new signalR.HubConnectionBuilder()
      .withUrl(APP_CONFIG.SIGNALR_HUB_URL, {
        accessTokenFactory: () => token,
      })
      .withAutomaticReconnect()
      .build();

    // Register event listeners
    this.setupEventListeners();

    try {
      await this.connection.start();
      console.log('SignalR connected');
      // Wait briefly to ensure state propagation
      await new Promise(resolve => setTimeout(resolve, 100));
    } catch (error) {
      console.error('SignalR connection failed:', error);
      this.connection = null;
      throw error;
    }
  }

  private setupEventListeners(): void {
    if (!this.connection) return;

    // Reconnection events
    this.connection.onreconnecting(() => {
      console.log('SignalR reconnecting...');
    });

    this.connection.onreconnected(async () => {
      console.log('SignalR reconnected');
      if (this.currentUserId !== null) {
        try {
          await this.authenticate(this.currentUserId);
        } catch (error) {
          console.error('SignalR re-authentication failed:', error);
        }
      }
    });

    this.connection.onclose((error) => {
      console.log('SignalR connection closed:', error);
      this.stopHeartbeat();
    });

    // Call-related events
    this.connection.on('IncomingCall', (call: IncomingCall) => {
      console.log('Incoming call:', call);
      this.onIncomingCall?.(call);
    });

    this.connection.on('CallInitiated', (call: IncomingCall) => {
      console.log('Call initiated:', call);
      this.onCallInitiated?.(call);
    });

    this.connection.on('CallAccepted', (data: { call_id: string; receiver_id: number }) => {
      console.log('Call accepted:', data);
      this.onCallAccepted?.(data.call_id, data.receiver_id);
    });

    this.connection.on('CallRejected', (data: { call_id: string; receiver_id: number }) => {
      console.log('Call rejected:', data);
      this.onCallRejected?.(data.call_id, data.receiver_id);
    });

    this.connection.on('CallEnded', (data: { call_id: string; EndedBy: number }) => {
      console.log('Call ended:', data);
      this.onCallEnded?.(data.call_id, data.EndedBy);
    });

    // WebRTC messages
    this.connection.on('WebRTCMessage', (message: WebRTCMessage) => {
      console.log('Received WebRTC message:', message);
      this.onWebRTCMessage?.(message);
    });

    // Chat messages
    this.connection.on('NewMessage', (message: ChatMessageApiResponse) => {
      console.log('New message:', message);
      this.onNewMessage?.(message);
    });

    // Error events
    this.connection.on('CallError', (error: string) => {
      console.error('Call error:', error);
      this.onError?.(error);
    });
  }

  async authenticate(userId?: number): Promise<void> {
    // Wait for connection to be ready
    if (!this.connection) {
      throw new Error('SignalR connection does not exist');
    }

    // If not connected, wait up to 2 seconds
    if (!this.isConnected) {
      let retries = 20; // Wait up to 2s (20 * 100ms)
      while (!this.isConnected && retries > 0) {
        await new Promise(resolve => setTimeout(resolve, 100));
        retries--;
      }
      
      if (!this.isConnected) {
        throw new Error('SignalR is not connected, timed out while waiting');
      }
    }

    try {
      await this.connection.invoke('Authenticate');
      if (userId !== undefined) {
        this.currentUserId = userId;
      }
      this.startHeartbeat();
      console.log('User authenticated:', userId);
    } catch (error) {
      console.error('User authentication failed:', error);
      throw error;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    void this.sendHeartbeat();
    this.heartbeatTimer = window.setInterval(() => {
      void this.sendHeartbeat();
    }, 2000);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      window.clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
    this.heartbeatInFlight = false;
  }

  private async sendHeartbeat(): Promise<void> {
    if (!this.connection || !this.isConnected || this.heartbeatInFlight) {
      return;
    }

    this.heartbeatInFlight = true;
    try {
      await this.connection.invoke('Heartbeat');
    } catch (error) {
      console.warn('SignalR heartbeat failed:', error);
    } finally {
      this.heartbeatInFlight = false;
    }
  }

  async initiateCall(data: { receiver_id: number; call_type: number }): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('InitiateCall', data);
      console.log('Initiate call:', data);
    } catch (error) {
      console.error('Failed to initiate call:', error);
      throw error;
    }
  }

  async answerCall(callId: string, accept: boolean): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('AnswerCall', { call_id: callId, accept });
      console.log('Answer call:', { callId, accept });
    } catch (error) {
      console.error('Failed to answer call:', error);
      throw error;
    }
  }

  async endCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('EndCall', callId);
      console.log('End call:', callId);
    } catch (error) {
      console.error('Failed to end call:', error);
      throw error;
    }
  }

  async joinCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('JoinCall', callId);
      console.log('Join call:', callId);
    } catch (error) {
      console.error('Failed to join call:', error);
      throw error;
    }
  }

  async leaveCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('LeaveCall', callId);
      console.log('Leave call:', callId);
    } catch (error) {
      console.error('Failed to leave call:', error);
      throw error;
    }
  }

  async sendWebRTCMessage(message: {
    call_id: string;
    type: number;
    data: string;
    receiver_id: number;
  }): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR is not connected');
    }

    try {
      await this.connection.invoke('SendWebRTCMessage', message);
      console.log('Send WebRTC message:', message);
    } catch (error) {
      console.error('Failed to send WebRTC message:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    this.stopHeartbeat();
    if (this.connection) {
      await this.connection.stop();
      this.connection = null;
      this.currentUserId = null;
      console.log('SignalR disconnected');
    }
  }
}

export const signalRService = new SignalRService();
