import { Alert, Button, Card, Collapse, Space, Tag, Typography } from 'antd';
import { useCallback, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router-dom';
import { hasKnownAdminPermission } from '../app/access';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';
import { IngestionSurface } from '../components/workbench/IngestionSurface';
import { KgSurface } from '../components/workbench/KgSurface';
import { PalaceRagSurface } from '../components/workbench/PalaceRagSurface';
import { type KnowledgeOpsView } from '../lib/knowledgeOpsClient';
import {
  type KnowledgeQueryPatch,
  defaultStatusForView,
  formatTimestamp,
  patchKnowledgeQuery,
  readCanonicalStatus,
  readQueryState as readKnowledgeQueryState,
  readStatusBadge,
} from '../lib/knowledgeOpsUtils';

export default function KnowledgeOpsPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('KnowledgeOpsPage requires an active admin session.');
  }

  const admin = session.admin;
  const canReadIngestion = hasKnownAdminPermission(admin, 'rag:read');
  const canWriteIngestion = hasKnownAdminPermission(admin, 'rag:write');
  const canReadKg = hasKnownAdminPermission(admin, 'kg:read');
  const canReviewKg = hasKnownAdminPermission(admin, 'kg:review');
  const accessibleViews = useMemo<KnowledgeOpsView[]>(() => {
    const nextViews: KnowledgeOpsView[] = [];
    if (canReadIngestion) {
      nextViews.push('ingestion');
      nextViews.push('palace-rag');
    }
    if (canReadKg) {
      nextViews.push('kg-review');
    }
    return nextViews;
  }, [canReadIngestion, canReadKg]);

  const [searchParams, setSearchParams] = useSearchParams();
  const query = useMemo(() => readKnowledgeQueryState(searchParams, accessibleViews), [accessibleViews, searchParams]);
  const needsCanonicalQuery =
    !searchParams.has('view') || !searchParams.has('status') || query.viewWasNormalized || query.statusWasNormalized;
  const contextSummary = searchParams.toString() || `view=${query.view}&status=${readCanonicalStatus(query)}`;

  const handlePatchQuery = useCallback(
    (patch: KnowledgeQueryPatch) => patchKnowledgeQuery(searchParams, setSearchParams, patch),
    [searchParams, setSearchParams],
  );

  useEffect(() => {
    if (!needsCanonicalQuery) {
      return;
    }

    const nextParams = new URLSearchParams(searchParams);
    nextParams.set('view', query.view);
    nextParams.set('status', readCanonicalStatus(query));
    setSearchParams(nextParams, { replace: true });
  }, [needsCanonicalQuery, query, searchParams, setSearchParams]);

  const canShowIngestionSurface = query.view === 'ingestion';
  const canShowKgSurface = query.view === 'kg-review';
  const canShowPalaceRagSurface = query.view === 'palace-rag';

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="knowledge-ops-page">
      <Space direction="vertical" size={4}>
        <Typography.Title level={3} style={{ marginBottom: 0 }}>
          Knowledge Ops Workbench
        </Typography.Title>
        <Typography.Paragraph type="secondary" style={{ marginBottom: 0 }}>
          单一路由 `/knowledge-ops` 挂三个真实工作面：ingestion queue、KG contradiction review 与 Palace RAG ops。view /
          status / selected 全部以 URL query 为真相源，失败态会留在当前页面而不是把 operator 弹走。
        </Typography.Paragraph>
      </Space>

      <Card size="small" title="Workbench surfaces">
        <Space wrap>
          {canReadIngestion ? (
            <Button
              data-testid="knowledge-view-ingestion"
              type={query.view === 'ingestion' ? 'primary' : 'default'}
              onClick={() =>
                handlePatchQuery({
                  view: 'ingestion',
                  status: defaultStatusForView('ingestion'),
                  selected: undefined,
                })
              }
            >
              Ingestion
            </Button>
          ) : null}
          {canReadIngestion ? (
            <Button
              data-testid="knowledge-view-palace-rag"
              type={query.view === 'palace-rag' ? 'primary' : 'default'}
              onClick={() =>
                handlePatchQuery({
                  view: 'palace-rag',
                  status: defaultStatusForView('palace-rag'),
                  selected: undefined,
                })
              }
            >
              Palace RAG
            </Button>
          ) : null}
          {canReadKg ? (
            <Button
              data-testid="knowledge-view-kg-review"
              type={query.view === 'kg-review' ? 'primary' : 'default'}
              onClick={() =>
                handlePatchQuery({
                  view: 'kg-review',
                  status: defaultStatusForView('kg-review'),
                  selected: undefined,
                })
              }
            >
              KG Review
            </Button>
          ) : null}
        </Space>
      </Card>

      <Collapse
        defaultActiveKey={[]}
        destroyInactivePanel={false}
        items={[
          {
            key: '1',
            label: '管理员权限与状态',
            children: (
              <Card size="small" title="Current admin / capabilities" bordered={false} styles={{ body: { padding: 0 } }}>
                <Space direction="vertical" size={10} style={{ width: '100%' }}>
                  <Space wrap>
                    <Tag color={warmPaperAdmin.palette.info}>user: {admin.username}</Tag>
                    <Tag color={canReadIngestion ? 'success' : 'default'}>rag:read {canReadIngestion ? 'enabled' : 'missing'}</Tag>
                    <Tag color={canWriteIngestion ? 'success' : 'default'}>rag:write {canWriteIngestion ? 'enabled' : 'missing'}</Tag>
                    <Tag color={canReadKg ? 'success' : 'default'}>kg:read {canReadKg ? 'enabled' : 'missing'}</Tag>
                    <Tag color={canReviewKg ? 'success' : 'default'}>kg:review {canReviewKg ? 'enabled' : 'missing'}</Tag>
                    <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
                    <Tag>access expires: {formatTimestamp(session.accessTokenExpiresAt)}</Tag>
                  </Space>
                  <Space wrap>
                    <Tag color={query.viewWasNormalized ? 'warning' : 'processing'}>
                      view: {query.rawView ? (query.viewWasNormalized ? `${query.rawView} → ${query.view}` : query.rawView) : query.view}
                    </Tag>
                    <Tag color={query.statusWasNormalized ? 'warning' : 'processing'}>
                      status: {readStatusBadge(query)}
                    </Tag>
                    <Tag color={query.selected ? 'warning' : 'default'}>selected: {query.selected ?? 'none'}</Tag>
                  </Space>
                  <Typography.Text code>{contextSummary}</Typography.Text>
                </Space>
              </Card>
            ),
          },
        ]}
      />

      {query.viewWasNormalized ? (
        <Alert
          showIcon
          type="warning"
          data-testid="knowledge-view-normalized"
          message="请求的 surface 已归一化到当前账号可访问的工作面"
          description={`原始 query view=${query.rawView ?? 'missing'} 仍保留在 URL 里供排查；当前按 ${query.view} 渲染。`}
        />
      ) : null}

      {query.statusWasNormalized ? (
        <Alert
          showIcon
          type="warning"
          data-testid="knowledge-status-normalized"
          message="非法状态过滤已归一化为安全默认值"
          description={`原始 query status=${query.rawStatus ?? 'missing'} 已按当前 surface 改写为 ${readCanonicalStatus(query)}。`}
        />
      ) : null}

      {!canWriteIngestion && canShowIngestionSurface ? (
        <Alert
          showIcon
          type="info"
          data-testid="knowledge-ingestion-readonly-note"
          message="当前账号只有 rag:read"
          description="可以查看 ingestion queue / detail / diagnostics，但 upload / retry 不会泄漏到只读界面。"
        />
      ) : null}

      {!canWriteIngestion && canShowPalaceRagSurface ? (
        <Alert
          showIcon
          type="info"
          data-testid="knowledge-palace-rag-readonly-note"
          message="当前账号只有 rag:read"
          description="可以查看 bridge review、trace samples 与 projection status，但 approve / reject 不会泄漏到只读界面。"
        />
      ) : null}

      {!canReviewKg && canShowKgSurface ? (
        <Alert
          showIcon
          type="info"
          data-testid="knowledge-kg-readonly-note"
          message="当前账号只有 kg:read"
          description="可以查看 contradiction detail / notifications，但 resolve / mark-read 操作被收口。"
        />
      ) : null}

      {canShowIngestionSurface ? (
        <IngestionSurface
          query={query}
          onPatchQuery={handlePatchQuery}
          canRead={canReadIngestion}
          canWrite={canWriteIngestion}
          needsCanonicalQuery={needsCanonicalQuery}
        />
      ) : null}

      {canShowPalaceRagSurface ? (
        <PalaceRagSurface
          query={query}
          onPatchQuery={handlePatchQuery}
          canRead={canReadIngestion}
          canWrite={canWriteIngestion}
          needsCanonicalQuery={needsCanonicalQuery}
        />
      ) : null}

      {canShowKgSurface ? (
        <KgSurface
          query={query}
          onPatchQuery={handlePatchQuery}
          canRead={canReadKg}
          canReview={canReviewKg}
          needsCanonicalQuery={needsCanonicalQuery}
        />
      ) : null}
    </Space>
  );
}
