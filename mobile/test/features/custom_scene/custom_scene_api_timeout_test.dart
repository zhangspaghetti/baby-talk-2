import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_api.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';

void main() {
  test('uses a 60 second default timeout for agentic discovery', () async {
    Duration? sendTimeout;
    Duration? receiveTimeout;
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..interceptors.add(
        _TimeoutInterceptor((options) {
          sendTimeout = options.sendTimeout;
          receiveTimeout = options.receiveTimeout;
        }),
      );
    final api = CustomSceneApi(
      authenticatedApiClient: AuthenticatedApiClient(
        apiService: _NoRefreshAccountApiService(),
      ),
      dio: dio,
    );

    await expectLater(
      api.generate(
        session: _session(),
        persistRefreshedSession: (session) async => session,
        request: const CustomSceneRequestDto(
          installationId: 'install_1',
          babyProfileId: 'baby_1',
          ageRange: 'm7_11',
          parentGoal: 'natural_opening',
          locale: 'zh-CN',
          customSceneText: '宝宝洗澡时不想碰水。',
          clientRequestId: 'custom_scene_timeout',
        ),
      ),
      throwsA(
        isA<CustomSceneApiException>().having(
          (error) => error.kind,
          'kind',
          CustomSceneApiFailureKind.timeout,
        ),
      ),
    );

    expect(sendTimeout, const Duration(seconds: 60));
    expect(receiveTimeout, const Duration(seconds: 60));
  });
}

class _TimeoutInterceptor extends Interceptor {
  _TimeoutInterceptor(this._capture);

  final void Function(RequestOptions options) _capture;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _capture(options);
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      ),
    );
  }
}

class _NoRefreshAccountApiService extends AccountApiService {
  _NoRefreshAccountApiService() : super();

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) {
    throw StateError('refresh should not be called');
  }

  @override
  Future<void> close() async {}
}

AccountSession _session() {
  return AccountSession(
    accountId: 'account_1',
    sessionId: 'session_1',
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: 'access-live',
    refreshToken: 'refresh-live',
    tokenType: 'Bearer',
    accessTokenExpiresAt: DateTime.utc(2026, 7, 28, 1),
    refreshTokenExpiresAt: DateTime.utc(2026, 8, 28),
  );
}
