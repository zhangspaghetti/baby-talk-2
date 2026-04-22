import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MentorViewModel', () {
    test('默认落到建议 tab，并在离线时保留本地建议与 fallback facts', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: AccountSession(
              accountId: 'account_1',
              sessionId: 'session_1',
              maskedPhoneNumber: '138****1234',
              createdAt: DateTime.utc(2026, 4, 9, 8),
            ),
            pendingSyncCount: 1,
            lastSyncPhase: 'home_visible_offline',
            lastVisibleError: '当前离线，已保留本地待同步事件，可稍后重试。',
          ),
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository(
        deriveResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'starter_1',
              origin: LocalMentorSuggestionOrigin.starterPhrase,
              title: '先回到熟悉短句',
              body: '先把 Warm water. 贴在动作上，说一句就好。',
              phraseEnglish: 'Warm water.',
              reasonCode: 'starter_phrase',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.starterPhrase,
          contextFallbackUsed: false,
          redactedContextSummary:
              'starter_phrase:bath_time/bath_time_warm_water',
        ),
      );
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      final opened = await viewModel.beginPanelSession(launcher: 'shell_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(opened, isTrue);
      expect(viewModel.selectedTab, MentorPanelTab.suggestions);
      expect(
        viewModel.chatAvailability.code,
        MentorChatAvailabilityCode.offline,
      );
      expect(viewModel.suggestions, isNotEmpty);
      expect(viewModel.bannerMessage, contains('离线'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([
          MentorFactType.panelOpened,
          MentorFactType.suggestionServed,
          MentorFactType.offlineFallbackServed,
        ]),
      );
    });

    test('共享 continuity adopted/skipped 状态会暴露给面板层', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository(
        deriveResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'shared_feeding_time',
              origin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
              title: '接住家庭刚完成的练习',
              body: '次照护者刚完成一次共享练习。现在先接着喂饭时间。',
              reasonCode: 'shared_context_adopted_newer',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
          contextFallbackUsed: false,
          redactedContextSummary:
              'shared:shared_context_adopted_newer:caregiver:feeding_time',
          sharedContextStatus: const MentorSharedContextStatus(
            code: 'shared_context_adopted_newer',
            headline: '已采用家庭共享连续性',
            detail: '次照护者刚完成一次共享练习，Mentor 现在按“喂饭时间”继续。',
            adopted: true,
          ),
        ),
      );
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(viewModel.sharedContextStatus, isNotNull);
      expect(viewModel.sharedContextStatus?.adopted, isTrue);
      expect(
        viewModel.sharedContextStatus?.code,
        'shared_context_adopted_newer',
      );
    });

    test('仓储抛错时回退到安全建议并暴露 suggestion_render_fallback', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository(
        deriveError: StateError('boom'),
      );
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(viewModel.panelStatus, MentorPanelStatus.error);
      expect(viewModel.lastErrorPhase, 'suggestion_render_fallback');
      expect(viewModel.suggestions, isNotEmpty);
      expect(
        viewModel.suggestions.every((suggestion) => suggestion.isSafeFallback),
        isTrue,
      );
      expect(viewModel.bannerMessage, contains('通用建议'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        contains(MentorFactType.suggestionServed),
      );
    });

    test('账号尚未加载时，聊天状态按 loading 暴露而不是空白', () {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      final repository = _RecordingMentorRepository();
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      expect(
        viewModel.chatAvailability.code,
        MentorChatAvailabilityCode.accountLoading,
      );
      expect(viewModel.chatAvailability.detail, contains('账号状态还在加载中'));
    });

    test('在线聊天成功时会保留受控回应并记录请求/响应 facts', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository(
        deriveResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'safe_default',
              origin: LocalMentorSuggestionOrigin.safeFallback,
              title: '先把节奏放慢',
              body: '先说一句短句，然后停两秒等回应。',
              reasonCode: 'fallback',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.safeFallback,
          contextFallbackUsed: true,
          fallbackReasonCode: 'fallback',
          redactedContextSummary: 'fallback:fallback',
        ),
      );
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(
          response: MentorChatResponse(
            correlationId: 'corr_success',
            responseText: '先抱近一点，只说一句：I\'m here with you.',
            code: 'ok',
            phase: 'response_delivered',
            retryable: false,
            fallbackUsed: false,
            authenticated: false,
            rateLimit: const MentorRateLimitStatus(
              limited: false,
              limit: 3,
              remaining: 2,
              windowSeconds: 600,
            ),
            respondedAt: DateTime.utc(2026, 4, 10, 0),
          ),
        ),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      viewModel.selectTab(MentorPanelTab.chat);
      viewModel.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await viewModel.submitChat();

      expect(viewModel.chatResponseText, contains('I\'m here with you.'));
      expect(viewModel.chatResponseCode, 'ok');
      expect(viewModel.chatResponsePhase, 'response_delivered');
      expect(viewModel.chatAuthenticated, isFalse);
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([
          MentorFactType.chatRequested,
          MentorFactType.chatResponseDelivered,
        ]),
      );
    });

    test('在线聊天超时时会暴露 banner/code 并记录 chatFailed fact', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository();
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(
          error: const MentorApiException(
            kind: MentorApiFailureKind.http,
            message: 'provider timeout',
            statusCode: 504,
            code: 'provider_timeout',
            details: <String, Object?>{
              'phase': 'provider_timeout',
              'retryable': true,
            },
          ),
        ),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      viewModel.selectTab(MentorPanelTab.chat);
      viewModel.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await viewModel.submitChat();

      expect(viewModel.chatResponseText, isNull);
      expect(viewModel.chatResponseCode, 'timeout');
      expect(viewModel.chatResponsePhase, 'provider_timeout');
      expect(viewModel.bannerMessage, contains('超时'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([MentorFactType.chatRequested, MentorFactType.chatFailed]),
      );
    });

    test('TTS 不可用时会暴露诊断并记录 tts_unavailable fact', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository(
        deriveResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'safe_small_step',
              origin: LocalMentorSuggestionOrigin.safeFallback,
              title: '先做一个小动作',
              body: '先说一句 I\'m here with you. 然后停半拍。',
              phraseEnglish: 'I\'m here with you.',
              reasonCode: 'safe_small_step',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.safeFallback,
          contextFallbackUsed: true,
          fallbackReasonCode: 'fallback',
          redactedContextSummary: 'fallback:fallback',
        ),
      );
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _FakeMentorApiService(),
        audioController: _UnavailableMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await viewModel.replaySuggestion(viewModel.suggestions.first);

      expect(viewModel.audioStatusCode, 'tts_unavailable');
      expect(viewModel.audioStatusMessage, contains('当前设备不支持朗读'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        contains(MentorFactType.ttsUnavailable),
      );
    });

    test('多轮聊天：发送两次后 messages 累积 4 条，conversationId 从响应穿透保持', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository();
      final apiService = _MultiTurnFakeMentorApiService();
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: apiService,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      viewModel.selectTab(MentorPanelTab.chat);

      // 第一轮
      viewModel.updateChatDraft('宝宝一直哭，我该怎么安抚？');
      await viewModel.submitChat();

      expect(viewModel.messages.length, 2);
      expect(viewModel.messages[0].role, ChatBubbleRole.user);
      expect(viewModel.messages[0].text, '宝宝一直哭，我该怎么安抚？');
      expect(viewModel.messages[1].role, ChatBubbleRole.assistant);
      expect(viewModel.conversationId, 'conv_server_123');

      // 第二轮
      viewModel.updateChatDraft('如果宝宝还是哭呢？');
      await viewModel.submitChat();

      expect(viewModel.messages.length, 4);
      expect(viewModel.messages[2].role, ChatBubbleRole.user);
      expect(viewModel.messages[2].text, '如果宝宝还是哭呢？');
      expect(viewModel.messages[3].role, ChatBubbleRole.assistant);
      // conversationId 应该保持不变
      expect(viewModel.conversationId, 'conv_server_123');
      // chatDraft 每轮提交后应被清空
      expect(viewModel.chatDraft, '');
    });

    test('多轮聊天：beginPanelSession 重置 messages 和 conversationId', () async {
      final accountViewModel = AccountViewModel(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountViewModel.initialize();
      final repository = _RecordingMentorRepository();
      final viewModel = MentorViewModel(
        repository: repository,
        accountViewModel: accountViewModel,
        apiService: _MultiTurnFakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(viewModel.dispose);
      addTearDown(accountViewModel.dispose);

      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      viewModel.selectTab(MentorPanelTab.chat);
      viewModel.updateChatDraft('测试');
      await viewModel.submitChat();
      expect(viewModel.messages, isNotEmpty);
      expect(viewModel.conversationId, isNotNull);

      // 结束并重新开始
      viewModel.endPanelSession();
      await viewModel.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(viewModel.messages, isEmpty);
      expect(viewModel.conversationId, isNull);
    });
  });
}

