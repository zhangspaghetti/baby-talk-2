import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiVersion;
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart'
    show mentorPromptMaxLength;

const _appVersionHeader = 'X-App-Version';
const _minVersionHeader = 'X-Min-Supported-Version';
const _upgradeUrlHeader = 'X-Upgrade-Url';

class DemoBackendFailureTokens {
  const DemoBackendFailureTokens._();

  static const timeout = '[timeout]';
  static const malformed = '[malformed]';
  static const deleted = '[deleted]';
  static const consentRequired = '[consent-required]';
  static const blocked = '[blocked]';
}

class InMemoryDemoBackend {
  InMemoryDemoBackend._({
    required HttpServer server,
    required this.minSupportedVersion,
    required this.upgradeUrl,
    required this.simulatedSlowResponse,
    required this.mentorRateLimit,
  }) : _server = server,
       baseUri = Uri.parse('http://${server.address.address}:${server.port}') {
    _subscription = _server.listen((request) async {
      await _handle(request);
    });
  }

  final HttpServer _server;
  late final StreamSubscription<HttpRequest> _subscription;

  final String minSupportedVersion;
  final String upgradeUrl;
  final Duration simulatedSlowResponse;
  final int mentorRateLimit;
  final Uri baseUri;

  int _challengeCount = 0;
  int _sessionCount = 0;
  int bootstrapCount = 0;
  int mentorRequestCount = 0;
  int onboardingConversationRequestCount = 0;
  int onboardingTurnRequestCount = 0;
  int onboardingAudioRequestCount = 0;
  Object? lastUnhandledError;
  Map<String, Object?>? lastMentorRequestSummary;
  String? lastMentorFailureBranch;
  bool? lastOnboardingTurnReactionProvided;
  String? lastOnboardingTurnReaction;

  Completer<void>? _onboardingConversationGate;
  bool _failNextOnboardingAudio = false;

  final Map<String, String> _challengePhoneById = <String, String>{};
  final Map<String, String> _accountIdByPhone = <String, String>{};
  final Map<String, _DemoAccountState> _accountsById =
      <String, _DemoAccountState>{};
  final Map<String, String> _sessionAccountById = <String, String>{};
  final Map<String, String> _sessionInstallationById = <String, String>{};
  final Map<String, List<Map<String, Object?>>> _eventsByInstallation =
      <String, List<Map<String, Object?>>>{};
  final Map<String, Set<String>> _eventKeysByInstallation =
      <String, Set<String>>{};
  final Map<String, int> _mentorRequestsByInstallation = <String, int>{};

  static Future<InMemoryDemoBackend> start({
    String minSupportedVersion = defaultAccountApiVersion,
    String upgradeUrl = 'https://download.example.com/babytalk.apk',
    Duration simulatedSlowResponse = const Duration(milliseconds: 250),
    int mentorRateLimit = 1,
    InternetAddress? bindAddress,
    int port = 0,
  }) async {
    final server = await HttpServer.bind(
      bindAddress ?? InternetAddress.loopbackIPv4,
      port,
    );
    return InMemoryDemoBackend._(
      server: server,
      minSupportedVersion: minSupportedVersion,
      upgradeUrl: upgradeUrl,
      simulatedSlowResponse: simulatedSlowResponse,
      mentorRateLimit: mentorRateLimit,
    );
  }

  int storedEventCount(String installationId) {
    return _eventsByInstallation[installationId]?.length ?? 0;
  }

  int mentorRequestsForInstallation(String installationId) {
    return _mentorRequestsByInstallation[installationId] ?? 0;
  }

  Future<void> dispose() async {
    releaseOnboardingConversation();
    await _subscription.cancel();
    await _server.close(force: true);
  }

  void holdNextOnboardingConversation() {
    final active = _onboardingConversationGate;
    if (active != null && !active.isCompleted) {
      throw StateError('onboarding conversation is already held');
    }
    _onboardingConversationGate = Completer<void>();
  }

