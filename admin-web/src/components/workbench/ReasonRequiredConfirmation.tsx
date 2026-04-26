import { Alert, Input, Modal, Space, Typography } from 'antd';
import { useEffect, useState } from 'react';
import { ApiError } from '../../lib/authClient';

type ReasonRequiredConfirmationProps = {
  open: boolean;
  title: string;
  subject: string;
  description: string;
  confirmText: string;
  onCancel: () => void;
  onConfirm: (reason: string) => Promise<void>;
};

export function ReasonRequiredConfirmation({
  open,
  title,
  subject,
  description,
  confirmText,
  onCancel,
  onConfirm,
}: ReasonRequiredConfirmationProps) {
  const [reason, setReason] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setReason('');
      setSubmitting(false);
      setErrorMessage(null);
      return;
    }
    setErrorMessage(null);
  }, [open]);

  const handleSubmit = async () => {
    const normalizedReason = reason.trim();
    if (!normalizedReason) {
      setErrorMessage('请输入禁用原因。');
      return;
    }

    setSubmitting(true);
    setErrorMessage(null);
    try {
      await onConfirm(normalizedReason);
      setReason('');
    } catch (error) {
      setErrorMessage(toReadableError(error));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Modal
      destroyOnHidden
      open={open}
      title={title}
      okText={confirmText}
      cancelText="取消"
      okButtonProps={{ danger: true, loading: submitting }}
      cancelButtonProps={{ disabled: submitting }}
      onCancel={onCancel}
      onOk={() => void handleSubmit()}
    >
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Alert
          showIcon
          type={errorMessage ? 'error' : 'warning'}
          message={subject}
          description={errorMessage ?? description}
          data-testid="disable-confirmation-state"
        />
        <div>
          <Typography.Text strong>禁用原因</Typography.Text>
          <Input.TextArea
            autoSize={{ minRows: 3, maxRows: 6 }}
            data-testid="disable-reason-input"
            maxLength={240}
            placeholder="例如：admin_review / abuse_report / duplicate_account"
            value={reason}
            onChange={(event) => setReason(event.target.value)}
          />
          <Typography.Text type="secondary">reason 会写入 consent audit trail，并作为重复禁用的对账线索。</Typography.Text>
        </div>
      </Space>
    </Modal>
  );
}

function toReadableError(error: unknown): string {
  if (error instanceof ApiError) {
    return `${error.message}（${error.code}）`;
  }
  if (error instanceof Error) {
    return error.message;
  }
  return '发生未预期错误。';
}

export default ReasonRequiredConfirmation;
