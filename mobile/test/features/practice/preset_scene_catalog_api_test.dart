import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

void main() {
  group('PresetSceneCatalogApi', () {
    test(
      'loads published scenes with public headers and preserves API order',
      () async {
        final adapter = _StaticDioAdapter(
          statusCode: 200,
          body: <Object>[
            _scene('bedtime', sortOrder: 90),
            _scene('bath_time', sortOrder: 1),
          ],
        );
        final dio = Dio(BaseOptions(baseUrl: 'http://catalog.test'))
          ..httpClientAdapter = adapter;
        final api = PresetSceneCatalogApi(dio: dio, appVersion: '1.3.0');

        final scenes = await api.fetchPublishedScenes();

        expect(scenes.map((scene) => scene.presetSceneId), [
          'bedtime',
          'bath_time',
        ]);
        expect(adapter.request.path, '/api/v1/practice/preset-scenes');
        expect(adapter.request.headers['Accept'], 'application/json');
        expect(adapter.request.headers['X-App-Version'], '1.3.0');
        expect(adapter.request.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('accepts a valid empty published catalog as authoritative', () async {
      final adapter = _StaticDioAdapter(statusCode: 200, body: <Object>[]);
      final dio = Dio(BaseOptions(baseUrl: 'http://catalog.test'))
        ..httpClientAdapter = adapter;

      final scenes = await PresetSceneCatalogApi(
        dio: dio,
      ).fetchPublishedScenes();

      expect(scenes, isEmpty);
    });

    for (final invalidCase in <String, Map<String, dynamic>>{
      'generationBrief': <String, dynamic>{'generationBrief': 'secret prompt'},
      'unknown field': <String, dynamic>{'extra': 'reject'},
      'missing field': <String, dynamic>{'summary': null},
      'wrong type': <String, dynamic>{'publishedVersion': '1'},
      'fractional integer': <String, dynamic>{'sortOrder': 1.5},
    }.entries) {
      test('rejects ${invalidCase.key} in public JSON', () async {
        final body = _scene('bath_time')..addAll(invalidCase.value);
        final api = _api(statusCode: 200, body: <Object>[body]);

        await expectLater(
          api.fetchPublishedScenes(),
          throwsA(
            isA<PresetSceneCatalogApiException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  PresetSceneCatalogFailureKind.malformed,
                )
                .having(
                  (error) => error.toString(),
                  'safe diagnostic',
                  isNot(contains('secret prompt')),
                ),
          ),
        );
      });
    }

    test(
      'rejects duplicate preset IDs and duplicate route identities',
      () async {
        final duplicateIdApi = _api(
          statusCode: 200,
          body: <Object>[
            _scene('bath_time'),
            _scene('bath_time', sortOrder: 2),
          ],
        );
        await expectLater(
          duplicateIdApi.fetchPublishedScenes(),
          throwsA(isA<PresetSceneCatalogApiException>()),
        );

        final duplicateRouteApi = _api(
          statusCode: 200,
          body: <Object>[
            _scene('scene_a', spaceId: 'shared'),
            _scene('scene_a', spaceId: 'shared', sortOrder: 2),
          ],
        );
        await expectLater(
          duplicateRouteApi.fetchPublishedScenes(),
          throwsA(isA<PresetSceneCatalogApiException>()),
        );
      },
    );

    test('maps non-success response without exposing response body', () async {
      final api = _api(
        statusCode: 503,
        body: <String, Object>{'message': 'private server payload'},
      );

      await expectLater(
        api.fetchPublishedScenes(),
        throwsA(
          isA<PresetSceneCatalogApiException>()
              .having(
                (error) => error.kind,
                'kind',
                PresetSceneCatalogFailureKind.http,
              )
              .having(
                (error) => error.toString(),
                'safe diagnostic',
                isNot(contains('private server payload')),
              ),
        ),
      );
    });

    test(
      'accepts a JSON string array but rejects a JSON object success body',
      () async {
        final stringApi = _api(
          statusCode: 200,
          body: jsonEncode(<Object>[_scene('bath_time')]),
        );
        expect(await stringApi.fetchPublishedScenes(), hasLength(1));

        final mapApi = _api(
          statusCode: 200,
          body: <String, Object>{'message': 'not a catalog'},
        );
        await expectLater(
          mapApi.fetchPublishedScenes(),
          throwsA(isA<PresetSceneCatalogApiException>()),
        );
      },
    );

    test(
      'maps timeout and socket transport failures without leaking details',
      () async {
        final timeoutApi = PresetSceneCatalogApi(
          dio: Dio(BaseOptions(baseUrl: 'http://catalog.test'))
            ..httpClientAdapter = _ThrowingDioAdapter(
              DioExceptionType.connectionTimeout,
            ),
        );
        await expectLater(
          timeoutApi.fetchPublishedScenes(),
          throwsA(
            isA<PresetSceneCatalogApiException>().having(
              (error) => error.kind,
              'kind',
              PresetSceneCatalogFailureKind.timeout,
            ),
          ),
        );

        final socketApi = PresetSceneCatalogApi(
          dio: Dio(BaseOptions(baseUrl: 'http://catalog.test'))
            ..httpClientAdapter = _ThrowingDioAdapter(
              DioExceptionType.connectionError,
              error: const SocketException('private socket detail'),
            ),
        );
        await expectLater(
          socketApi.fetchPublishedScenes(),
          throwsA(
            isA<PresetSceneCatalogApiException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  PresetSceneCatalogFailureKind.network,
                )
                .having(
                  (error) => error.toString(),
                  'safe diagnostic',
                  isNot(contains('private socket detail')),
                ),
          ),
        );
      },
    );

    test('enforces scene ID and sort order invariants at runtime', () {
      final valid65 = 'a${'b' * 64}';
      final valid96 = 'a${'b' * 95}';
      expect(_definitionForId(valid65), isA<PresetSceneDefinition>());
      expect(_definitionForId(valid96), isA<PresetSceneDefinition>());
      expect(
        _definitionForId('valid', spaceId: valid65),
        isA<PresetSceneDefinition>(),
      );
      expect(
        _definitionForId('valid', spaceId: valid96),
        isA<PresetSceneDefinition>(),
      );
      for (final invalidId in <String>['Avalid', 'a/b', 'a${'b' * 96}']) {
        expect(() => _definitionForId(invalidId), throwsArgumentError);
      }
      for (final invalidSpace in <String>['Avalid', 'a/b', 'a${'b' * 96}']) {
        expect(
          () => _definitionForId('valid', spaceId: invalidSpace),
          throwsArgumentError,
        );
      }
      expect(
        () => PresetSceneDefinition(
          presetSceneId: 'valid',
          publishedVersion: 1,
          spaceId: 'daily_care',
          title: 'Title',
          summary: 'Summary',
          sceneTag: 'Tag',
          coachTip: 'Tip',
          sortOrder: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}

PresetSceneCatalogApi _api({required int statusCode, required Object body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://catalog.test'))
    ..httpClientAdapter = _StaticDioAdapter(statusCode: statusCode, body: body);
  return PresetSceneCatalogApi(dio: dio);
}

Map<String, dynamic> _scene(
  String presetSceneId, {
  String spaceId = 'daily_care',
  int sortOrder = 1,
}) {
  return <String, dynamic>{
    'presetSceneId': presetSceneId,
    'publishedVersion': 1,
    'spaceId': spaceId,
    'title': 'Title $presetSceneId',
    'summary': 'Summary $presetSceneId',
    'sceneTag': 'tag_$presetSceneId',
    'coachTip': 'Tip $presetSceneId',
    'sortOrder': sortOrder,
  };
}

class _StaticDioAdapter implements HttpClientAdapter {
  _StaticDioAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object body;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingDioAdapter implements HttpClientAdapter {
  _ThrowingDioAdapter(this.type, {this.error});

  final DioExceptionType type;
  final Object? error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException(requestOptions: options, type: type, error: error);
  }

  @override
  void close({bool force = false}) {}
}

PresetSceneDefinition _definitionForId(
  String id, {
  String spaceId = 'daily_care',
}) {
  return PresetSceneDefinition(
    presetSceneId: id,
    publishedVersion: 1,
    spaceId: spaceId,
    title: 'Title',
    summary: 'Summary',
    sceneTag: 'Tag',
    coachTip: 'Tip',
    sortOrder: 0,
  );
}