class _RecordingMentorRepository implements MentorRepository {
  _RecordingMentorRepository({this.deriveResult, this.deriveError});

  final LocalMentorSuggestionResult? deriveResult;
  final Object? deriveError;
  final List<MentorFactEvent> appendedFacts = <MentorFactEvent>[];

  @override
  Future<MentorFactEvent> appendFact({
    required MentorFactType eventType,
    required String phase,
    DateTime? createdAt,
    String? localEventId,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) async {
    final fact = MentorFactEvent(
      localEventId:
          localEventId ?? 'fact_${appendedFacts.length}_${eventType.wireValue}',
      installationId: 'install_test',
      eventType: eventType,
      phase: phase,
      createdAt:
          createdAt ?? DateTime.utc(2026, 4, 9, 8, 0, appendedFacts.length),
      correlationId: correlationId,
      redactedSummary: redactedSummary,
      visibleStatus: visibleStatus,
      visibleDetail: visibleDetail,
      retryable: retryable,
      contextFallbackUsed: contextFallbackUsed,
    );
    appendedFacts.add(fact);
    return fact;
  }

  @override
  Future<LocalMentorSuggestionResult> deriveLocalSuggestions() async {
    if (deriveError != null) {
      throw deriveError!;
    }
    return deriveResult ??
        LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'safe_default',
              origin: LocalMentorSuggestionOrigin.safeFallback,
              title: '先把节奏放慢',
              body: '先说一句短句，然后停两秒等回应。',
              reasonCode: 'fallback',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.safeFallback,
          contextFallbackUsed: true,
          fallbackReasonCode: 'fallback',
          redactedContextSummary: 'fallback:fallback',
        );
  }

