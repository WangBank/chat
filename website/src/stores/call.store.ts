import { makeAutoObservable } from 'mobx';
import { signalRService, type IncomingCall } from '../services/signalr.service';
import { webRTCService, CallType } from '../services/webrtc.service';
import { authStore } from './auth.store';

class CallStore {
  currentCall: IncomingCall | null = null;
  isInCall: boolean = false;
  isRinging: boolean = false;
  localStream: MediaStream | null = null;
  remoteStream: MediaStream | null = null;

  constructor() {
    makeAutoObservable(this);
    this.setupSignalRHandlers();
    this.setupWebRTCHandlers();
  }

  setupSignalRHandlers() {
    signalRService.onIncomingCall = (call: IncomingCall) => {
      this.currentCall = call;
      this.isRinging = true;
    };

    signalRService.onCallInitiated = async (call: IncomingCall) => {
      // Caller receives call-init event and updates currentCall (mainly call_id)
      if (this.currentCall && (!this.currentCall.call_id || this.currentCall.call_id === '')) {
        this.currentCall.call_id = call.call_id;
        this.currentCall.start_time = call.start_time;
        // Send pending offer
        await webRTCService.sendPendingOffer(call.call_id);
      } else if (!this.currentCall) {
        this.currentCall = call;
        this.isRinging = true;
        // Send pending offer
        await webRTCService.sendPendingOffer(call.call_id);
      }
    };

    signalRService.onCallAccepted = async (callId: string) => {
      // Update currentCall.call_id if it was empty
      if (this.currentCall) {
        if (!this.currentCall.call_id || this.currentCall.call_id === '') {
          this.currentCall.call_id = callId;
        }
        if (this.currentCall.call_id === callId) {
          this.isRinging = false;
          this.isInCall = true;
          await webRTCService.acceptCall({
            callId: this.currentCall.call_id,
            caller: this.currentCall.caller,
            receiver: this.currentCall.receiver,
            callType: this.currentCall.call_type as CallType,
            status: this.currentCall.status,
            startTime: this.currentCall.start_time,
          });
        }
      }
    };

    signalRService.onCallRejected = (callId: string) => {
      if (this.currentCall && this.currentCall.call_id === callId) {
        this.cleanup();
      }
    };

    signalRService.onCallEnded = (callId: string) => {
      if (this.currentCall && this.currentCall.call_id === callId) {
        this.cleanup();
      }
    };

    signalRService.onWebRTCMessage = async (message) => {
      await webRTCService.handleWebRTCMessage(message);
    };

    signalRService.onError = (error: string) => {
      console.error('Call error:', error);
      this.cleanup();
    };
  }

  setupWebRTCHandlers() {
    webRTCService.onLocalStream = (stream: MediaStream) => {
      this.localStream = stream;
    };

    webRTCService.onRemoteStream = (stream: MediaStream) => {
      this.remoteStream = stream;
    };

    webRTCService.onCallEnded = () => {
      this.cleanup();
    };

    webRTCService.onError = (error: string) => {
      console.error('WebRTC error:', error);
      this.cleanup();
    };
  }

  async initiateCall(receiverId: number, callType: CallType, receiverInfo?: any) {
    try {
      // Ensure SignalR is connected
      if (!signalRService.isConnected && authStore.token && authStore.user) {
        await signalRService.connect(authStore.token);
        await signalRService.authenticate(authStore.user.id);
      }
      console.log('authStore.user', authStore.user);
      console.log('receiverInfo', receiverInfo);
      // Set currentCall before initiating (caller side)
      // call_id will be updated when CallInitiated arrives
      if (authStore.user && receiverInfo) {
        this.currentCall = {
          call_id: '', // Updated when CallInitiated is received
          caller: {
            id: authStore.user.id,
            username: authStore.user.username,
            email: authStore.user.email,
            display_name: authStore.user.display_name,
            avatar_path: authStore.user.avatar_path,
            is_online: authStore.user.is_online,
            created_at: authStore.user.created_at,
            updated_at: authStore.user.updated_at,
          },
          receiver: receiverInfo,
          call_type: callType,
          status: 1, // Initiated
          start_time: new Date().toISOString(),
        };
        this.isRinging = true;
      }
      
      await webRTCService.initiateCall(receiverId, callType);
    } catch (error) {
      console.error('Failed to initiate call:', error);
      this.cleanup();
      throw error;
    }
  }

  async acceptCall() {
    if (this.currentCall) {
      await webRTCService.acceptCall({
        callId: this.currentCall.call_id,
        caller: this.currentCall.caller,
        receiver: this.currentCall.receiver,
        callType: this.currentCall.call_type as CallType,
        status: this.currentCall.status,
        startTime: this.currentCall.start_time,
      });
      this.isRinging = false;
      this.isInCall = true;
    }
  }

  async rejectCall() {
    if (this.currentCall) {
      await webRTCService.rejectCall(this.currentCall.call_id);
      this.cleanup();
    }
  }

  async endCall() {
    await webRTCService.endCall();
    this.cleanup();
  }

  private cleanup() {
    // Stop all media streams
    if (this.localStream) {
      this.localStream.getTracks().forEach((track) => {
        track.stop();
      });
    }
    if (this.remoteStream) {
      this.remoteStream.getTracks().forEach((track) => {
        track.stop();
      });
    }
    
    this.currentCall = null;
    this.isInCall = false;
    this.isRinging = false;
    this.localStream = null;
    this.remoteStream = null;
  }
}

export const callStore = new CallStore();
