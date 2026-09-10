import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';

void main() {
  group('MentorApiService auth characterization', () {
    test(
      'REFACTOR-006: authenticated chat 写入 Bearer Authorization header',
      () async {
        final adapter = _RecordingDioAdapter();
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8080',
            validateStatus: (status) => true,
          ),
        );
        dio.httpClientAdapter = adapter;
        final accountApiService = _NoRefreshAccountApiService();
        final service = MentorApiService(
          dio: dio,
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: accountApiService,
          ),
        );

        final response = await service.sendChat(
          installationId: 'install_test',
          prompt: '宝宝一直哭，我现在该怎么说？',
          surface: 'home',
          mode: 'single_turn',
          correlationId: 'corr_test',
          session: _jwtSession(),
          persistRefreshedSession: (session) async => session,
        );

        expect(response.authenticated, isTrue);
        expect(accountApiService.refreshCallCount, 0);
        expect(adapter.requests, hasLength(1));
        expect(adapter.requests.single.path, '/api/v1/mentor/chat');
        expect(
          adapter.requests.single.headers['X-App-Version'],
          defaultMentorApiVersion,
        );
        expect(
          adapter.requests.single.headers[authorizationHeaderName],
          'Bearer access-live',
        );
      },
    );

    test(
      '401 refreshes once, persists session, then retries authenticated chat',
      () async {
        final adapter = _UnauthorizedThenSuccessDioAdapter();
        final dio = Dio(
          BaseOptions(
            baseUrl: 'http://localhost:8080',
            validateStatus: (status) => true,
          ),
        );
        dio.httpClientAdapter = adapter;
        final accountApiService = _RefreshingAccountApiService();
        final service = MentorApiService(
          dio: dio,
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: accountApiService,
          ),
        );
        AccountSession? persisted;

        await service.sendChat(
          installationId: 'install_test',
          prompt: '宝宝一直哭，我现在该怎么说？',
          surface: 'home',
          mode: 'single_turn',
          correlationId: 'corr_refresh',
          session: _jwtSession(),
          persistRefreshedSession: (session) async {
            persisted = session;
            return session;
          },
        );

        expect(accountApiService.refreshCallCount, 1);
        expect(persisted?.accessToken, 'access-refreshed');
        expect(adapter.requests, hasLength(2));
        expect(
          adapter.requests[0].headers[authorizationHeaderName],
          'Bearer access-live',
        );
        expect(
          adapter.requests[1].headers[authorizationHeaderName],
          'Bearer access-refreshed',
        );
      },
    );
  });
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
    throw StateError('refresh should not be called by this characterization');
  }

  @override
  Future<void> close() async {}
}

class _RefreshingAccountApiService extends AccountApiService {
  _RefreshingAccountApiService() : super();

  int refreshCallCount = 0;

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) async {
    refreshCallCount += 1;
    return AccountSessionResponse(
      accountId: 'account_auth',
      sessionId: 'session_auth',
      maskedPhoneNumber: '138****1234',
      createdAt: DateTime.utc(2026, 4, 10, 8),
      consentStatus: 'accepted',
      accessToken: 'access-refreshed',
      refreshToken: 'refresh-refreshed',
      tokenType: 'Bearer',
      accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 9),
      refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
    );
  }

  @override
  Future<void> close() async {}
}

class _RecordingDioAdapter implements HttpClientAdapter {
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
      jsonEncode(<String, Object?>{
        'correlationId': 'corr_test',
        'responseText': '先抱近一点，只说一句：I\'m here with you.',
        'code': 'ok',
        'phase': 'response_delivered',
        'retryable': false,
        'fallbackUsed': false,
        'authenticated': true,
        'rateLimit': <String, Object?>{
          'limited': false,
          'limit': 3,
          'remaining': 2,
          'windowSeconds': 600,
        },
        'respondedAt': DateTime.utc(2026, 4, 10, 0).toIso8601String(),
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _UnauthorizedThenSuccessDioAdapter extends _RecordingDioAdapter {
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
    if (requests.length == 1) {
      return ResponseBody.fromString(
        jsonEncode(<String, Object?>{
          'code': 'invalid_session',
          'message': 'access token expired',
        }),
        401,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'correlationId': 'corr_refresh',
        'responseText': '先抱近一点。',
        'code': 'ok',
        'phase': 'response_delivered',
        'retryable': false,
        'fallbackUsed': false,
        'authenticated': true,
        'rateLimit': <String, Object?>{
          'limited': false,
          'limit': 3,
          'remaining': 2,
          'windowSeconds': 600,
        },
        'respondedAt': DateTime.utc(2026, 4, 10, 0).toIso8601String(),
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _RecordedDioRequest {
  const _RecordedDioRequest({required this.path, required this.headers});

  final String path;
  final Map<String, Object?> headers;
}
