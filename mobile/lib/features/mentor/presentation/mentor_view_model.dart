import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';

const _safeFallbackService = LocalMentorSuggestionService();

enum MentorPanelTab { suggestions, chat }

enum MentorPanelStatus { idle, loading, ready, fallback, error }

enum MentorChatAvailabilityCode {
  accountLoading,
  sessionUnknown,
  offline,
  timeout,
  unauthorized401,
  consentRevoked403,
  upgradeRequired426,
  malformed,
  serverError,
  accountDeleted,
  notConfigured,
}

extension MentorPanelTabLabel on MentorPanelTab {
  String get label {
    switch (this) {
      case MentorPanelTab.suggestions:
        return '建议';
      case MentorPanelTab.chat:
        return '聊天';
    }
  }
}

extension MentorPanelStatusLabel on MentorPanelStatus {
  String get label {
    switch (this) {
      case MentorPanelStatus.idle:
        return 'idle';
      case MentorPanelStatus.loading:
        return 'loading';
      case MentorPanelStatus.ready:
        return 'success';
      case MentorPanelStatus.fallback:
        return 'fallback';
      case MentorPanelStatus.error:
        return 'error';
    }
  }
}

extension MentorChatAvailabilityCodeWire on MentorChatAvailabilityCode {
  String get wireValue {
    switch (this) {
      case MentorChatAvailabilityCode.accountLoading:
        return 'account-loading';
      case MentorChatAvailabilityCode.sessionUnknown:
        return 'session-unknown';
      case MentorChatAvailabilityCode.offline:
        return 'offline';
      case MentorChatAvailabilityCode.timeout:
        return 'timeout';
      case MentorChatAvailabilityCode.unauthorized401:
        return '401';
      case MentorChatAvailabilityCode.consentRevoked403:
        return '403';
      case MentorChatAvailabilityCode.upgradeRequired426:
        return '426';
      case MentorChatAvailabilityCode.malformed:
        return 'malformed';
      case MentorChatAvailabilityCode.serverError:
        return 'server-error';
      case MentorChatAvailabilityCode.accountDeleted:
        return 'account-deleted';
      case MentorChatAvailabilityCode.notConfigured:
        return 'not-configured';
    }
  }
}

class MentorChatAvailability {
  const MentorChatAvailability({
    required this.code,
    required this.title,
    required this.detail,
    required this.phase,
    required this.retryable,
  });

  final MentorChatAvailabilityCode code;
  final String title;
  final String detail;
  final String phase;
  final bool retryable;

  String get chipLabel => 'chat · ${code.wireValue}';
}

class MentorViewModel extends ChangeNotifier {
  MentorViewModel({
    required MentorRepository repository,
    required AccountViewModel accountViewModel,
  }) : _repository = repository,
       _accountViewModel = accountViewModel,
       _chatAvailability = _deriveChatAvailability(accountViewModel) {
    _accountViewModel.addListener(_handleAccountChanged);
  }

  final MentorRepository _repository;
  final AccountViewModel _accountViewModel;

  MentorPanelTab _selectedTab = MentorPanelTab.suggestions;
  MentorPanelStatus _panelStatus = MentorPanelStatus.idle;
  MentorChatAvailability _chatAvailability;
  List<LocalMentorSuggestion> _suggestions = const <LocalMentorSuggestion>[];
  String? _bannerMessage;
  String? _bannerCode;
  String? _lastVisibleBanner;
  String? _lastErrorPhase;
  bool _lastRetryable = false;
  bool _isPanelVisible = false;
  bool _isRefreshingSuggestions = false;
  int _panelSequence = 0;
  String _lastLauncher = 'unknown';
  bool _disposed = false;

  MentorPanelTab get selectedTab => _selectedTab;
  MentorPanelStatus get panelStatus => _panelStatus;
  MentorChatAvailability get chatAvailability => _chatAvailability;
  List<LocalMentorSuggestion> get suggestions => _suggestions;
  String? get bannerMessage => _bannerMessage;
  String? get bannerCode => _bannerCode;
  String? get lastVisibleBanner => _lastVisibleBanner;
  String? get lastErrorPhase => _lastErrorPhase;
  bool get lastRetryable => _lastRetryable;
  bool get isPanelVisible => _isPanelVisible;
  bool get isLoading => _panelStatus == MentorPanelStatus.loading;
  bool get isRefreshingSuggestions => _isRefreshingSuggestions;
  String get statusChipLabel => 'state · ${_panelStatus.label}';
  String get selectedTabChipLabel => 'tab · ${_selectedTab.label}';