  @override
  Future<void> close({bool deleteFromDisk = false}) async {}

  @override
  Future<String> ensureInstallationId() async => 'install_test';

  @override
  Future<MentorFactInspection> inspectFactLog() async {
    return MentorFactInspection(
      installationId: 'install_test',
      storedFactCount: appendedFacts.length,
      validFacts: List<MentorFactEvent>.unmodifiable(appendedFacts),
      skippedFactCount: 0,
    );
  }

  @override
  Future<List<MentorFactEvent>> listFactHistory({
    MentorFactType? eventType,
    int? limit,
  }) async {
    final filtered = eventType == null
        ? appendedFacts
        : appendedFacts.where((fact) => fact.eventType == eventType).toList();
    if (limit == null || filtered.length <= limit) {
      return List<MentorFactEvent>.unmodifiable(filtered);
    }
    return List<MentorFactEvent>.unmodifiable(filtered.take(limit));
  }

  @override
  Future<String?> readExistingInstallationId() async => 'install_test';
}

class _StaticAccountRepository implements AccountRepository {
  _StaticAccountRepository({required this.seedSnapshot});

  final AccountLocalSnapshot seedSnapshot;

  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    return seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    return seedSnapshot ?? this.seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    return seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    return seedSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    return seedSnapshot;
  }

  @override
  Future<void> close() async {}
}

class _FakeMentorApiService extends MentorApiService {
  _FakeMentorApiService({this.response, this.error})
    : super(baseUri: Uri.parse('http://localhost:8080'));

  final MentorChatResponse? response;
  final MentorApiException? error;

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    String? sessionId,
    String? contextSummary,
    String? conversationId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return response ??
        MentorChatResponse(
          correlationId: correlationId,
          responseText: '先把语速放慢，说一句：I\'m here with you.',
          code: 'ok',
          phase: 'response_delivered',
          retryable: false,
          fallbackUsed: false,
          authenticated: sessionId != null,
          rateLimit: const MentorRateLimitStatus(
            limited: false,
            limit: 3,
            remaining: 2,
            windowSeconds: 600,
          ),
          respondedAt: DateTime.utc(2026, 4, 10, 0),
          conversationId: conversationId ?? 'conv_test_001',
        );
  }

  @override
  Future<void> close() async {}
}

class _SilentMentorAudioController implements MentorAudioController {
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> ensureAvailable() async => true;

  @override
  Future<void> speakText(String text) async {}

  @override
  Future<void> stop() async {}
}

class _UnavailableMentorAudioController implements MentorAudioController {
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> ensureAvailable() async => false;

  @override
  Future<void> speakText(String text) async {
    throw const MentorAudioException(
      kind: MentorAudioFailureKind.unavailable,
      message: '当前设备不支持朗读。',
    );
  }

  @override
  Future<void> stop() async {}
}

/// 多轮聊天测试用的 Fake API Service，记录收到的 conversationId 并始终返回固定 conversationId。
class _MultiTurnFakeMentorApiService extends MentorApiService {
  _MultiTurnFakeMentorApiService()
    : super(baseUri: Uri.parse('http://localhost:8080'));

  final List<String?> receivedConversationIds = <String?>[];
  int _callCount = 0;

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    String? sessionId,
    String? contextSummary,
    String? conversationId,
  }) async {
    receivedConversationIds.add(conversationId);
    _callCount++;
    return MentorChatResponse(
      correlationId: 'corr_multi_$_callCount',
      responseText: '回复第$_callCount轮：先抱近一点，说 I\'m here.',
      code: 'ok',
      phase: 'response_delivered',
      retryable: false,
      fallbackUsed: false,
      authenticated: false,
      rateLimit: const MentorRateLimitStatus(
        limited: false,
        limit: 3,
        remaining: 2,
        windowSeconds: 600,
      ),
      respondedAt: DateTime.utc(2026, 4, 10, 0),
      conversationId: 'conv_server_123',
    );
  }

  @override
  Future<void> close() async {}
}
