import * as signalR from '@microsoft/signalr';
import { APP_CONFIG } from '../config/app.config';

export interface IncomingCall {
  call_id: string;
  caller: any;
  receiver: any;
  call_type: number; // 1: 语音, 2: 视频
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

  // 回调函数
  onIncomingCall?: (call: IncomingCall) => void;
  onCallInitiated?: (call: IncomingCall) => void; // 呼叫方收到通话初始化通知
  onCallAccepted?: (callId: string, receiverId: number) => void;
  onCallRejected?: (callId: string, receiverId: number) => void;
  onCallEnded?: (callId: string, endedBy: number) => void;
  onWebRTCMessage?: (message: WebRTCMessage) => void;
  onNewMessage?: (message: any) => void;
  onError?: (error: string) => void;

  get isConnected(): boolean {
    return this.connection?.state === signalR.HubConnectionState.Connected;
  }

  async connect(token: string): Promise<void> {
    // 如果已连接，直接返回
    if (this.connection && this.isConnected) {
      return;
    }

    // 如果连接存在但未连接，先停止旧连接
    if (this.connection) {
      try {
        await this.connection.stop();
      } catch (error) {
        console.warn('停止旧连接失败:', error);
      }
      this.connection = null;
    }

    this.connection = new signalR.HubConnectionBuilder()
      .withUrl(`${APP_CONFIG.SIGNALR_HUB_URL}?access_token=${token}`, {
        accessTokenFactory: () => token,
      })
      .withAutomaticReconnect()
      .build();

    // 设置事件监听器
    this.setupEventListeners();

    try {
      await this.connection.start();
      console.log('SignalR连接成功');
      // 等待一小段时间确保状态更新
      await new Promise(resolve => setTimeout(resolve, 100));
    } catch (error) {
      console.error('SignalR连接失败:', error);
      this.connection = null;
      throw error;
    }
  }

  private setupEventListeners(): void {
    if (!this.connection) return;

    // 重连事件
    this.connection.onreconnecting(() => {
      console.log('SignalR正在重连...');
    });

    this.connection.onreconnected(() => {
      console.log('SignalR重连成功');
    });

    this.connection.onclose((error) => {
      console.log('SignalR连接关闭:', error);
    });

    // 通话相关事件
    this.connection.on('IncomingCall', (call: IncomingCall) => {
      console.log('收到来电:', call);
      this.onIncomingCall?.(call);
    });

    this.connection.on('CallInitiated', (call: IncomingCall) => {
      console.log('通话已发起:', call);
      this.onCallInitiated?.(call);
    });

    this.connection.on('CallAccepted', (data: { call_id: string; receiver_id: number }) => {
      console.log('通话被接受:', data);
      this.onCallAccepted?.(data.call_id, data.receiver_id);
    });

    this.connection.on('CallRejected', (data: { call_id: string; receiver_id: number }) => {
      console.log('通话被拒绝:', data);
      this.onCallRejected?.(data.call_id, data.receiver_id);
    });

    this.connection.on('CallEnded', (data: { call_id: string; EndedBy: number }) => {
      console.log('通话结束:', data);
      this.onCallEnded?.(data.call_id, data.EndedBy);
    });

    // WebRTC消息
    this.connection.on('WebRTCMessage', (message: WebRTCMessage) => {
      console.log('收到WebRTC消息:', message);
      this.onWebRTCMessage?.(message);
    });

    // 聊天消息
    this.connection.on('NewMessage', (message: any) => {
      console.log('收到新消息:', message);
      this.onNewMessage?.(message);
    });

    // 错误事件
    this.connection.on('CallError', (error: string) => {
      console.error('通话错误:', error);
      this.onError?.(error);
    });
  }

  async authenticate(userId: number): Promise<void> {
    // 等待连接建立
    if (!this.connection) {
      throw new Error('SignalR连接不存在');
    }

    // 如果未连接，等待连接建立（最多等待2秒）
    if (!this.isConnected) {
      let retries = 20; // 等待最多2秒 (20 * 100ms)
      while (!this.isConnected && retries > 0) {
        await new Promise(resolve => setTimeout(resolve, 100));
        retries--;
      }
      
      if (!this.isConnected) {
        throw new Error('SignalR未连接，等待超时');
      }
    }

    try {
      await this.connection.invoke('Authenticate', userId);
      console.log('用户认证成功:', userId);
    } catch (error) {
      console.error('用户认证失败:', error);
      throw error;
    }
  }

  async initiateCall(data: { receiver_id: number; call_type: number }): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('InitiateCall', data);
      console.log('发起通话:', data);
    } catch (error) {
      console.error('发起通话失败:', error);
      throw error;
    }
  }

  async answerCall(callId: string, accept: boolean): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('AnswerCall', { call_id: callId, accept });
      console.log('应答通话:', { callId, accept });
    } catch (error) {
      console.error('应答通话失败:', error);
      throw error;
    }
  }

  async endCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('EndCall', callId);
      console.log('结束通话:', callId);
    } catch (error) {
      console.error('结束通话失败:', error);
      throw error;
    }
  }

  async joinCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('JoinCall', callId);
      console.log('加入通话:', callId);
    } catch (error) {
      console.error('加入通话失败:', error);
      throw error;
    }
  }

  async leaveCall(callId: string): Promise<void> {
    if (!this.connection || !this.isConnected) {
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('LeaveCall', callId);
      console.log('离开通话:', callId);
    } catch (error) {
      console.error('离开通话失败:', error);
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
      throw new Error('SignalR未连接');
    }

    try {
      await this.connection.invoke('SendWebRTCMessage', message);
      console.log('发送WebRTC消息:', message);
    } catch (error) {
      console.error('发送WebRTC消息失败:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.connection) {
      await this.connection.stop();
      this.connection = null;
      console.log('SignalR已断开连接');
    }
  }
}

export const signalRService = new SignalRService();

