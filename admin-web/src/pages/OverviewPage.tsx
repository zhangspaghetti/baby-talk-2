import { ProCard } from '@ant-design/pro-components';
import { Alert, Card, Space, Tag, Typography } from 'antd';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';

export default function OverviewPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('OverviewPage requires an active admin session.');
  }

  const admin = session.admin;

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="overview-page">
      <Alert
        showIcon
        type="info"
        message="Overview shell seed 已接线"
        description="这里先保留 truthful placeholder，不伪造 prioritized inbox、健康分数或跨域 KPI；后续切片会把真实待处理工作流挂进来。"
      />

      <ProCard ghost gutter={[16, 16]} wrap>
        <ProCard colSpan={{ xs: 24, lg: 14 }}>
          <Card title="当前真相源" bordered={false}>
            <Space direction="vertical" size={10} style={{ width: '100%' }}>
              <Typography.Text>
                当前登录身份仍以后端 <Typography.Text code>/api/admin/me</Typography.Text> 为准；本页只回显允许暴露的
                username / roles / permission codes。
              </Typography.Text>
              <Space wrap>
                <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
                <Tag color={warmPaperAdmin.palette.success}>roles: {admin.roles.length}</Tag>
                <Tag color={warmPaperAdmin.palette.accentDark}>permissions: {admin.permissions.length}</Tag>
              </Space>
              <Space wrap>
                {admin.roles.map((role) => (
                  <Tag key={role}>{role}</Tag>
                ))}
              </Space>
            </Space>
          </Card>
        </ProCard>

        <ProCard colSpan={{ xs: 24, lg: 10 }}>
          <Card title="后续会补上的真实内容" bordered={false}>
            <Space direction="vertical" size={8} style={{ width: '100%' }}>
              <Typography.Text>• prioritized inbox 与 domain counts</Typography.Text>
              <Typography.Text>• stale/freshness strip 与 recent activity</Typography.Text>
              <Typography.Text>• 角色感知 default landing 的可视化解释</Typography.Text>
            </Space>
          </Card>
        </ProCard>
      </ProCard>
    </Space>
  );
}
