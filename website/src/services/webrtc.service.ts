import { Room, RoomEvent } from 'livekit-client';
import { apiService, type UserSummaryResponse } from './api.service';
import { signalRService } from './signalr.service';

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
  private room: Room | null = null;
  private localStream: MediaStream | null = null;
  private remoteStream: MediaStream | null = null;
  private currentCall: Call | null = null;
  private isInCall = false;
  private isDisconnecting = false;

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

  async initiateCall(receiverId: number, callType: CallType): Promise<void> {
    await signalRService.initiateCall({ receiver_id: receiverId, call_type: callType });
  }

  setCurrentCall(call: Call): void {
    this.currentCall = call;
  }

  async startCallAsCaller(call: Call): Promise<void> {
    await this.connectToLiveKit(call);
  }

  async acceptCall(call: Call): Promise<void> {
    this.currentCall = call;
    await signalRService.answerCall(call.callId, true);
    await this.connectToLiveKit(call);
  }

  async rejectCall(callId: string): Promise<void> {
    await signalRService.answerCall(callId, false);
    await this.disconnectFromLiveKit();
  }

  async endCall(): Promise<void> {
    const callId = this.currentCall?.callId;
    await this.disconnectFromLiveKit();
    if (callId) {
      await signalRService.endCall(callId);
    }
  }

  async disconnectFromLiveKit(): Promise<void> {
    const room = this.room;
    this.isDisconnecting = true;
    this.room = null;
    this.isInCall = false;
    this.localStream = null;
    this.remoteStream = null;
    if (room) {
      room.disconnect();
    }
    this.isDisconnecting = false;
  }

  cleanup(): void {
    void this.disconnectFromLiveKit();
    this.currentCall = null;
  }

  async setMuted(muted: boolean): Promise<void> {
    await this.room?.localParticipant.setMicrophoneEnabled(!muted);
  }

  async setCameraEnabled(enabled: boolean): Promise<void> {
    if (this.currentCall?.callType !== CallType.Video) return;
    await this.room?.localParticipant.setCameraEnabled(enabled);
    this.refreshStreams();
  }

  private async connectToLiveKit(call: Call): Promise<void> {
    await this.disconnectFromLiveKit();
    this.currentCall = call;

    const response = await apiService.createLiveKitToken(call.callId);
    if (!response.success || !response.data) {
      throw new Error(response.message || '媒体服务暂不可用');
    }

    await signalRService.joinCall(call.callId);
    // Calls are strictly one-to-one. Keep both subscriptions active so a remote
    // track is immediately available to the CallPage MediaStream renderer.
    const room = new Room({ adaptiveStream: false, dynacast: false });
    this.room = room;
    this.bindRoomEvents(room);

    try {
      await room.connect(response.data.url, response.data.token);
      await room.localParticipant.setMicrophoneEnabled(true);
      if (call.callType === CallType.Video) {
        await room.localParticipant.setCameraEnabled(true);
      }
      this.isInCall = true;
      this.refreshStreams();
    } catch (error) {
      await this.disconnectFromLiveKit();
      const message = error instanceof Error ? error.message : '连接媒体服务失败';
      this.onError?.(message);
      throw error;
    }
  }

  private bindRoomEvents(room: Room): void {
    const refresh = () => this.refreshStreams();
    room.on(RoomEvent.TrackSubscribed, refresh);
    room.on(RoomEvent.TrackUnsubscribed, refresh);
    room.on(RoomEvent.LocalTrackPublished, refresh);
    room.on(RoomEvent.LocalTrackUnpublished, refresh);
    room.on(RoomEvent.ParticipantConnected, refresh);
    room.on(RoomEvent.ParticipantDisconnected, refresh);
    room.on(RoomEvent.Disconnected, () => {
      if (this.room !== room || this.isDisconnecting) return;
      this.isInCall = false;
      this.onError?.('媒体连接已断开');
    });
  }

  private refreshStreams(): void {
    const room = this.room;
    if (!room) return;

    const localTracks = [...room.localParticipant.trackPublications.values()]
      .map((publication) => publication.track?.mediaStreamTrack)
      .filter((track): track is MediaStreamTrack => Boolean(track));
    const remoteTracks = [...room.remoteParticipants.values()]
      .flatMap((participant) => [...participant.trackPublications.values()])
      .map((publication) => publication.track?.mediaStreamTrack)
      .filter((track): track is MediaStreamTrack => Boolean(track));

    this.localStream = localTracks.length > 0 ? new MediaStream(localTracks) : null;
    this.remoteStream = remoteTracks.length > 0 ? new MediaStream(remoteTracks) : null;
    if (this.localStream) this.onLocalStream?.(this.localStream);
    if (this.remoteStream) this.onRemoteStream?.(this.remoteStream);
  }
}

export const webRTCService = new WebRTCService();
