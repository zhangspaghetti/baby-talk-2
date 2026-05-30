import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';

class _MockInterceptor extends Interceptor {
  _MockInterceptor(this._handler);

  final Future<Response<dynamic>> Function(RequestOptions options) _handler;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final response = await _handler(options);
      handler.resolve(response);
    } catch (error) {
      if (error is DioException) {
        handler.reject(error);
        return;
      }
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
}

Dio _createMockDio(
  Future<Response<dynamic>> Function(RequestOptions options) handler,
) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => true,
    ),
  )..interceptors.add(_MockInterceptor(handler));
}

void main() {
  group('GardenFertilizerApiService', () {
    test('claim sends eventKey and requestId', () async {
      final dio = _createMockDio((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/api/v1/garden/fertilizer/claim');
        final body = options.data as Map<String, dynamic>;
        expect(body['eventKey'], 'evt-1');
        expect(body['requestId'], 'req-1');

        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'appliedCount': 0,
            'claimedEventKeys': ['evt-1'],
            'lastClaimedAt': '2026-05-30T10:00:00Z',
            'lastAppliedAt': null,
          },
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });
      final service = GardenFertilizerApiService(dio: dio);

      final state = await service.claim(eventKey: 'evt-1', requestId: 'req-1');

      expect(state.claimedEventKeys, {'evt-1'});
      expect(state.appliedCount, 0);
    });

    test('apply sends requestId and parses fertilizer state', () async {
      final dio = _createMockDio((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/api/v1/garden/fertilizer/apply');
        final body = options.data as Map<String, dynamic>;
        expect(body['requestId'], 'req-apply-1');

        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'appliedCount': 1,
            'claimedEventKeys': ['evt-1'],
            'lastClaimedAt': '2026-05-30T10:00:00Z',
            'lastAppliedAt': '2026-05-30T10:01:00Z',
          },
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });
      final service = GardenFertilizerApiService(dio: dio);

      final state = await service.apply(requestId: 'req-apply-1');

      expect(state.appliedCount, 1);
      expect(state.backpackCount, 0);
      expect(state.lastAppliedAt, isNotNull);
    });

    test('fetchState reads remote authoritative state', () async {
      final dio = _createMockDio((options) async {
        expect(options.method, 'GET');
        expect(options.path, '/api/v1/garden/fertilizer/state');
        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'appliedCount': 2,
            'claimedEventKeys': ['evt-1', 'evt-2', 'evt-3'],
            'lastClaimedAt': '2026-05-30T10:00:00Z',
            'lastAppliedAt': '2026-05-30T10:10:00Z',
          },
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });
      final service = GardenFertilizerApiService(dio: dio);

      final state = await service.fetchState();

      expect(state.appliedCount, 2);
      expect(state.backpackCount, 1);
      expect(state.claimedEventKeys, {'evt-1', 'evt-2', 'evt-3'});
    });

    test('network error maps to network exception', () async {
      final dio = _createMockDio((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        );
      });
      final service = GardenFertilizerApiService(dio: dio);

      expect(
        () => service.fetchState(),
        throwsA(
          isA<GardenFertilizerApiException>().having(
            (e) => e.kind,
            'kind',
            GardenFertilizerApiFailureKind.network,
          ),
        ),
      );
    });
  });
}