  void releaseOnboardingConversation() {
    final active = _onboardingConversationGate;
    _onboardingConversationGate = null;
    if (active != null && !active.isCompleted) active.complete();
  }

  void failNextOnboardingAudio() {
    _failNextOnboardingAudio = true;
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    try {
      if (!await _enforceVersionGate(request)) {
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/auth/challenges') {
        await _handleCreateChallenge(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/auth/verify') {
        await _handleVerifyChallenge(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/auth/refresh') {
        await _handleRefreshSession(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/consent/accept') {
        await _handleAcceptConsent(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/consent/revoke') {
        await _handleRevokeConsent(request);
        return;
      }

      if (request.method == 'DELETE' && path == '/api/v1/account') {
        await _handleDeleteAccount(request);
        return;
      }

      if (request.method == 'GET' && path == '/api/v1/bootstrap') {
        await _handleBootstrap(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/sync/events') {
        await _handleSyncEvents(request);
        return;
      }

      if (request.method == 'POST' && path == '/api/v1/mentor/chat') {
        await _handleMentorChat(request);
        return;
      }

      if (request.method == 'POST' &&
          path == '/api/v1/onboarding/conversations') {
        await _handleOnboardingConversation(request);
        return;
      }

      final segments = request.uri.pathSegments;
      if (request.method == 'POST' &&
          segments.length == 6 &&
          segments[0] == 'api' &&
          segments[1] == 'v1' &&
          segments[2] == 'onboarding' &&
          segments[3] == 'conversations' &&
          segments[5] == 'turns') {
        await _handleOnboardingTurn(request, segments[4]);
        return;
      }

      if (request.method == 'GET' &&
          segments.length == 8 &&
          segments[0] == 'api' &&
          segments[1] == 'v1' &&
          segments[2] == 'onboarding' &&
          segments[3] == 'conversations' &&
          segments[5] == 'utterances' &&
          segments[7] == 'audio') {
        await _handleOnboardingAudio(
          request,
          conversationId: segments[4],
          utteranceId: segments[6],
        );
        return;
      }

      await _writeJson(request.response, HttpStatus.notFound, {
        'code': 'not_found',
        'message': 'unsupported route',
      });
    } catch (error) {
      lastUnhandledError = error;
      await _writeJson(request.response, HttpStatus.internalServerError, {
        'code': 'test_backend_error',
        'message': '$error',
      });
    }
  }

  Future<void> _handleOnboardingConversation(HttpRequest request) async {
    final body = await _readJsonBody(request);
    if (body['installationId'] is! String ||
        body['localEventId'] is! String ||
        body['careEntryId'] is! String) {
      await _writeJson(request.response, HttpStatus.badRequest, {
        'code': 'invalid_onboarding_conversation',
        'message': 'required identity missing',
      });
      return;
    }
    onboardingConversationRequestCount += 1;
    final gate = _onboardingConversationGate;
    if (gate != null) await gate.future;
    await _writeJson(
      request.response,
      HttpStatus.ok,
      _onboardingConversationResponse(
        conversationId: 'onbc_demo_1',
        utteranceId: 'utterance_demo_1',
        english: 'Remote bedtime support.',
        chinese: '远程睡前陪伴。',
        pronunciation: 'ri-mout bed-taim se-port',
        audioCapability: 'capability-demo-first',
      ),
    );
  }

  Future<void> _handleOnboardingTurn(
    HttpRequest request,
    String conversationId,
  ) async {
    final body = await _readJsonBody(request);
    final reactionProvided = body['reactionProvided'];
    final reaction = body['reaction'];
    if (reactionProvided is! bool ||
        (reaction != null && reaction is! String) ||
        body['previousUtteranceId'] is! String ||
        body['localEventId'] is! String) {
      await _writeJson(request.response, HttpStatus.badRequest, {
        'code': 'invalid_onboarding_turn',
        'message': 'invalid turn contract',
      });
      return;
    }
    onboardingTurnRequestCount += 1;
    lastOnboardingTurnReactionProvided = reactionProvided;
    lastOnboardingTurnReaction = reaction as String?;
    await _writeJson(
      request.response,
      HttpStatus.ok,
      _onboardingConversationResponse(
        conversationId: conversationId,
        utteranceId: 'utterance_demo_2',
        english: 'Remote next support.',
        chinese: '远程下一句陪伴。',
        pronunciation: 'ri-mout nekst se-port',
        audioCapability: 'capability-demo-next',
      ),
    );
  }

  Future<void> _handleOnboardingAudio(
    HttpRequest request, {
    required String conversationId,
    required String utteranceId,
  }) async {
    onboardingAudioRequestCount += 1;
    if (_failNextOnboardingAudio) {
      _failNextOnboardingAudio = false;
      await _writeJson(request.response, HttpStatus.serviceUnavailable, {
        'code': 'onboarding_audio_unavailable',
        'message': 'simulated audio failure',
      });
      return;
    }
    final expectedCapability = utteranceId == 'utterance_demo_1'
        ? 'capability-demo-first'
        : utteranceId == 'utterance_demo_2'
        ? 'capability-demo-next'
        : null;
    final capability = request.headers.value('X-Onboarding-Audio-Capability');
    if (conversationId != 'onbc_demo_1' ||
        expectedCapability == null ||
        capability != expectedCapability) {
      await _writeJson(request.response, HttpStatus.notFound, {
        'code': 'onboarding_audio_not_found',
        'message': 'audio not found',
      });
      return;
    }
    const bytes = <int>[1, 2, 3, 4];
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType('audio', 'mpeg');
    request.response.headers.set(
      HttpHeaders.cacheControlHeader,
      'private, no-store',
    );
    request.response.headers.set(
      HttpHeaders.varyHeader,
      'X-Onboarding-Audio-Capability',
    );
    request.response.headers.set(
      'X-Generated-Audio-Voice-Version',
      'demo-onboarding-v1',
    );
    request.response.contentLength = bytes.length;
    request.response.add(bytes);
    await request.response.close();
  }

  Map<String, Object?> _onboardingConversationResponse({
    required String conversationId,
    required String utteranceId,
    required String english,
    required String chinese,
    required String pronunciation,
    required String audioCapability,
  }) {
    return <String, Object?>{
      'conversationId': conversationId,
      'expiresAt': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      'utterance': <String, Object?>{
        'utteranceId': utteranceId,
        'englishText': english,
        'chineseText': chinese,
        'pronunciationHint': pronunciation,
        'audioRef': audioCapability,
        'source': 'remote_generated',
      },
    };
  }

  Future<void> _handleCreateChallenge(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final phoneNumber =
        (body['phoneNumber'] as String?)?.trim().isNotEmpty == true
        ? (body['phoneNumber'] as String).trim()
        : '13800138000';

    await _delayForFailureToken(<String?>[phoneNumber]);
    if (_containsFailureToken(
      phoneNumber,
      DemoBackendFailureTokens.malformed,
    )) {
      await _writeMalformedJson(request.response);
      return;
    }

    final challengeId = 'challenge_${++_challengeCount}';
    _challengePhoneById[challengeId] = phoneNumber;
    await _writeJson(request.response, HttpStatus.created, {
      'challengeId': challengeId,
      'maskedPhoneNumber': _maskPhoneNumber(phoneNumber),
      'codeLength': 6,
      'expiresAt': DateTime.utc(2026, 4, 10, 10).toIso8601String(),
    });
  }

  Future<void> _handleVerifyChallenge(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final challengeId = body['challengeId'] as String?;
    final verificationCode = body['verificationCode'] as String?;
    final installationId = body['installationId'] as String?;
    final phoneNumber = challengeId == null
        ? null
        : _challengePhoneById[challengeId];

    await _delayForFailureToken(<String?>[phoneNumber, installationId]);
    if (_containsFailureToken(
          phoneNumber,
          DemoBackendFailureTokens.malformed,
        ) ||
        _containsFailureToken(
          installationId,
          DemoBackendFailureTokens.malformed,
        )) {
      await _writeMalformedJson(request.response);
      return;
    }

    if (challengeId == null ||
        phoneNumber == null ||
        verificationCode != '246810' ||
        installationId == null ||
        installationId.trim().isEmpty) {
      await _writeJson(request.response, HttpStatus.badRequest, {
        'code': 'verification_failed',
        'message': 'challenge 或验证码非法。',
      });
      return;
    }

    final accountId = _accountIdByPhone.putIfAbsent(phoneNumber, () {
      return 'acct_${_accountIdByPhone.length + 1}';
    });
    final accountState = _accountsById.putIfAbsent(
      accountId,
      () => _DemoAccountState(
        accountId: accountId,
        phoneNumber: phoneNumber,
        consentStatus: 'signed_out',
        deleted: _containsFailureToken(
          phoneNumber,
          DemoBackendFailureTokens.deleted,
        ),
        keepConsentPending: _containsFailureToken(
          phoneNumber,
          DemoBackendFailureTokens.consentRequired,
        ),
      ),
    );

    final sessionId = 'sess_${++_sessionCount}';
    _sessionAccountById[sessionId] = accountState.accountId;
    _sessionInstallationById[sessionId] = installationId;
    const tokenExpiry = '2030-12-31T23:59:59.000Z';
    await _writeJson(request.response, HttpStatus.ok, {
      'accountId': accountState.accountId,
      'sessionId': sessionId,
      'maskedPhoneNumber': _maskPhoneNumber(phoneNumber),
      'createdAt': DateTime.utc(
        2026,
        4,
        10,
        10,
        _sessionCount,
      ).toIso8601String(),
      'consentStatus': accountState.consentStatus,
      'accessToken': sessionId,
      'refreshToken': sessionId,
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': tokenExpiry,
      'refreshTokenExpiresAt': tokenExpiry,
    });
  }

  Future<void> _handleRefreshSession(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final refreshToken = body['refreshToken'] as String?;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'refreshToken 缺失。',
      });
      return;
    }
    final account = _resolveAccount(refreshToken);
    if (account == null) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'refresh token 无效。',
      });
      return;
    }
    const tokenExpiry = '2030-12-31T23:59:59.000Z';
    await _writeJson(request.response, HttpStatus.ok, {
      'accountId': account.accountId,
      'sessionId': refreshToken,
      'maskedPhoneNumber': _maskPhoneNumber(account.phoneNumber),
      'createdAt': DateTime.utc(2026, 4, 10, 10).toIso8601String(),
      'consentStatus': account.consentStatus,
      'accessToken': refreshToken,
      'refreshToken': refreshToken,
      'tokenType': 'Bearer',
      'accessTokenExpiresAt': tokenExpiry,
      'refreshTokenExpiresAt': tokenExpiry,
    });
  }

  Future<void> _handleAcceptConsent(HttpRequest request) async {
    final sessionId = _extractSessionFromBearer(request);
    final account = _resolveAccount(sessionId);
    if (account == null) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'session 不存在。',
      });
      return;
    }

    if (!account.keepConsentPending && !account.deleted) {
      account.consentStatus = 'accepted';
    }
    await _writeJson(request.response, HttpStatus.ok, {
      'applied': true,
      'result': 'applied',
      'consentStatus': account.consentStatus,
      'updatedAt': DateTime.utc(2026, 4, 10, 10, 5).toIso8601String(),
    });
  }

  Future<void> _handleRevokeConsent(HttpRequest request) async {
    final sessionId = _extractSessionFromBearer(request);
    final account = _resolveAccount(sessionId);
    if (account == null) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'session 不存在。',
      });
      return;
    }

    account.consentStatus = 'revoked';
    await _writeJson(request.response, HttpStatus.ok, {
      'applied': true,
      'result': 'revoked',
      'consentStatus': account.consentStatus,
      'updatedAt': DateTime.utc(2026, 4, 10, 10, 6).toIso8601String(),
    });
  }

  Future<void> _handleDeleteAccount(HttpRequest request) async {
    final sessionId = _extractSessionFromBearer(request);
    final account = _resolveAccount(sessionId);
    if (account == null) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'session 不存在。',
      });
      return;
    }

    account.deleted = true;
    account.consentStatus = 'deleted';
    final deletedEventCount = _eventsByInstallation.values
        .expand((events) => events)
        .where((event) => event['accountIdHint'] == account.accountId)
        .length;
    await _writeJson(request.response, HttpStatus.ok, {
      'applied': true,
      'result': 'deleted',
      'deletedEventCount': deletedEventCount,
      'updatedAt': DateTime.utc(2026, 4, 10, 10, 7).toIso8601String(),
    });
  }

  Future<void> _handleBootstrap(HttpRequest request) async {
    bootstrapCount += 1;
    final sessionId = _extractSessionFromBearer(request);
    final account = _resolveAccount(sessionId);
    final installationId = request.uri.queryParameters['installationId'];

    await _delayForFailureToken(<String?>[installationId]);
    if (_containsFailureToken(
      installationId,
      DemoBackendFailureTokens.malformed,
    )) {
      await _writeMalformedJson(request.response, statusCode: HttpStatus.ok);
      return;
    }

    if (account == null ||
        installationId == null ||
        installationId.trim().isEmpty) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'session 不存在。',
      });
      return;
    }

    if (account.deleted ||
        _containsFailureToken(
          installationId,
          DemoBackendFailureTokens.deleted,
        )) {
      await _writeJson(request.response, HttpStatus.gone, {
        'code': 'account_deleted',
        'message': '账号已删除。',
      });
      return;
    }

    if (account.consentStatus != 'accepted') {
      await _writeJson(request.response, HttpStatus.conflict, {
        'code': 'consent_required',
        'message': '尚未完成同意。',
      });
      return;
    }

    final events = List<Map<String, Object?>>.from(
      _eventsByInstallation[installationId] ?? const <Map<String, Object?>>[],
    );
    await _writeJson(request.response, HttpStatus.ok, {
      'accountId': account.accountId,
      'sessionId': sessionId,
      'installationId': installationId,
      'consentStatus': 'accepted',
      'eventCount': events.length,
      'events': events,
      'bootstrapAt': DateTime.utc(
        2026,
        4,
        10,
        10,
        8,
        bootstrapCount,
      ).toIso8601String(),
    });
  }

  Future<void> _handleSyncEvents(HttpRequest request) async {
    final sessionId = _extractSessionFromBearer(request);
    final account = _resolveAccount(sessionId);
    final installationFromSession = sessionId == null
        ? null
        : _sessionInstallationById[sessionId];
    final body = await _readJsonBody(request);
    final installationId = body['installationId'] as String?;
    final rawEvents = body['events'] as List<Object?>? ?? const <Object?>[];

    await _delayForFailureToken(<String?>[installationId]);
    if (_containsFailureToken(
      installationId,
      DemoBackendFailureTokens.malformed,
    )) {
      await _writeMalformedJson(request.response, statusCode: HttpStatus.ok);
      return;
    }

    if (account == null ||
        installationId == null ||
        installationId != installationFromSession) {
      await _writeJson(request.response, HttpStatus.unauthorized, {
        'code': 'invalid_session',
        'message': 'session 或 installationId 非法。',
      });
      return;
    }

    if (account.deleted) {
      await _writeJson(request.response, HttpStatus.gone, {
        'code': 'account_deleted',
        'message': '账号已删除。',
      });
      return;
    }

    if (account.consentStatus != 'accepted') {
      await _writeJson(request.response, HttpStatus.conflict, {
        'code': 'consent_required',
        'message': '尚未完成同意。',
      });
      return;
    }

    final acceptedEventKeys = <String>[];
    final duplicateEventKeys = <String>[];
    final storedEvents = _eventsByInstallation.putIfAbsent(
      installationId,
      () => <Map<String, Object?>>[],
    );
    final seenKeys = _eventKeysByInstallation.putIfAbsent(
      installationId,
      () => <String>{},
    );

    for (final rawEvent in rawEvents) {
      final event = Map<String, Object?>.from(rawEvent as Map);
      final eventKey = event['eventKey'] as String?;
      if (eventKey == null || eventKey.trim().isEmpty) {
        continue;
      }
      if (!seenKeys.add(eventKey)) {
        duplicateEventKeys.add(eventKey);
        continue;
      }
      storedEvents.add(<String, Object?>{
        'accountIdHint': account.accountId,
        'eventKey': eventKey,
        'localEventId': event['localEventId'],
        'installationId': event['installationId'],
        'spaceId': event['spaceId'],
        'activityId': event['activityId'],
        'phraseId': event['phraseId'],
        'reactionType': event['reactionType'],
        'clientTimestamp': event['clientTimestamp'],
        'receivedAt': DateTime.utc(
          2026,
          4,
          10,
          10,
          9,
          storedEvents.length,
        ).toIso8601String(),
      });
      acceptedEventKeys.add(eventKey);
    }

    await _writeJson(request.response, HttpStatus.ok, {
      'receivedCount': rawEvents.length,
      'acceptedCount': acceptedEventKeys.length,
      'duplicateCount': duplicateEventKeys.length,
      'acceptedEventKeys': acceptedEventKeys,
      'duplicateEventKeys': duplicateEventKeys,
      'syncedAt': DateTime.utc(2026, 4, 10, 10, 10).toIso8601String(),
    });
  }

  Future<void> _handleMentorChat(HttpRequest request) async {
    mentorRequestCount += 1;
    final body = await _readJsonBody(request);
    final sessionId = _extractSessionFromBearer(request);
    final installationId = body['installationId'] as String?;
    final prompt = (body['prompt'] as String?)?.trim() ?? '';
    final surface = (body['surface'] as String?)?.trim() ?? '';
    final mode = (body['mode'] as String?)?.trim() ?? '';
    final correlationId =
        (body['correlationId'] as String?)?.trim().isNotEmpty == true
        ? (body['correlationId'] as String).trim()
        : 'corr_${mentorRequestCount.toString().padLeft(4, '0')}';
    lastMentorRequestSummary = <String, Object?>{
      'installationId': installationId,
      'promptLength': prompt.length,
      'surface': surface,
      'mode': mode,
      'correlationId': correlationId,
      'hasSession': sessionId != null,
    };

    await _delayForFailureToken(<String?>[
      installationId,
      prompt,
      correlationId,
    ]);

    if (installationId == null ||
        installationId.trim().isEmpty ||
        prompt.isEmpty ||
        !_isAllowedSurface(surface) ||
        mode != 'single_turn') {
      lastMentorFailureBranch = 'invalid_request';
      await _writeJson(request.response, HttpStatus.badRequest, {
        'code': 'missing_prompt',
        'message': 'prompt / surface / mode 非法。',
      });
      return;
    }

    if (prompt.length > mentorPromptMaxLength) {
      lastMentorFailureBranch = 'prompt_too_long';
      await _writeJson(request.response, HttpStatus.badRequest, {
        'code': 'prompt_too_long',
        'message': 'prompt 过长。',
        'details': {
          'phase': 'prompt_too_long',
          'maxLength': mentorPromptMaxLength,
        },
      });
      return;
    }

    final account = _resolveAccount(sessionId);
    if (sessionId != null && account == null) {
      lastMentorFailureBranch = 'invalid_session';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.unauthorized,
        code: 'invalid_session',
        message: 'session 不存在。',
        phase: 'invalid_session',
        retryable: true,
      );
      return;
    }

    if (account != null && account.deleted) {
      lastMentorFailureBranch = 'account_deleted';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.gone,
        code: 'account_deleted',
        message: '账号已删除。',
        phase: 'account_deleted',
        retryable: false,
      );
      return;
    }

    if (account != null && account.consentStatus != 'accepted') {
      lastMentorFailureBranch = 'consent_revoked';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.forbidden,
        code: 'consent_revoked',
        message: '同意状态不可用。',
        phase: 'consent_revoked',
        retryable: true,
      );
      return;
    }

    if (_containsFailureToken(prompt, DemoBackendFailureTokens.malformed) ||
        _containsFailureToken(
          installationId,
          DemoBackendFailureTokens.malformed,
        ) ||
        _containsFailureToken(
          correlationId,
          DemoBackendFailureTokens.malformed,
        )) {
      lastMentorFailureBranch = 'malformed';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.badGateway,
        code: 'provider_malformed_response',
        message: 'provider 返回了不可信内容。',
        phase: 'provider_malformed_response',
        retryable: true,
      );
      return;
    }

    if (_containsFailureToken(prompt, DemoBackendFailureTokens.timeout) ||
        _containsFailureToken(
          installationId,
          DemoBackendFailureTokens.timeout,
        ) ||
        _containsFailureToken(
          correlationId,
          DemoBackendFailureTokens.timeout,
        )) {
      lastMentorFailureBranch = 'timeout';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.gatewayTimeout,
        code: 'provider_timeout',
        message: 'provider 响应超时。',
        phase: 'provider_timeout',
        retryable: true,
      );
      return;
    }

    final mentorRequests =
        (_mentorRequestsByInstallation[installationId] ?? 0) + 1;
    _mentorRequestsByInstallation[installationId] = mentorRequests;
    final remaining = mentorRateLimit - mentorRequests;

    if (mentorRequests > mentorRateLimit) {
      lastMentorFailureBranch = 'rate_limited';
      await _writeMentorError(
        request.response,
        statusCode: HttpStatus.tooManyRequests,
        code: 'mentor_rate_limited',
        message: '请求过于频繁。',
        phase: 'rate_limited',
        retryable: true,
        extraDetails: <String, Object?>{
          'rateLimited': true,
          'limit': mentorRateLimit,
          'remaining': 0,
          'windowSeconds': 600,
        },
      );
      return;
    }

    if (_shouldUseBlockedFallback(prompt)) {
      lastMentorFailureBranch = null;
      await _writeJson(request.response, HttpStatus.ok, {
        'correlationId': correlationId,
        'responseText': 'I\'m here with you. 先放慢语速，只说一句最稳妥的短句，然后停下来观察宝宝。',
        'code': 'blocked_fallback',
        'phase': 'blocked_fallback',
        'retryable': false,
        'fallbackUsed': true,
        'authenticated': sessionId != null,
        'rateLimit': {
          'limited': false,
          'limit': mentorRateLimit,
          'remaining': remaining < 0 ? 0 : remaining,
          'windowSeconds': 600,
        },
        'respondedAt': DateTime.utc(
          2026,
          4,
          10,
          10,
          11,
          mentorRequestCount,
        ).toIso8601String(),
      });
      return;
    }

    lastMentorFailureBranch = null;
    await _writeJson(request.response, HttpStatus.ok, {
      'correlationId': correlationId,
      'responseText': '先抱近一点，只说一句：I\'m here with you. 然后停两秒等宝宝回应。',
      'code': 'ok',
      'phase': 'response_delivered',
      'retryable': false,
      'fallbackUsed': false,
      'authenticated': sessionId != null,
      'rateLimit': {
        'limited': false,
        'limit': mentorRateLimit,
        'remaining': remaining < 0 ? 0 : remaining,
        'windowSeconds': 600,
      },
      'respondedAt': DateTime.utc(
        2026,
        4,
        10,
        10,
        12,
        mentorRequestCount,
      ).toIso8601String(),
    });
  }

  Future<bool> _enforceVersionGate(HttpRequest request) async {
    final appVersion = request.headers.value(_appVersionHeader);
    if (appVersion == null || appVersion.trim().isEmpty) {
      await _writeVersionError(
        request.response,
        code: 'app_version_required',
        message: '缺少 X-App-Version，请升级客户端。',
      );
      return false;
    }

    if (_compareVersions(appVersion, minSupportedVersion) < 0) {
      await _writeVersionError(
        request.response,
        code: 'app_version_unsupported',
        message: '当前版本过旧，请升级后重试。',
      );
      return false;
    }
    return true;
  }

  Future<void> _writeVersionError(
    HttpResponse response, {
    required String code,
    required String message,
  }) {
    response.headers.set(_minVersionHeader, minSupportedVersion);
    response.headers.set(_upgradeUrlHeader, upgradeUrl);
    return _writeJson(response, 426, {
      'code': code,
      'message': message,
      'minimumSupportedVersion': minSupportedVersion,
      'upgradeUrl': upgradeUrl,
    });
  }

  Future<void> _writeMentorError(
    HttpResponse response, {
    required int statusCode,
    required String code,
    required String message,
    required String phase,
    required bool retryable,
    Map<String, Object?> extraDetails = const <String, Object?>{},
  }) {
    return _writeJson(response, statusCode, {
      'code': code,
      'message': message,
      'details': <String, Object?>{
        'phase': phase,
        'retryable': retryable,
        ...extraDetails,
      },
    });
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _delayForFailureToken(Iterable<String?> values) async {
    if (values.any(
      (value) => _containsFailureToken(value, DemoBackendFailureTokens.timeout),
    )) {
      await Future<void>.delayed(simulatedSlowResponse);
    }
  }

  bool _containsFailureToken(String? value, String token) {
    return value != null && value.contains(token);
  }

  bool _shouldUseBlockedFallback(String prompt) {
    final normalized = prompt.toLowerCase();
    if (_containsFailureToken(prompt, DemoBackendFailureTokens.blocked)) {
      return true;
    }
    return normalized.contains('体罚') ||
        normalized.contains('打他') ||
        normalized.contains('13800138000') ||
        normalized.contains('246810');
  }

  bool _isAllowedSurface(String surface) {
    return const <String>{
      'practice',
      'home',
      'discover',
      'garden',
      'growth',
      'standalone_home',
    }.contains(surface);
  }

  String? _extractSessionFromBearer(HttpRequest request) {
    final auth = request.headers.value(HttpHeaders.authorizationHeader);
    if (auth == null) return null;
    const prefix = 'Bearer ';
    if (!auth.startsWith(prefix)) return null;
    final token = auth.substring(prefix.length).trim();
    return token.isNotEmpty ? token : null;
  }

  _DemoAccountState? _resolveAccount(String? sessionId) {
    if (sessionId == null) {
      return null;
    }
    final accountId = _sessionAccountById[sessionId];
    if (accountId == null) {
      return null;
    }
    return _accountsById[accountId];
  }

  int _compareVersions(String left, String right) {
    final leftParts = left.split('.').map(int.tryParse).toList(growable: false);
    final rightParts = right
        .split('.')
        .map(int.tryParse)
        .toList(growable: false);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < maxLength; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] ?? 0 : 0;
      final rightValue = index < rightParts.length ? rightParts[index] ?? 0 : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  String _maskPhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return '***';
    }
    final prefix = digits.substring(0, 3);
    final suffix = digits.substring(digits.length - 4);
    return '$prefix****$suffix';
  }

  Future<void> _writeMalformedJson(
    HttpResponse response, {
    int statusCode = HttpStatus.badGateway,
  }) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write('{"code":"malformed"');
    await response.close();
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> json,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(json));
    await response.close();
  }
}

class _DemoAccountState {
  _DemoAccountState({
    required this.accountId,
    required this.phoneNumber,
    required this.consentStatus,
    required this.deleted,
    required this.keepConsentPending,
  });

  final String accountId;
  final String phoneNumber;
  String consentStatus;
  bool deleted;
  final bool keepConsentPending;
}