  Future<bool> beginPanelSession({required String launcher}) async {
    if (_isPanelVisible) {
      return false;
    }

    _isPanelVisible = true;
    _lastLauncher = launcher;
    _selectedTab = MentorPanelTab.suggestions;
    _panelStatus = MentorPanelStatus.loading;
    _suggestions = const <LocalMentorSuggestion>[];
    _syncChatAvailability(notify: false);
    _applyBanner(
      _suggestionBannerForAvailability(_chatAvailability),
      code: _chatAvailability.code.wireValue,
      retryable: _chatAvailability.retryable,
      errorPhase: _chatAvailability.phase,
    );
    final sequence = ++_panelSequence;
    notifyListeners();

    unawaited(_loadSuggestions(sequence: sequence, launcher: launcher));
    return true;
  }

  void endPanelSession() {
    if (!_isPanelVisible) {
      return;
    }
    _isPanelVisible = false;
    _panelSequence += 1;
    notifyListeners();
  }

  void selectTab(MentorPanelTab tab) {
    if (_selectedTab == tab) {
      return;
    }
    _selectedTab = tab;
    notifyListeners();
  }

  Future<void> reloadSuggestions() async {
    if (_isRefreshingSuggestions) {
      return;
    }
    _isRefreshingSuggestions = true;
    _panelStatus = MentorPanelStatus.loading;
    notifyListeners();
    final sequence = ++_panelSequence;
    try {
      await _loadSuggestions(sequence: sequence, launcher: _lastLauncher);
    } finally {
      _isRefreshingSuggestions = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> retryChatAvailability() async {
    await _accountViewModel.refreshRuntimeState(
      trigger: AccountRuntimeTrigger.manualRetry,
    );
    _syncChatAvailability();
  }

  Future<void> _loadSuggestions({
    required int sequence,
    required String launcher,
  }) async {
    final correlationId =
        'mentor_panel_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    await _appendFactSafely(
      eventType: MentorFactType.panelOpened,
      phase: 'panel_opened',
      correlationId: correlationId,
      redactedSummary: 'launcher:$launcher',
      visibleStatus: 'panel-opened',
      visibleDetail: 'Mentor 面板已打开',
    );

    LocalMentorSuggestionResult result;
    var effectiveStatus = MentorPanelStatus.ready;
    var effectiveErrorPhase = _chatAvailability.phase;
    var effectiveRetryable = _chatAvailability.retryable;
    var effectiveBanner = _suggestionBannerForAvailability(_chatAvailability);
    var effectiveBannerCode = _chatAvailability.code.wireValue;

    try {
      result = await _repository.deriveLocalSuggestions();
      if (result.contextFallbackUsed) {
        effectiveStatus = MentorPanelStatus.fallback;
        effectiveErrorPhase =
            result.fallbackReasonCode ?? 'context_fallback_used';
        effectiveRetryable = true;
        effectiveBanner = _buildFallbackBanner(
          result.fallbackReasonCode ?? 'context_fallback_used',
        );
        effectiveBannerCode =
            result.fallbackReasonCode ?? 'context_fallback_used';
        await _appendFactSafely(
          eventType: MentorFactType.contextFallbackUsed,
          phase: result.fallbackReasonCode ?? 'context_fallback_used',
          correlationId: correlationId,
          redactedSummary: result.redactedContextSummary,
          visibleStatus: 'suggestion-fallback',
          visibleDetail: '本地上下文不足，已回退到通用建议',
          retryable: true,
          contextFallbackUsed: true,
        );
      }
    } catch (_) {
      result = _safeFallbackService.derive(
        const LocalMentorSuggestionContext(
          contextFallbackUsed: true,
          fallbackReasonCode: 'suggestion_render_fallback',
        ),
      );
      effectiveStatus = MentorPanelStatus.error;
      effectiveErrorPhase = 'suggestion_render_fallback';
      effectiveRetryable = true;
      effectiveBanner = '本地上下文暂时没读出来，先给你一条稳妥的通用建议。';
      effectiveBannerCode = 'suggestion_render_fallback';
    }

    await _appendFactSafely(
      eventType: MentorFactType.suggestionServed,
      phase: effectiveErrorPhase == _chatAvailability.phase
          ? 'suggestion_served'
          : effectiveErrorPhase,
      correlationId: correlationId,
      redactedSummary: result.redactedContextSummary,
      visibleStatus: effectiveStatus == MentorPanelStatus.ready
          ? 'suggestion-ready'
          : 'suggestion-fallback',
      visibleDetail: _visibleDetailForSuggestions(result),
      retryable: effectiveRetryable,
      contextFallbackUsed: result.contextFallbackUsed,
    );

    await _appendFactSafely(
      eventType: MentorFactType.offlineFallbackServed,
      phase: _chatAvailability.phase,
      correlationId: correlationId,
      redactedSummary: 'chat_unavailable:${_chatAvailability.code.wireValue}',
      visibleStatus: _chatAvailability.code.wireValue,
      visibleDetail: _chatAvailability.detail,
      retryable: _chatAvailability.retryable,
      contextFallbackUsed: result.contextFallbackUsed,
    );

    if (!_isCurrentSequence(sequence)) {
      return;
    }

    _suggestions = List<LocalMentorSuggestion>.unmodifiable(result.suggestions);
    _panelStatus = effectiveStatus;
    _applyBanner(
      effectiveBanner,
      code: effectiveBannerCode,
      retryable: effectiveRetryable,
      errorPhase: effectiveErrorPhase,
    );
    notifyListeners();
  }

  Future<void> _appendFactSafely({
    required MentorFactType eventType,
    required String phase,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) async {
    try {
      await _repository.appendFact(
        eventType: eventType,
        phase: phase,
        correlationId: correlationId,
        redactedSummary: redactedSummary,
        visibleStatus: visibleStatus,
        visibleDetail: visibleDetail,
        retryable: retryable,
        contextFallbackUsed: contextFallbackUsed,
      );
    } catch (_) {
      // Mentor facts 失败时不阻断用户获得本地建议；诊断由 UI 状态继续暴露。
    }
  }

  void _handleAccountChanged() {
    _syncChatAvailability();
  }

  void _syncChatAvailability({bool notify = true}) {
    final next = _deriveChatAvailability(_accountViewModel);
    if (_chatAvailability.code == next.code &&
        _chatAvailability.detail == next.detail &&
        _chatAvailability.phase == next.phase &&
        _chatAvailability.retryable == next.retryable) {
      return;
    }
    _chatAvailability = next;
    if (_selectedTab == MentorPanelTab.chat) {
      _applyBanner(
        next.detail,
        code: next.code.wireValue,
        retryable: next.retryable,
        errorPhase: next.phase,
      );
    } else if (_panelStatus == MentorPanelStatus.idle ||
        _panelStatus == MentorPanelStatus.loading) {
      _applyBanner(
        _suggestionBannerForAvailability(next),
        code: next.code.wireValue,
        retryable: next.retryable,
        errorPhase: next.phase,
      );
    }
    if (notify && !_disposed) {
      notifyListeners();
    }
  }

  void _applyBanner(
    String? message, {
    required String code,
    required bool retryable,
    required String errorPhase,
  }) {
    _bannerMessage = message;
    _bannerCode = code;
    _lastVisibleBanner = message;
    _lastRetryable = retryable;
    _lastErrorPhase = errorPhase;
  }

  String _suggestionBannerForAvailability(MentorChatAvailability availability) {
    switch (availability.code) {
      case MentorChatAvailabilityCode.accountLoading:
        return '账号状态还在读取中，先把可离线使用的本地建议给你。';
      case MentorChatAvailabilityCode.sessionUnknown:
        return '当前先走离线建议；等账号与 session 确认后，再打开在线聊天。';
      case MentorChatAvailabilityCode.offline:
        return '你现在离线中，聊天不会发请求；先用下面的本地建议继续。';
      case MentorChatAvailabilityCode.timeout:
        return '聊天状态检查刚刚超时了，先保留本地建议，你稍后可以重试。';
      case MentorChatAvailabilityCode.unauthorized401:
        return '登录状态已经过期，当前先保留本地建议；重新登录后再试在线聊天。';
      case MentorChatAvailabilityCode.consentRevoked403:
        return '同意状态当前不可用，先保留本地建议；重新登录并再次同意后再试。';
      case MentorChatAvailabilityCode.upgradeRequired426:
        return '当前版本过旧，先保留本地建议；升级后才能继续在线聊天。';
      case MentorChatAvailabilityCode.malformed:
        return '聊天服务响应异常，先保留本地建议，不展示不可信内容。';
      case MentorChatAvailabilityCode.serverError:
        return '聊天服务暂时不可用，先保留本地建议，稍后再试就好。';
      case MentorChatAvailabilityCode.accountDeleted:
        return '账号已删除，当前先保留本地建议；重新注册后才能继续在线聊天。';
      case MentorChatAvailabilityCode.notConfigured:
        return '这一步先给你稳定离线建议；在线聊天会在后续任务里接进来。';
    }
  }

  String _buildFallbackBanner(String reasonCode) {
    switch (reasonCode) {
      case 'onboarding_missing':
        return '还没读到 onboarding 档案，先给你一条通用建议，不影响继续开口。';
      case 'onboarding_malformed':
      case 'onboarding_unavailable':
        return '本地档案暂时不可读，先给你一条通用建议，避免面板空白。';
      case 'starter_seed_missing':
      case 'practice_restore_failed':
      case 'practice_restore_timeout':
      case 'practice_restore_malformed':
        return '最近上下文没有完整恢复，先给你一条通用建议，稍后再试也可以。';
      case 'suggestion_render_fallback':
        return '本地上下文暂时没读出来，先给你一条稳妥的通用建议。';
      default:
        return '本地上下文暂时不完整，先给你一条稳妥的通用建议。';
    }
  }

  String _visibleDetailForSuggestions(LocalMentorSuggestionResult result) {
    if (result.contextFallbackUsed) {
      return '当前展示通用本地建议';
    }
    if (result.suggestions.isEmpty) {
      return '当前没有可展示建议';
    }
    final primary = result.suggestions.first;
    return '当前展示 ${primary.title}';
  }

  bool _isCurrentSequence(int sequence) {
    return !_disposed && _isPanelVisible && sequence == _panelSequence;
  }

  static MentorChatAvailability _deriveChatAvailability(
    AccountViewModel accountViewModel,
  ) {
    final snapshot = accountViewModel.snapshot;
    final phase = snapshot.lastSyncPhase.toLowerCase();
    final visibleError = snapshot.lastVisibleError;

    if (!accountViewModel.hasLoaded ||
        (accountViewModel.isLoading && !accountViewModel.hasLoaded)) {
      return const MentorChatAvailability(
        code: MentorChatAvailabilityCode.accountLoading,
        title: '正在读取聊天状态',
        detail: '账号状态还在加载中，先看本地建议。',
        phase: 'account_state_loading',
        retryable: false,
      );
    }

    if (phase.contains('offline')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.offline,
        title: '当前离线',
        detail: visibleError ?? '离线时不会发聊天请求，先用本地建议继续。',
        phase: 'offline',
        retryable: true,
      );
    }

    if (phase.contains('timeout')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.timeout,
        title: '聊天暂时超时',
        detail: visibleError ?? '当前先保留文字建议，你可以稍后重试。',
        phase: 'timeout',
        retryable: true,
      );
    }

    if (accountViewModel.isVersionBlocked || phase.contains('426')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.upgradeRequired426,
        title: '当前版本需要升级',
        detail: visibleError ?? '升级后才能使用在线聊天。',
        phase: 'upgrade_required_426',
        retryable: false,
      );
    }

