import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart'
    show AccountRuntimeTrigger;
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';

const _safeFallbackService = LocalMentorSuggestionService();

enum MentorPanelTab { suggestions, chat }

enum MentorPanelStatus { idle, loading, ready, fallback, error }

enum MentorChatAvailabilityCode { accountLoading, ready, offline }

/// 聊天气泡展示数据，供 UI 层使用。
enum ChatBubbleRole { user, assistant }

class ChatBubbleData {
  const ChatBubbleData({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  final ChatBubbleRole role;
  final String text;
  final DateTime timestamp;
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
      case MentorChatAvailabilityCode.ready:
        return 'ready';
      case MentorChatAvailabilityCode.offline:
        return 'offline';
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
    required this.canSubmit,
  });

  final MentorChatAvailabilityCode code;
  final String title;
  final String detail;
  final String phase;
  final bool retryable;
  final bool canSubmit;

  String get chipLabel => 'chat · ${code.wireValue}';
}

class MentorChatFailureSurface {
  const MentorChatFailureSurface({
    required this.code,
    required this.phase,
    required this.message,
    required this.retryable,
  });

  final String code;
  final String phase;
  final String message;
  final bool retryable;
}

class MentorNotifier extends ChangeNotifier {
  MentorNotifier({
    required MentorRepository repository,
    required AccountNotifier accountNotifier,
    MentorApiService? apiService,
    MentorAudioController? audioController,
    PersistRefreshedSession? persistRefreshedSession,
  }) : _repository = repository,
       _accountNotifier = accountNotifier,
       _apiService = apiService ?? MentorApiService(),
       _audioController = audioController ?? FlutterTtsMentorAudioController(),
       _persistRefreshedSession = persistRefreshedSession,
       _ownsApiService = apiService == null,
       _ownsAudioController = audioController == null,
       _chatAvailability = _deriveChatAvailability(accountNotifier) {
    _accountNotifier.addListener(_handleAccountChanged);
  }

  final MentorRepository _repository;
  final AccountNotifier _accountNotifier;
  final MentorApiService _apiService;
  final MentorAudioController _audioController;
  final PersistRefreshedSession? _persistRefreshedSession;
  final bool _ownsApiService;
  final bool _ownsAudioController;

  MentorPanelTab _selectedTab = MentorPanelTab.suggestions;
  MentorPanelStatus _panelStatus = MentorPanelStatus.idle;
  MentorChatAvailability _chatAvailability;
  List<LocalMentorSuggestion> _suggestions = const <LocalMentorSuggestion>[];
  MentorSharedContextStatus? _sharedContextStatus;
  String? _bannerMessage;
  String? _bannerCode;
  String? _lastVisibleBanner;
  String? _lastErrorPhase;
  bool _lastRetryable = false;
  bool _isPanelVisible = false;
  bool _isRefreshingSuggestions = false;
  int _panelSequence = 0;
  String _lastLauncher = 'unknown';
  String _lastSurface = 'home';
  bool _disposed = false;

  String _chatDraft = '';
  bool _isSubmittingChat = false;
  String? _chatResponseText;
  String? _chatResponseCode;
  String? _chatResponsePhase;
  String? _chatCorrelationId;
  bool _chatFallbackUsed = false;
  bool _chatAuthenticated = false;
  MentorRateLimitStatus? _chatRateLimit;

  String? _conversationId;
  List<ChatBubbleData> _messages = <ChatBubbleData>[];

  bool _isSpeaking = false;
  String? _audioStatusMessage;
  String? _audioStatusCode;

  MentorPanelTab get selectedTab => _selectedTab;
  MentorPanelStatus get panelStatus => _panelStatus;
  MentorChatAvailability get chatAvailability => _chatAvailability;
  List<LocalMentorSuggestion> get suggestions => _suggestions;
  MentorSharedContextStatus? get sharedContextStatus => _sharedContextStatus;
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

