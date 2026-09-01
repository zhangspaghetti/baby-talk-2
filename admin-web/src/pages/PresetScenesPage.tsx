import {
  FormOutlined,
  HistoryOutlined,
  ReloadOutlined,
  SaveOutlined,
} from '@ant-design/icons';
import { ProTable, type ProColumns } from '@ant-design/pro-components';
import {
  Alert,
  Button,
  Card,
  Drawer,
  Empty,
  Form,
  Input,
  InputNumber,
  Modal,
  Popconfirm,
  Space,
  Spin,
  Switch,
  Table,
  Tag,
  Typography,
  type FormInstance,
} from 'antd';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { isSuperAdmin } from '../app/access';
import { ApiError, hasPermission, toApiError } from '../lib/authClient';
import type { ApiError as ApiErrorType } from '../lib/authClient';
import {
  presetScenesClient,
  type PresetSceneDetailView,
  type PresetSceneDraftView,
  type PresetSceneDraftWrite,
  type PresetScenePublishedView,
  type PresetSceneSummaryView,
} from '../lib/presetScenesClient';
import { useAuth } from '../auth/auth-provider';

type DraftFormValues = Omit<PresetSceneDraftWrite, 'lockVersion'>;

type MutationState =
  | { phase: 'idle' }
  | { phase: 'pending'; operation: string }
  | { phase: 'success'; message: string }
  | { phase: 'error'; operation: string; error: ApiErrorType };

type ConflictState = {
  operation: string;
  local: DraftFormValues;
  server: PresetSceneDraftView | PresetSceneDetailView;
};

const EMPTY_FORM_VALUES: DraftFormValues = {
  title: '',
  summary: '',
  sceneTag: '',
  coachTip: '',
  sortOrder: 0,
  generationBrief: '',
  enabled: true,
};

const DRAFT_COMPARISON_FIELDS: Array<keyof DraftFormValues> = [
  'title',
  'summary',
  'sceneTag',
  'coachTip',
  'sortOrder',
  'generationBrief',
  'enabled',
];

const FORM_FIELDS: Array<keyof DraftFormValues> = [
  'title',
  'summary',
  'sceneTag',
  'coachTip',
  'sortOrder',
  'generationBrief',
  'enabled',
];

