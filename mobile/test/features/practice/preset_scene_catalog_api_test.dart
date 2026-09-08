import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/remote/preset_scene_catalog_api.dart';

void main() {
  group('PresetSceneCatalogApi', () {
    test('loads published scenes with public headers and preserves API order', () async {
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
    });

    test('accepts a valid empty published catalog as authoritative', () async {
      final adapter = _StaticDioAdapter(statusCode: 200, body: <Object>[]);
      final dio = Dio(BaseOptions(baseUrl: 'http://catalog.test'))
        ..httpClientAdapter = adapter;

      final scenes = await PresetSceneCatalogApi(dio: dio).fetchPublishedScenes();

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
        final body = _scene('bath_time')
          ..addAll(invalidCase.value);
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

    test('rejects duplicate preset IDs and duplicate route identities', () async {
      final duplicateIdApi = _api(
        statusCode: 200,
        body: <Object>[_scene('bath_time'), _scene('bath_time', sortOrder: 2)],
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
    });

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
