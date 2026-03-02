import { Modal, Button, Space, Avatar } from 'antd';
import { PhoneOutlined, CloseOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { callStore } from '../stores/call.store';
import { authStore } from '../stores/auth.store';

const CallModal = observer(() => {
  const currentUserId = authStore.user?.id || 0;
  const caller = callStore.currentCall?.caller;
  const receiver = callStore.currentCall?.receiver;
  // Determine if current user is caller
  const isCaller = caller?.id === currentUserId;
  // Determine if current user is receiver
  const isReceiver = receiver?.id === currentUserId;
  
  // Show modal only when ringing and not already in call
  const shouldShowModal = callStore.isRinging && callStore.currentCall && !callStore.isInCall;

  const handleAccept = () => {
    callStore.acceptCall();
  };

  const handleReject = async () => {
    await callStore.rejectCall();
  };

  // Hide modal while in active call (CallPage handles it)
  if (callStore.isInCall) {
    return null;
  }
  
  // Hide modal when not ringing
  if (!shouldShowModal) {
    return null;
  }

  return (
    <Modal
      open={shouldShowModal}
      footer={null}
      closable={false}
      centered
      width={400}
    >
      <div style={{ textAlign: 'center', padding: '24px 0' }}>
        {/* Receiver: show accept/reject actions */}
        {isReceiver && (
          <>
            <Avatar
              size={80}
              src={caller?.avatar_path}
              style={{ marginBottom: 16 }}
            >
              {caller?.display_name?.[0] || caller?.username[0]}
            </Avatar>
            <h3>{caller?.display_name || caller?.username}</h3>
            <p style={{ color: '#999', marginBottom: 24 }}>
              {callStore.currentCall?.call_type === 1 ? 'Voice call' : 'Video call'}
            </p>
            <Space size="large">
              <Button
                type="primary"
                danger
                icon={<CloseOutlined />}
                size="large"
                onClick={handleReject}
              >
                Reject
              </Button>
              <Button
                type="primary"
                icon={<PhoneOutlined />}
                size="large"
                onClick={handleAccept}
              >
                Accept
              </Button>
            </Space>
          </>
        )}
        {/* Caller: show calling state */}
        {isCaller && (
          <>
            <Avatar
              size={80}
              src={receiver?.avatar_path}
              style={{ marginBottom: 16 }}
            >
              {receiver?.display_name?.[0] || receiver?.username[0]}
            </Avatar>
            <h3>{receiver?.display_name || receiver?.username}</h3>
            <p style={{ color: '#999', marginBottom: 24 }}>Calling...</p>
            <Button
              type="primary"
              danger
              icon={<CloseOutlined />}
              size="large"
              onClick={handleReject}
            >
              Cancel
            </Button>
          </>
        )}
      </div>
    </Modal>
  );
});

export default CallModal;

