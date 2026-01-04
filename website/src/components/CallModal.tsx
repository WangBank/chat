import { Modal, Button, Space, Avatar } from 'antd';
import { PhoneOutlined, CloseOutlined } from '@ant-design/icons';
import { observer } from 'mobx-react-lite';
import { callStore } from '../stores/call.store';
import { authStore } from '../stores/auth.store';

const CallModal = observer(() => {
  const currentUserId = authStore.user?.id || 0;
  const caller = callStore.currentCall?.caller;
  const receiver = callStore.currentCall?.receiver;
  // 判断是否是呼叫方：当前用户是caller
  const isCaller = caller?.id === currentUserId;
  // 判断是否是接收方：当前用户是receiver
  const isReceiver = receiver?.id === currentUserId;
  
  // 只有在等待接听（isRinging）且不在通话中时显示Modal
  const shouldShowModal = callStore.isRinging && callStore.currentCall && !callStore.isInCall;

  const handleAccept = () => {
    callStore.acceptCall();
  };

  const handleReject = async () => {
    await callStore.rejectCall();
  };

  // 如果正在通话中，不显示Modal（CallPage会显示）
  if (callStore.isInCall) {
    return null;
  }
  
  // 如果不在等待接听状态，不显示Modal
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
        {/* 接收方：显示接听按钮 */}
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
              {callStore.currentCall?.call_type === 1 ? '语音通话' : '视频通话'}
            </p>
            <Space size="large">
              <Button
                type="primary"
                danger
                icon={<CloseOutlined />}
                size="large"
                onClick={handleReject}
              >
                拒绝
              </Button>
              <Button
                type="primary"
                icon={<PhoneOutlined />}
                size="large"
                onClick={handleAccept}
              >
                接听
              </Button>
            </Space>
          </>
        )}
        {/* 呼叫方：显示正在呼叫 */}
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
            <p style={{ color: '#999', marginBottom: 24 }}>正在呼叫...</p>
            <Button
              type="primary"
              danger
              icon={<CloseOutlined />}
              size="large"
              onClick={handleReject}
            >
              取消
            </Button>
          </>
        )}
      </div>
    </Modal>
  );
});

export default CallModal;

