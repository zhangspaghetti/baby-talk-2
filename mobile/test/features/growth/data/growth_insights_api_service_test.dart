import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';

void main() {
  test('fetches server-confirmed growth insights with account Bearer token', () async {
    final adapter = _RecordingDioAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    dio.httpClientAdapter = adapter;
    final service = GrowthInsightsApiService(
      dio: dio,
      authenticatedApiClient: AuthenticatedApiClient(
        apiService: _NoRefreshAccountApiService(),
      ),
      sessionLoader: () async => _session(),
      persistRefreshedSession: (session) async => session,
    );

    final payload = await service.fetchInsights('week');

    expect(payload.stats.totalEvents, 7);
    expect(adapter.request.path, '/api/v1/growth/insights');
    expect(adapter.request.queryParameters['period'], 'week');
    expect(
      adapter.request.headers[authorizationHeaderName],
      'Bearer access-live',
    );
  });
}

AccountSession _session() => AccountSession(
  accountId: 'account_auth',
  sessionId: 'session_auth',
  maskedPhoneNumber: '138****1234',
  createdAt: DateTime.utc(2026, 4, 10, 8),
  accessToken: 'access-live',
  refreshToken: 'refresh-live',
  tokenType: 'Bearer',
  accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
  refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
);

class _NoRefreshAccountApiService extends AccountApiService {
  _NoRefreshAccountApiService() : super();

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) => throw StateError('refresh should not be needed');

  @override
  Future<void> close() async {}
}

class _RecordingDioAdapter implements HttpClientAdapter {
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode({
        'period': 'week',
        'windowStart': '2026-05-18T00:00:00Z',
        'windowEnd': '2026-05-25T00:00:00Z',
        'generatedAt': '2026-05-25T00:00:00Z',
        'stats': {
          'totalEvents': 7,
          'uniquePhrases': 3,
          'uniqueActivities': 2,
          'cooperatingCount': 1,
          'practicedDays': 3,
        },
        'streak': {
          'currentStreak': 2,
          'longestStreak': 4,
          'totalDaysPracticed': 5,
        },
        'bars': [],
        'scenes': [],
        'recentActivity': {'thisWeekCount': 7, 'lastWeekCount': 2},
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
