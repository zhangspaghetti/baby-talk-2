import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MentorNotifier', () {
    test('默认落到建议 tab，并在离线时保留本地建议与 fallback facts', () async {
      final accountNotifier = AccountNotifier(
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
            lastVisibleError: '当前离线，已保留本机待同步记录，可稍后重试。',
          ),
        ),
      );
      await accountNotifier.initialize();
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
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      final opened = await notifier.beginPanelSession(launcher: 'shell_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(opened, isTrue);
      expect(notifier.selectedTab, MentorPanelTab.suggestions);
      expect(
        notifier.chatAvailability.code,
        MentorChatAvailabilityCode.offline,
      );
      expect(notifier.suggestions, isNotEmpty);
      expect(notifier.bannerMessage, contains('离线'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([
          MentorFactType.panelOpened,
          MentorFactType.suggestionServed,
          MentorFactType.offlineFallbackServed,
        ]),
      );
    });

    test('共享建议 adopted/skipped 状态会暴露给面板层', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountNotifier.initialize();
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
            headline: '已采用家庭共享建议',
            detail: '次照护者刚完成一次共享练习，导师现在按“喂饭时间”继续。',
            adopted: true,
          ),
        ),
      );
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.sharedContextStatus, isNotNull);
      expect(notifier.sharedContextStatus?.adopted, isTrue);
      expect(
        notifier.sharedContextStatus?.code,
        'shared_context_adopted_newer',
      );
    });

    test('仓储抛错时回退到安全建议并暴露 suggestion_render_fallback', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository(
        deriveError: StateError('boom'),
      );
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.panelStatus, MentorPanelStatus.error);
      expect(notifier.lastErrorPhase, 'suggestion_render_fallback');
      expect(notifier.suggestions, isNotEmpty);
      expect(
        notifier.suggestions.every((suggestion) => suggestion.isSafeFallback),
        isTrue,
      );
      expect(notifier.bannerMessage, contains('通用建议'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        contains(MentorFactType.suggestionServed),
      );
    });

    test('账号尚未加载时，聊天状态按 loading 暴露而不是空白', () {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      final repository = _RecordingMentorRepository();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _FakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      expect(
        notifier.chatAvailability.code,
        MentorChatAvailabilityCode.accountLoading,
      );
      expect(notifier.chatAvailability.detail, contains('账号状态还在加载中'));
    });

    test('已登录且已同意的在线聊天成功时会保留受控回应并记录请求/响应 facts', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _jwtSession(sessionId: 'session_success'),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
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
      final apiService = _FakeMentorApiService(
        response: MentorChatResponse(
          correlationId: 'corr_success',
          responseText: '先抱近一点，只说一句：I\'m here with you.',
          code: 'ok',
          phase: 'response_delivered',
          retryable: false,
          fallbackUsed: false,
          authenticated: true,
          rateLimit: const MentorRateLimitStatus(
            limited: false,
            limit: 3,
            remaining: 2,
            windowSeconds: 600,
          ),
          respondedAt: DateTime.utc(2026, 4, 10, 0),
        ),
      );
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: apiService,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await notifier.submitChat();

      expect(notifier.chatResponseText, contains('I\'m here with you.'));
      expect(notifier.chatResponseCode, 'ok');
      expect(notifier.chatResponsePhase, 'response_delivered');
      expect(notifier.chatAuthenticated, isTrue);
      expect(apiService.receivedSessions.single?.sessionId, 'session_success');
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([
          MentorFactType.chatRequested,
          MentorFactType.chatResponseDelivered,
        ]),
      );
    });

    test('REFACTOR-007: 未登录或未同意状态会 fail closed 且不调用 Mentor API', () async {
      final scenarios = <_ConsentChatScenario>[
        _ConsentChatScenario(
          label: 'local_only_without_session',
          snapshot: AccountLocalSnapshot.localOnly,
          expectedCode: MentorChatAvailabilityCode.loginRequired,
          expectedPhase: 'mentor_login_required',
        ),
        _ConsentChatScenario(
          label: 'signed_out_without_session',
          snapshot: AccountLocalSnapshot.signedOut,
          expectedCode: MentorChatAvailabilityCode.loginRequired,
          expectedPhase: 'mentor_login_required',
        ),
        _ConsentChatScenario(
          label: 'revoked_with_session',
          snapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.revoked,
            session: _jwtSession(sessionId: 'session_revoked'),
            lastSyncPhase: 'consent_revoked',
          ),
          expectedCode: MentorChatAvailabilityCode.consentRequired,
          expectedPhase: 'mentor_consent_required',
        ),
        _ConsentChatScenario(
          label: 'deleted_with_session',
          snapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.deleted,
            session: _jwtSession(sessionId: 'session_deleted'),
            lastSyncPhase: 'account_deleted',
          ),
          expectedCode: MentorChatAvailabilityCode.consentRequired,
          expectedPhase: 'mentor_consent_required',
        ),
        _ConsentChatScenario(
          label: 'accepted_without_jwt_tokens',
          snapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: AccountSession(
              accountId: 'account_legacy',
              sessionId: 'session_legacy',
              maskedPhoneNumber: '138****1234',
              createdAt: DateTime.utc(2026, 4, 10, 8),
            ),
            lastSyncPhase: 'batch_ack_applied',
          ),
          expectedCode: MentorChatAvailabilityCode.loginRequired,
          expectedPhase: 'mentor_session_required',
        ),
      ];

      for (final scenario in scenarios) {
        final accountNotifier = AccountNotifier(
          repository: _StaticAccountRepository(seedSnapshot: scenario.snapshot),
        );
        await accountNotifier.initialize();
        final repository = _RecordingMentorRepository();
        final apiService = _FakeMentorApiService();
        final notifier = MentorNotifier(
          repository: repository,
          accountNotifier: accountNotifier,
          apiService: apiService,
          audioController: _SilentMentorAudioController(),
        );
        addTearDown(notifier.dispose);
        addTearDown(accountNotifier.dispose);

        await notifier.beginPanelSession(launcher: 'home_fab');
        await Future<void>.delayed(const Duration(milliseconds: 1));
        notifier.selectTab(MentorPanelTab.chat);
        notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

        expect(
          notifier.chatAvailability.code,
          scenario.expectedCode,
          reason: scenario.label,
        );
        expect(notifier.chatAvailability.phase, scenario.expectedPhase);
        expect(notifier.canSubmitChat, isFalse, reason: scenario.label);

        await notifier.submitChat();

        expect(apiService.receivedSessions, isEmpty, reason: scenario.label);
        expect(notifier.chatResponseText, isNull, reason: scenario.label);
        expect(notifier.bannerCode, scenario.expectedCode.wireValue);
        expect(
          repository.appendedFacts.where(
            (fact) =>
                fact.eventType == MentorFactType.chatFailed &&
                fact.phase == scenario.expectedPhase,
          ),
          isNotEmpty,
          reason: scenario.label,
        );
      }
    });

    test('REFACTOR-005 baseline: offline preflight 不会调用 Mentor API', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _jwtSession(sessionId: 'session_offline'),
            lastSyncPhase: 'home_visible_offline',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final apiService = _FakeMentorApiService();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: apiService,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      expect(
        notifier.chatAvailability.code,
        MentorChatAvailabilityCode.offline,
      );
      expect(notifier.canSubmitChat, isFalse);

      await notifier.submitChat();

      expect(apiService.receivedSessions, isEmpty);
      expect(notifier.chatResponseText, isNull);
      expect(notifier.bannerCode, 'offline');
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        contains(MentorFactType.chatFailed),
      );
      expect(
        repository.appendedFacts.where(
          (fact) => fact.phase == 'offline' && fact.visibleStatus == 'offline',
        ),
        isNotEmpty,
      );
    });

    test('已登录聊天会复用 JWT session seam，并把 authenticated=true 反馈给 UI', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: AccountSession(
              accountId: 'account_signed_in',
              sessionId: 'session_signed_in',
              maskedPhoneNumber: '138****1234',
              createdAt: DateTime.utc(2026, 4, 10, 8),
              accessToken: 'access-live',
              refreshToken: 'refresh-live',
              tokenType: 'Cookie',
              accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
              refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
            ),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final apiService = _FakeMentorApiService();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: apiService,
        persistRefreshedSession: (refreshedSession) async => refreshedSession,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await notifier.submitChat();

      expect(notifier.chatAuthenticated, isTrue);
      expect(notifier.chatResponseCode, 'ok');
      expect(apiService.receivedSessions.single?.accessToken, 'access-live');
    });

    test('已登录聊天遇到 401 时会保留旧 banner 语义并标记 authenticated path', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: AccountSession(
              accountId: 'account_signed_in',
              sessionId: 'session_signed_in',
              maskedPhoneNumber: '138****1234',
              createdAt: DateTime.utc(2026, 4, 10, 8),
              accessToken: 'access-live',
              refreshToken: 'refresh-live',
              tokenType: 'Cookie',
              accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
              refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
            ),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final apiService = _FakeMentorApiService(
        error: const MentorApiException(
          kind: MentorApiFailureKind.http,
          message: 'unauthorized',
          statusCode: 401,
          code: 'invalid_session',
          details: <String, Object?>{'phase': 'invalid_session'},
        ),
      );
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: apiService,
        persistRefreshedSession: (refreshedSession) async => refreshedSession,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await notifier.submitChat();

      expect(notifier.chatAuthenticated, isTrue);
      expect(notifier.chatResponseCode, '401');
      expect(notifier.bannerMessage, contains('重新登录'));
      expect(
        apiService.receivedSessions.single?.sessionId,
        'session_signed_in',
      );
    });

    test('在线聊天超时时会暴露 banner/code 并记录 chatFailed fact', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _jwtSession(sessionId: 'session_timeout'),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
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
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('宝宝一直哭，我现在该怎么说？');

      await notifier.submitChat();

      expect(notifier.chatResponseText, isNull);
      expect(notifier.chatResponseCode, 'timeout');
      expect(notifier.chatResponsePhase, 'provider_timeout');
      expect(notifier.bannerMessage, contains('超时'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        containsAll([MentorFactType.chatRequested, MentorFactType.chatFailed]),
      );
    });

    test('TTS 不可用时会暴露诊断并记录 tts_unavailable fact', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot.signedOut,
        ),
      );
      await accountNotifier.initialize();
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
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _FakeMentorApiService(),
        audioController: _UnavailableMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await notifier.replaySuggestion(notifier.suggestions.first);

      expect(notifier.audioStatusCode, 'tts_unavailable');
      expect(notifier.audioStatusMessage, contains('当前设备不支持朗读'));
      expect(
        repository.appendedFacts.map((fact) => fact.eventType),
        contains(MentorFactType.ttsUnavailable),
      );
    });

    test('多轮聊天：发送两次后 messages 累积 4 条，conversationId 从响应穿透保持', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _jwtSession(sessionId: 'session_multi_turn'),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final apiService = _MultiTurnFakeMentorApiService();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: apiService,
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);

      // 第一轮
      notifier.updateChatDraft('宝宝一直哭，我该怎么安抚？');
      await notifier.submitChat();

      expect(notifier.messages.length, 2);
      expect(notifier.messages[0].role, ChatBubbleRole.user);
      expect(notifier.messages[0].text, '宝宝一直哭，我该怎么安抚？');
      expect(notifier.messages[1].role, ChatBubbleRole.assistant);
      expect(notifier.conversationId, 'conv_server_123');

      // 第二轮
      notifier.updateChatDraft('如果宝宝还是哭呢？');
      await notifier.submitChat();

      expect(notifier.messages.length, 4);
      expect(notifier.messages[2].role, ChatBubbleRole.user);
      expect(notifier.messages[2].text, '如果宝宝还是哭呢？');
      expect(notifier.messages[3].role, ChatBubbleRole.assistant);
      // conversationId 应该保持不变
      expect(notifier.conversationId, 'conv_server_123');
      // chatDraft 每轮提交后应被清空
      expect(notifier.chatDraft, '');
    });

    test('多轮聊天：beginPanelSession 重置 messages 和 conversationId', () async {
      final accountNotifier = AccountNotifier(
        repository: _StaticAccountRepository(
          seedSnapshot: AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _jwtSession(sessionId: 'session_reset_chat'),
            lastSyncPhase: 'batch_ack_applied',
          ),
        ),
      );
      await accountNotifier.initialize();
      final repository = _RecordingMentorRepository();
      final notifier = MentorNotifier(
        repository: repository,
        accountNotifier: accountNotifier,
        apiService: _MultiTurnFakeMentorApiService(),
        audioController: _SilentMentorAudioController(),
      );
      addTearDown(notifier.dispose);
      addTearDown(accountNotifier.dispose);

      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      notifier.selectTab(MentorPanelTab.chat);
      notifier.updateChatDraft('测试');
      await notifier.submitChat();
      expect(notifier.messages, isNotEmpty);
      expect(notifier.conversationId, isNotNull);

      // 结束并重新开始
      notifier.endPanelSession();
      await notifier.beginPanelSession(launcher: 'home_fab');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(notifier.messages, isEmpty);
      expect(notifier.conversationId, isNull);
    });
  });
}

