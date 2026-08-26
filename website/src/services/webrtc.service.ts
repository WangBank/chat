import type { UserSummaryResponse } from './api.service';
import {
  signalRService,
  WebRTCMessageType,
  type WebRTCMessage,
} from './signalr.service';

export const CallType = {
  Voice: 1,
  Video: 2,
} as const;

export type CallType = (typeof CallType)[keyof typeof CallType];
export type CallPeer = UserSummaryResponse & { id: number };

export interface Call {
  callId: string;
  caller: CallPeer;
  receiver: CallPeer;
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
  private pendingIceCandidates: RTCIceCandidateInit[] = [];

  // Callbacks
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

  // Create peer connection
  private createPeerConnection(): RTCPeerConnection {
    const configuration: RTCConfiguration = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
      ],
    };

    const pc = new RTCPeerConnection(configuration);

    // Attach local stream
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        pc.addTrack(track, this.localStream!);
      });
    }

    // Listen for remote stream
    pc.ontrack = (event) => {
      console.log('Received remote stream');
      const [stream] = event.streams;
      if (stream) {
        this.remoteStream = stream;
      } else {
        this.remoteStream ??= new MediaStream();
        this.remoteStream.addTrack(event.track);
      }
      this.onRemoteStream?.(this.remoteStream);
    };

    // Listen for ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        const candidate = JSON.stringify(event.candidate);
        // Use current callId if available; otherwise temporary value
        const callId = this.currentCall?.callId || '';
        const currentUserId = this.getCurrentUserId();
        
        // Resolve receiver ID
        let receiverId = 0;
        if (this.currentCall) {
          receiverId = this.currentCall.caller.id === currentUserId
            ? this.currentCall.receiver.id
            : this.currentCall.caller.id;
        }
        
        if (callId && receiverId) {
          signalRService.sendWebRTCMessage({
            call_id: callId,
            type: WebRTCMessageType.IceCandidate,
            data: candidate,
            receiver_id: receiverId,
          });
        }
      }
    };

    // Listen for connection state
    pc.onconnectionstatechange = () => {
      console.log('Connection state:', pc.connectionState);
      if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
        this.endCall();
      }
    };

    return pc;
  }

  // Get user media
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
      console.error('Failed to get user media:', error);
      throw error;
    }
  }

  // Initiate call
  async initiateCall(receiverId: number, callType: CallType): Promise<void> {
    try {
      // Get user media
      await this.getUserMedia(callType);

      // Create peer connection
      this.peerConnection = this.createPeerConnection();

      // Initiate call. Offer is created only after the receiver accepts.
      await signalRService.initiateCall({
        receiver_id: receiverId,
        call_type: callType,
      });
    } catch (error) {
      console.error('Failed to initiate call:', error);
      this.onError?.('Failed to initiate call');
      throw error;
    }
  }

  setCurrentCall(call: Call): void {
    this.currentCall = call;
  }

  async startCallAsCaller(call: Call): Promise<void> {
    this.currentCall = call;
    this.isInCall = true;

    if (!this.localStream) {
      await this.getUserMedia(call.callType);
    }

    if (!this.peerConnection) {
      this.peerConnection = this.createPeerConnection();
    }

    await signalRService.joinCall(call.callId);

    const offer = await this.peerConnection.createOffer();
    await this.peerConnection.setLocalDescription(offer);

    const receiverId = call.receiver.id;
    await signalRService.sendWebRTCMessage({
      call_id: call.callId,
      type: WebRTCMessageType.Offer,
      data: JSON.stringify(offer),
      receiver_id: receiverId,
    });
  }

  // Accept call
  async acceptCall(call: Call): Promise<void> {
    try {
      this.currentCall = call;
      this.isInCall = true;

      // Get user media
      await this.getUserMedia(call.callType);

      // Create peer connection
      this.peerConnection = this.createPeerConnection();

      // Join call
      await signalRService.joinCall(call.callId);

      // Answer call
      await signalRService.answerCall(call.callId, true);

      // Do not create answer here
      // Answer should be created in handleWebRTCMessage after receiving Offer
    } catch (error) {
      console.error('Failed to accept call:', error);
      this.onError?.('Failed to accept call');
      throw error;
    }
  }

  // Reject call
  async rejectCall(callId: string): Promise<void> {
    try {
      await signalRService.answerCall(callId, false);
    } catch (error) {
      console.error('Failed to reject call:', error);
    } finally {
      // Ensure resources are cleaned up
      this.cleanup();
    }
  }

  // Handle WebRTC message
  async handleWebRTCMessage(message: WebRTCMessage): Promise<void> {
    try {
      const data = JSON.parse(message.data);

      switch (message.type) {
        case WebRTCMessageType.Offer: {
          // Create peer connection if not created yet (callee side)
          if (!this.peerConnection) {
            // Ensure user media is available
            if (!this.localStream) {
              // Determine call type from currentCall
              if (this.currentCall) {
                await this.getUserMedia(this.currentCall.callType);
              } else {
                // Default to video call if currentCall is missing
                await this.getUserMedia(CallType.Video);
              }
            }
            this.peerConnection = this.createPeerConnection();
          }

          // Set remote description (offer)
          await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data));
          await this.flushPendingIceCandidates();
          
          // Create answer
          const answer = await this.peerConnection.createAnswer();
          await this.peerConnection.setLocalDescription(answer);

          const answerData = JSON.stringify(answer);
          await signalRService.sendWebRTCMessage({
            call_id: message.call_id,
            type: WebRTCMessageType.Answer,
            data: answerData,
            receiver_id: message.sender_id,
          });
          break;
        }

        case WebRTCMessageType.Answer:
          if (!this.peerConnection) {
            console.error('Received answer without peer connection');
            return;
          }
          await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data));
          await this.flushPendingIceCandidates();
          break;

        case WebRTCMessageType.IceCandidate:
          if (!this.peerConnection) {
            console.warn('Received ICE candidate without peer connection; may still be initializing');
            this.pendingIceCandidates.push(data);
            return;
          }
          await this.peerConnection.addIceCandidate(new RTCIceCandidate(data));
          break;
      }
    } catch (error) {
      console.error('Failed to handle WebRTC message:', error);
      this.onError?.('Failed to handle WebRTC message');
    }
  }

  // End call
  async endCall(): Promise<void> {
    if (this.currentCall) {
      try {
        await signalRService.endCall(this.currentCall.callId);
      } catch (error) {
        console.error('Failed to end call:', error);
      }
    }

    // Ensure resources are cleaned up
    this.cleanup();
    this.onCallEnded?.();
  }

  // Cleanup resources
  private cleanup(): void {
    // Stop local stream
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => track.stop());
      this.localStream = null;
    }

    // Close peer connection
    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
    }

    this.currentCall = null;
    this.isInCall = false;
    this.remoteStream = null;
    this.pendingIceCandidates = [];
  }

  private async flushPendingIceCandidates(): Promise<void> {
    if (!this.peerConnection || this.pendingIceCandidates.length === 0) return;

    const candidates = this.pendingIceCandidates;
    this.pendingIceCandidates = [];
    for (const candidate of candidates) {
      await this.peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
    }
  }

  // Get current user ID from localStorage
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
