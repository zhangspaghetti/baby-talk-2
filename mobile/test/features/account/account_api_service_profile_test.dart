import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';

void main() {
  test('profile GET parses the account-backed canonical fields', () async {
    late RequestOptions request;
    final service = AccountApiService(
      dio: _mockDio((options) async {
        request = options;
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: _profileJson,
        );
      }),
    );

    final response = await service.getBabyProfile(accessToken: 'access_live');

    expect(request.method, 'GET');
    expect(request.path, '/api/v1/onboarding/profile');
    expect(request.headers['Authorization'], 'Bearer access_live');
    expect(response.babyProfileId, 'profile_1');
    expect(response.babyName, '小满');
    expect(response.ageRange, 'm7_11');
    expect(response.version, 2);
  });

  test('profile PUT sends only the account profile contract', () async {
    late RequestOptions request;
    final service = AccountApiService(
      dio: _mockDio((options) async {
        request = options;
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: _profileJson,
        );
      }),
    );

    await service.putBabyProfile(
      accessToken: 'access_live',
      expectedVersion: 2,
      babyName: '小满',
      ageRange: 'm7_11',
      onboardingState: 'draft',
      clientTraceId: 'settings_profile_123',
    );

    expect(request.method, 'PUT');
    expect(request.path, '/api/v1/onboarding/profile');
    expect(request.data, {
      'expectedVersion': 2,
      'babyName': '小满',
      'ageRange': 'm7_11',
      'parentGoal': null,
      'onboardingState': 'draft',
      'completedAt': null,
      'clientTraceId': 'settings_profile_123',
    });
  });
}

final _profileJson = <String, Object?>{
  'babyProfileId': 'profile_1',
  'babyName': '小满',
  'ageRange': 'm7_11',
  'parentGoal': null,
  'starter': null,
  'onboardingState': 'draft',
  'onboardingCompletedAt': null,
  'version': 2,
  'createdAt': '2026-08-20T00:00:00Z',
  'updatedAt': '2026-08-20T00:00:00Z',
};

Dio _mockDio(Future<Response<dynamic>> Function(RequestOptions) handler) => Dio(
  BaseOptions(baseUrl: 'http://localhost:8080', validateStatus: (_) => true),
)..interceptors.add(_MockInterceptor(handler));

final class _MockInterceptor extends Interceptor {
  _MockInterceptor(this.handler);

  final Future<Response<dynamic>> Function(RequestOptions) handler;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler next) async {
    next.resolve(await handler(options));
  }
}
