import { ProCard } from '@ant-design/pro-components';
import { Alert, Card, Space, Tag, Typography } from 'antd';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';

export default function KnowledgeOpsPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('KnowledgeOpsPage requires an active admin session.');
  }

  const admin = session.admin;
  const hasKnowledgeAccess = admin.permissions.includes('rag:read') || admin.permissions.includes('kg:read');

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="knowledge-ops-page">
      <Alert
        showIcon
        type="info"
        message="Knowledge Ops 先落空壳，不做假数据"
        description="Ingestion queue、KG review split-view 与 retry / resolve 行为会在后续切片落地；当前页面只证明 shell、权限 metadata 与 placeholder 能真实挂载。"
      />

      <ProCard ghost gutter={[16, 16]} wrap>
        <ProCard colSpan={{ xs: 24, lg: 12 }}>
          <Card title="权限门槛" bordered={false}>
            <Space direction="vertical" size={10} style={{ width: '100%' }}>
              <Typography.Text>
                本模块接受 <Typography.Text code>rag:read</Typography.Text> 或 <Typography.Text code>kg:read</Typography.Text>。
              </Typography.Text>
              <Space wrap>
                <Tag color={hasKnowledgeAccess ? warmPaperAdmin.palette.success : warmPaperAdmin.palette.error}>
                  knowledge access {hasKnowledgeAccess ? 'enabled' : 'missing'}
                </Tag>
                <Tag>rag:read {admin.permissions.includes('rag:read') ? 'enabled' : 'missing'}</Tag>
                <Tag>kg:read {admin.permissions.includes('kg:read') ? 'enabled' : 'missing'}</Tag>
              </Space>
            </Space>
          </Card>
        </ProCard>

        <ProCard colSpan={{ xs: 24, lg: 12 }}>
          <Card title="后续真实模块范围" bordered={false}>
            <Space direction="vertical" size={8} style={{ width: '100%' }}>
              <Typography.Text>• ingestion queue 与 retry state</Typography.Text>
              <Typography.Text>• KG contradiction split-view 与 resolve flow</Typography.Text>
              <Typography.Text>• queue/deep-link state 复原与协作 handoff 上下文</Typography.Text>
            </Space>
          </Card>
        </ProCard>
      </ProCard>
    </Space>
  );
}
