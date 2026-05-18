import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('Bearer authorization headers', () {
    test('helper trims access tokens and omits empty values', () {
      expect(
        buildBearerAuthorizationHeaderValue(' access-live '),
        'Bearer access-live',
      );
      expect(buildBearerAuthorizationHeaderValue(null), isNull);
      expect(buildBearerAuthorizationHeaderValue('  '), isNull);
    });

    test('AccountApiService protected endpoints write Bearer header', () async {
      final adapter = _RecordingDioAdapter(_accountResponseFor);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
      dio.httpClientAdapter = adapter;
      final service = AccountApiService(dio: dio);

      await service.acceptConsent(
        accessToken: 'access-live',
        consentVersion: 'pipl-v1',
      );
      await service.revokeConsent(
        accessToken: 'access-live',
        reason: 'user_requested',
      );
      await service.deleteAccount(
        accessToken: 'access-live',
        reason: 'forget_me',
      );
      await service.syncEvents(
        accessToken: 'access-live',
        installationId: 'install_test',
        events: <InteractionEventUploadRecord>[
          InteractionEventUploadRecord(
            eventKey: 'event_1',
            localEventId: 'local_1',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            reactionType: BabyReactionType.calm,
            clientTimestamp: DateTime.utc(2026, 4, 10, 8),
          ),
        ],
      );
      await service.bootstrap(
        accessToken: 'access-live',
        installationId: 'install_test',
      );

      expect(adapter.requests.map((request) => request.path), <String>[
        '/api/v1/consent/accept',
        '/api/v1/consent/revoke',
        '/api/v1/account',
        '/api/v1/sync/events',
        '/api/v1/bootstrap',
      ]);
      expect(
        adapter.requests.map(
          (request) => request.headers[authorizationHeaderName],
        ),
        everyElement('Bearer access-live'),
      );
    });

    test(
      'HouseholdApiService protected endpoints write Bearer header',
      () async {
        final adapter = _RecordingDioAdapter(_householdResponseFor);
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
        dio.httpClientAdapter = adapter;
        final accountApiService = _NoRefreshAccountApiService();
        final service = HouseholdApiService(
          dio: dio,
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: accountApiService,
          ),
        );

        await service.createInvite(
          session: _jwtSession(),
          persistRefreshedSession: (session) async => session,
          role: HouseholdRole.caregiver,
          source: 'settings',
        );
        await service.acceptInvite(
          session: _jwtSession(),
          persistRefreshedSession: (session) async => session,
          token: 'invite_token',
          source: 'deeplink',
        );
        await service.fetchSharedContext(
          session: _jwtSession(),
          persistRefreshedSession: (session) async => session,
        );

        expect(accountApiService.refreshCallCount, 0);
        expect(adapter.requests.map((request) => request.path), <String>[
          '/api/v1/caregiver-invites',
          '/api/v1/caregiver-invites/accept',
          '/api/v1/household/shared-context',
        ]);
        expect(
          adapter.requests.map(
            (request) => request.headers[authorizationHeaderName],
          ),
          everyElement('Bearer access-live'),
        );
      },
    );
  });
}

Map<String, Object?> _accountResponseFor(RequestOptions options) {
  switch (options.path) {
    case '/api/v1/consent/accept':
    case '/api/v1/consent/revoke':
      return <String, Object?>{
        'applied': true,
        'result': 'accepted',
        'consentStatus': 'accepted',
        'updatedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
      };
    case '/api/v1/account':
      return <String, Object?>{
        'applied': true,
        'result': 'deleted',
        'deletedEventCount': 3,
        'updatedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
      };
    case '/api/v1/sync/events':
      return <String, Object?>{
        'receivedCount': 1,
        'acceptedCount': 1,
        'duplicateCount': 0,
        'acceptedEventKeys': <String>['event_1'],
        'duplicateEventKeys': <String>[],
        'syncedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
      };
    case '/api/v1/bootstrap':
      return <String, Object?>{
        'consentStatus': 'accepted',
        'eventCount': 0,
        'events': <Object?>[],
        'bootstrapAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
      };
    default:
      throw StateError('Unexpected account path ${options.path}');
  }
}

Map<String, Object?> _householdResponseFor(RequestOptions options) {
  switch (options.path) {
    case '/api/v1/caregiver-invites':
      return <String, Object?>{
        'householdId': 'household_1',
        'token': 'invite_token',
        'inviteUrl': 'https://example.test/invite/invite_token',
        'role': 'caregiver',
        'source': 'settings',
        'expiresAt': DateTime.utc(2026, 4, 11, 8).toIso8601String(),
      };
    case '/api/v1/caregiver-invites/accept':
      return <String, Object?>{
        'householdId': 'household_1',
        'role': 'caregiver',
        'acceptedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
        'sharedContext': _sharedContextResponseJson(),
      };
    case '/api/v1/household/shared-context':
      return _sharedContextResponseJson();
    default:
      throw StateError('Unexpected household path ${options.path}');
  }
}

Map<String, Object?> _sharedContextResponseJson() {
  return <String, Object?>{
    'householdId': 'household_1',
    'role': 'caregiver',
    'lastAcceptedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
    'snapshot': <String, Object?>{
      'babyProfileSummary': '20 months',
      'continuitySummary': 'bath_time recent',
      'gardenSummary': 'calm streak',
      'practice': <String, Object?>{
        'spaceId': 'daily_care',
        'activityId': 'bath_time',
      },
      'latestInteractionAt': DateTime.utc(2026, 4, 10, 7).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 4, 10, 8).toIso8601String(),
    },
  };
}

AccountSession _jwtSession() {
  return AccountSession(
    accountId: 'account_auth',
    sessionId: 'session_auth',
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 4, 10, 8),
    accessToken: 'access-live',
    refreshToken: 'refresh-live',
    tokenType: 'Cookie',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
  );
}

class _NoRefreshAccountApiService extends AccountApiService {
  _NoRefreshAccountApiService() : super();

  int refreshCallCount = 0;

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) async {
    refreshCallCount += 1;
    throw StateError('refresh should not be called by this test');
  }

  @override
  Future<void> close() async {}
}

class _RecordingDioAdapter implements HttpClientAdapter {
  _RecordingDioAdapter(this.responseFor);

  final Map<String, Object?> Function(RequestOptions options) responseFor;
  final List<_RecordedDioRequest> requests = <_RecordedDioRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RecordedDioRequest(
        path: options.path,
        headers: Map<String, Object?>.from(options.headers),
      ),
    );
    return ResponseBody.fromString(
      jsonEncode(responseFor(options)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordedDioRequest {
  const _RecordedDioRequest({required this.path, required this.headers});

  final String path;
  final Map<String, Object?> headers;
}
