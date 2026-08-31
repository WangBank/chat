import { useCallback, useEffect, useState } from 'react';
import { Button, Modal, Spin, Typography, message } from 'antd';
import { ReloadOutlined, SafetyCertificateOutlined } from '@ant-design/icons';
import { apiService, type EmailCodeCaptchaChallenge } from '../services/api.service';

export type EmailCodeCaptchaPurpose = 'registration' | 'change_email' | 'change_password';

export interface EmailCodeCaptchaResult {
  captcha_id: string;
  captcha_answer: number[];
}

interface EmailCodeCaptchaModalProps {
  open: boolean;
  purpose: EmailCodeCaptchaPurpose;
  email?: string;
  username?: string;
  onCancel: () => void;
  onVerified: (result: EmailCodeCaptchaResult) => void;
}

const symbolMeta: Record<string, { glyph: string; label: string; color: string }> = {
  circle: { glyph: '●', label: '圆点', color: '#1677ff' },
  triangle: { glyph: '▲', label: '三角', color: '#13a8a8' },
  square: { glyph: '■', label: '方块', color: '#722ed1' },
  diamond: { glyph: '◆', label: '菱形', color: '#d46b08' },
  star: { glyph: '★', label: '星形', color: '#d4a106' },
  plus: { glyph: '✚', label: '十字', color: '#eb2f96' },
  moon: { glyph: '☾', label: '月牙', color: '#597ef7' },
  flower: { glyph: '✿', label: '花形', color: '#cf1322' },
  sparkle: { glyph: '✦', label: '闪光', color: '#08979c' },
};

const metaFor = (symbol: string) => symbolMeta[symbol] ?? { glyph: '?', label: '图案', color: '#8c8c8c' };

export default function EmailCodeCaptchaModal({
  open,
  purpose,
  email,
  username,
  onCancel,
  onVerified,
}: EmailCodeCaptchaModalProps) {
  const [challenge, setChallenge] = useState<EmailCodeCaptchaChallenge>();
  const [selected, setSelected] = useState<number[]>([]);
  const [loading, setLoading] = useState(false);

  const loadChallenge = useCallback(async () => {
    setLoading(true);
    setSelected([]);
    try {
      const response = await apiService.createEmailCodeCaptcha({ purpose, email, username });
      if (!response.success || !response.data) {
        throw new Error(response.message || '图案校验获取失败');
      }
      setChallenge(response.data);
    } catch (error) {
      setChallenge(undefined);
      const requestError = error as { response?: { data?: { message?: string } }; message?: string };
      message.error(requestError.response?.data?.message || requestError.message || '图案校验获取失败');
    } finally {
      setLoading(false);
    }
  }, [email, purpose, username]);

  useEffect(() => {
    if (open) {
      void loadChallenge();
    } else {
      setChallenge(undefined);
      setSelected([]);
    }
  }, [loadChallenge, open]);

  const selectTile = (position: number) => {
    if (selected.includes(position) || selected.length >= 3) return;
    setSelected((current) => [...current, position]);
  };

  const selectedOrder = (position: number) => {
    const order = selected.indexOf(position);
    return order >= 0 ? order + 1 : null;
  };

  const submit = () => {
    if (!challenge || selected.length !== 3) return;
    onVerified({ captcha_id: challenge.captcha_id, captcha_answer: selected });
  };

  return (
    <Modal
      open={open}
      title={<span><SafetyCertificateOutlined style={{ color: '#1677ff', marginRight: 8 }} />安全校验</span>}
      onCancel={onCancel}
      footer={null}
      destroyOnHidden
      centered
      width={400}
    >
      <Typography.Paragraph type="secondary" style={{ marginTop: 4, marginBottom: 14 }}>
        为保护邮箱验证码，请按顺序点按下方图案。校验仅本次有效。
      </Typography.Paragraph>

      {loading || !challenge ? (
        <div style={{ minHeight: 244, display: 'grid', placeItems: 'center' }}>
          <Spin tip="正在生成安全校验" />
        </div>
      ) : (
        <>
          <div
            aria-label="需要依次点按的图案"
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 12,
              minHeight: 58,
              padding: '10px 12px',
              marginBottom: 16,
              borderRadius: 12,
              color: '#0f3a66',
              background: 'linear-gradient(120deg, #edf7ff 0%, #f6fbff 100%)',
              border: '1px solid #d4edff',
            }}
          >
            {challenge.target_sequence.map((symbol, index) => {
              const item = metaFor(symbol);
              return (
                <span key={`${symbol}-${index}`} style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
                  {index > 0 && <span style={{ color: '#8c96a3', fontSize: 16 }}>→</span>}
                  <span aria-label={item.label} style={{ color: item.color, fontSize: 28, lineHeight: 1 }}>{item.glyph}</span>
                </span>
              );
            })}
          </div>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 10,
              padding: 10,
              borderRadius: 16,
              background: '#f8fbff',
              border: '1px solid #e3eff8',
            }}
          >
            {challenge.tiles.map((tile) => {
              const item = metaFor(tile.symbol);
              const order = selectedOrder(tile.position);
              return (
                <button
                  key={tile.position}
                  type="button"
                  aria-label={`选择${item.label}${order ? `，第${order}个` : ''}`}
                  onClick={() => selectTile(tile.position)}
                  style={{
                    position: 'relative',
                    height: 68,
                    borderRadius: 12,
                    border: order ? '2px solid #1677ff' : '1px solid #dbe8f3',
                    color: item.color,
                    background: order ? '#e6f4ff' : '#fff',
                    cursor: order || selected.length >= 3 ? 'default' : 'pointer',
                    fontSize: 31,
                    transition: 'transform 120ms ease, border-color 120ms ease',
                  }}
                >
                  {item.glyph}
                  {order && (
                    <span
                      style={{
                        position: 'absolute',
                        top: -7,
                        right: -7,
                        display: 'grid',
                        placeItems: 'center',
                        width: 22,
                        height: 22,
                        borderRadius: '50%',
                        color: '#fff',
                        background: '#1677ff',
                        fontSize: 12,
                        fontWeight: 700,
                      }}
                    >
                      {order}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16 }}>
            <Button icon={<ReloadOutlined />} onClick={() => void loadChallenge()}>换一个图案</Button>
            <Button type="primary" disabled={selected.length !== 3} onClick={submit}>
              完成校验并发送
            </Button>
          </div>
        </>
      )}
    </Modal>
  );
}
