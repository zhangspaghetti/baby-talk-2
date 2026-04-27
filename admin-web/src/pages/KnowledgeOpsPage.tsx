import { Alert, Button, Card, Collapse, Descriptions, Empty, Input, List, Space, Spin, Tag, Typography } from 'antd';
import { useCallback, useEffect, useMemo, useRef, useState, type ChangeEvent } from 'react';
import { useSearchParams } from 'react-router-dom';
import { hasKnownAdminPermission } from '../app/access';
import { warmPaperAdmin } from '../app/theme';
import { useAuth } from '../auth/auth-provider';
import { DetailContainer } from '../components/workbench/DetailContainer';
import { QueuePageShell } from '../components/workbench/QueuePageShell';
import { ApiError, toApiError } from '../lib/authClient';
import {
  KNOWLEDGE_CONTRADICTION_FILTERS,
  KNOWLEDGE_CONTRADICTION_STATUSES,
  KNOWLEDGE_INGESTION_FILTERS,
  KNOWLEDGE_INGESTION_STATUSES,
  KNOWLEDGE_OPS_VIEWS,
  PALACE_BRIDGE_EDGE_STATUSES,
  PALACE_RAG_SUBVIEWS,
  knowledgeOpsClient,
  type KnowledgeContradictionDetailView,
  type KnowledgeContradictionFilter,
  type KnowledgeContradictionQueueItemView,
  type KnowledgeContradictionStatus,
  type KnowledgeIngestionFilter,
  type KnowledgeIngestionJobMutationView,
  type KnowledgeIngestionJobView,
  type KnowledgeIngestionStatus,
  type KnowledgeNotificationView,
  type KnowledgeOpsView,
  type PalaceBridgeEdgeStatus,
  type PalaceBridgeEdgeView,
  type PalaceProjectionStatusView,
  type PalaceQueryTraceSampleView,
  type PalaceRagSubview,
} from '../lib/knowledgeOpsClient';
import {
  DEFAULT_BRIDGE_REVIEW_STATUS,
  DEFAULT_NOTIFICATION_LIMIT,
  DEFAULT_PALACE_RAG_SUBVIEW,
  DEFAULT_QUEUE_LIMIT,
  DEFAULT_STATUS,
  DEFAULT_VIEW,
  MAX_INGESTION_POLL_ATTEMPTS,
  QUERY_PARAM_KEYS,
  type IngestionActionState,
  type KgActionState,
  type KnowledgeQueryPatch,
  type PalaceRagActionState,
  type QueryState,
  countTraceCandidates,
  contradictionStatusColor,
  defaultStatusForView,
  fileInputStyle,
  formatConfidence,
  formatTimestamp,
  includesTupleValue,
  ingestionStatusColor,
  isNonTerminalIngestionStatus,
  isTimeoutLike,
  notificationTypeColor,
  palaceBridgeStatusColor,
  patchKnowledgeQuery,
  readCanonicalStatus,
  readIngestionFreshnessTag,
  readQueryState as readKnowledgeQueryState,
  readStatusBadge,
  readStringDetail,
} from '../lib/knowledgeOpsUtils';

const PALACE_TRACE_LIMIT = 20;
const INGESTION_POLL_INTERVAL_MS = 3_000;

const INGESTION_VIEW_OPTIONS: Array<{ value: KnowledgeIngestionFilter; label: string }> = [
  { value: 'all', label: '全部' },
  { value: 'PENDING', label: 'PENDING' },
  { value: 'PROCESSING', label: 'PROCESSING' },
  { value: 'COMPLETED', label: 'COMPLETED' },
  { value: 'FAILED', label: 'FAILED' },
];

const KG_VIEW_OPTIONS: Array<{ value: KnowledgeContradictionFilter; label: string }> = [
  { value: 'all', label: '全部' },
  { value: 'detected', label: 'detected' },
  { value: 'reviewing', label: 'reviewing' },
  { value: 'escalated', label: 'escalated' },
  { value: 'resolved', label: 'resolved' },
  { value: 'dismissed', label: 'dismissed' },
];