class _ConsentChatScenario {
  const _ConsentChatScenario({
    required this.label,
    required this.snapshot,
    required this.expectedCode,
    required this.expectedPhase,
  });

  final String label;
  final AccountLocalSnapshot snapshot;
  final MentorChatAvailabilityCode expectedCode;
  final String expectedPhase;
}

AccountSession _jwtSession({required String sessionId}) {
  return AccountSession(
    accountId: 'account_$sessionId',
    sessionId: sessionId,
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 4, 10, 8),
    accessToken: 'access_$sessionId',
    refreshToken: 'refresh_$sessionId',
    tokenType: 'Cookie',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
  );
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
  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) async {
    return refreshedSession;
  }

  @override
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<void> close() async {}
}

class _FakeMentorApiService extends MentorApiService {
  _FakeMentorApiService({this.response, this.error})
    : super(baseUrl: 'http://localhost:8080');

  final MentorChatResponse? response;
  final MentorApiException? error;
  final List<AccountSession?> receivedSessions = <AccountSession?>[];

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    AccountSession? session,
    Future<AccountSession> Function(AccountSession refreshedSession)?
    persistRefreshedSession,
    String? contextSummary,
    String? conversationId,
  }) async {
    receivedSessions.add(session);
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
          authenticated: session != null,
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
  _MultiTurnFakeMentorApiService() : super(baseUrl: 'http://localhost:8080');

  final List<String?> receivedConversationIds = <String?>[];
  final List<AccountSession?> receivedSessions = <AccountSession?>[];
  int _callCount = 0;

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    AccountSession? session,
    Future<AccountSession> Function(AccountSession refreshedSession)?
    persistRefreshedSession,
    String? contextSummary,
    String? conversationId,
  }) async {
    receivedConversationIds.add(conversationId);
    receivedSessions.add(session);
    _callCount++;
    return MentorChatResponse(
      correlationId: 'corr_multi_$_callCount',
      responseText: '回复第$_callCount轮：先抱近一点，说 I\'m here.',
      code: 'ok',
      phase: 'response_delivered',
      retryable: false,
      fallbackUsed: false,
      authenticated: session != null,
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
