import { Alert, Button, Card, Descriptions, Empty, Input, List, Space, Spin, Tag, Typography } from 'antd';
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react';
import { warmPaperAdmin } from '../../app/theme';
import { ApiError, toApiError } from '../../lib/authClient';
import {
  knowledgeOpsClient,
  type KnowledgeIngestionFilter,
  type KnowledgeIngestionJobView,
} from '../../lib/knowledgeOpsClient';
import {
  DEFAULT_QUEUE_LIMIT,
  MAX_INGESTION_POLL_ATTEMPTS,
  type IngestionActionState,
  type KnowledgeQueryPatch,
  type QueryState,
  fileInputStyle,
  formatTimestamp,
  ingestionStatusColor,
  isNonTerminalIngestionStatus,
  isTimeoutLike,
  readIngestionFreshnessTag,
  readStringDetail,
} from '../../lib/knowledgeOpsUtils';
import { DetailContainer } from './DetailContainer';
import { QueuePageShell } from './QueuePageShell';

const INGESTION_POLL_INTERVAL_MS = 3_000;

const INGESTION_VIEW_OPTIONS: Array<{ value: KnowledgeIngestionFilter; label: string }> = [
  { value: 'all', label: '全部' },
  { value: 'PENDING', label: 'PENDING' },
  { value: 'PROCESSING', label: 'PROCESSING' },
  { value: 'COMPLETED', label: 'COMPLETED' },
  { value: 'FAILED', label: 'FAILED' },
];

export interface IngestionSurfaceProps {
  query: QueryState;
  onPatchQuery: (patch: KnowledgeQueryPatch) => void;
  canRead: boolean;
  canWrite: boolean;
  needsCanonicalQuery: boolean;
}

