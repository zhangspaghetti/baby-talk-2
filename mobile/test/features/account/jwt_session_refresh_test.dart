import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

void main() {
  group('AuthenticatedApiClient', () {
    late _FakeRefreshAccountApiService api;
    late AuthenticatedApiClient client;

    setUp(() {
      api = _FakeRefreshAccountApiService();
      client = AuthenticatedApiClient(apiService: api);
    });

    test('并发 401 只触发一次 refresh，并共享 replay 结果', () async {
      final requestTokens = <String>[];
      final persistedSessions = <AccountSession>[];
      final refreshGate = Completer<void>();
      api.refreshGate = refreshGate;

      Future<String> send(String accessToken) async {
        requestTokens.add(accessToken);
        if (accessToken == 'access-old') {
          throw const AccountApiException(
            kind: AccountApiFailureKind.http,
            message: 'expired access token',
            statusCode: 401,
            code: 'access_token_rotated',
          );
        }
        return 'ok:$accessToken';
      }

      final firstFuture = client.execute(
        session: _jwtSession(),
        send: send,
        persistRefreshedSession: (session) async {
          persistedSessions.add(session);
          return session;
        },
      );
      final secondFuture = client.execute(
        session: _jwtSession(),
        send: send,
        persistRefreshedSession: (session) async {
          persistedSessions.add(session);
          return session;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      refreshGate.complete();
      final results = await Future.wait([firstFuture, secondFuture]);

      expect(api.refreshCallCount, 1);
      expect(persistedSessions, hasLength(1));
      expect(requestTokens, <String>[
        'access-old',
        'access-old',
        'access-new',
        'access-new',
      ]);
      expect(
        results.map((result) => result.value),
        everyElement('ok:access-new'),
      );
      expect(
        results.map((result) => result.session.accessToken),
        everyElement('access-new'),
      );
      expect(
        results.map((result) => result.session.refreshToken),
        everyElement('refresh-new'),
      );
    });

    test('refresh timeout fail closed，且不会 replay 原请求', () async {
      final requestTokens = <String>[];
      api.refreshException = const AccountApiException.timeout(
        message: '请求超时。',
      );

      Future<void> send(String accessToken) async {
        requestTokens.add(accessToken);
        throw const AccountApiException(
          kind: AccountApiFailureKind.http,
          message: 'expired access token',
          statusCode: 401,
          code: 'access_token_rotated',
        );
      }

      await expectLater(
        () => client.execute(
          session: _jwtSession(),
          send: send,
          persistRefreshedSession: (session) async => session,
        ),
        throwsA(
          isA<AuthenticatedApiClientException>()
              .having(
                (error) => error.phaseSuffix,
                'phaseSuffix',
                'refresh_timeout',
              )
              .having(
                (error) => error.visibleMessage,
                'visibleMessage',
                contains('重新登录'),
              ),
        ),
      );

      expect(api.refreshCallCount, 1);
      expect(requestTokens, <String>['access-old']);
    });

    test('replay 后再次 401 不会进入第二轮 refresh', () async {
      final requestTokens = <String>[];
      var persistCalls = 0;

      Future<void> send(String accessToken) async {
        requestTokens.add(accessToken);
        throw AccountApiException(
          kind: AccountApiFailureKind.http,
          message: 'unauthorized',
          statusCode: 401,
          code: accessToken == 'access-old'
              ? 'access_token_rotated'
              : 'access_token_revoked',
        );
      }

      await expectLater(
        () => client.execute(
          session: _jwtSession(),
          send: send,
          persistRefreshedSession: (session) async {
            persistCalls += 1;
            return session;
          },
        ),
        throwsA(
          isA<AuthenticatedApiClientException>().having(
            (error) => error.phaseSuffix,
            'phaseSuffix',
            'session_expired',
          ),
        ),
      );

      expect(api.refreshCallCount, 1);
      expect(persistCalls, 1);
      expect(requestTokens, <String>['access-old', 'access-new']);
    });

    test('legacy session 缺 token 时直接 fail closed，不发送受保护请求', () async {
      var requestCalled = false;

      await expectLater(
        () => client.execute(
          session: AccountSession(
            accountId: 'acct_test',
            sessionId: 'sess_legacy',
            maskedPhoneNumber: '138****8000',
            createdAt: DateTime.utc(2026, 4, 9, 2),
          ),
          send: (accessToken) async {
            requestCalled = true;
            return 'unexpected';
          },
          persistRefreshedSession: (session) async => session,
        ),
        throwsA(
          isA<AuthenticatedApiClientException>().having(
            (error) => error.phaseSuffix,
            'phaseSuffix',
            'session_expired',
          ),
        ),
      );

      expect(requestCalled, isFalse);
      expect(api.refreshCallCount, 0);
    });
  });
}

AccountSession _jwtSession() {
  return AccountSession(
    accountId: 'acct_test',
    sessionId: 'sess_test',
    maskedPhoneNumber: '138****8000',
    createdAt: DateTime.utc(2026, 4, 9, 2),
    accessToken: 'access-old',
    refreshToken: 'refresh-old',
    tokenType: 'Bearer',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 9, 2, 15),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 16, 2),
  );
}

class _FakeRefreshAccountApiService extends AccountApiService {
  _FakeRefreshAccountApiService() : super();

  int refreshCallCount = 0;
  AccountApiException? refreshException;
  AccountSessionResponse refreshResponse = AccountSessionResponse(
    accountId: 'acct_test',
    sessionId: 'sess_test',
    maskedPhoneNumber: '138****8000',
    createdAt: DateTime.utc(2026, 4, 9, 2),
    consentStatus: 'accepted',
    accessToken: 'access-new',
    refreshToken: 'refresh-new',
    tokenType: 'Bearer',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 9, 2, 30),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 16, 2),
  );
  Completer<void>? refreshGate;

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) async {
    refreshCallCount += 1;
    await refreshGate?.future;
    if (refreshException != null) {
      throw refreshException!;
    }
    return refreshResponse;
  }

  @override
  Future<void> close() async {}
}
