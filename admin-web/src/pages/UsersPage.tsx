import { ProCard } from '@ant-design/pro-components';
import { Alert, Card, Space, Tag, Typography } from 'antd';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';

export default function UsersPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('UsersPage requires an active admin session.');
  }

  const admin = session.admin;

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="users-page">
      <Alert
        showIcon
        type="warning"
        message="Users 工作面仍是 placeholder"
        description="本任务只交付路由、主题和 shell seed；不会伪造 account table、drawer 详情或 destructive actions。"
      />

      <ProCard ghost gutter={[16, 16]} wrap>
        <ProCard colSpan={{ xs: 24, lg: 12 }}>
          <Card title="准入条件" bordered={false}>
            <Space direction="vertical" size={10} style={{ width: '100%' }}>
              <Typography.Text>
                Route catalog 已声明本模块需要 <Typography.Text code>users:read</Typography.Text>。
              </Typography.Text>
              <Space wrap>
                <Tag color={admin.permissions.includes('users:read') ? warmPaperAdmin.palette.success : warmPaperAdmin.palette.error}>
                  users:read {admin.permissions.includes('users:read') ? 'enabled' : 'missing'}
                </Tag>
                <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
              </Space>
            </Space>
          </Card>
        </ProCard>

        <ProCard colSpan={{ xs: 24, lg: 12 }}>
          <Card title="后续真实模块范围" bordered={false}>
            <Space direction="vertical" size={8} style={{ width: '100%' }}>
              <Typography.Text>• consumer accounts 列表 / 筛选 / 分页</Typography.Text>
              <Typography.Text>• 独立 detail surface 与 consent/session 证据</Typography.Text>
              <Typography.Text>• 带原因的禁用动作与 audit trail</Typography.Text>
            </Space>
          </Card>
        </ProCard>
      </ProCard>
    </Space>
  );
}