export function IngestionSurface({
  query,
  onPatchQuery,
  canRead,
  canWrite,
  needsCanonicalQuery,
}: IngestionSurfaceProps) {
  const [ingestionJobs, setIngestionJobs] = useState<KnowledgeIngestionJobView[]>([]);
  const [ingestionLoading, setIngestionLoading] = useState(false);
  const [ingestionError, setIngestionError] = useState<ApiError | null>(null);
  const [ingestionReloadNonce, setIngestionReloadNonce] = useState(0);
  const [ingestionDetail, setIngestionDetail] = useState<KnowledgeIngestionJobView | null>(null);
  const [ingestionDetailLoading, setIngestionDetailLoading] = useState(false);
  const [ingestionDetailError, setIngestionDetailError] = useState<ApiError | null>(null);
  const [ingestionActionState, setIngestionActionState] = useState<IngestionActionState>({ phase: 'idle' });
  const [ingestionPollAttempt, setIngestionPollAttempt] = useState(0);
  const [ingestionPollStale, setIngestionPollStale] = useState(false);
  const [ingestionPollReason, setIngestionPollReason] = useState<string | undefined>();
  const [ingestionPollLastSuccessAt, setIngestionPollLastSuccessAt] = useState<string | undefined>();
  const [selectedUploadFile, setSelectedUploadFile] = useState<File | null>(null);
  const [uploadBookTitle, setUploadBookTitle] = useState('');
  const [uploadInputVersion, setUploadInputVersion] = useState(0);

  const ingestionJobsRef = useRef<KnowledgeIngestionJobView[]>([]);
  const ingestionDetailRef = useRef<KnowledgeIngestionJobView | null>(null);

  useEffect(() => {
    ingestionJobsRef.current = ingestionJobs;
  }, [ingestionJobs]);

  useEffect(() => {
    ingestionDetailRef.current = ingestionDetail;
  }, [ingestionDetail]);

  useEffect(() => {
    setIngestionPollAttempt(0);
    setIngestionPollStale(false);
    setIngestionPollReason(undefined);
  }, [query.ingestionStatus, query.selected, query.view, ingestionReloadNonce]);

  const fetchIngestionList = useCallback(
    async (mode: 'load' | 'poll' = 'load') => {
      if (mode !== 'poll') {
        setIngestionLoading(true);
      }
      if (mode === 'load') {
        setIngestionError(null);
      }

      try {
        const nextJobs = await knowledgeOpsClient.listIngestionJobs({
          status: query.ingestionStatus === 'all' ? undefined : query.ingestionStatus,
          limit: DEFAULT_QUEUE_LIMIT,
        });
        setIngestionJobs(nextJobs);
        setIngestionError(null);
        return { ok: true as const, jobs: nextJobs };
      } catch (error) {
        const apiError = toApiError(error);
        if (isTimeoutLike(apiError) && ingestionJobsRef.current.length > 0) {
          setIngestionError(apiError);
          return { ok: false as const, timeoutPreserved: true };
        }
        setIngestionJobs([]);
        setIngestionError(apiError);
        return { ok: false as const, timeoutPreserved: false };
      } finally {
        if (mode !== 'poll') {
          setIngestionLoading(false);
        }
      }
    },
    [query.ingestionStatus],
  );

  const fetchIngestionDetail = useCallback(async (jobId: string, mode: 'load' | 'poll' = 'load') => {
    if (mode !== 'poll') {
      setIngestionDetailLoading(true);
    }
    if (mode === 'load') {
      setIngestionDetailError(null);
    }

    try {
      const nextDetail = await knowledgeOpsClient.getIngestionJob(jobId);
      setIngestionDetail(nextDetail);
      setIngestionDetailError(null);
      return { ok: true as const, detail: nextDetail };
    } catch (error) {
      const apiError = toApiError(error);
      if (isTimeoutLike(apiError) && ingestionDetailRef.current?.id === jobId) {
        setIngestionDetailError(apiError);
        return { ok: false as const, timeoutPreserved: true };
      }
      setIngestionDetail(null);
      setIngestionDetailError(apiError);
      return { ok: false as const, timeoutPreserved: false };
    } finally {
      if (mode !== 'poll') {
        setIngestionDetailLoading(false);
      }
    }
  }, []);

  const refreshIngestionSurface = useCallback(
    async (mode: 'load' | 'poll' = 'load') => {
      const selectedId = query.selected;
      const [listResult, detailResult] = await Promise.all([
        fetchIngestionList(mode),
        selectedId ? fetchIngestionDetail(selectedId, mode) : Promise.resolve({ ok: true as const, detail: null }),
      ]);
      return {
        listResult,
        detailResult,
      };
    },
    [fetchIngestionDetail, fetchIngestionList, query.selected],
  );

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'ingestion') {
      return;
    }
    void refreshIngestionSurface('load');
  }, [ingestionReloadNonce, needsCanonicalQuery, query.ingestionStatus, query.selected, query.view, refreshIngestionSurface]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'ingestion') {
      return;
    }

    const hasLiveQueue = ingestionJobs.some((job) => isNonTerminalIngestionStatus(job.status));
    const hasLiveSelectedJob = isNonTerminalIngestionStatus(
      ingestionDetail?.status ?? ingestionJobs.find((job) => job.id === query.selected)?.status,
    );
    const shouldPoll = hasLiveQueue || hasLiveSelectedJob;

    if (!shouldPoll) {
      setIngestionPollAttempt(0);
      setIngestionPollStale(false);
      setIngestionPollReason(undefined);
      return;
    }

    if (ingestionPollStale) {
      return;
    }

    if (ingestionPollAttempt >= MAX_INGESTION_POLL_ATTEMPTS) {
      setIngestionPollStale(true);
      setIngestionPollReason('poll_budget_exhausted');
      return;
    }

    const timer = window.setTimeout(() => {
      void refreshIngestionSurface('poll').then(({ listResult, detailResult }) => {
        const listTimedOut = !listResult.ok && listResult.timeoutPreserved;
        const detailTimedOut = !detailResult.ok && detailResult.timeoutPreserved;
        if (listTimedOut || detailTimedOut) {
          setIngestionPollStale(true);
          setIngestionPollReason('request_timeout');
          setIngestionPollAttempt((value) => value + 1);
          return;
        }

        if (!listResult.ok || !detailResult.ok) {
          setIngestionPollStale(true);
          setIngestionPollReason('request_failed');
          setIngestionPollAttempt((value) => value + 1);
          return;
        }

        setIngestionPollAttempt((value) => value + 1);
        setIngestionPollLastSuccessAt(new Date().toISOString());
      });
    }, INGESTION_POLL_INTERVAL_MS);

    return () => {
      window.clearTimeout(timer);
    };
  }, [
    ingestionDetail,
    ingestionJobs,
    ingestionPollAttempt,
    ingestionPollStale,
    needsCanonicalQuery,
    query.selected,
    query.view,
    refreshIngestionSurface,
  ]);

  const selectedIngestionId = query.view === 'ingestion' ? query.selected : undefined;
  const selectedIngestionNotInList =
    selectedIngestionId !== undefined &&
    !ingestionLoading &&
    ingestionError == null &&
    !ingestionJobs.some((job) => job.id === selectedIngestionId);
  const ingestionFreshness = readIngestionFreshnessTag({
    stale: ingestionPollStale,
    active: ingestionJobs.some((job) => isNonTerminalIngestionStatus(job.status)),
    attempt: ingestionPollAttempt,
  });
  const latestIngestionUpdate = useMemo(() => {
    const timestamps = [...ingestionJobs.map((job) => job.updatedAt), ingestionDetail?.updatedAt, ingestionPollLastSuccessAt].filter(
      (value): value is string => Boolean(value),
    );
    return timestamps.sort((left, right) => Date.parse(right) - Date.parse(left))[0];
  }, [ingestionDetail?.updatedAt, ingestionJobs, ingestionPollLastSuccessAt]);
  const activeIngestionActionJob =
    ingestionActionState.phase === 'success'
      ? (ingestionDetail?.id === ingestionActionState.response.jobId
          ? ingestionDetail
          : ingestionJobs.find((job) => job.id === ingestionActionState.response.jobId) ?? null)
      : null;

  const resetIngestionPolling = useCallback(() => {
    setIngestionPollAttempt(0);
    setIngestionPollStale(false);
    setIngestionPollReason(undefined);
    setIngestionReloadNonce((value) => value + 1);
  }, []);

  const handleUploadFileChange = useCallback((event: ChangeEvent<HTMLInputElement>) => {
    const nextFile = event.target.files?.[0] ?? null;
    setSelectedUploadFile(nextFile);
  }, []);

  const handleUpload = useCallback(async () => {
    if (!selectedUploadFile) {
      setIngestionActionState({
        phase: 'error',
        kind: 'upload',
        error: new ApiError(400, 'invalid_knowledge_ingestion_file', '请先选择一个 PDF 文件。'),
      });
      return;
    }

    setIngestionActionState({ phase: 'pending', kind: 'upload', target: selectedUploadFile.name });
    try {
      const response = await knowledgeOpsClient.uploadIngestion(selectedUploadFile, uploadBookTitle);
      setIngestionActionState({ phase: 'success', kind: 'upload', response });
      setSelectedUploadFile(null);
      setUploadBookTitle('');
      setUploadInputVersion((value) => value + 1);
      onPatchQuery({ selected: response.jobId });
      setIngestionReloadNonce((value) => value + 1);
    } catch (error) {
      setIngestionActionState({ phase: 'error', kind: 'upload', error: toApiError(error) });
    }
  }, [onPatchQuery, selectedUploadFile, uploadBookTitle]);

  const handleRetry = useCallback(async () => {
    const jobId = ingestionDetail?.id ?? selectedIngestionId;
    if (!jobId) {
      setIngestionActionState({
        phase: 'error',
        kind: 'retry',
        error: new ApiError(400, 'invalid_knowledge_ingestion_job_id', '当前没有可重试的 ingestion job。'),
      });
      return;
    }

    setIngestionActionState({ phase: 'pending', kind: 'retry', target: jobId });
    try {
      const response = await knowledgeOpsClient.retryIngestionJob(jobId);
      setIngestionActionState({ phase: 'success', kind: 'retry', response });
      setIngestionReloadNonce((value) => value + 1);
    } catch (error) {
      setIngestionActionState({ phase: 'error', kind: 'retry', error: toApiError(error) });
    }
  }, [ingestionDetail?.id, selectedIngestionId]);

  if (!canRead || query.view !== 'ingestion') {
    return null;
  }

  return (
    <>
      <Card size="small" title="Inline diagnostics" data-testid="knowledge-inline-diagnostics">
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <Typography.Text type="secondary">
            malformed payload 会在 client parser 边界抛出 `invalid_response_payload`；timeout 会把 ingestion surface 标成 stale；当前 surface 会保留最近一次可用快照供 operator 继续排查。
          </Typography.Text>
          <Space wrap>
            <Tag color={ingestionError ? 'warning' : 'success'}>
              list: {ingestionError ? ingestionError.code : ingestionLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={ingestionDetailError ? 'warning' : 'success'}>
              detail: {ingestionDetailError ? ingestionDetailError.code : ingestionDetailLoading ? 'loading' : 'ready'}
            </Tag>
            <Tag color={ingestionPollStale ? 'warning' : 'success'}>
              poll: {ingestionPollStale ? ingestionPollReason ?? 'stale' : `${ingestionPollAttempt}/${MAX_INGESTION_POLL_ATTEMPTS}`}
            </Tag>
            <Tag color={ingestionFreshness.color}>{ingestionFreshness.label}</Tag>
            <Tag color={latestIngestionUpdate ? 'processing' : 'default'}>
              latest update: {formatTimestamp(latestIngestionUpdate)}
            </Tag>
          </Space>
        </Space>
      </Card>

      <Card size="small" title="Ingestion controls">
        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
          <div>
            <Typography.Text type="secondary">status filter</Typography.Text>
            <Space wrap style={{ marginTop: 8 }}>
              {INGESTION_VIEW_OPTIONS.map((option) => (
                <Button
                  key={option.value}
                  data-testid={`knowledge-ingestion-status-${option.value}`}
                  type={query.ingestionStatus === option.value ? 'primary' : 'default'}
                  onClick={() =>
                    onPatchQuery({
                      status: option.value,
                      selected: undefined,
                    })
                  }
                >
                  {option.label}
                </Button>
              ))}
            </Space>
          </div>

          <Space wrap>
            <Button data-testid="knowledge-ingestion-reload" onClick={() => setIngestionReloadNonce((value) => value + 1)}>
              重新读取 queue
            </Button>
            {ingestionPollStale ? (
              <Button data-testid="knowledge-ingestion-resume-poll" type="primary" onClick={resetIngestionPolling}>
                恢复 polling
              </Button>
            ) : null}
          </Space>

          {canWrite ? (
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <div>
                <Typography.Text type="secondary">bookTitle</Typography.Text>
                <Input
                  data-testid="knowledge-upload-book-title"
                  placeholder="可选：书名/上传批次标记"
                  value={uploadBookTitle}
                  onChange={(event) => setUploadBookTitle(event.target.value)}
                />
              </div>
              <div>
                <Typography.Text type="secondary">PDF file</Typography.Text>
                <input
                  key={uploadInputVersion}
                  type="file"
                  accept="application/pdf"
                  data-testid="knowledge-upload-file"
                  style={fileInputStyle}
                  onChange={handleUploadFileChange}
                />
              </div>
              <Space wrap>
                <Button
                  type="primary"
                  data-testid="knowledge-upload-submit"
                  loading={ingestionActionState.phase === 'pending' && ingestionActionState.kind === 'upload'}
                  onClick={() => void handleUpload()}
                >
                  上传 PDF
                </Button>
                {selectedUploadFile ? <Tag>{selectedUploadFile.name}</Tag> : <Tag>未选择文件</Tag>}
              </Space>
            </Space>
          ) : null}

          <IngestionActionFeedback state={ingestionActionState} activeJob={activeIngestionActionJob} />

          {ingestionPollStale ? (
            <Alert
              showIcon
              type="warning"
              data-testid="knowledge-ingestion-stale"
              message="ingestion surface 已变 stale"
              description={`最近一次 polling 未完成（${ingestionPollReason ?? 'unknown'}）。当前快照保留，operator 可手动 reload 或恢复 polling。`}
            />
          ) : null}
        </Space>
      </Card>

      <QueuePageShell
        queue={
          <Card title={`Ingestion jobs (${ingestionJobs.length})`} data-testid="knowledge-ingestion-queue">
            {ingestionError ? (
              <Alert
                showIcon
                type={ingestionError.status >= 500 || ingestionError.status === 0 ? 'error' : 'warning'}
                data-testid="knowledge-ingestion-list-error"
                style={{ marginBottom: 16 }}
                message="ingestion queue 读取失败"
                description={
                  <Space direction="vertical" size={8}>
                    <span>{ingestionError.message}</span>
                    <Typography.Text type="secondary">错误码：{ingestionError.code}</Typography.Text>
                  </Space>
                }
              />
            ) : null}

            {selectedIngestionNotInList && !ingestionError ? (
              <Alert
                showIcon
                type="warning"
                data-testid="knowledge-ingestion-selected-missing"
                style={{ marginBottom: 16 }}
                message="当前选中的 job 不在当前过滤结果里"
                description="可能是因为状态已变化、当前 filter 不再命中，或者刚刚完成 retry / upload。详情面会保留当前 selected job。"
              />
            ) : null}

            {ingestionLoading ? (
              <div style={{ padding: '24px 0' }}>
                <Spin tip="正在读取 ingestion queue…" />
              </div>
            ) : null}

            {!ingestionLoading && ingestionJobs.length === 0 && !ingestionError ? (
              <div data-testid="knowledge-ingestion-empty">
                <Empty description="当前过滤条件下没有 ingestion jobs。" />
              </div>
            ) : null}

            {!ingestionLoading && ingestionJobs.length > 0 ? (
              <List
                dataSource={ingestionJobs}
                renderItem={(job) => {
                  const selected = job.id === selectedIngestionId;
                  return (
                    <List.Item key={job.id} data-testid={`knowledge-ingestion-row-${job.id}`}>
                      <Card
                        size="small"
                        style={{
                          width: '100%',
                          borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined,
                        }}
                        title={
                          <Space wrap>
                            <Typography.Text code>{job.id}</Typography.Text>
                            <Tag color={ingestionStatusColor(job.status)}>{job.status}</Tag>
                            {job.retryable ? <Tag color="orange">retryable</Tag> : null}
                          </Space>
                        }
                        extra={
                          <Button
                            type={selected ? 'default' : 'primary'}
                            data-testid={`knowledge-open-ingestion-${job.id}`}
                            onClick={() =>
                              onPatchQuery({
                                selected: job.id,
                              })
                            }
                          >
                            {selected ? '已打开' : '查看详情'}
                          </Button>
                        }
                      >
                        <Descriptions column={1} size="small">
                          <Descriptions.Item label="filename">{job.originalFilename}</Descriptions.Item>
                          <Descriptions.Item label="updatedAt">{formatTimestamp(job.updatedAt)}</Descriptions.Item>
                        </Descriptions>
                      </Card>
                    </List.Item>
                  );
                }}
              />
            ) : null}
          </Card>
        }
        detail={
          <DetailContainer
            title={selectedIngestionId ? `Ingestion detail · ${selectedIngestionId}` : 'Ingestion detail'}
            extra={
              <Space>
                {selectedIngestionId ? (
                  <Button data-testid="knowledge-close-ingestion-detail" onClick={() => onPatchQuery({ selected: undefined })}>
                    关闭详情
                  </Button>
                ) : null}
                {selectedIngestionId ? (
                  <Button data-testid="knowledge-reload-ingestion-detail" onClick={() => setIngestionReloadNonce((value) => value + 1)}>
                    重试 detail
                  </Button>
                ) : null}
                {selectedIngestionId && canWrite && ingestionDetail?.retryable ? (
                  <Button
                    danger
                    type="primary"
                    data-testid="knowledge-retry-job"
                    loading={ingestionActionState.phase === 'pending' && ingestionActionState.kind === 'retry'}
                    onClick={() => void handleRetry()}
                  >
                    Retry FAILED job
                  </Button>
                ) : null}
              </Space>
            }
            testId="knowledge-ingestion-detail"
          >
            {!selectedIngestionId ? (
              <div data-testid="knowledge-ingestion-detail-placeholder">
                <Empty description="从 queue 里选择一个 ingestion job 后，这里会显示 job 状态、updatedAt 与错误上下文。" />
              </div>
            ) : null}

            {selectedIngestionId && ingestionDetailLoading ? (
              <div data-testid="knowledge-ingestion-detail-loading" style={{ padding: '24px 0' }}>
                <Spin tip="正在读取 ingestion detail…" />
              </div>
            ) : null}

            {selectedIngestionId && !ingestionDetailLoading && ingestionDetailError ? (
              <Alert
                showIcon
                type={ingestionDetailError.status === 404 ? 'warning' : 'error'}
                data-testid="knowledge-ingestion-detail-error"
                message={ingestionDetailError.status === 404 ? 'ingestion detail 不存在' : 'ingestion detail 读取失败'}
                description={
                  <Space direction="vertical" size={8}>
                    <span>{ingestionDetailError.message}</span>
                    <Typography.Text type="secondary">错误码：{ingestionDetailError.code}</Typography.Text>
                  </Space>
                }
              />
            ) : null}

            {ingestionDetail && !ingestionDetailLoading && !ingestionDetailError ? (
              <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                <Descriptions column={1} bordered size="small">
                  <Descriptions.Item label="jobId">
                    <Typography.Text code>{ingestionDetail.id}</Typography.Text>
                  </Descriptions.Item>
                  <Descriptions.Item label="originalFilename">{ingestionDetail.originalFilename}</Descriptions.Item>
                  <Descriptions.Item label="status">
                    <Tag data-testid="knowledge-ingestion-status" color={ingestionStatusColor(ingestionDetail.status)}>
                      {ingestionDetail.status}
                    </Tag>
                  </Descriptions.Item>
                  <Descriptions.Item label="totalChunks">{ingestionDetail.totalChunks}</Descriptions.Item>
                  <Descriptions.Item label="createdAt">{formatTimestamp(ingestionDetail.createdAt)}</Descriptions.Item>
                  <Descriptions.Item label="updatedAt">{formatTimestamp(ingestionDetail.updatedAt)}</Descriptions.Item>
                  <Descriptions.Item label="retryable">{String(ingestionDetail.retryable)}</Descriptions.Item>
                </Descriptions>

                <Card size="small" title="Error / operator notes">
                  <Typography.Paragraph style={{ whiteSpace: 'pre-wrap', marginBottom: 0 }}>
                    {ingestionDetail.errorMessage ?? '当前 job 没有 errorMessage。'}
                  </Typography.Paragraph>
                </Card>
              </Space>
            ) : null}
          </DetailContainer>
        }
      />
    </>
  );
}

