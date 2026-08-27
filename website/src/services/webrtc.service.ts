import type { UserSummaryResponse } from './api.service';
import {
  signalRService,
  WebRTCMessageType,
  type WebRTCMessage,
} from './signalr.service';
import { APP_CONFIG } from '../config/app.config';

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
  private iceServersPromise: Promise<RTCIceServer[]> | null = null;

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
  private async createPeerConnection(): Promise<RTCPeerConnection> {
    const configuration: RTCConfiguration = {
      iceServers: await this.loadIceServers(),
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
      console.log('ICE state:', pc.iceConnectionState, 'signaling:', pc.signalingState);
      if (pc.connectionState === 'disconnected' || pc.connectionState === 'failed') {
        this.endCall();
      }
    };
    pc.oniceconnectionstatechange = () => {
      console.log('ICE connection state:', pc.iceConnectionState);
    };
    pc.onicecandidateerror = (event) => {
      console.warn('ICE candidate error:', event.errorCode, event.errorText || '');
    };

    return pc;
  }

  private async loadIceServers(): Promise<RTCIceServer[]> {
    if (!this.iceServersPromise) {
      this.iceServersPromise = this.fetchIceServers();
    }
    return this.iceServersPromise;
  }

  private async fetchIceServers(): Promise<RTCIceServer[]> {
    const fallback: RTCIceServer[] = [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' },
    ];

    try {
      const response = await fetch(`${APP_CONFIG.API_BASE_URL}/api/system/webrtc-config`);
      if (!response.ok) return fallback;

      const payload = await response.json() as { ice_servers?: unknown };
      if (!Array.isArray(payload.ice_servers)) return fallback;

      const iceServers = payload.ice_servers.flatMap((server): RTCIceServer[] => {
        if (!server || typeof server !== 'object') return [];
        const value = server as { urls?: unknown; username?: unknown; credential?: unknown };
        const urls = Array.isArray(value.urls)
          ? value.urls.filter((url): url is string => typeof url === 'string' && url.length > 0)
          : typeof value.urls === 'string' && value.urls.length > 0
            ? value.urls
            : [];
        if (Array.isArray(urls) && urls.length === 0) return [];

        return [{
          urls,
          ...(typeof value.username === 'string' ? { username: value.username } : {}),
          ...(typeof value.credential === 'string' ? { credential: value.credential } : {}),
        }];
      });

      return iceServers.length > 0 ? iceServers : fallback;
    } catch {
      return fallback;
    }
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
      this.peerConnection = await this.createPeerConnection();

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
      this.peerConnection = await this.createPeerConnection();
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
        this.peerConnection = await this.createPeerConnection();

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
            this.peerConnection = await this.createPeerConnection();
          }

          // Set remote description (offer)
          await this.peerConnection.setRemoteDescription(new RTCSessionDescription(data));
          console.log('Remote offer installed:', {
            signaling: this.peerConnection.signalingState,
            transceivers: this.peerConnection.getTransceivers().map((item) => ({
              direction: item.direction,
              currentDirection: item.currentDirection,
              kind: item.receiver.track.kind,
            })),
          });
          await this.flushPendingIceCandidates();
          
          // Create answer
          const answer = await this.peerConnection.createAnswer();
          await this.peerConnection.setLocalDescription(answer);
          console.log('Local answer created:', {
            signaling: this.peerConnection.signalingState,
            transceivers: this.peerConnection.getTransceivers().map((item) => ({
              direction: item.direction,
              currentDirection: item.currentDirection,
              kind: item.receiver.track.kind,
            })),
          });

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
          // ICE delivery can race ahead of the offer/answer. WebRTC rejects a
          // candidate until the matching remote description is installed, so
          // preserve it and flush immediately after setRemoteDescription.
          if (!this.peerConnection || !this.peerConnection.remoteDescription) {
            console.warn('Received ICE candidate before remote description; queued for later');
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