export default function PresetScenesPage() {
  const { session } = useAuth();
  if (!session) {
    throw new Error('PresetScenesPage requires an active admin session.');
  }

  const admin = session.admin;
  const canWrite = isSuperAdmin(admin) || hasPermission(admin, 'practice:write');
  const canPublish = isSuperAdmin(admin) || hasPermission(admin, 'practice:publish');
  const [form] = Form.useForm<DraftFormValues>();
  const formSceneIdRef = useRef<string | null>(null);
  const sceneRequestIdRef = useRef(0);
  const historyRequestIdRef = useRef(0);

  const [scenes, setScenes] = useState<PresetSceneSummaryView[]>([]);
  const [listLoading, setListLoading] = useState(false);
  const [listError, setListError] = useState<ApiError | null>(null);
  const [reloadNonce, setReloadNonce] = useState(0);
  const [selectedSceneId, setSelectedSceneId] = useState<string | null>(null);
  const [selectedScene, setSelectedScene] = useState<PresetSceneDetailView | null>(null);
  const [sceneLoading, setSceneLoading] = useState(false);
  const [sceneError, setSceneError] = useState<ApiError | null>(null);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [formDirty, setFormDirty] = useState(false);
  const [mutation, setMutation] = useState<MutationState>({ phase: 'idle' });
  const [conflict, setConflict] = useState<ConflictState | null>(null);
  const [historySceneId, setHistorySceneId] = useState<string | null>(null);
  const [historyOpen, setHistoryOpen] = useState(false);
  const [history, setHistory] = useState<PresetScenePublishedView[]>([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState<ApiError | null>(null);

  useEffect(() => {
    let cancelled = false;
    setListLoading(true);
    setListError(null);

    void presetScenesClient
      .listScenes()
      .then((nextScenes) => {
        if (!cancelled) {
          setScenes(nextScenes);
        }
      })
      .catch((error) => {
        if (!cancelled) {
          setListError(toApiError(error));
        }
      })
      .finally(() => {
        if (!cancelled) {
          setListLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [reloadNonce]);

  const loadScene = useCallback(
    async (presetSceneId: string, preserveForm: boolean): Promise<PresetSceneDetailView | null> => {
      const requestId = sceneRequestIdRef.current + 1;
      sceneRequestIdRef.current = requestId;
      setSceneLoading(true);
      setSceneError(null);

      try {
        const detail = await presetScenesClient.getScene(presetSceneId);
        if (requestId !== sceneRequestIdRef.current) {
          return null;
        }
        setSelectedScene(detail);
        if (!preserveForm) {
          applyFormValues(form, toFormValues(detail.draft ?? detail));
          setFormDirty(false);
          formSceneIdRef.current = presetSceneId;
        }
        return detail;
      } catch (error) {
        if (requestId === sceneRequestIdRef.current) {
          setSceneError(toApiError(error));
        }
        return null;
      } finally {
        if (requestId === sceneRequestIdRef.current) {
          setSceneLoading(false);
        }
      }
    },
    [form],
  );

  const openScene = useCallback(
    async (presetSceneId: string) => {
      const preserveForm =
        formSceneIdRef.current === presetSceneId && formDirty;
      setDrawerOpen(true);
      setSelectedSceneId(presetSceneId);
      setConflict(null);
      setMutation({ phase: 'idle' });
      if (!preserveForm) {
        form.resetFields();
        applyFormValues(form, EMPTY_FORM_VALUES);
        setFormDirty(false);
      }
      setSelectedScene(null);
      await loadScene(presetSceneId, preserveForm);
    },
    [form, formDirty, loadScene],
  );

  const loadHistory = useCallback(async (presetSceneId: string) => {
    const requestId = historyRequestIdRef.current + 1;
    historyRequestIdRef.current = requestId;
    setHistoryLoading(true);
    setHistoryError(null);
    try {
      const nextHistory = await presetScenesClient.versions(presetSceneId);
      if (requestId === historyRequestIdRef.current) {
        setHistory(nextHistory);
      }
    } catch (error) {
      if (requestId === historyRequestIdRef.current) {
        setHistoryError(toApiError(error));
      }
    } finally {
      if (requestId === historyRequestIdRef.current) {
        setHistoryLoading(false);
      }
    }
  }, []);

  const openHistory = useCallback(
    async (presetSceneId: string) => {
      setHistorySceneId(presetSceneId);
      setHistoryOpen(true);
      setHistory([]);
      await loadHistory(presetSceneId);
    },
    [loadHistory],
  );

  const reloadAfterMutation = () => {
    setReloadNonce((value) => value + 1);
  };

  const handleConflict = async (operation: string, apiError: ApiError) => {
    setMutation({ phase: 'error', operation, error: apiError });
    if (!selectedSceneId || apiError.code !== 'practice_draft_version_conflict') {
      return;
    }

    const local = readFormValues(form.getFieldsValue(true));
    const refreshed = await loadScene(selectedSceneId, true);
    if (refreshed) {
      setConflict({
        operation,
        local,
        server: refreshed.draft ?? refreshed,
      });
    }
  };

  const handleCreateDraft = async () => {
    if (!canWrite || !selectedSceneId) {
      return;
    }

    let values: DraftFormValues;
    try {
      values = await form.validateFields();
    } catch {
      return;
    }

    const write = toDraftWrite(values, 0);
    setMutation({ phase: 'pending', operation: '创建草稿' });
    try {
      const draft = await presetScenesClient.createDraft(selectedSceneId, write);
      setSelectedScene((current) => (current ? { ...current, draft } : current));
      applyFormValues(form, toFormValues(draft));
      setFormDirty(false);
      formSceneIdRef.current = selectedSceneId;
      setConflict(null);
      setMutation({ phase: 'success', message: '草稿已创建。' });
      reloadAfterMutation();
    } catch (error) {
      await handleConflict('创建草稿', toApiError(error));
    }
  };

  const handleSave = async (values: DraftFormValues) => {
    if (!canWrite || !selectedSceneId || !selectedScene) {
      return;
    }

    const lockVersion = selectedScene.draft?.lockVersion ?? 0;
    const write = toDraftWrite(values, lockVersion);
    setMutation({ phase: 'pending', operation: '保存草稿' });
    try {
      const draft = selectedScene.draft
        ? await presetScenesClient.updateDraft(selectedSceneId, write)
        : await presetScenesClient.createDraft(selectedSceneId, write);
      setSelectedScene((current) => (current ? { ...current, draft } : current));
      applyFormValues(form, toFormValues(draft));
      setFormDirty(false);
      formSceneIdRef.current = selectedSceneId;
      setConflict(null);
      setMutation({ phase: 'success', message: '草稿已保存。' });
      reloadAfterMutation();
    } catch (error) {
      await handleConflict('保存草稿', toApiError(error));
    }
  };

  const handlePublish = async () => {
    if (!canPublish || !selectedSceneId || !selectedScene?.draft) {
      return;
    }
    if (canWrite && formDirty) {
      setMutation({
        phase: 'error',
        operation: '发布版本',
        error: new ApiError(409, 'draft_unsaved_changes', '请先保存当前草稿，再发布版本。'),
      });
      return;
    }

    setMutation({ phase: 'pending', operation: '发布版本' });
    try {
      const published = await presetScenesClient.publish(selectedSceneId, {
        lockVersion: selectedScene.draft.lockVersion,
      });
      setSelectedScene((current) => (current ? mergePublished(current, published) : current));
      applyFormValues(form, toFormValues(published));
      setFormDirty(false);
      formSceneIdRef.current = selectedSceneId;
      setConflict(null);
      setMutation({
        phase: 'success',
        message: published.enabled ? `已发布 v${published.version}。` : `已停用并发布 v${published.version}。`,
      });
      reloadAfterMutation();
    } catch (error) {
      await handleConflict('发布版本', toApiError(error));
    }
  };

  const handleRollback = async (version: number) => {
    if (!canPublish || !historySceneId) {
      return;
    }

    setMutation({ phase: 'pending', operation: `回滚到 v${version}` });
    try {
      const published = await presetScenesClient.rollback(historySceneId, version);
      setHistory((current) =>
        [published, ...current.filter((item) => item.version !== published.version)].sort(
          (left, right) => right.version - left.version,
        ),
      );
      if (selectedSceneId === historySceneId) {
        setSelectedScene((current) => (current ? mergePublished(current, published) : current));
        applyFormValues(form, toFormValues(published));
        setFormDirty(false);
        formSceneIdRef.current = historySceneId;
      }
      setMutation({ phase: 'success', message: `已从 v${version} 回滚并发布 v${published.version}。` });
      reloadAfterMutation();
      await loadHistory(historySceneId);
    } catch (error) {
      setMutation({ phase: 'error', operation: `回滚到 v${version}`, error: toApiError(error) });
    }
  };

  const columns = useMemo<ProColumns<PresetSceneSummaryView>[]>(
    () => [
      {
        title: '场景',
        dataIndex: 'title',
        key: 'title',
        render: (_, record) => (
          <Space direction="vertical" size={0}>
            <Typography.Text strong data-testid={`preset-scene-row-${record.presetSceneId}`}>
              {record.title}
            </Typography.Text>
            <Typography.Text type="secondary">{record.presetSceneId}</Typography.Text>
          </Space>
        ),
      },
      {
        title: 'published',
        key: 'published',
        render: (_, record) => (
          <Space wrap>
            <Tag color={record.enabled ? 'success' : 'default'}>
              published v{record.publishedVersion} · {record.enabled ? 'enabled' : 'disabled'}
            </Tag>
            <Tag color={record.draftLockVersion === null ? 'default' : 'warning'}>
              {record.draftLockVersion === null ? 'no draft' : `draft · lock ${record.draftLockVersion}`}
            </Tag>
          </Space>
        ),
      },
      {
        title: 'metadata',
        key: 'metadata',
        render: (_, record) => (
          <Space direction="vertical" size={0}>
            <Typography.Text>{record.sceneTag}</Typography.Text>
            <Typography.Text type="secondary">sort {record.sortOrder}</Typography.Text>
            <Typography.Text type="secondary">updated {formatTimestamp(record.updatedAt)}</Typography.Text>
          </Space>
        ),
      },
      {
        title: 'actions',
        key: 'actions',
        render: (_, record) => (
          <Space wrap>
            <Button
              type="link"
              icon={<FormOutlined />}
              data-testid={`preset-scene-edit-${record.presetSceneId}`}
              onClick={() => void openScene(record.presetSceneId)}
            >
              编辑
            </Button>
            <Button
              type="link"
              icon={<HistoryOutlined />}
              data-testid={`preset-scene-history-${record.presetSceneId}`}
              onClick={() => void openHistory(record.presetSceneId)}
            >
              版本历史
            </Button>
          </Space>
        ),
      },
    ],
    [openHistory, openScene],
  );

  const selectedDraft = selectedScene?.draft ?? null;

  return (
    <Space direction="vertical" size="large" style={{ width: '100%' }} data-testid="preset-scenes-page">
      <Card size="small" title="Preset scenes · publishing context" data-testid="preset-scenes-context">
        <Space direction="vertical" size={10} style={{ width: '100%' }}>
          <Space wrap>
            <Tag>user: {admin.username}</Tag>
            <Tag color="success">practice:read enabled</Tag>
            <Tag color={canWrite ? 'success' : 'default'}>
              practice:write {canWrite ? 'enabled' : 'missing'}
            </Tag>
            <Tag color={canPublish ? 'success' : 'default'}>
              practice:publish {canPublish ? 'enabled' : 'missing'}
            </Tag>
            <Tag>roles: {admin.roles.join(', ') || 'none'}</Tag>
          </Space>
          {!canWrite ? (
            <Alert
              showIcon
              type="info"
              data-testid="preset-scenes-readonly-note"
              message="当前账号为只读模式"
              description="可以查看发布版本和历史；保存草稿按钮已禁用。"
            />
          ) : null}
        </Space>
      </Card>

      {listError ? (
        <Alert
          showIcon
          type="error"
          data-testid="preset-scenes-list-error"
          message="预置场景列表读取失败"
          description={`${listError.message}（${listError.code}）`}
        />
      ) : null}

      <Card
        title={`Preset scenes (${scenes.length})`}
        data-testid="preset-scenes-list-card"
        extra={
          <Button
            icon={<ReloadOutlined />}
            data-testid="preset-scenes-reload"
            onClick={() => setReloadNonce((value) => value + 1)}
          >
            重新读取
          </Button>
        }
      >
        <div data-testid="preset-scenes-list">
          <ProTable<PresetSceneSummaryView>
            rowKey="presetSceneId"
            columns={columns}
            dataSource={scenes}
            loading={listLoading}
            search={false}
            options={false}
            pagination={false}
            cardBordered={false}
            locale={{ emptyText: listLoading ? '正在读取预置场景…' : <Empty description="暂无预置场景。" /> }}
          />
        </div>
      </Card>

      <Drawer
        open={drawerOpen}
        width={640}
        title={selectedScene ? `编辑预置场景 · ${selectedScene.presetSceneId}` : '编辑预置场景'}
        onClose={() => setDrawerOpen(false)}
        destroyOnClose={false}
        data-testid="preset-scene-drawer"
      >
        {sceneError ? (
          <Alert
            showIcon
            type="error"
            data-testid="preset-scene-detail-error"
            message="预置场景读取失败"
            description={`${sceneError.message}（${sceneError.code}）`}
          />
        ) : null}

        {sceneLoading && !selectedScene ? (
          <div data-testid="preset-scene-loading" style={{ padding: '32px 0', textAlign: 'center' }}>
            <Spin tip="正在读取场景详情…" />
          </div>
        ) : null}

        {selectedScene ? (
          <Space direction="vertical" size="middle" style={{ width: '100%' }}>
            <Space wrap>
              <Tag color={selectedScene.enabled ? 'success' : 'default'}>
                published v{selectedScene.publishedVersion} · {selectedScene.enabled ? 'enabled' : 'disabled'}
              </Tag>
              <Tag>space: {selectedScene.spaceId}</Tag>
              <Tag data-testid="preset-scene-draft-lock">
                draft lockVersion: {selectedDraft?.lockVersion ?? 'new'}
              </Tag>
            </Space>

            {selectedDraft ? (
              <Alert
                showIcon
                type="warning"
                data-testid="preset-scene-draft-state"
                message="当前存在唯一 draft"
                description={`lockVersion=${selectedDraft.lockVersion} · updated=${formatTimestamp(selectedDraft.updatedAt)}`}
              />
            ) : (
              <Alert
                showIcon
                type="info"
                data-testid="preset-scene-no-draft"
                message="当前没有 draft"
                description={
                  canWrite ? (
                    <Button
                      type="link"
                      disabled={mutation.phase === 'pending'}
                      data-testid="preset-scene-create-draft"
                      onClick={() => void handleCreateDraft()}
                    >
                      创建草稿
                    </Button>
                  ) : (
                    'practice:write 缺失；可查看 published 内容。'
                  )
                }
              />
            )}

            {conflict ? (
              <ConflictComparison
                conflict={conflict}
                onUseServer={() => {
                  applyFormValues(form, toFormValues(conflict.server));
                  formSceneIdRef.current = selectedScene.presetSceneId;
                  setFormDirty(false);
                  setConflict(null);
                  setMutation({ phase: 'idle' });
                }}
              />
            ) : null}

            <MutationFeedback mutation={mutation} />

            <Form<DraftFormValues>
              form={form}
              layout="vertical"
              onFinish={(values) => void handleSave(values)}
              onValuesChange={() => setFormDirty(true)}
              disabled={!canWrite || mutation.phase === 'pending'}
              data-testid="preset-scene-form"
            >
              <Form.Item name="title" label="title" rules={textRules('title', 120)}>
                <Input data-testid="preset-scene-title" />
              </Form.Item>
              <Form.Item name="summary" label="summary" rules={textRules('summary', 240)}>
                <Input.TextArea autoSize={{ minRows: 2, maxRows: 5 }} data-testid="preset-scene-summary" />
              </Form.Item>
              <Form.Item name="sceneTag" label="sceneTag" rules={textRules('sceneTag', 120)}>
                <Input data-testid="preset-scene-tag" />
              </Form.Item>
              <Form.Item name="coachTip" label="coachTip" rules={textRules('coachTip', 240)}>
                <Input.TextArea autoSize={{ minRows: 2, maxRows: 5 }} data-testid="preset-scene-coach-tip" />
              </Form.Item>
              <Form.Item
                name="sortOrder"
                label="sortOrder"
                rules={[{ required: true, message: 'sortOrder 不能为空。' }]}
              >
                <InputNumber min={0} precision={0} style={{ width: '100%' }} data-testid="preset-scene-sort-order" />
              </Form.Item>
              <Form.Item
                name="generationBrief"
                label="generationBrief"
                rules={textRules('generationBrief', 1200)}
              >
                <Input.TextArea autoSize={{ minRows: 4, maxRows: 10 }} data-testid="preset-scene-generation-brief" />
              </Form.Item>
              <Form.Item name="enabled" label="enabled" valuePropName="checked">
                <Switch data-testid="preset-scene-enabled" />
              </Form.Item>
              <Form.Item>
                <Space wrap>
                  <Button
                    type="primary"
                    icon={<SaveOutlined />}
                    htmlType="submit"
                    disabled={!canWrite || mutation.phase === 'pending'}
                    data-testid="preset-scene-save"
                  >
                    保存草稿
                  </Button>
                  <Button
                    type="primary"
                    ghost
                    disabled={!canPublish || !selectedDraft || mutation.phase === 'pending'}
                    loading={mutation.phase === 'pending' && mutation.operation === '发布版本'}
                    data-testid="preset-scene-publish"
                    onClick={() => void handlePublish()}
                  >
                    发布版本
                  </Button>
                </Space>
              </Form.Item>
            </Form>
          </Space>
        ) : null}
      </Drawer>

      <Modal
        open={historyOpen}
        title={`版本历史${historySceneId ? ` · ${historySceneId}` : ''}`}
        footer={null}
        width={900}
        onCancel={() => setHistoryOpen(false)}
        data-testid="preset-scene-history-modal"
      >
        {historyError ? (
          <Alert
            showIcon
            type="error"
            data-testid="preset-scene-history-error"
            message="版本历史读取失败"
            description={`${historyError.message}（${historyError.code}）`}
          />
        ) : null}
        <Table<PresetScenePublishedView>
          rowKey={(record) => `${record.presetSceneId}-${record.version}`}
          loading={historyLoading}
          dataSource={history}
          pagination={false}
          scroll={{ x: 760 }}
          columns={[
            {
              title: 'version',
              dataIndex: 'version',
              key: 'version',
              render: (value: number) => <Tag>v{value}</Tag>,
            },
            {
              title: 'state',
              key: 'state',
              render: (_: unknown, record) => (
                <Space wrap>
                  <Tag color={record.enabled ? 'success' : 'default'}>
                    published · {record.enabled ? 'enabled' : 'disabled'}
                  </Tag>
                  <Typography.Text type="secondary">{formatTimestamp(record.publishedAt)}</Typography.Text>
                </Space>
              ),
            },
            {
              title: 'title',
              dataIndex: 'title',
              key: 'title',
            },
            {
              title: 'actions',
              key: 'actions',
              render: (_: unknown, record) => (
                <Popconfirm
                  title={`确认回滚到 v${record.version}？`}
                  description="回滚会复制历史内容并创建新的 published 版本。"
                  okText="确认回滚"
                  cancelText="取消"
                  onConfirm={() => void handleRollback(record.version)}
                >
                  <Button
                    disabled={!canPublish || mutation.phase === 'pending'}
                    data-testid={`preset-scene-rollback-${record.presetSceneId}-${record.version}`}
                  >
                    回滚到 v{record.version}
                  </Button>
                </Popconfirm>
              ),
            },
          ]}
          locale={{ emptyText: historyLoading ? '正在读取版本历史…' : '暂无 published 版本。' }}
        />
      </Modal>
    </Space>
  );
}

function textRules(field: string, max: number) {
  return [
    { required: true, whitespace: true, message: `${field} 不能为空。` },
    { max, message: `${field} 不能超过 ${max} 个字符。` },
  ];
}

function toFormValues(value: PresetSceneDraftView | PresetSceneDetailView | PresetScenePublishedView): DraftFormValues {
  return {
    title: value.title,
    summary: value.summary,
    sceneTag: value.sceneTag,
    coachTip: value.coachTip,
    sortOrder: value.sortOrder,
    generationBrief: value.generationBrief,
    enabled: value.enabled,
  };
}

function applyFormValues(form: FormInstance<DraftFormValues>, values: DraftFormValues) {
  form.setFieldsValue(values);
  form.setFields(
    FORM_FIELDS.map((name) => ({
      name,
      value: values[name],
      touched: false,
      errors: [],
      warnings: [],
    })),
  );
}

function readFormValues(value: Partial<DraftFormValues>): DraftFormValues {
  return {
    title: value.title ?? '',
    summary: value.summary ?? '',
    sceneTag: value.sceneTag ?? '',
    coachTip: value.coachTip ?? '',
    sortOrder: value.sortOrder ?? 0,
    generationBrief: value.generationBrief ?? '',
    enabled: value.enabled ?? true,
  };
}

function toDraftWrite(values: DraftFormValues, lockVersion: number): PresetSceneDraftWrite {
  return {
    title: values.title.trim(),
    summary: values.summary.trim(),
    sceneTag: values.sceneTag.trim(),
    coachTip: values.coachTip.trim(),
    sortOrder: values.sortOrder,
    generationBrief: values.generationBrief.trim(),
    enabled: values.enabled,
    lockVersion,
  };
}

function mergePublished(detail: PresetSceneDetailView, published: PresetScenePublishedView): PresetSceneDetailView {
  return {
    ...detail,
    publishedVersion: published.version,
    title: published.title,
    summary: published.summary,
    sceneTag: published.sceneTag,
    coachTip: published.coachTip,
    sortOrder: published.sortOrder,
    generationBrief: published.generationBrief,
    enabled: published.enabled,
    updatedAt: published.updatedAt,
    publishedAt: published.publishedAt,
    draft: null,
  };
}

function formatTimestamp(value: string | null | undefined): string {
  if (!value) {
    return '—';
  }
  const timestamp = Date.parse(value);
  return Number.isNaN(timestamp) ? value : new Date(timestamp).toLocaleString();
}

function formatComparisonValue(field: keyof DraftFormValues, value: unknown): string {
  if (field === 'enabled') {
    return value ? 'enabled' : 'disabled';
  }
  return String(value ?? '');
}

function readServerComparisonValue(
  server: PresetSceneDraftView | PresetSceneDetailView,
  field: keyof DraftFormValues,
): unknown {
  return server[field];
}

function ConflictComparison({
  conflict,
  onUseServer,
}: {
  conflict: ConflictState;
  onUseServer: () => void;
}) {
  return (
    <Alert
      showIcon
      type="warning"
      data-testid="preset-scene-conflict"
      message={`${conflict.operation}失败：服务器草稿版本已变化`}
      description={
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <Typography.Text>
            未保存内容已保留。请对比本地值与服务器值后，选择继续编辑或加载服务器草稿。
          </Typography.Text>
          {DRAFT_COMPARISON_FIELDS.map((field) => (
            <div key={field} data-testid={`preset-scene-conflict-${field}`}>
              <Typography.Text code>{field}</Typography.Text>
              <Typography.Text type="secondary">
                {' '}
                local: {formatComparisonValue(field, conflict.local[field])} · server:{' '}
                {formatComparisonValue(field, readServerComparisonValue(conflict.server, field))}
              </Typography.Text>
            </div>
          ))}
          <Button onClick={onUseServer} data-testid="preset-scene-use-server-draft">
            使用服务器草稿
          </Button>
        </Space>
      }
    />
  );
}

function MutationFeedback({ mutation }: { mutation: MutationState }) {
  if (mutation.phase === 'idle') {
    return null;
  }
  if (mutation.phase === 'pending') {
    return <Alert type="info" showIcon data-testid="preset-scene-mutation-feedback" message={`${mutation.operation}中…`} />;
  }
  if (mutation.phase === 'success') {
    return <Alert type="success" showIcon data-testid="preset-scene-mutation-feedback" message={mutation.message} />;
  }
  return (
    <Alert
      type={mutation.error.status >= 500 ? 'error' : 'warning'}
      showIcon
      data-testid="preset-scene-mutation-feedback"
      message={`${mutation.operation}失败`}
      description={`${mutation.error.message}（${mutation.error.code}）`}
    />
  );
}