    if (phase.contains('session_expired')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.unauthorized401,
        title: '登录已过期',
        detail: visibleError ?? '请重新登录后再试在线聊天。',
        phase: 'unauthorized_401',
        retryable: true,
      );
    }

    if (accountViewModel.isRevoked || phase.contains('consent_revoked')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.consentRevoked403,
        title: '同意状态不可用',
        detail: visibleError ?? '重新登录并再次同意后才能继续在线聊天。',
        phase: 'consent_revoked_403',
        retryable: true,
      );
    }

    if (accountViewModel.isDeleted || phase.contains('account_deleted')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.accountDeleted,
        title: '账号已删除',
        detail: visibleError ?? '重新注册后才能继续在线聊天。',
        phase: 'account_deleted',
        retryable: false,
      );
    }

    if (phase.contains('malformed')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.malformed,
        title: '服务响应异常',
        detail: visibleError ?? '当前先保留本地建议，避免展示不可信内容。',
        phase: 'malformed',
        retryable: true,
      );
    }

    if (phase.contains('server_error')) {
      return MentorChatAvailability(
        code: MentorChatAvailabilityCode.serverError,
        title: '服务暂时不可用',
        detail: visibleError ?? '当前先保留本地建议，稍后再试。',
        phase: 'server_error',
        retryable: true,
      );
    }

    if (accountViewModel.isSignedIn) {
      return const MentorChatAvailability(
        code: MentorChatAvailabilityCode.notConfigured,
        title: '在线聊天准备中',
        detail: '这一版先提供稳定的本地建议；在线聊天会在后续任务接进来。',
        phase: 'chat_not_configured',
        retryable: false,
      );
    }

    return const MentorChatAvailability(
      code: MentorChatAvailabilityCode.sessionUnknown,
      title: '聊天暂不可用',
      detail: '还没有可用 session；当前先用本地建议，不会发网络请求。',
      phase: 'session_unknown',
      retryable: false,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _accountViewModel.removeListener(_handleAccountChanged);
    super.dispose();
  }
}