function IngestionActionFeedback({
  state,
  activeJob,
}: {
  state: IngestionActionState;
  activeJob: KnowledgeIngestionJobView | null;
}) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="knowledge-ingestion-feedback"
        message={state.kind === 'upload' ? '正在上传 PDF' : '正在提交 retry'}
        description={state.target}
      />
    );
  }

  if (state.phase === 'error') {
    const jobId = readStringDetail(state.error, 'jobId');
    const errorMessage = readStringDetail(state.error, 'errorMessage');
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-ingestion-feedback"
        message={state.kind === 'upload' ? '上传失败' : 'retry 失败'}
        description={
          <Space direction="vertical" size={4}>
            <span>{state.error.message}</span>
            <Typography.Text type="secondary">错误码：{state.error.code}</Typography.Text>
            {jobId ? <Typography.Text type="secondary">jobId: {jobId}</Typography.Text> : null}
            {errorMessage ? <Typography.Text type="secondary">errorMessage: {errorMessage}</Typography.Text> : null}
          </Space>
        }
      />
    );
  }

  if (activeJob?.id === state.response.jobId && activeJob.status === 'FAILED') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-ingestion-feedback"
        message={state.kind === 'upload' ? '上传任务已失败' : 'retry 后任务再次失败'}
        description={`jobId=${activeJob.id}; status=${activeJob.status}; updatedAt=${formatTimestamp(activeJob.updatedAt)}; errorMessage=${activeJob.errorMessage ?? '—'}`}
      />
    );
  }

  if (activeJob?.id === state.response.jobId && activeJob.status === 'COMPLETED') {
    return (
      <Alert
        showIcon
        type="success"
        data-testid="knowledge-ingestion-feedback"
        message={state.kind === 'upload' ? '上传任务已完成' : 'retry 已完成'}
        description={`jobId=${activeJob.id}; status=${activeJob.status}; totalChunks=${activeJob.totalChunks}; updatedAt=${formatTimestamp(activeJob.updatedAt)}`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="info"
      data-testid="knowledge-ingestion-feedback"
      message={state.kind === 'upload' ? '上传已入队' : 'retry 已提交'}
      description={`jobId=${state.response.jobId}; status=${activeJob?.status ?? state.response.status}; updatedAt=${formatTimestamp(activeJob?.updatedAt ?? state.response.updatedAt)}; errorMessage=${activeJob?.errorMessage ?? state.response.errorMessage ?? '—'}`}
    />
  );
}

export default IngestionSurface;