const PALACE_RAG_VIEW_OPTIONS: Array<{ value: PalaceRagSubview; label: string }> = [
  { value: 'bridge-review', label: 'Bridge review' },
  { value: 'trace-samples', label: 'Trace samples' },
  { value: 'projection', label: 'Projection' },
];

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

  const [kgQueueItems, setKgQueueItems] = useState<KnowledgeContradictionQueueItemView[]>([]);
  const [kgLoading, setKgLoading] = useState(false);
  const [kgError, setKgError] = useState<ApiError | null>(null);
  const [kgReloadNonce, setKgReloadNonce] = useState(0);
  const [kgDetail, setKgDetail] = useState<KnowledgeContradictionDetailView | null>(null);
  const [kgDetailLoading, setKgDetailLoading] = useState(false);
  const [kgDetailError, setKgDetailError] = useState<ApiError | null>(null);
  const [notifications, setNotifications] = useState<KnowledgeNotificationView[]>([]);
  const [notificationsLoading, setNotificationsLoading] = useState(false);
  const [notificationsError, setNotificationsError] = useState<ApiError | null>(null);
  const [kgActionState, setKgActionState] = useState<KgActionState>({ phase: 'idle' });
  const [resolveDraft, setResolveDraft] = useState('');

  const [palaceReloadNonce, setPalaceReloadNonce] = useState(0);
  const [bridgeEdges, setBridgeEdges] = useState<PalaceBridgeEdgeView[]>([]);
  const [bridgeLoading, setBridgeLoading] = useState(false);
  const [bridgeError, setBridgeError] = useState<ApiError | null>(null);
  const [bridgeDetail, setBridgeDetail] = useState<PalaceBridgeEdgeView | null>(null);
  const [bridgeDetailLoading, setBridgeDetailLoading] = useState(false);
  const [bridgeDetailError, setBridgeDetailError] = useState<ApiError | null>(null);
  const [projectionStatus, setProjectionStatus] = useState<PalaceProjectionStatusView | null>(null);
  const [projectionLoading, setProjectionLoading] = useState(false);
  const [projectionError, setProjectionError] = useState<ApiError | null>(null);
  const [traceItems, setTraceItems] = useState<PalaceQueryTraceSampleView[]>([]);
  const [tracesLoading, setTracesLoading] = useState(false);
  const [tracesError, setTracesError] = useState<ApiError | null>(null);
  const [palaceRagAction, setPalaceRagAction] = useState<PalaceRagActionState>({ phase: 'idle' });

  const ingestionJobsRef = useRef<KnowledgeIngestionJobView[]>([]);
  const ingestionDetailRef = useRef<KnowledgeIngestionJobView | null>(null);

  useEffect(() => {
    ingestionJobsRef.current = ingestionJobs;
  }, [ingestionJobs]);

  useEffect(() => {
    ingestionDetailRef.current = ingestionDetail;
  }, [ingestionDetail]);

  useEffect(() => {
    if (!needsCanonicalQuery) {
      return;
    }

    const nextParams = new URLSearchParams(searchParams);
    nextParams.set('view', query.view);
    nextParams.set('status', readCanonicalStatus(query));
    setSearchParams(nextParams, { replace: true });
  }, [needsCanonicalQuery, query, searchParams, setSearchParams]);

  useEffect(() => {
    setIngestionPollAttempt(0);
    setIngestionPollStale(false);
    setIngestionPollReason(undefined);
  }, [query.ingestionStatus, query.selected, query.view, ingestionReloadNonce]);

  useEffect(() => {
    if (query.view !== 'kg-review') {
      return;
    }
    setResolveDraft(kgDetail?.adminNotes ?? '');
  }, [kgDetail?.adminNotes, kgDetail?.id, query.view]);

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

  const fetchKgQueue = useCallback(async () => {
    setKgLoading(true);
    setKgError(null);
    try {
      const nextItems = await knowledgeOpsClient.listContradictions({
        status: query.kgStatus === 'all' ? undefined : query.kgStatus,
        limit: DEFAULT_QUEUE_LIMIT,
      });
      setKgQueueItems(nextItems);
    } catch (error) {
      const apiError = toApiError(error);
      setKgQueueItems([]);
      setKgError(apiError);
    } finally {
      setKgLoading(false);
    }
  }, [query.kgStatus]);

  const fetchKgDetail = useCallback(async (contradictionId: string) => {
    setKgDetailLoading(true);
    setKgDetailError(null);
    try {
      const nextDetail = await knowledgeOpsClient.getContradiction(contradictionId);
      setKgDetail(nextDetail);
      return nextDetail;
    } catch (error) {
      const apiError = toApiError(error);
      setKgDetail(null);
      setKgDetailError(apiError);
      return null;
    } finally {
      setKgDetailLoading(false);
    }
  }, []);

  const fetchNotifications = useCallback(async (contradictionId: string) => {
    setNotificationsLoading(true);
    setNotificationsError(null);
    try {
      const nextNotifications = await knowledgeOpsClient.listNotifications(contradictionId, {
        limit: DEFAULT_NOTIFICATION_LIMIT,
      });
      setNotifications(nextNotifications);
      return nextNotifications;
    } catch (error) {
      const apiError = toApiError(error);
      setNotifications([]);
      setNotificationsError(apiError);
      return null;
    } finally {
      setNotificationsLoading(false);
    }
  }, []);

  const refreshKgSurface = useCallback(async () => {
    const selectedId = query.selected;
    await Promise.all([
      fetchKgQueue(),
      selectedId ? fetchKgDetail(selectedId) : Promise.resolve(null),
      selectedId ? fetchNotifications(selectedId) : Promise.resolve(null),
    ]);
  }, [fetchKgDetail, fetchKgQueue, fetchNotifications, query.selected]);

  const fetchBridgeEdges = useCallback(async () => {
    setBridgeLoading(true);
    setBridgeError(null);
    try {
      const nextEdges = await knowledgeOpsClient.listBridgeEdges({
        status: DEFAULT_BRIDGE_REVIEW_STATUS,
        limit: DEFAULT_QUEUE_LIMIT,
      });
      setBridgeEdges(nextEdges);
      return nextEdges;
    } catch (error) {
      const apiError = toApiError(error);
      setBridgeEdges([]);
      setBridgeError(apiError);
      return null;
    } finally {
      setBridgeLoading(false);
    }
  }, []);

  const fetchBridgeDetail = useCallback(async (edgeId: string) => {
    setBridgeDetailLoading(true);
    setBridgeDetailError(null);
    try {
      const nextEdge = await knowledgeOpsClient.getBridgeEdge(edgeId);
      setBridgeDetail(nextEdge);
      return nextEdge;
    } catch (error) {
      const apiError = toApiError(error);
      setBridgeDetail(null);
      setBridgeDetailError(apiError);
      return null;
    } finally {
      setBridgeDetailLoading(false);
    }
  }, []);

  const fetchProjectionStatus = useCallback(async () => {
    setProjectionLoading(true);
    setProjectionError(null);
    try {
      const nextStatus = await knowledgeOpsClient.getProjectionStatus();
      setProjectionStatus(nextStatus);
      return nextStatus;
    } catch (error) {
      const apiError = toApiError(error);
      setProjectionStatus(null);
      setProjectionError(apiError);
      return null;
    } finally {
      setProjectionLoading(false);
    }
  }, []);

  const fetchTraceSamples = useCallback(async () => {
    setTracesLoading(true);
    setTracesError(null);
    try {
      const nextItems = await knowledgeOpsClient.listTraceSamples({ limit: PALACE_TRACE_LIMIT });
      setTraceItems(nextItems);
      return nextItems;
    } catch (error) {
      const apiError = toApiError(error);
      setTraceItems([]);
      setTracesError(apiError);
      return null;
    } finally {
      setTracesLoading(false);
    }
  }, []);

  const refreshPalaceRagSurface = useCallback(async () => {
    const selectedId = query.selected;
    await Promise.all([
      fetchBridgeEdges(),
      fetchProjectionStatus(),
      query.palaceRagSubview === 'trace-samples' ? fetchTraceSamples() : Promise.resolve(null),
      selectedId ? fetchBridgeDetail(selectedId) : Promise.resolve(null),
    ]);
  }, [fetchBridgeDetail, fetchBridgeEdges, fetchProjectionStatus, fetchTraceSamples, query.palaceRagSubview, query.selected]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'ingestion') {
      return;
    }
    void refreshIngestionSurface('load');
  }, [ingestionReloadNonce, needsCanonicalQuery, query.ingestionStatus, query.selected, query.view, refreshIngestionSurface]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'kg-review') {
      return;
    }
    void refreshKgSurface();
  }, [kgReloadNonce, needsCanonicalQuery, query.kgStatus, query.selected, query.view, refreshKgSurface]);

  useEffect(() => {
    if (needsCanonicalQuery || query.view !== 'palace-rag') {
      return;
    }
    void refreshPalaceRagSurface();
  }, [needsCanonicalQuery, palaceReloadNonce, query.palaceRagSubview, query.selected, query.view, refreshPalaceRagSurface]);

  useEffect(() => {
    if (query.view !== 'ingestion' || needsCanonicalQuery) {
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
  const selectedContradictionId = query.view === 'kg-review' ? query.selected : undefined;
  const selectedBridgeEdgeId = query.view === 'palace-rag' ? query.selected : undefined;
  const selectedIngestionNotInList =
    selectedIngestionId !== undefined &&
    !ingestionLoading &&
    ingestionError == null &&
    !ingestionJobs.some((job) => job.id === selectedIngestionId);
  const selectedContradictionNotInList =
    selectedContradictionId !== undefined &&
    !kgLoading &&
    kgError == null &&
    !kgQueueItems.some((item) => item.id === selectedContradictionId);
  const selectedBridgeEdgeNotInList =
    selectedBridgeEdgeId !== undefined &&
    !bridgeLoading &&
    bridgeError == null &&
    !bridgeEdges.some((edge) => edge.id === selectedBridgeEdgeId);

  const canShowIngestionSurface = query.view === 'ingestion';
  const canShowKgSurface = query.view === 'kg-review';
  const canShowPalaceRagSurface = query.view === 'palace-rag';
  const ingestionFreshness = readIngestionFreshnessTag({
    stale: ingestionPollStale,
    active: ingestionJobs.some((job) => isNonTerminalIngestionStatus(job.status)),
    attempt: ingestionPollAttempt,
  });
  const latestIngestionUpdate = useMemo(() => {
    const timestamps = [
      ...ingestionJobs.map((job) => job.updatedAt),
      ingestionDetail?.updatedAt,
      ingestionPollLastSuccessAt,
    ].filter((value): value is string => Boolean(value));
    return timestamps.sort((left, right) => Date.parse(right) - Date.parse(left))[0];
  }, [ingestionDetail?.updatedAt, ingestionJobs, ingestionPollLastSuccessAt]);
  const activeIngestionActionJob =
    ingestionActionState.phase === 'success'
      ? (ingestionDetail?.id === ingestionActionState.response.jobId
          ? ingestionDetail
          : ingestionJobs.find((job) => job.id === ingestionActionState.response.jobId) ?? null)
      : null;

  const resetIngestionPolling = () => {
    setIngestionPollAttempt(0);
    setIngestionPollStale(false);
    setIngestionPollReason(undefined);
    setIngestionReloadNonce((value) => value + 1);
  };

  const handleUploadFileChange = (event: ChangeEvent<HTMLInputElement>) => {
    const nextFile = event.target.files?.[0] ?? null;
    setSelectedUploadFile(nextFile);
  };

  const handleUpload = async () => {
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
      patchKnowledgeQuery(searchParams, setSearchParams, {
        selected: response.jobId,
      });
      setIngestionReloadNonce((value) => value + 1);
    } catch (error) {
      setIngestionActionState({ phase: 'error', kind: 'upload', error: toApiError(error) });
    }
  };

  const handleRetry = async () => {
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
  };

  const handleResolve = async () => {
    const contradictionId = kgDetail?.id ?? selectedContradictionId;
    if (!contradictionId) {
      setKgActionState({
        phase: 'error',
        kind: 'resolve',
        target: 'missing',
        error: new ApiError(400, 'invalid_knowledge_contradiction_id', '当前没有可处理的 contradiction。'),
      });
      return;
    }

    setKgActionState({ phase: 'pending', kind: 'resolve', target: contradictionId });
    try {
      const detail = await knowledgeOpsClient.resolveContradiction(contradictionId, resolveDraft);
      setKgActionState({ phase: 'success', kind: 'resolve', detail });
      setKgReloadNonce((value) => value + 1);
    } catch (error) {
      setKgActionState({ phase: 'error', kind: 'resolve', target: contradictionId, error: toApiError(error) });
    }
  };

  const handleMarkNotificationRead = async (notificationId: string) => {
    setKgActionState({ phase: 'pending', kind: 'mark-read', target: notificationId });
    try {
      const notification = await knowledgeOpsClient.markNotificationRead(notificationId);
      setKgActionState({ phase: 'success', kind: 'mark-read', notification });
      setKgReloadNonce((value) => value + 1);
    } catch (error) {
      setKgActionState({ phase: 'error', kind: 'mark-read', target: notificationId, error: toApiError(error) });
    }
  };

  const handleBridgeReview = async (decision: 'approve' | 'reject') => {
    const edgeId = bridgeDetail?.id ?? selectedBridgeEdgeId;
    if (!edgeId) {
      setPalaceRagAction({
        phase: 'error',
        edgeId: 'missing',
        error: new ApiError(400, 'invalid_palace_bridge_edge_id', '当前没有可操作的 bridge edge。'),
      });
      return;
    }

    setPalaceRagAction({ phase: 'pending', edgeId });
    try {
      const nextEdge =
        decision === 'approve'
          ? await knowledgeOpsClient.approveBridgeEdge(edgeId)
          : await knowledgeOpsClient.rejectBridgeEdge(edgeId);
      setBridgeDetail(nextEdge);
      setBridgeDetailError(null);
      setPalaceRagAction({ phase: 'success', edge: nextEdge });
      setPalaceReloadNonce((value) => value + 1);
    } catch (error) {
      setPalaceRagAction({ phase: 'error', edgeId, error: toApiError(error) });
    }
  };

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
                patchKnowledgeQuery(searchParams, setSearchParams, {
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
                patchKnowledgeQuery(searchParams, setSearchParams, {
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
                patchKnowledgeQuery(searchParams, setSearchParams, {
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

      <Card size="small" title="Inline diagnostics" data-testid="knowledge-inline-diagnostics">
        <Space direction="vertical" size={8} style={{ width: '100%' }}>
          <Typography.Text type="secondary">
            malformed payload 会在 client parser 边界抛出 `invalid_response_payload`；timeout 会把 ingestion surface 标成 stale；bridge 404 与
            projection notReady 会在对应子视图显式暴露，而不是静默吞掉。
          </Typography.Text>
          <Space wrap>
            {canShowIngestionSurface ? (
              <>
                <Tag color={ingestionError ? 'warning' : 'success'}>
                  list: {ingestionError ? ingestionError.code : ingestionLoading ? 'loading' : 'ready'}
                </Tag>
                <Tag color={ingestionDetailError ? 'warning' : 'success'}>
                  detail: {ingestionDetailError ? ingestionDetailError.code : ingestionDetailLoading ? 'loading' : 'ready'}
                </Tag>
                <Tag color={ingestionPollStale ? 'warning' : 'success'}>
                  poll: {ingestionPollStale ? ingestionPollReason ?? 'stale' : `${ingestionPollAttempt}/${MAX_INGESTION_POLL_ATTEMPTS}`}
                </Tag>
              </>
            ) : null}
            {canShowKgSurface ? (
              <>
                <Tag color={kgError ? 'warning' : 'success'}>kg list: {kgError ? kgError.code : kgLoading ? 'loading' : 'ready'}</Tag>
                <Tag color={kgDetailError ? 'warning' : 'success'}>
                  kg detail: {kgDetailError ? kgDetailError.code : kgDetailLoading ? 'loading' : 'ready'}
                </Tag>
                <Tag color={notificationsError ? 'warning' : 'success'}>
                  notifications: {notificationsError ? notificationsError.code : notificationsLoading ? 'loading' : 'ready'}
                </Tag>
              </>
            ) : null}
            {canShowPalaceRagSurface ? (
              <>
                <Tag color={bridgeError ? 'warning' : 'success'}>
                  bridge list: {bridgeError ? bridgeError.code : bridgeLoading ? 'loading' : 'ready'}
                </Tag>
                <Tag color={bridgeDetailError ? 'warning' : 'success'}>
                  bridge detail: {bridgeDetailError ? bridgeDetailError.code : bridgeDetailLoading ? 'loading' : 'ready'}
                </Tag>
                <Tag color={projectionError ? 'warning' : projectionStatus?.notReady ? 'default' : 'success'}>
                  projection: {projectionError ? projectionError.code : projectionLoading ? 'loading' : projectionStatus?.notReady ? 'notReady' : 'ready'}
                </Tag>
                <Tag color={tracesError ? 'warning' : 'success'}>
                  traces: {tracesError ? tracesError.code : tracesLoading ? 'loading' : query.palaceRagSubview === 'trace-samples' ? 'ready' : 'idle'}
                </Tag>
              </>
            ) : null}
          </Space>
        </Space>
      </Card>

      {canShowIngestionSurface ? (
        <>
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
                        patchKnowledgeQuery(searchParams, setSearchParams, {
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

              {canWriteIngestion ? (
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
                                  patchKnowledgeQuery(searchParams, setSearchParams, {
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
                              <Descriptions.Item label="totalChunks">{job.totalChunks}</Descriptions.Item>
                              <Descriptions.Item label="updatedAt">{formatTimestamp(job.updatedAt)}</Descriptions.Item>
                              <Descriptions.Item label="errorMessage">{job.errorMessage ?? '—'}</Descriptions.Item>
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
                      <Button data-testid="knowledge-close-ingestion-detail" onClick={() => patchKnowledgeQuery(searchParams, setSearchParams, { selected: undefined })}>
                        关闭详情
                      </Button>
                    ) : null}
                    {selectedIngestionId ? (
                      <Button data-testid="knowledge-reload-ingestion-detail" onClick={() => setIngestionReloadNonce((value) => value + 1)}>
                        重试 detail
                      </Button>
                    ) : null}
                    {selectedIngestionId && canWriteIngestion && ingestionDetail?.retryable ? (
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
      ) : null}

      {canShowPalaceRagSurface ? (
        <>
          <Card size="small" title="Palace RAG controls">
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <div>
                <Typography.Text type="secondary">sub-view</Typography.Text>
                <Space wrap style={{ marginTop: 8 }}>
                  {PALACE_RAG_VIEW_OPTIONS.map((option) => (
                    <Button
                      key={option.value}
                      data-testid={`knowledge-palace-subview-${option.value}`}
                      type={query.palaceRagSubview === option.value ? 'primary' : 'default'}
                      onClick={() =>
                        patchKnowledgeQuery(searchParams, setSearchParams, {
                          status: option.value,
                        })
                      }
                    >
                      {option.label}
                    </Button>
                  ))}
                </Space>
              </div>

              <Space wrap>
                <Button data-testid="knowledge-palace-reload" onClick={() => setPalaceReloadNonce((value) => value + 1)}>
                  重新读取 Palace surface
                </Button>
              </Space>

              <PalaceRagActionFeedback state={palaceRagAction} />
            </Space>
          </Card>

          {query.palaceRagSubview === 'bridge-review' ? (
            <QueuePageShell
              queue={
                <Card title={`Bridge review queue (${bridgeEdges.length})`} data-testid="knowledge-palace-bridge-list">
                  {bridgeError ? (
                    <Alert
                      showIcon
                      type={bridgeError.status >= 500 || bridgeError.status === 0 ? 'error' : 'warning'}
                      data-testid="knowledge-palace-bridge-list-error"
                      style={{ marginBottom: 16 }}
                      message="bridge review queue 读取失败"
                      description={
                        <Space direction="vertical" size={8}>
                          <span>{bridgeError.message}</span>
                          <Typography.Text type="secondary">错误码：{bridgeError.code}</Typography.Text>
                        </Space>
                      }
                    />
                  ) : null}

                  {selectedBridgeEdgeNotInList && !bridgeError ? (
                    <Alert
                      showIcon
                      type="warning"
                      data-testid="knowledge-palace-selected-missing"
                      style={{ marginBottom: 16 }}
                      message="当前选中的 bridge edge 不在 proposed queue 里"
                      description="可能是因为刚刚 approve / reject 后状态已变化。详情面仍会保留当前 selected edge。"
                    />
                  ) : null}

                  {bridgeLoading ? (
                    <div style={{ padding: '24px 0' }}>
                      <Spin tip="正在读取 bridge review queue…" />
                    </div>
                  ) : null}

                  {!bridgeLoading && bridgeEdges.length === 0 && !bridgeError ? (
                    <div data-testid="knowledge-palace-bridge-empty">
                      <Empty description="当前没有待审核的 bridge edges。" />
                    </div>
                  ) : null}

                  {!bridgeLoading && bridgeEdges.length > 0 ? (
                    <List
                      dataSource={bridgeEdges}
                      renderItem={(edge) => {
                        const selected = edge.id === selectedBridgeEdgeId;
                        return (
                          <List.Item key={edge.id} data-testid={`knowledge-palace-bridge-row-${edge.id}`}>
                            <Card
                              size="small"
                              style={{
                                width: '100%',
                                borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined,
                              }}
                              title={
                                <Space wrap>
                                  <Typography.Text code>{edge.id}</Typography.Text>
                                  <Tag color={palaceBridgeStatusColor(edge.status)}>{edge.status}</Tag>
                                  <Tag color="processing">confidence {formatConfidence(edge.confidence)}</Tag>
                                </Space>
                              }
                              extra={
                                <Button
                                  type={selected ? 'default' : 'primary'}
                                  data-testid={`knowledge-open-palace-bridge-${edge.id}`}
                                  onClick={() =>
                                    patchKnowledgeQuery(searchParams, setSearchParams, {
                                      selected: edge.id,
                                    })
                                  }
                                >
                                  {selected ? '已打开' : '查看详情'}
                                </Button>
                              }
                            >
                              <Descriptions column={1} size="small">
                                <Descriptions.Item label="room A">{edge.roomAWing} / {edge.roomAName}</Descriptions.Item>
                                <Descriptions.Item label="room B">{edge.roomBWing} / {edge.roomBName}</Descriptions.Item>
                                <Descriptions.Item label="source books">{edge.sourceBookA} / {edge.sourceBookB}</Descriptions.Item>
                                <Descriptions.Item label="createdAt">{formatTimestamp(edge.createdAt)}</Descriptions.Item>
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
                  title={selectedBridgeEdgeId ? `Bridge detail · ${selectedBridgeEdgeId}` : 'Bridge detail'}
                  extra={
                    <Space>
                      {selectedBridgeEdgeId ? (
                        <Button data-testid="knowledge-close-palace-bridge-detail" onClick={() => patchKnowledgeQuery(searchParams, setSearchParams, { selected: undefined })}>
                          关闭详情
                        </Button>
                      ) : null}
                      {selectedBridgeEdgeId ? (
                        <Button data-testid="knowledge-reload-palace-bridge-detail" onClick={() => setPalaceReloadNonce((value) => value + 1)}>
                          重试 detail
                        </Button>
                      ) : null}
                    </Space>
                  }
                  testId="knowledge-palace-bridge-detail"
                >
                  {!selectedBridgeEdgeId ? (
                    <div data-testid="knowledge-palace-bridge-placeholder">
                      <Empty description="从 bridge review queue 里选择一条 edge 后，这里会显示 bridge 详情与 approve / reject 操作。" />
                    </div>
                  ) : null}

                  {selectedBridgeEdgeId && bridgeDetailLoading ? (
                    <div data-testid="knowledge-palace-bridge-detail-loading" style={{ padding: '24px 0' }}>
                      <Spin tip="正在读取 bridge detail…" />
                    </div>
                  ) : null}

                  {selectedBridgeEdgeId && !bridgeDetailLoading && bridgeDetailError ? (
                    <Alert
                      showIcon
                      type={bridgeDetailError.status === 404 ? 'warning' : 'error'}
                      data-testid="knowledge-palace-bridge-detail-error"
                      message={bridgeDetailError.status === 404 ? 'bridge detail 不存在' : 'bridge detail 读取失败'}
                      description={
                        <Space direction="vertical" size={8}>
                          <span>{bridgeDetailError.message}</span>
                          <Typography.Text type="secondary">错误码：{bridgeDetailError.code}</Typography.Text>
                        </Space>
                      }
                    />
                  ) : null}

                  {bridgeDetail && !bridgeDetailLoading && !bridgeDetailError ? (
                    <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                      <Descriptions column={1} bordered size="small">
                        <Descriptions.Item label="edgeId">
                          <Typography.Text code>{bridgeDetail.id}</Typography.Text>
                        </Descriptions.Item>
                        <Descriptions.Item label="status">
                          <Tag data-testid="knowledge-palace-bridge-status" color={palaceBridgeStatusColor(bridgeDetail.status)}>
                            {bridgeDetail.status}
                          </Tag>
                        </Descriptions.Item>
                        <Descriptions.Item label="confidence">{formatConfidence(bridgeDetail.confidence)}</Descriptions.Item>
                        <Descriptions.Item label="room A">{bridgeDetail.roomAWing} / {bridgeDetail.roomAName}</Descriptions.Item>
                        <Descriptions.Item label="room B">{bridgeDetail.roomBWing} / {bridgeDetail.roomBName}</Descriptions.Item>
                        <Descriptions.Item label="sourceBookA">{bridgeDetail.sourceBookA}</Descriptions.Item>
                        <Descriptions.Item label="sourceBookB">{bridgeDetail.sourceBookB}</Descriptions.Item>
                        <Descriptions.Item label="createdAt">{formatTimestamp(bridgeDetail.createdAt)}</Descriptions.Item>
                        <Descriptions.Item label="reviewedBy">{bridgeDetail.reviewedBy ?? '—'}</Descriptions.Item>
                        <Descriptions.Item label="reviewedAt">{formatTimestamp(bridgeDetail.reviewedAt)}</Descriptions.Item>
                      </Descriptions>

                      <Card size="small" title="Bridge decision">
                        <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                          <Typography.Text type="secondary">
                            仅 `proposed` edge 可执行 approve / reject；操作后 queue 会刷新，但当前 selected context 会保留。
                          </Typography.Text>
                          <Space wrap>
                            <Button
                              type="primary"
                              data-testid="knowledge-palace-approve-bridge"
                              disabled={!canWriteIngestion || bridgeDetail.status !== 'proposed'}
                              loading={palaceRagAction.phase === 'pending' && palaceRagAction.edgeId === bridgeDetail.id}
                              onClick={() => void handleBridgeReview('approve')}
                            >
                              Approve edge
                            </Button>
                            <Button
                              danger
                              data-testid="knowledge-palace-reject-bridge"
                              disabled={!canWriteIngestion || bridgeDetail.status !== 'proposed'}
                              loading={palaceRagAction.phase === 'pending' && palaceRagAction.edgeId === bridgeDetail.id}
                              onClick={() => void handleBridgeReview('reject')}
                            >
                              Reject edge
                            </Button>
                          </Space>
                        </Space>
                      </Card>
                    </Space>
                  ) : null}
                </DetailContainer>
              }
            />
          ) : null}

          {query.palaceRagSubview === 'trace-samples' ? (
            <Card title={`Trace samples (${traceItems.length})`} data-testid="knowledge-palace-trace-list">
              {tracesError ? (
                <Alert
                  showIcon
                  type={tracesError.status >= 500 || tracesError.status === 0 ? 'error' : 'warning'}
                  data-testid="knowledge-palace-trace-error"
                  style={{ marginBottom: 16 }}
                  message="trace samples 读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{tracesError.message}</span>
                      <Typography.Text type="secondary">错误码：{tracesError.code}</Typography.Text>
                    </Space>
                  }
                />
              ) : null}

              {tracesLoading ? (
                <div style={{ padding: '24px 0' }}>
                  <Spin tip="正在读取 trace samples…" />
                </div>
              ) : null}

              {!tracesLoading && traceItems.length === 0 && !tracesError ? (
                <Empty description="当前没有可供抽样的 QueryTrace 记录。" />
              ) : null}

              {!tracesLoading && traceItems.length > 0 ? (
                <List
                  dataSource={traceItems}
                  renderItem={(trace) => {
                    const candidateCount = countTraceCandidates(trace.candidatesJson);
                    return (
                      <List.Item key={trace.id} data-testid={`knowledge-palace-trace-row-${trace.id}`}>
                        <Card size="small" style={{ width: '100%' }}>
                          <Space direction="vertical" size={8} style={{ width: '100%' }}>
                            <Space wrap>
                              <Typography.Text code>{trace.id}</Typography.Text>
                              <Tag color="processing">{trace.temporalRuleApplied ?? 'skipped'}</Tag>
                              <Tag>queriedAt: {formatTimestamp(trace.queriedAt)}</Tag>
                              <Tag>projection: {trace.projectionVersionUsed ?? '—'}</Tag>
                              <Tag>candidates: {candidateCount ?? 'unparseable'}</Tag>
                            </Space>
                            <Typography.Text type="secondary">entry_rooms</Typography.Text>
                            <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                              {trace.entryRooms}
                            </Typography.Paragraph>
                            <Typography.Text type="secondary">candidates_json</Typography.Text>
                            <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                              {trace.candidatesJson}
                            </Typography.Paragraph>
                            <Typography.Text type="secondary">
                              bridge_edges_crossed: {trace.bridgeEdgesCrossed ?? '—'}
                            </Typography.Text>
                          </Space>
                        </Card>
                      </List.Item>
                    );
                  }}
                />
              ) : null}
            </Card>
          ) : null}

          {query.palaceRagSubview === 'projection' ? (
            <Card title="Projection status" data-testid="knowledge-palace-projection-status">
              {projectionError ? (
                <Alert
                  showIcon
                  type={projectionError.status >= 500 || projectionError.status === 0 ? 'error' : 'warning'}
                  data-testid="knowledge-palace-projection-error"
                  style={{ marginBottom: 16 }}
                  message="projection status 读取失败"
                  description={
                    <Space direction="vertical" size={8}>
                      <span>{projectionError.message}</span>
                      <Typography.Text type="secondary">错误码：{projectionError.code}</Typography.Text>
                    </Space>
                  }
                />
              ) : null}

              {projectionLoading ? (
                <div style={{ padding: '24px 0' }}>
                  <Spin tip="正在读取 projection status…" />
                </div>
              ) : null}

              {!projectionLoading && projectionStatus?.notReady ? (
                <Empty description="No projection available yet — trigger a book ingestion to populate." />
              ) : null}

              {!projectionLoading && projectionStatus && !projectionStatus.notReady ? (
                <Descriptions column={1} bordered size="small">
                  <Descriptions.Item label="versionNum">{projectionStatus.versionNum ?? '—'}</Descriptions.Item>
                  <Descriptions.Item label="roomCount">{projectionStatus.roomCount ?? '—'}</Descriptions.Item>
                  <Descriptions.Item label="lastIngestionBatchId">{projectionStatus.lastIngestionBatchId ?? '—'}</Descriptions.Item>
                  <Descriptions.Item label="status">{projectionStatus.status ?? '—'}</Descriptions.Item>
                  <Descriptions.Item label="createdAt">{formatTimestamp(projectionStatus.createdAt)}</Descriptions.Item>
                </Descriptions>
              ) : null}
            </Card>
          ) : null}
        </>
      ) : null}

      {canShowKgSurface ? (
        <>
          <Card size="small" title="KG review controls">
            <Space direction="vertical" size="middle" style={{ width: '100%' }}>
              <div>
                <Typography.Text type="secondary">status filter</Typography.Text>
                <Space wrap style={{ marginTop: 8 }}>
                  {KG_VIEW_OPTIONS.map((option) => (
                    <Button
                      key={option.value}
                      data-testid={`knowledge-kg-status-${option.value}`}
                      type={query.kgStatus === option.value ? 'primary' : 'default'}
                      onClick={() =>
                        patchKnowledgeQuery(searchParams, setSearchParams, {
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
                <Button data-testid="knowledge-kg-reload" onClick={() => setKgReloadNonce((value) => value + 1)}>
                  重新读取 contradiction queue
                </Button>
              </Space>

              <KgActionFeedback state={kgActionState} />
            </Space>
          </Card>

          <QueuePageShell
            queue={
              <Card title={`KG contradictions (${kgQueueItems.length})`} data-testid="knowledge-contradiction-list">
                {kgError ? (
                  <Alert
                    showIcon
                    type={kgError.status >= 500 || kgError.status === 0 ? 'error' : 'warning'}
                    data-testid="knowledge-kg-list-error"
                    style={{ marginBottom: 16 }}
                    message="contradiction queue 读取失败"
                    description={
                      <Space direction="vertical" size={8}>
                        <span>{kgError.message}</span>
                        <Typography.Text type="secondary">错误码：{kgError.code}</Typography.Text>
                      </Space>
                    }
                  />
                ) : null}

                {selectedContradictionNotInList && !kgError ? (
                  <Alert
                    showIcon
                    type="warning"
                    data-testid="knowledge-kg-selected-missing"
                    style={{ marginBottom: 16 }}
                    message="当前选中的 contradiction 不在当前过滤结果里"
                    description="可能是因为刚刚 resolve 后状态已变化。详情和通知列表仍会保留当前 selected contradiction。"
                  />
                ) : null}

                {kgLoading ? (
                  <div style={{ padding: '24px 0' }}>
                    <Spin tip="正在读取 KG contradiction queue…" />
                  </div>
                ) : null}

                {!kgLoading && kgQueueItems.length === 0 && !kgError ? (
                  <div data-testid="knowledge-kg-empty">
                    <Empty description="当前过滤条件下没有 contradiction queue items。" />
                  </div>
                ) : null}

                {!kgLoading && kgQueueItems.length > 0 ? (
                  <List
                    dataSource={kgQueueItems}
                    renderItem={(item) => {
                      const selected = item.id === selectedContradictionId;
                      return (
                        <List.Item key={item.id} data-testid={`knowledge-kg-row-${item.id}`}>
                          <Card
                            size="small"
                            style={{
                              width: '100%',
                              borderColor: selected ? warmPaperAdmin.palette.accentDark : undefined,
                            }}
                            title={
                              <Space wrap>
                                <Typography.Text code>{item.id}</Typography.Text>
                                <Tag color={contradictionStatusColor(item.status)}>{item.status}</Tag>
                                <Tag color={item.unreadNotificationCount > 0 ? 'gold' : 'default'}>
                                  unread {item.unreadNotificationCount}
                                </Tag>
                              </Space>
                            }
                            extra={
                              <Button
                                type={selected ? 'default' : 'primary'}
                                data-testid={`knowledge-open-kg-${item.id}`}
                                onClick={() =>
                                  patchKnowledgeQuery(searchParams, setSearchParams, {
                                    selected: item.id,
                                  })
                                }
                              >
                                {selected ? '已打开' : '查看详情'}
                              </Button>
                            }
                          >
                            <Descriptions column={1} size="small">
                              <Descriptions.Item label="entityTopic">{item.entityTopic}</Descriptions.Item>
                              <Descriptions.Item label="sourceA / sourceB">
                                {item.sourceABook} / {item.sourceBBook}
                              </Descriptions.Item>
                              <Descriptions.Item label="detectedAt">{formatTimestamp(item.detectedAt)}</Descriptions.Item>
                              <Descriptions.Item label="adminNotes">{item.adminNotes ?? '—'}</Descriptions.Item>
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
                title={selectedContradictionId ? `KG detail · ${selectedContradictionId}` : 'KG detail'}
                extra={
                  <Space>
                    {selectedContradictionId ? (
                      <Button data-testid="knowledge-close-kg-detail" onClick={() => patchKnowledgeQuery(searchParams, setSearchParams, { selected: undefined })}>
                        关闭详情
                      </Button>
                    ) : null}
                    {selectedContradictionId ? (
                      <Button data-testid="knowledge-reload-kg-detail" onClick={() => setKgReloadNonce((value) => value + 1)}>
                        重试 detail
                      </Button>
                    ) : null}
                  </Space>
                }
                testId="knowledge-kg-detail"
              >
                {!selectedContradictionId ? (
                  <div data-testid="knowledge-kg-detail-placeholder">
                    <Empty description="从 contradiction queue 里选择一项后，这里会显示 detail、resolve 区与通知列表。" />
                  </div>
                ) : null}

                {selectedContradictionId && kgDetailLoading ? (
                  <div data-testid="knowledge-kg-detail-loading" style={{ padding: '24px 0' }}>
                    <Spin tip="正在读取 contradiction detail…" />
                  </div>
                ) : null}

                {selectedContradictionId && !kgDetailLoading && kgDetailError ? (
                  <Alert
                    showIcon
                    type={kgDetailError.status === 404 ? 'warning' : 'error'}
                    data-testid="knowledge-kg-detail-error"
                    message={kgDetailError.status === 404 ? 'contradiction detail 不存在' : 'contradiction detail 读取失败'}
                    description={
                      <Space direction="vertical" size={8}>
                        <span>{kgDetailError.message}</span>
                        <Typography.Text type="secondary">错误码：{kgDetailError.code}</Typography.Text>
                      </Space>
                    }
                  />
                ) : null}

                {kgDetail && !kgDetailLoading && !kgDetailError ? (
                  <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                    <Descriptions column={1} bordered size="small">
                      <Descriptions.Item label="id">
                        <Typography.Text code>{kgDetail.id}</Typography.Text>
                      </Descriptions.Item>
                      <Descriptions.Item label="entityTopic">{kgDetail.entityTopic}</Descriptions.Item>
                      <Descriptions.Item label="status">
                        <Tag data-testid="knowledge-kg-status" color={contradictionStatusColor(kgDetail.status)}>
                          {kgDetail.status}
                        </Tag>
                      </Descriptions.Item>
                      <Descriptions.Item label="sourceA / sourceB">
                        {kgDetail.sourceABook} / {kgDetail.sourceBBook}
                      </Descriptions.Item>
                      <Descriptions.Item label="detectedAt">{formatTimestamp(kgDetail.detectedAt)}</Descriptions.Item>
                      <Descriptions.Item label="reviewedAt">{formatTimestamp(kgDetail.reviewedAt)}</Descriptions.Item>
                      <Descriptions.Item label="resolvedAt">{formatTimestamp(kgDetail.resolvedAt)}</Descriptions.Item>
                      <Descriptions.Item label="notificationCount">{kgDetail.notificationCount}</Descriptions.Item>
                      <Descriptions.Item label="unreadNotificationCount">{kgDetail.unreadNotificationCount}</Descriptions.Item>
                    </Descriptions>

                    <Card size="small" title="Contradiction detail">
                      <Space direction="vertical" size={8} style={{ width: '100%' }}>
                        <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                          {kgDetail.description}
                        </Typography.Paragraph>
                        <Typography.Text type="secondary">agentReviewResult: {kgDetail.agentReviewResult ?? '—'}</Typography.Text>
                      </Space>
                    </Card>

                    <Card size="small" title="Resolve contradiction">
                      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
                        <Input.TextArea
                          data-testid="knowledge-resolve-notes"
                          rows={4}
                          value={resolveDraft}
                          disabled={!canReviewKg}
                          placeholder="可选：admin notes"
                          onChange={(event) => setResolveDraft(event.target.value)}
                        />
                        <Space wrap>
                          <Button
                            type="primary"
                            data-testid="knowledge-resolve-submit"
                            disabled={!canReviewKg || kgDetail.status === 'resolved'}
                            loading={kgActionState.phase === 'pending' && kgActionState.kind === 'resolve'}
                            onClick={() => void handleResolve()}
                          >
                            标记为已解决
                          </Button>
                          <Tag color={kgDetail.status === 'resolved' ? 'success' : 'default'}>
                            current status: {kgDetail.status}
                          </Tag>
                        </Space>
                      </Space>
                    </Card>
                  </Space>
                ) : null}

                <Card
                  size="small"
                  title={`Notifications (${notifications.length})`}
                  data-testid="knowledge-notification-list"
                  style={{ marginTop: 16 }}
                >
                  {notificationsError ? (
                    <Alert
                      showIcon
                      type={notificationsError.status >= 500 || notificationsError.status === 0 ? 'error' : 'warning'}
                      data-testid="knowledge-notification-error"
                      style={{ marginBottom: 16 }}
                      message="管理员通知读取失败"
                      description={
                        <Space direction="vertical" size={8}>
                          <span>{notificationsError.message}</span>
                          <Typography.Text type="secondary">错误码：{notificationsError.code}</Typography.Text>
                        </Space>
                      }
                    />
                  ) : null}

                  {selectedContradictionId && notificationsLoading ? (
                    <div style={{ padding: '24px 0' }}>
                      <Spin tip="正在读取 notifications…" />
                    </div>
                  ) : null}

                  {!selectedContradictionId ? (
                    <Empty description="选择一个 contradiction 后，这里会显示相关管理员通知。" />
                  ) : null}

                  {selectedContradictionId && !notificationsLoading && notifications.length === 0 && !notificationsError ? (
                    <Empty description="当前 contradiction 没有管理员通知。" />
                  ) : null}

                  {selectedContradictionId && !notificationsLoading && notifications.length > 0 ? (
                    <List
                      dataSource={notifications}
                      renderItem={(notification) => (
                        <List.Item key={notification.id} data-testid={`knowledge-notification-row-${notification.id}`}>
                          <Card size="small" style={{ width: '100%' }}>
                            <Space direction="vertical" size={8} style={{ width: '100%' }}>
                              <Space wrap>
                                <Typography.Text code>{notification.id}</Typography.Text>
                                <Tag color={notificationTypeColor(notification.notificationType)}>{notification.notificationType}</Tag>
                                <Tag color={notification.isRead ? 'success' : 'gold'}>
                                  {notification.isRead ? 'read' : 'unread'}
                                </Tag>
                              </Space>
                              <Typography.Paragraph style={{ marginBottom: 0, whiteSpace: 'pre-wrap' }}>
                                {notification.message}
                              </Typography.Paragraph>
                              <Space wrap>
                                <Typography.Text type="secondary">createdAt: {formatTimestamp(notification.createdAt)}</Typography.Text>
                                {canReviewKg && !notification.isRead ? (
                                  <Button
                                    type="primary"
                                    size="small"
                                    data-testid={`knowledge-notification-read-${notification.id}`}
                                    loading={
                                      kgActionState.phase === 'pending' &&
                                      kgActionState.kind === 'mark-read' &&
                                      kgActionState.target === notification.id
                                    }
                                    onClick={() => void handleMarkNotificationRead(notification.id)}
                                  >
                                    标记已读
                                  </Button>
                                ) : null}
                              </Space>
                            </Space>
                          </Card>
                        </List.Item>
                      )}
                    />
                  ) : null}
                </Card>
              </DetailContainer>
            }
          />
        </>
      ) : null}
    </Space>
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

function PalaceRagActionFeedback({ state }: { state: PalaceRagActionState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="knowledge-palace-feedback"
        message="正在提交 bridge edge 决策"
        description={state.edgeId}
      />
    );
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-palace-feedback"
        message="bridge edge 决策失败"
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="success"
      data-testid="knowledge-palace-feedback"
      message="bridge edge 状态已更新"
      description={`edgeId=${state.edge.id}; status=${state.edge.status}; reviewedBy=${state.edge.reviewedBy ?? '—'}; reviewedAt=${formatTimestamp(state.edge.reviewedAt)}`}
    />
  );
}

function KgActionFeedback({ state }: { state: KgActionState }) {
  if (state.phase === 'idle') {
    return null;
  }

  if (state.phase === 'pending') {
    return (
      <Alert
        showIcon
        type="info"
        data-testid="knowledge-kg-feedback"
        message={state.kind === 'resolve' ? '正在 resolve contradiction' : '正在标记通知已读'}
        description={state.target}
      />
    );
  }

  if (state.phase === 'error') {
    return (
      <Alert
        showIcon
        type="error"
        data-testid="knowledge-kg-feedback"
        message={state.kind === 'resolve' ? 'resolve 失败' : '标记已读失败'}
        description={`${state.error.message}（${state.error.code}）`}
      />
    );
  }

  if (state.kind === 'resolve') {
    return (
      <Alert
        showIcon
        type="success"
        data-testid="knowledge-kg-feedback"
        message="contradiction 已解决"
        description={`id=${state.detail.id}; status=${state.detail.status}; resolvedAt=${formatTimestamp(state.detail.resolvedAt)}; adminNotes=${state.detail.adminNotes ?? '—'}`}
      />
    );
  }

  return (
    <Alert
      showIcon
      type="success"
      data-testid="knowledge-kg-feedback"
      message="通知已标记为已读"
      description={`notificationId=${state.notification.id}; isRead=${String(state.notification.isRead)}; createdAt=${formatTimestamp(state.notification.createdAt)}`}
    />
  );
}

