import { signalRService, type WebRTCMessage } from './signalr.service';

export const CallType = {
  Voice: 1,
  Video: 2,
} as const;

export type CallType = (typeof CallType)[keyof typeof CallType];

export interface Call {
  callId: string;
  caller: any;
  receiver: any;
  callType: CallType;
  status: number;
  startTime: string;
}

class WebRTCService {
  private peerConnection: RTCPeerConnection | null = null;
  private localStream: MediaStream | null = null;
  private remoteStream: MediaStream | null = null;
  private currentCall: Call | null = null;
  private isInCall: boolean = false;
  private pendingOffer: { offer: RTCSessionDescriptionInit; receiverId: number } | null = null;

  // 回调函数
  onLocalStream?: (stream: MediaStream) => void;
  onRemoteStream?: (stream: MediaStream) => void;
  onCallEnded?: () => void;
  onError?: (error: string) => void;

  get currentCallInfo(): Call | null {
    return this.currentCall;
  }

  get isInCallState(): boolean {
    return this.isInCall;
  }

  // 创建PeerConnection
  private createPeerConnection(): RTCPeerConnection {
    const configuration: RTCConfiguration = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ],
    };

    const pc = new RTCPeerConnection(configuration);

    // 添加本地流
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        pc.addTrack(track, this.localStream!);
      });
    }

    // 监听远程流
    pc.ontrack = (event) => {
      console.log('收到远程流');
      this.remoteStream = event.streams[0];
      this.onRemoteStream?.(this.remoteStream);
    };

    // 监听ICE候选
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        const candidate = JSON.stringify(event.candidate);
        // 如果currentCall存在，使用它的callId，否则使用临时值（会在收到CallInitiated时更新）
        const callId = this.currentCall?.callId || '';
        const currentUserId = this.getCurrentUserId();
        
        // 确定接收者ID
        let receiverId = 0;
        if (this.currentCall) {
          receiverId = this.currentCall.caller.id === currentUserId
            ? this.currentCall.receiver.id
            : this.currentCall.caller.id;
        }
        
        if (callId && receiverId) {
          signalRService.sendWebRTCMessage({
            call_id: callId,
            type: 3, // ICE Candidate
            data: candidate,
            receiver_id: receiverId,
          });
        }
      }
    };

    // 监听连接状态
    pc.onconnectionstatechange = () => {
      console.log('连接状态:', pc.connectionState);
      if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
        this.endCall();
      }
    };

    return pc;
  }

  // 获取用户媒体
  async getUserMedia(callType: CallType): Promise<MediaStream> {
    const constraints: MediaStreamConstraints = {
      audio: true,
      video: callType === CallType.Video,
    };

    try {
      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      this.localStream = stream;
      this.onLocalStream?.(stream);
      return stream;
    } catch (error) {
      console.error('获取用户媒体失败:', error);
      throw error;
    }
  }

  // 发起通话
  async initiateCall(receiverId: number, callType: CallType): Promise<void> {
    try {
      // 获取用户媒体
      await this.getUserMedia(callType);

      // 创建PeerConnection
      this.peerConnection = this.createPeerConnection();

      // 创建Offer
      if (this.peerConnection) {
        const offer = await this.peerConnection.createOffer();
        await this.peerConnection.setLocalDescription(offer);

        // 保存Offer，等待call_id设置后再发送
        this.pendingOffer = {
          offer,
          receiverId,
        };
        
        // 发起通话
        await signalRService.initiateCall({
          receiver_id: receiverId,
          call_type: callType,
        });
      }
    } catch (error) {
      console.error('发起通话失败:', error);
      this.onError?.('发起通话失败');
      throw error;
    }
  }

  // 发送待发送的Offer（在收到call_id后调用）
  async sendPendingOffer(callId: string): Promise<void> {
    if (this.pendingOffer && callId) {
      const offerData = JSON.stringify(this.pendingOffer.offer);
      await signalRService.sendWebRTCMessage({
        call_id: callId,
        type: 1, // Offer
        data: offerData,
        receiver_id: this.pendingOffer.receiverId,
      });
      this.pendingOffer = null;
    }
  }

  // 接受通话
  async acceptCall(call: Call): Promise<void> {
    try {
      this.currentCall = call;
      this.isInCall = true;

      // 获取用户媒体
      await this.getUserMedia(call.callType);

      // 创建PeerConnection
      this.peerConnection = this.createPeerConnection();

      // 加入通话
      await signalRService.joinCall(call.callId);

      // 应答通话
      await signalRService.answerCall(call.callId, true);

      // 注意：不要在这里创建Answer
      // Answer应该在收到Offer后，在handleWebRTCMessage中创建
      // 如果已经收到Offer，handleWebRTCMessage会自动处理
    } catch (error) {
      console.error('接受通话失败:', error);
      this.onError?.('接受通话失败');
      throw error;
    }
  }

  // 拒绝通话
  async rejectCall(callId: string): Promise<void> {
    try {
      await signalRService.answerCall(callId, false);
    } catch (error) {
      console.error('拒绝通话失败:', error);
    } finally {
      // 确保清理资源
      this.cleanup();
    }
  }

  // 处理WebRTC消息
  async handleWebRTCMessage(message: WebRTCMessage): Promise<void> {
    try {
      const data = JSON.parse(message.data);

      switch (message.type) {
        case 1: // Offer
          // 如果还没有PeerConnection，先创建（接收方场景）
          if (!this.peerConnection) {
            // 确保已经获取用户媒体
            if (!this.localStream) {
              // 需要知道通话类型，从currentCall获取
              if (this.currentCall) {
                await this.getUserMedia(this.currentCall.callType);
              } else {
                // 如果没有currentCall，默认使用视频通话
                await this.getUserMedia(CallType.Video);
              }
            }
            this.peerConnection = this.createPeerConnection();
          }

          // 设置远程描述（Offer）
          await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data));
          
          // 创建Answer
          const answer = await this.peerConnection.createAnswer();
          await this.peerConnection.setLocalDescription(answer);

          const answerData = JSON.stringify(answer);
          await signalRService.sendWebRTCMessage({
            call_id: message.call_id,
            type: 2, // Answer
            data: answerData,
            receiver_id: message.sender_id,
          });
          break;

        case 2: // Answer
          if (!this.peerConnection) {
            console.error('收到Answer但没有PeerConnection');
            return;
          }
          await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data));
          break;

        case 3: // ICE Candidate
          if (!this.peerConnection) {
            console.warn('收到ICE Candidate但没有PeerConnection，可能还在初始化');
            return;
          }
          await this.peerConnection.addIceCandidate(new RTCIceCandidate(data));
          break;
      }
    } catch (error) {
      console.error('处理WebRTC消息失败:', error);
      this.onError?.('处理WebRTC消息失败');
    }
  }

  // 结束通话
  async endCall(): Promise<void> {
    if (this.currentCall) {
      try {
        await signalRService.endCall(this.currentCall.callId);
      } catch (error) {
        console.error('结束通话失败:', error);
      }
    }

    // 确保清理资源
    this.cleanup();
    this.onCallEnded?.();
  }

  // 清理资源
  private cleanup(): void {
    // 停止本地流
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }

    // 关闭PeerConnection
    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
    }

    this.currentCall = null;
    this.isInCall = false;
    this.remoteStream = null;
    this.pendingOffer = null;
  }

  // 获取当前用户ID（从localStorage）
  private getCurrentUserId(): number {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      const user = JSON.parse(userStr);
      return user.id;
    }
    return 0;
  }
}

export const webRTCService = new WebRTCService();