  String get chatDraft => _chatDraft;
  bool get isSubmittingChat => _isSubmittingChat;
  bool get canSubmitChat =>
      !_isSubmittingChat &&
      _chatAvailability.canSubmit &&
      _chatDraft.trim().isNotEmpty;
  String? get chatResponseText => _chatResponseText;
  String? get chatResponseCode => _chatResponseCode;
  String? get chatResponsePhase => _chatResponsePhase;
  String? get chatCorrelationId => _chatCorrelationId;
  bool get chatFallbackUsed => _chatFallbackUsed;
  bool get chatAuthenticated => _chatAuthenticated;
  MentorRateLimitStatus? get chatRateLimit => _chatRateLimit;

  String? get conversationId => _conversationId;
  List<ChatBubbleData> get messages =>
      List<ChatBubbleData>.unmodifiable(_messages);

  bool get isSpeaking => _isSpeaking;
  String? get audioStatusMessage => _audioStatusMessage;
  String? get audioStatusCode => _audioStatusCode;

  Future<List<MentorFactEvent>> listFactHistory({
    MentorFactType? eventType,
    int? limit,
  }) {
    return _repository.listFactHistory(eventType: eventType, limit: limit);
  }

  Future<bool> beginPanelSession({
    required String launcher,
    String surface = 'home',
  }) async {
    if (_isPanelVisible) {
      return false;
    }

    _isPanelVisible = true;
    _lastLauncher = launcher;
    _lastSurface = surface;
    _selectedTab = MentorPanelTab.suggestions;
    _panelStatus = MentorPanelStatus.loading;
    _suggestions = const <LocalMentorSuggestion>[];
    _sharedContextStatus = null;
    _chatDraft = '';
    _chatResponseText = null;
    _chatResponseCode = null;
    _chatResponsePhase = null;
    _chatCorrelationId = null;
    _chatFallbackUsed = false;
    _chatAuthenticated = false;
    _chatRateLimit = null;
    _conversationId = null;
    _messages = <ChatBubbleData>[];
    _audioStatusMessage = null;
    _audioStatusCode = null;
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
    if (tab == MentorPanelTab.chat && _chatResponseText == null) {
      _applyBanner(
        _chatAvailability.detail,
        code: _chatAvailability.code.wireValue,
        retryable: _chatAvailability.retryable,
        errorPhase: _chatAvailability.phase,
      );
    }
    notifyListeners();
  }

  void updateChatDraft(String value) {
    if (_chatDraft == value) {
      return;
    }
    _chatDraft = value;
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
    await _accountNotifier.refreshRuntimeState(
      trigger: AccountRuntimeTrigger.manualRetry,
    );
    _syncChatAvailability();
  }

