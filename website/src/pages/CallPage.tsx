import { useEffect, useRef, useState } from 'react';
import { Button, Avatar, Space } from 'antd';
import {
  VideoCameraOutlined,
  CloseOutlined,
  AudioOutlined,
  AudioMutedOutlined,
} from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { callStore } from '../stores/call.store';
import { authStore } from '../stores/auth.store';
import { APP_CONFIG } from '../config/app.config';

const CallPage = observer(() => {
  const localVideoRef = useRef<HTMLVideoElement>(null);
  const remoteVideoRef = useRef<HTMLVideoElement>(null);
  const remoteAudioRef = useRef<HTMLAudioElement>(null);
  const [isMuted, setIsMuted] = useState(false);
  const [isVideoEnabled, setIsVideoEnabled] = useState(true);
  const [callDuration, setCallDuration] = useState(0);

  const currentUserId = authStore.user?.id || 0;
  const caller = callStore.currentCall?.caller;
  const receiver = callStore.currentCall?.receiver;
  const isCaller = caller?.id === currentUserId;
  const callType = callStore.currentCall?.call_type || 1; // 1: 语音, 2: 视频
  const isVideoCall = callType === 2;

  useEffect(() => {
    // 设置视频流
    if (callStore.localStream && localVideoRef.current) {
      localVideoRef.current.srcObject = callStore.localStream;
    }
    if (callStore.remoteStream) {
      if (remoteVideoRef.current && isVideoCall) {
        remoteVideoRef.current.srcObject = callStore.remoteStream;
      }
      if (remoteAudioRef.current) {
        remoteAudioRef.current.srcObject = callStore.remoteStream;
      }
    }

    // 计算通话时长
    let durationInterval: ReturnType<typeof setInterval> | null = null;
    if (callStore.isInCall && callStore.currentCall) {
      const startTime = new Date(callStore.currentCall.start_time).getTime();
      durationInterval = setInterval(() => {
        const now = Date.now();
        const duration = Math.floor((now - startTime) / 1000);
        setCallDuration(duration);
      }, 1000);
    }

    return () => {
      if (durationInterval) {
        clearInterval(durationInterval);
      }
    };
  }, [callStore.localStream, callStore.remoteStream, callStore.isInCall, callStore.currentCall, isVideoCall]);

  const handleMute = () => {
    if (callStore.localStream) {
      const audioTracks = callStore.localStream.getAudioTracks();
      audioTracks.forEach((track) => {
        track.enabled = isMuted;
      });
      setIsMuted(!isMuted);
    }
  };

  const handleToggleVideo = () => {
    if (callStore.localStream && isVideoCall) {
      const videoTracks = callStore.localStream.getVideoTracks();
      videoTracks.forEach((track) => {
        track.enabled = isVideoEnabled;
      });
      setIsVideoEnabled(!isVideoEnabled);
    }
  };

  const handleEndCall = async () => {
    await callStore.endCall();
    setIsMuted(false);
    setIsVideoEnabled(true);
    setCallDuration(0);
  };

  const formatDuration = (seconds: number) => {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
      return `${hours}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    return `${minutes}:${secs.toString().padStart(2, '0')}`;
  };

  const getAvatarUrl = (avatarPath?: string) => {
    if (avatarPath) {
      return `${APP_CONFIG.API_BASE_URL}${avatarPath}?t=${Date.now()}`;
    }
    return undefined;
  };

  const otherUser = isCaller ? receiver : caller;

  // CallPage只在通话中时显示，等待接听时由CallModal显示
  if (!callStore.isInCall) {
    return null;
  }

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: isVideoCall ? '#000' : 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        zIndex: 2000,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        color: '#fff',
      }}
    >
      {/* 视频通话：显示远程视频 */}
      {isVideoCall && callStore.isInCall && (
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          <video
            ref={remoteVideoRef}
            autoPlay
            playsInline
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'contain',
            }}
          />
        </div>
      )}

      {/* 视频通话：显示本地视频 */}
      {isVideoCall && callStore.isInCall && (
        <div
          style={{
            position: 'absolute',
            bottom: 120,
            right: 20,
            width: 200,
            height: 150,
            borderRadius: 8,
            overflow: 'hidden',
            border: '2px solid #fff',
            background: '#000',
          }}
        >
          <video
            ref={localVideoRef}
            autoPlay
            playsInline
            muted
            style={{
              width: '100%',
              height: '100%',
              objectFit: 'cover',
            }}
          />
        </div>
      )}

      {/* 语音通话：显示音频播放器（隐藏） */}
      {!isVideoCall && callStore.isInCall && (
        <audio ref={remoteAudioRef} autoPlay playsInline />
      )}

      {/* 用户信息 */}
      <div
        style={{
          textAlign: 'center',
          marginBottom: 40,
          zIndex: 1,
        }}
      >
        <Avatar
          size={120}
          src={getAvatarUrl(otherUser?.avatar_path)}
          style={{ marginBottom: 24, border: '4px solid #fff' }}
        >
          {otherUser?.display_name?.[0] || otherUser?.username?.[0]}
        </Avatar>
        <h2 style={{ color: '#fff', marginBottom: 8, fontSize: 28 }}>
          {otherUser?.display_name || otherUser?.username}
        </h2>
        {callStore.isRinging && !callStore.isInCall && (
          <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: 16 }}>
            {isCaller ? '正在呼叫...' : '来电中...'}
          </p>
        )}
        {callStore.isInCall && (
          <p style={{ color: 'rgba(255,255,255,0.8)', fontSize: 16 }}>
            {formatDuration(callDuration)}
          </p>
        )}
      </div>

      {/* 控制按钮 */}
      <Space size="large" style={{ zIndex: 1 }}>
        {/* 静音按钮 */}
        {callStore.isInCall && (
          <Button
            type="primary"
            shape="circle"
            size="large"
            icon={isMuted ? <AudioMutedOutlined /> : <AudioOutlined />}
            onClick={handleMute}
            danger={isMuted}
            style={{
              width: 60,
              height: 60,
              fontSize: 24,
            }}
          />
        )}

        {/* 视频开关（仅视频通话） */}
        {callStore.isInCall && isVideoCall && (
          <Button
            type="primary"
            shape="circle"
            size="large"
            icon={<VideoCameraOutlined />}
            onClick={handleToggleVideo}
            danger={!isVideoEnabled}
            style={{
              width: 60,
              height: 60,
              fontSize: 24,
            }}
          />
        )}

        {/* 挂断按钮 */}
        <Button
          type="primary"
          shape="circle"
          size="large"
          icon={<CloseOutlined />}
          onClick={handleEndCall}
          danger
          style={{
            width: 60,
            height: 60,
            fontSize: 24,
          }}
        />
      </Space>
    </div>
  );
});

export default CallPage;