  Future<void> submitChat() async {
    final prompt = _chatDraft.trim();
    if (prompt.isEmpty) {
      _applyBanner(
        '先写下你现在卡住的那一句，Mentor 才能给出受控回应。',
        code: 'missing_prompt',
        retryable: false,
        errorPhase: 'missing_prompt',
      );
      notifyListeners();
      return;
    }
    if (prompt.length > mentorPromptMaxLength) {
      _applyBanner(
        '这次求助请控制在 $mentorPromptMaxLength 个字以内，避免把不必要的细节发出去。',
        code: 'prompt_too_long',
        retryable: false,
        errorPhase: 'prompt_too_long',
      );
      notifyListeners();
      return;
    }
    if (_isSubmittingChat) {
      return;
    }
    if (!_chatAvailability.canSubmit) {
      _applyBanner(
        _chatAvailability.detail,
        code: _chatAvailability.code.wireValue,
        retryable: _chatAvailability.retryable,
        errorPhase: _chatAvailability.phase,
      );
      await _appendFactSafely(
        eventType: MentorFactType.chatFailed,
        phase: _chatAvailability.phase,
        redactedSummary: 'preflight:${_chatAvailability.code.wireValue}',
        visibleStatus: _chatAvailability.code.wireValue,
        visibleDetail: _chatAvailability.detail,
        retryable: _chatAvailability.retryable,
      );
      notifyListeners();
      return;
    }

    _isSubmittingChat = true;
    _selectedTab = MentorPanelTab.chat;
    _chatResponseText = null;
    _chatResponseCode = null;
    _chatResponsePhase = null;
    _chatCorrelationId = null;
    _chatFallbackUsed = false;
    _chatAuthenticated = false;
    _chatRateLimit = null;
    // 多轮聊天：追加用户消息到气泡列表
    _messages = List<ChatBubbleData>.from(_messages)
      ..add(
        ChatBubbleData(
          role: ChatBubbleRole.user,
          text: prompt,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    _applyBanner(
      '正在向小禾老师请求一次受控回应…',
      code: 'chat_requesting',
      retryable: false,
      errorPhase: 'chat_requesting',
    );
    notifyListeners();

    final correlationId =
        'mentor_chat_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final installationId = await _repository.ensureInstallationId();
    final session = _accountNotifier.isSignedIn
        ? _accountNotifier.snapshot.session
        : null;

    await _appendFactSafely(
      eventType: MentorFactType.chatRequested,
      phase: 'chat_requested',
      correlationId: correlationId,
      redactedSummary:
          'surface:$_lastSurface;len:${prompt.length};auth:${session == null ? 'anon' : 'cookie'}',
      visibleStatus: 'chat-requested',
      visibleDetail: '正在请求一次受控回应',
    );

    try {
      final response = await _apiService.sendChat(
        installationId: installationId,
        prompt: prompt,
        surface: _lastSurface,
        mode: 'single_turn',
        correlationId: correlationId,
        session: session,
        persistRefreshedSession: _persistRefreshedSession,
        contextSummary: _buildContextSummary(),
        conversationId: _conversationId,
      );

      _chatResponseText = response.responseText;
      _chatResponseCode = response.code;
      _chatResponsePhase = response.phase;
      _chatCorrelationId = response.correlationId;
      _chatFallbackUsed = response.fallbackUsed;
      _chatAuthenticated = response.authenticated;
      _chatRateLimit = response.rateLimit;
      // 多轮聊天：更新 conversationId 并追加 AI 回复
      if (response.conversationId != null) {
        _conversationId = response.conversationId;
      }
      _messages = List<ChatBubbleData>.from(_messages)
        ..add(
          ChatBubbleData(
            role: ChatBubbleRole.assistant,
            text: response.responseText,
            timestamp: DateTime.now().toUtc(),
          ),
        );
      _chatDraft = '';
      _panelStatus = response.fallbackUsed
          ? MentorPanelStatus.fallback
          : MentorPanelStatus.ready;
      _applyBanner(
        response.fallbackUsed ? '这次回应已被安全降级成可直接读出的文字建议。' : null,
        code: response.code,
        retryable: response.retryable,
        errorPhase: response.phase,
      );

      await _appendFactSafely(
        eventType: MentorFactType.chatResponseDelivered,
        phase: response.phase,
        correlationId: response.correlationId,
        redactedSummary:
            'code:${response.code};len:${response.responseText.length};auth:${response.authenticated}',
        visibleStatus: response.code,
        visibleDetail: response.fallbackUsed ? '已展示安全降级回应' : '已展示受控回应',
        retryable: response.retryable,
      );
    } on MentorApiException catch (error) {
      final surface = _mapChatFailure(error);
      _panelStatus = MentorPanelStatus.error;
      _chatResponseText = null;
      _chatResponseCode = surface.code;
      _chatResponsePhase = surface.phase;
      _chatCorrelationId = error.correlationId ?? correlationId;
      _chatFallbackUsed = false;
      _chatAuthenticated = session != null;
      _chatRateLimit = null;
      _applyBanner(
        surface.message,
        code: surface.code,
        retryable: surface.retryable,
        errorPhase: surface.phase,
      );

      await _appendFactSafely(
        eventType: MentorFactType.chatFailed,
        phase: surface.phase,
        correlationId: error.correlationId ?? correlationId,
        redactedSummary:
            'code:${surface.code};status:${error.statusCode ?? 'none'}',
        visibleStatus: surface.code,
        visibleDetail: surface.message,
        retryable: surface.retryable,
      );
    } finally {
      _isSubmittingChat = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> replaySuggestion(LocalMentorSuggestion suggestion) {
    final text = _composeSuggestionAudioText(suggestion);
    return _speakText(
      text: text,
      correlationId: null,
      summary: 'suggestion:${suggestion.suggestionId};len:${text.length}',
      visibleDetail: '正在朗读建议「${suggestion.title}」',
    );
  }

  Future<void> replayChatResponse() async {
    final text = _chatResponseText?.trim();
    if (text == null || text.isEmpty) {
      return;
    }
    await _speakText(
      text: text,
      correlationId: _chatCorrelationId,
      summary:
          'chat_response:${_chatResponseCode ?? 'unknown'};len:${text.length}',
      visibleDetail: '正在朗读受控聊天回应',
    );
  }

  Future<void> _speakText({
    required String text,
    required String summary,
    required String visibleDetail,
    String? correlationId,
  }) async {
    if (_isSpeaking) {
      return;
    }
    _isSpeaking = true;
    _audioStatusMessage = null;
    _audioStatusCode = null;
    notifyListeners();

    try {
      await _audioController.speakText(text);
      await _appendFactSafely(
        eventType: MentorFactType.ttsPlayed,
        phase: 'tts_played',
        correlationId: correlationId,
        redactedSummary: summary,
        visibleStatus: 'tts-played',
        visibleDetail: visibleDetail,
      );
    } on MentorAudioException catch (error) {
      final phase = error.isUnavailable ? 'tts_unavailable' : 'tts_failed';
      _audioStatusMessage = error.message;
      _audioStatusCode = phase;
      await _appendFactSafely(
        eventType: MentorFactType.ttsUnavailable,
        phase: phase,
        correlationId: correlationId,
        redactedSummary: summary,
        visibleStatus: phase,
        visibleDetail: error.message,
        retryable: !error.isUnavailable,
      );
    } finally {
      _isSpeaking = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
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
      redactedSummary: 'launcher:$launcher;surface:$_lastSurface',
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

    if (_chatAvailability.code == MentorChatAvailabilityCode.offline) {
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
    }

    if (!_isCurrentSequence(sequence)) {
      return;
    }

    _suggestions = List<LocalMentorSuggestion>.unmodifiable(result.suggestions);
    _sharedContextStatus = result.sharedContextStatus;
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
      // Mentor facts 失败时不阻断用户获得建议 / 聊天 / TTS；诊断由 UI 状态继续暴露。
    }
  }

  void _handleAccountChanged() {
    _syncChatAvailability();
  }

  void _syncChatAvailability({bool notify = true}) {
    final next = _deriveChatAvailability(_accountNotifier);
    if (_chatAvailability.code == next.code &&
        _chatAvailability.detail == next.detail &&
        _chatAvailability.phase == next.phase &&
        _chatAvailability.retryable == next.retryable &&
        _chatAvailability.canSubmit == next.canSubmit) {
      return;
    }
    _chatAvailability = next;
    if (_selectedTab == MentorPanelTab.chat && _chatResponseText == null) {
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
      case MentorChatAvailabilityCode.ready:
        return '先给你离线也能用的本地建议；网络稳定时你也可以直接切到聊天。';
      case MentorChatAvailabilityCode.offline:
        return '你现在离线中，聊天不会发请求；先用下面的本地建议继续。';
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
    if (result.sharedContextStatus?.adopted ?? false) {
      return '当前展示共享 continuity 建议';
    }
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

  String _composeSuggestionAudioText(LocalMentorSuggestion suggestion) {
    final phrase = suggestion.phraseEnglish?.trim();
    if (phrase != null && phrase.isNotEmpty) {
      return phrase;
    }
    return suggestion.body.trim();
  }

  String? _buildContextSummary() {
    if (_suggestions.isEmpty) {
      return _sharedContextStatus == null
          ? null
          : 'shared:${_sharedContextStatus!.code}';
    }
    final primary = _suggestions.first;
    final sharedSegment = _sharedContextStatus == null
        ? ''
        : ';shared:${_sharedContextStatus!.code}';
    return 'suggestion:${primary.suggestionId};reason:${primary.reasonCode ?? 'none'}$sharedSegment';
  }

  MentorChatFailureSurface _mapChatFailure(MentorApiException error) {
    if (error.isOffline) {
      return const MentorChatFailureSurface(
        code: 'offline',
        phase: 'offline',
        message: '当前离线，暂时发不出 Mentor 求助。先用本地建议继续。',
        retryable: true,
      );
    }
    if (error.isTimeout) {
      return MentorChatFailureSurface(
        code: 'timeout',
        phase: error.phase ?? 'provider_timeout',
        message: '小禾老师这次回应超时了，先别等，继续用本地建议，稍后可重试。',
        retryable: true,
      );
    }
    if (error.isUnauthorized) {
      return MentorChatFailureSurface(
        code: '401',
        phase: error.phase ?? 'invalid_session',
        message: '登录状态已经失效；重新登录后再试一次受控聊天。',
        retryable: true,
      );
    }
    if (error.isConsentRevoked) {
      return MentorChatFailureSurface(
        code: '403',
        phase: error.phase ?? 'consent_revoked',
        message: '当前账号同意状态不可用；重新登录并再次同意后再试。',
        retryable: true,
      );
    }
    if (error.isVersionBlocked) {
      return MentorChatFailureSurface(
        code: '426',
        phase: error.phase ?? 'app_version_unsupported',
        message: '当前版本过旧，升级后才能继续使用在线聊天。',
        retryable: false,
      );
    }
    if (error.isRateLimited) {
      return MentorChatFailureSurface(
        code: 'rate-limited',
        phase: error.phase ?? 'rate_limited',
        message: '刚刚已经求助过一次了，先用当前建议继续，稍后再试。',
        retryable: true,
      );
    }
    if (error.isMalformed) {
      return MentorChatFailureSurface(
        code: 'malformed',
        phase: error.phase ?? 'provider_malformed_response',
        message: '这次返回内容不可信，已拦下不展示；你可以稍后重试。',
        retryable: true,
      );
    }
    if (error.code == 'blocked_fallback') {
      return MentorChatFailureSurface(
        code: 'blocked-fallback',
        phase: error.phase ?? 'blocked_fallback',
        message: '这次问题触发了安全边界，系统已改用更稳妥的回应方式。',
        retryable: false,
      );
    }
    return MentorChatFailureSurface(
      code: 'server-error',
      phase: error.phase ?? 'server_error',
      message: '聊天服务暂时不可用，先保留文字建议，稍后再试。',
      retryable: error.isRetryable || error.isServerFailure,
    );
  }

  static MentorChatAvailability _deriveChatAvailability(
    AccountNotifier accountNotifier,
  ) {
    final snapshot = accountNotifier.snapshot;
    final phase = snapshot.lastSyncPhase.toLowerCase();

    if (!accountNotifier.hasLoaded ||
        (accountNotifier.isLoading && !accountNotifier.hasLoaded)) {
      return const MentorChatAvailability(
        code: MentorChatAvailabilityCode.accountLoading,
        title: '正在读取聊天状态',
        detail: '账号状态还在加载中，先看本地建议。',
        phase: 'account_state_loading',
        retryable: false,
        canSubmit: false,
      );
    }

    if (phase.contains('offline')) {
      return const MentorChatAvailability(
        code: MentorChatAvailabilityCode.offline,
        title: '当前离线',
        detail: '离线时不会发聊天请求，先用本地建议继续。',
        phase: 'offline',
        retryable: true,
        canSubmit: false,
      );
    }

    return const MentorChatAvailability(
      code: MentorChatAvailabilityCode.ready,
      title: '可以发起一次受控聊天',
      detail: '你可以直接描述当下卡住的场景，Mentor 会返回一条安全文本回应。',
      phase: 'ready',
      retryable: false,
      canSubmit: true,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _accountNotifier.removeListener(_handleAccountChanged);
    if (_ownsApiService) {
      _apiService.close();
    }
    if (_ownsAudioController) {
      unawaited(_audioController.dispose());
    }
    super.dispose();
  }
}
