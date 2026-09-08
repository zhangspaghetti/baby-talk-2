import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_api.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_dtos.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_mapper.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_repository_impl.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('SceneGenerationRequestDto', () {
    test('custom request emits only the unified privacy-safe keys', () {
      final request = SceneGenerationRequestDto(
        source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        locale: 'zh-CN',
        installationId: 'install_1',
        clientRequestId: 'scene_request_1',
      );

      final json = request.toJson();

      expect(json.keys.toSet(), <String>{
        'source',
        'locale',
        'installationId',
        'clientRequestId',
      });
      expect((json['source'] as Map<String, Object?>).keys.toSet(), <String>{
        'type',
        'text',
      });
      expect(json['source'], <String, Object?>{
        'type': 'custom',
        'text': '宝宝洗澡时一直躲水。',
      });
      expect(json.containsKey('babyProfileId'), isFalse);
      expect(json.containsKey('ageRange'), isFalse);
      expect(json.containsKey('parentGoal'), isFalse);
      expect(json.containsKey('generationBrief'), isFalse);
      expect(json.containsKey('babyName'), isFalse);
      expect(json.containsKey('householdId'), isFalse);
      expect(json.containsKey('role'), isFalse);
    });

    test('preset request emits only type and presetSceneId in source', () {
      final request = SceneGenerationRequestDto(
        source: const PresetSceneGenerationSource('bath_time'),
        locale: 'zh-CN',
        installationId: 'install_1',
        clientRequestId: 'scene_request_2',
      );

      final json = request.toJson();

      expect(json.keys.toSet(), <String>{
        'source',
        'locale',
        'installationId',
        'clientRequestId',
      });
      expect(json['source'], <String, Object?>{
        'type': 'preset',
        'presetSceneId': 'bath_time',
      });
      final source = json['source'] as Map<String, Object?>;
      expect(source.containsKey('text'), isFalse);
      expect(source.containsKey('generationBrief'), isFalse);
    });
  });

  group('SceneGenerationMapper', () {
    test(
      'maps backend response to generated care moment with exact semantics',
      () {
        final moment = const SceneGenerationMapper().toGeneratedCareMoment(
          SceneGenerationResponseDto.fromJson(_validResponse()),
          expectedSource: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        );

        expect(moment.generatedContentId, 'gcn_1');
        expect(moment.sceneId, 'space_bath');
        expect(moment.spaceId, 'space_bath');
        expect(moment.momentId, 'activity_bath');
        expect(moment.activityId, 'activity_bath');
        expect(moment.title, '洗澡安抚');
        expect(moment.sceneTag, 'bath');
        expect(moment.coachTip, '慢慢说');
        expect(moment.source, 'generated');
        expect(moment.inputSource, SceneGenerationSourceType.custom);
        expect(moment.presetSceneId, isNull);
        expect(moment.presetSceneVersion, isNull);
        expect(moment.starter.utteranceId, 'utt_starter');
        expect(
          moment.reactionSupports[BabyReactionType.hesitant].phraseId,
          'phrase_hesitant',
        );
      },
    );

    test('preserves preset attribution and version from source metadata', () {
      final moment = const SceneGenerationMapper().toGeneratedCareMoment(
        SceneGenerationResponseDto.fromJson(
          _validResponse(
            source: <String, Object?>{
              'type': 'preset',
              'presetSceneId': 'bath_time',
              'presetSceneVersion': 3,
            },
          ),
        ),
        expectedSource: const PresetSceneGenerationSource('bath_time'),
      );

      expect(moment.inputSource, SceneGenerationSourceType.preset);
      expect(moment.presetSceneId, 'bath_time');
      expect(moment.presetSceneVersion, 3);
    });

    test('rejects unknown, missing, and wrong-typed response fields', () {
      final unknown = _validResponse()..['debugBody'] = 'private';
      expect(
        () => SceneGenerationResponseDto.fromJson(unknown),
        throwsFormatException,
      );

      final missing = _validResponse()..remove('starter');
      expect(
        () => SceneGenerationResponseDto.fromJson(missing),
        throwsFormatException,
      );

      final wrongType = _validResponse()..['bundleSchemaVersion'] = 1;
      expect(
        () => SceneGenerationResponseDto.fromJson(wrongType),
        throwsFormatException,
      );
    });

    test('rejects duplicate canonical reactions and duplicate identities', () {
      final duplicateReaction = _validResponse();
      final supports = duplicateReaction['reactionSupports'] as List<dynamic>;
      final second = supports[1] as Map<String, dynamic>;
      second['reaction'] = 'cooperating';
      second['displayOrder'] = 2;
      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          SceneGenerationResponseDto.fromJson(duplicateReaction),
          expectedSource: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );

      final duplicatePhrase = _validResponse();
      final duplicatePhraseSupport =
          (duplicatePhrase['reactionSupports'] as List<dynamic>)[0]
              as Map<String, dynamic>;
      duplicatePhraseSupport['phraseId'] = 'phrase_starter';
      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          SceneGenerationResponseDto.fromJson(duplicatePhrase),
          expectedSource: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );
    });

    test('rejects invalid source attribution metadata', () {
      final customWithPreset = _validResponse(
        source: <String, Object?>{
          'type': 'custom',
          'presetSceneId': 'bath_time',
          'presetSceneVersion': null,
        },
      );
      expect(
        () => SceneGenerationResponseDto.fromJson(customWithPreset),
        throwsFormatException,
      );

      final presetWithoutVersion = _validResponse(
        source: <String, Object?>{
          'type': 'preset',
          'presetSceneId': 'bath_time',
          'presetSceneVersion': 0,
        },
      );
      expect(
        () => SceneGenerationResponseDto.fromJson(presetWithoutVersion),
        throwsFormatException,
      );
    });

    test('rejects response source type that differs from requested source', () {
      final response = SceneGenerationResponseDto.fromJson(_validResponse());

      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          response,
          expectedSource: const PresetSceneGenerationSource('activity_bath'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );
    });

    test('rejects preset source ID that differs from requested source', () {
      final response = SceneGenerationResponseDto.fromJson(
        _validResponse(
          source: <String, Object?>{
            'type': 'preset',
            'presetSceneId': 'activity_bath',
            'presetSceneVersion': 3,
          },
        ),
      );

      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          response,
          expectedSource: const PresetSceneGenerationSource('different_scene'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );
    });

    test(
      'rejects route identity that violates backend scene and activity invariants',
      () {
        final badScene = _validResponse()
          ..['route'] = <String, Object?>{
            'sceneId': 'not_space',
            'spaceId': 'space_bath',
            'momentId': 'activity_bath',
            'activityId': 'activity_bath',
            'phraseId': 'phrase_starter',
          };
        final badMoment = _validResponse()
          ..['route'] = <String, Object?>{
            'sceneId': 'space_bath',
            'spaceId': 'space_bath',
            'momentId': 'not_activity',
            'activityId': 'activity_bath',
            'phraseId': 'phrase_starter',
          };
        for (final invalid in <Map<String, dynamic>>[badScene, badMoment]) {
          expect(
            () => const SceneGenerationMapper().toGeneratedCareMoment(
              SceneGenerationResponseDto.fromJson(invalid),
              expectedSource: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
            ),
            throwsA(isA<SceneGenerationMappingException>()),
          );
        }
      },
    );

    test('rejects route phrase mismatch and preset activity mismatch', () {
      final badPhrase = _validResponse()
        ..['route'] = <String, Object?>{
          'sceneId': 'space_bath',
          'spaceId': 'space_bath',
          'momentId': 'activity_bath',
          'activityId': 'activity_bath',
          'phraseId': 'different_phrase',
        };
      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          SceneGenerationResponseDto.fromJson(badPhrase),
          expectedSource: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );

      final badPreset =
          _validResponse(
              source: <String, Object?>{
                'type': 'preset',
                'presetSceneId': 'activity_bath',
                'presetSceneVersion': 3,
              },
            )
            ..['route'] = <String, Object?>{
              'sceneId': 'space_bath',
              'spaceId': 'space_bath',
              'momentId': 'another_activity',
              'activityId': 'another_activity',
              'phraseId': 'phrase_starter',
            };
      expect(
        () => const SceneGenerationMapper().toGeneratedCareMoment(
          SceneGenerationResponseDto.fromJson(badPreset),
          expectedSource: const PresetSceneGenerationSource('activity_bath'),
        ),
        throwsA(isA<SceneGenerationMappingException>()),
      );
    });
  });

  group('SceneGenerationApi', () {
    test(
      'posts through authenticated client and refreshes once on 401',
      () async {
        final adapter = _SequenceAdapter(<_AdapterReply>[
          _AdapterReply(401, <String, Object?>{
            'timestamp': '2026-09-08T00:00:00Z',
            'status': 401,
            'code': 'invalid_session',
            'message': 'private backend body',
            'details': <String, Object?>{},
          }),
          _AdapterReply(200, _validResponse()),
        ]);
        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
          ..httpClientAdapter = adapter;
        final accountApi = _RefreshingAccountApiService();
        final api = SceneGenerationApi(
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: accountApi,
          ),
          dio: dio,
        );

        final response = await api.generate(
          session: _session(accessToken: 'access_old'),
          persistRefreshedSession: (session) async => session,
          request: SceneGenerationRequestDto(
            source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
            locale: 'zh-CN',
            installationId: 'install_1',
            clientRequestId: 'scene_request_3',
          ),
        );

        expect(response.generatedContentId, 'gcn_1');
        expect(accountApi.refreshCallCount, 1);
        expect(adapter.requests, hasLength(2));
        expect(adapter.requests[0].path, '/api/v1/practice/scene-generations');
        expect(adapter.requests[1].path, '/api/v1/practice/scene-generations');
        expect(
          adapter.requests.map(
            (request) => request.headers[authorizationHeaderName],
          ),
          <String>['Bearer access_old', 'Bearer access_new'],
        );
        expect(adapter.requests[1].headers['X-App-Version'], '1.3.0');
        expect(adapter.requests[1].data, <String, Object?>{
          'source': <String, Object?>{'type': 'custom', 'text': '宝宝洗澡时一直躲水。'},
          'locale': 'zh-CN',
          'installationId': 'install_1',
          'clientRequestId': 'scene_request_3',
        });
      },
    );

    test('does not expose backend body in API exception string', () async {
      final adapter = _SequenceAdapter(<_AdapterReply>[
        _AdapterReply(422, <String, Object?>{
          'timestamp': '2026-09-08T00:00:00Z',
          'status': 422,
          'code': 'generated_content_rejected',
          'message': '宝宝洗澡时一直躲水。',
          'details': <String, Object?>{
            'generatedContentId': 'gcn_rejected',
            'retryable': false,
          },
        }),
      ]);
      final api = SceneGenerationApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _RefreshingAccountApiService(),
        ),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
          ..httpClientAdapter = adapter,
      );

      await expectLater(
        api.generate(
          session: _session(),
          persistRefreshedSession: (session) async => session,
          request: SceneGenerationRequestDto(
            source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
            locale: 'zh-CN',
            installationId: 'install_1',
            clientRequestId: 'scene_request_4',
          ),
        ),
        throwsA(
          isA<SceneGenerationApiException>()
              .having(
                (error) => error.code,
                'code',
                'generated_content_rejected',
              )
              .having(
                (error) => error.generatedContentId,
                'content id',
                'gcn_rejected',
              )
              .having(
                (error) => error.toString(),
                'safe toString',
                allOf(
                  isNot(contains('宝宝洗澡时一直躲水。')),
                  isNot(contains('private backend body')),
                ),
              ),
        ),
      );
    });

    test(
      'accepts standard error envelope from a map and JSON string',
      () async {
        final standard = _standardError(
          status: 503,
          code: 'generation_unavailable',
          details: <String, Object?>{
            'generatedContentId': 'gcn_standard',
            'retryable': true,
          },
        );
        final mapError = await _apiErrorFor(status: 503, body: standard);
        final stringError = await _apiErrorFor(
          status: 503,
          body: jsonEncode(standard),
        );

        expect(mapError.code, 'generation_unavailable');
        expect(mapError.statusCode, 503);
        expect(mapError.generatedContentId, 'gcn_standard');
        expect(mapError.retryable, isTrue);
        expect(stringError.code, 'generation_unavailable');
        expect(stringError.statusCode, 503);
        expect(stringError.generatedContentId, 'gcn_standard');
      },
    );

    test(
      'accepts version-gate envelope and uses HTTP status as authority',
      () async {
        final versionEnvelope = _versionError(
          code: 'app_version_required',
          details: const <String, Object?>{},
        );
        final mapError = await _apiErrorFor(status: 426, body: versionEnvelope);
        final stringError = await _apiErrorFor(
          status: 426,
          body: jsonEncode(versionEnvelope),
        );

        expect(mapError.code, 'app_version_required');
        expect(mapError.statusCode, 426);
        expect(stringError.code, 'app_version_required');
        expect(stringError.statusCode, 426);
      },
    );

    test(
      'rejects unknown and mixed error envelope keys as malformed',
      () async {
        final unknown = _versionError(
          code: 'app_version_required',
          details: const <String, Object?>{},
        )..['debugBody'] = 'private';
        final mixed = _versionError(
          code: 'app_version_required',
          details: const <String, Object?>{},
        )..['status'] = 426;

        final unknownError = await _apiErrorFor(status: 426, body: unknown);
        final mixedError = await _apiErrorFor(status: 426, body: mixed);

        expect(unknownError.kind, SceneGenerationApiFailureKind.malformed);
        expect(mixedError.kind, SceneGenerationApiFailureKind.malformed);
      },
    );

    test('accepts gateway RATE_LIMITED envelope only for HTTP 429', () async {
      final gatewayBody = <String, Object?>{
        'code': 'RATE_LIMITED',
        'message': 'private rate-limit message',
        'retryAfter': 17,
      };
      final mapError = await _apiErrorFor(status: 429, body: gatewayBody);
      final stringError = await _apiErrorFor(
        status: 429,
        body: jsonEncode(gatewayBody),
      );

      expect(mapError.kind, SceneGenerationApiFailureKind.http);
      expect(mapError.statusCode, 429);
      expect(mapError.code, 'RATE_LIMITED');
      expect(mapError.retryAfter, 17);
      expect(stringError.code, 'RATE_LIMITED');
      expect(stringError.retryAfter, 17);
      expect(
        mapError.toString(),
        isNot(contains('private rate-limit message')),
      );
    });

    test(
      'rejects malformed gateway rate-limit shapes and non-429 status',
      () async {
        final cases = <({int status, Map<String, Object?> body})>[
          (
            status: 429,
            body: <String, Object?>{
              'code': 'RATE_LIMITED',
              'message': 'limited',
            },
          ),
          (
            status: 429,
            body: <String, Object?>{
              'code': 'RATE_LIMITED',
              'message': 'limited',
              'retryAfter': 0,
            },
          ),
          (
            status: 429,
            body: <String, Object?>{
              'code': 'RATE_LIMITED',
              'message': 'limited',
              'retryAfter': '17',
            },
          ),
          (
            status: 429,
            body: <String, Object?>{
              'code': 'OTHER',
              'message': 'limited',
              'retryAfter': 17,
            },
          ),
          (
            status: 429,
            body: <String, Object?>{
              'code': 'RATE_LIMITED',
              'message': 'limited',
              'retryAfter': 17,
              'extra': true,
            },
          ),
          (
            status: 503,
            body: <String, Object?>{
              'code': 'RATE_LIMITED',
              'message': 'limited',
              'retryAfter': 17,
            },
          ),
        ];

        for (final testCase in cases) {
          final error = await _apiErrorFor(
            status: testCase.status,
            body: testCase.body,
          );
          expect(error.kind, SceneGenerationApiFailureKind.malformed);
        }
      },
    );

    test(
      'keeps details strict for version and non-null standard rate errors',
      () async {
        final standardWrongType = _standardError(
          status: 429,
          code: 'custom_scene_rate_limited',
          details: const <String, Object?>{},
        )..['details'] = <Object?>['wrong'];
        final standardError = await _apiErrorFor(
          status: 429,
          body: standardWrongType,
        );

        final versionWrongType = _versionError(
          code: 'generation_rate_limited',
          details: const <String, Object?>{},
        )..['details'] = 'wrong';
        final versionError = await _apiErrorFor(
          status: 429,
          body: versionWrongType,
        );

        expect(standardError.kind, SceneGenerationApiFailureKind.malformed);
        expect(versionError.kind, SceneGenerationApiFailureKind.malformed);
      },
    );

    test(
      'allows only missing or nullable details in standard HTTP 429 envelope',
      () async {
        final missingDetails = await _apiErrorFor(
          status: 429,
          body: _standardError(status: 429, code: 'custom_scene_rate_limited'),
        );
        final nullableDetails = _standardError(
          status: 429,
          code: 'custom_scene_rate_limited',
          details: const <String, Object?>{},
        )..['details'] = null;
        final nullableError = await _apiErrorFor(
          status: 429,
          body: nullableDetails,
        );

        expect(missingDetails.code, 'custom_scene_rate_limited');
        expect(nullableError.code, 'custom_scene_rate_limited');
      },
    );

    test('refresh persistence callback receives refreshed session', () async {
      final adapter = _SequenceAdapter(<_AdapterReply>[
        _AdapterReply(
          401,
          _standardError(
            status: 401,
            code: 'invalid_session',
            details: const <String, Object?>{},
          ),
        ),
        _AdapterReply(200, _validResponse()),
      ]);
      final api = SceneGenerationApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _RefreshingAccountApiService(),
        ),
        dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
          ..httpClientAdapter = adapter,
      );
      AccountSession? persisted;

      await api.generate(
        session: _session(accessToken: 'access_old'),
        persistRefreshedSession: (session) async {
          persisted = session;
          return session;
        },
        request: SceneGenerationRequestDto(
          source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
          locale: 'zh-CN',
          installationId: 'install_1',
          clientRequestId: 'scene_request_persist',
        ),
      );

      expect(persisted?.accessToken, 'access_new');
      expect(persisted?.refreshToken, 'refresh_new');
    });

    test(
      'repository forwards refreshed session to persistence callback',
      () async {
        final adapter = _SequenceAdapter(<_AdapterReply>[
          _AdapterReply(
            401,
            _standardError(
              status: 401,
              code: 'invalid_session',
              details: const <String, Object?>{},
            ),
          ),
          _AdapterReply(200, _validResponse()),
        ]);
        final api = SceneGenerationApi(
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: _RefreshingAccountApiService(),
          ),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
            ..httpClientAdapter = adapter,
        );
        AccountSession? persisted;
        final repository = SceneGenerationRepositoryImpl(
          api: api,
          accountSnapshotLoader: () async => AccountLocalSnapshot(
            consentState: AccountConsentState.acceptedPendingSync,
            session: _session(accessToken: 'access_old'),
          ),
          persistRefreshedSession: (session) async {
            persisted = session;
            return session;
          },
          localeLoader: () async => 'zh-CN',
          installationIdLoader: () async => 'install_1',
        );

        await repository.generate(
          source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
          clientRequestId: 'scene_request_repository_persist',
        );

        expect(persisted?.accessToken, 'access_new');
        expect(persisted?.refreshToken, 'refresh_new');
      },
    );
  });

  group('SceneGenerationRepositoryImpl', () {
    test(
      'loads only accepted JWT session, locale, and installation ID',
      () async {
        final gateway = _RecordingSceneGenerationGateway(
          source: <String, Object?>{
            'type': 'preset',
            'presetSceneId': 'bath_time',
            'presetSceneVersion': 3,
          },
        );
        var accountLoads = 0;
        var localeLoads = 0;
        var installationLoads = 0;
        final repository = SceneGenerationRepositoryImpl(
          api: gateway,
          mapper: const SceneGenerationMapper(),
          accountSnapshotLoader: () async {
            accountLoads += 1;
            return AccountLocalSnapshot(
              consentState: AccountConsentState.acceptedPendingSync,
              session: _session(),
            );
          },
          persistRefreshedSession: (session) async => session,
          localeLoader: () async {
            localeLoads += 1;
            return 'zh-CN';
          },
          installationIdLoader: () async {
            installationLoads += 1;
            return 'install_1';
          },
        );

        final result = await repository.generate(
          source: const PresetSceneGenerationSource('bath_time'),
          clientRequestId: 'scene_request_5',
        );

        expect(result.inputSource, SceneGenerationSourceType.preset);
        expect(accountLoads, 1);
        expect(localeLoads, 1);
        expect(installationLoads, 1);
        expect(gateway.request?.toJson(), <String, Object?>{
          'source': <String, Object?>{
            'type': 'preset',
            'presetSceneId': 'bath_time',
          },
          'locale': 'zh-CN',
          'installationId': 'install_1',
          'clientRequestId': 'scene_request_5',
        });
        expect(gateway.request?.toJson().containsKey('babyProfileId'), isFalse);
      },
    );

    test('fails without accepted JWT before API side effect', () async {
      final gateway = _RecordingSceneGenerationGateway();
      final repository = SceneGenerationRepositoryImpl(
        api: gateway,
        accountSnapshotLoader: () async => AccountLocalSnapshot.localOnly,
        persistRefreshedSession: (session) async => session,
        localeLoader: () async => 'zh-CN',
        installationIdLoader: () async => 'install_1',
      );

      await expectLater(
        repository.generate(
          source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
          clientRequestId: 'scene_request_6',
        ),
        throwsA(
          isA<SceneGenerationFailure>().having(
            (failure) => failure.kind,
            'kind',
            SceneGenerationFailureKind.authenticationRequired,
          ),
        ),
      );
      expect(gateway.callCount, 0);
    });

    test(
      'maps gateway RATE_LIMITED response to retryable rateLimited failure',
      () async {
        final api = SceneGenerationApi(
          authenticatedApiClient: AuthenticatedApiClient(
            apiService: _RefreshingAccountApiService(),
          ),
          dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
            ..httpClientAdapter = _SequenceAdapter(<_AdapterReply>[
              _AdapterReply(429, <String, Object?>{
                'code': 'RATE_LIMITED',
                'message': 'private rate-limit message',
                'retryAfter': 17,
              }),
            ]),
        );
        final repository = _repositoryForRealApi(api);

        await expectLater(
          repository.generate(
            source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
            clientRequestId: 'scene_request_rate_gateway',
          ),
          throwsA(
            isA<SceneGenerationFailure>()
                .having(
                  (failure) => failure.kind,
                  'kind',
                  SceneGenerationFailureKind.rateLimited,
                )
                .having((failure) => failure.retryable, 'retryable', isTrue),
          ),
        );
      },
    );

    test(
      'maps stable HTTP envelopes including version and policy codes',
      () async {
        const cases =
            <
              ({
                int status,
                String code,
                SceneGenerationFailureKind kind,
                bool retryable,
                bool versionEnvelope,
                bool includeDetails,
              })
            >[
              (
                status: 400,
                code: 'unsafe_custom_scene_text',
                kind: SceneGenerationFailureKind.invalidInput,
                retryable: false,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 400,
                code: 'invalid_scene_input',
                kind: SceneGenerationFailureKind.invalidInput,
                retryable: false,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 400,
                code: 'validation_failed',
                kind: SceneGenerationFailureKind.invalidInput,
                retryable: false,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 426,
                code: 'app_version_required',
                kind: SceneGenerationFailureKind.unavailable,
                retryable: false,
                versionEnvelope: true,
                includeDetails: true,
              ),
              (
                status: 400,
                code: 'invalid_app_version',
                kind: SceneGenerationFailureKind.invalidInput,
                retryable: false,
                versionEnvelope: true,
                includeDetails: true,
              ),
              (
                status: 422,
                code: 'generated_content_rejected',
                kind: SceneGenerationFailureKind.rejected,
                retryable: false,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 502,
                code: 'generation_invalid_output',
                kind: SceneGenerationFailureKind.rejected,
                retryable: false,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 429,
                code: 'custom_scene_rate_limited',
                kind: SceneGenerationFailureKind.rateLimited,
                retryable: true,
                versionEnvelope: false,
                includeDetails: false,
              ),
              (
                status: 429,
                code: 'generation_rate_limited',
                kind: SceneGenerationFailureKind.rateLimited,
                retryable: true,
                versionEnvelope: false,
                includeDetails: true,
              ),
              (
                status: 429,
                code: 'unknown_rate_code',
                kind: SceneGenerationFailureKind.rateLimited,
                retryable: true,
                versionEnvelope: false,
                includeDetails: false,
              ),
            ];

        for (final testCase in cases) {
          final body = testCase.versionEnvelope
              ? _versionError(
                  code: testCase.code,
                  details: testCase.includeDetails
                      ? <String, Object?>{
                          'generatedContentId': 'gcn_${testCase.code}',
                          'retryable': false,
                        }
                      : null,
                )
              : _standardError(
                  status: testCase.status,
                  code: testCase.code,
                  details: testCase.includeDetails
                      ? <String, Object?>{
                          'generatedContentId': 'gcn_${testCase.code}',
                          'retryable': false,
                        }
                      : null,
                );
          final api = SceneGenerationApi(
            authenticatedApiClient: AuthenticatedApiClient(
              apiService: _RefreshingAccountApiService(),
            ),
            dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
              ..httpClientAdapter = _SequenceAdapter(<_AdapterReply>[
                _AdapterReply(testCase.status, body),
              ]),
          );
          final repository = _repositoryForRealApi(api);

          await expectLater(
            repository.generate(
              source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
              clientRequestId: 'scene_${testCase.code}',
            ),
            throwsA(
              isA<SceneGenerationFailure>()
                  .having((failure) => failure.kind, 'kind', testCase.kind)
                  .having(
                    (failure) => failure.retryable,
                    'retryable',
                    testCase.retryable,
                  ),
            ),
          );
        }
      },
    );

    test(
      'maps every stable backend error kind and preserves recovery metadata',
      () async {
        const cases =
            <
              ({
                String code,
                int status,
                SceneGenerationFailureKind kind,
                bool retryable,
                bool requiresNewId,
              })
            >[
              (
                code: 'profile_unavailable',
                status: 404,
                kind: SceneGenerationFailureKind.profileUnavailable,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'shared_profile_unavailable',
                status: 404,
                kind: SceneGenerationFailureKind.sharedProfileUnavailable,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'household_access_required',
                status: 403,
                kind: SceneGenerationFailureKind.householdAccessRequired,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'preset_scene_unavailable',
                status: 404,
                kind: SceneGenerationFailureKind.presetSceneUnavailable,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'invalid_scene_source',
                status: 400,
                kind: SceneGenerationFailureKind.invalidInput,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'client_request_id_conflict',
                status: 409,
                kind: SceneGenerationFailureKind.requestConflict,
                retryable: false,
                requiresNewId: false,
              ),
              (
                code: 'client_request_terminal',
                status: 409,
                kind: SceneGenerationFailureKind.requestTerminal,
                retryable: true,
                requiresNewId: true,
              ),
              (
                code: 'generation_in_progress',
                status: 409,
                kind: SceneGenerationFailureKind.generationInProgress,
                retryable: true,
                requiresNewId: false,
              ),
              (
                code: 'custom_scene_rate_limited',
                status: 429,
                kind: SceneGenerationFailureKind.rateLimited,
                retryable: true,
                requiresNewId: false,
              ),
              (
                code: 'generation_unavailable',
                status: 503,
                kind: SceneGenerationFailureKind.unavailable,
                retryable: true,
                requiresNewId: false,
              ),
              (
                code: 'generation_timeout',
                status: 504,
                kind: SceneGenerationFailureKind.timeout,
                retryable: true,
                requiresNewId: false,
              ),
              (
                code: 'generated_content_rejected',
                status: 422,
                kind: SceneGenerationFailureKind.rejected,
                retryable: false,
                requiresNewId: false,
              ),
            ];

        for (final testCase in cases) {
          final gateway = _RecordingSceneGenerationGateway(
            error: SceneGenerationApiException.http(
              statusCode: testCase.status,
              code: testCase.code,
              generatedContentId: 'gcn_error',
              retryable: testCase.retryable,
              requiresNewClientRequestId: testCase.requiresNewId,
            ),
          );
          final repository = _repositoryFor(gateway);

          await expectLater(
            repository.generate(
              source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
              clientRequestId: 'scene_request_${testCase.code}',
            ),
            throwsA(
              isA<SceneGenerationFailure>()
                  .having((failure) => failure.kind, 'kind', testCase.kind)
                  .having(
                    (failure) => failure.generatedContentId,
                    'generatedContentId',
                    'gcn_error',
                  )
                  .having(
                    (failure) => failure.requiresNewClientRequestId,
                    'requiresNewClientRequestId',
                    testCase.requiresNewId,
                  ),
            ),
          );
        }
      },
    );

    test('redacts sensitive fixture values from failure strings', () {
      const sensitive = <String>[
        'private message body',
        '宝宝洗澡时一直躲水。',
        'install_secret',
        'account_secret',
        'Bearer token_secret',
        '13800138000',
      ];
      final failure = const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.unexpected,
        generatedContentId: 'gcn_safe',
      );

      final rendered = failure.toString();
      for (final value in sensitive) {
        expect(rendered, isNot(contains(value)));
      }
    });
  });
}

Future<SceneGenerationApiException> _apiErrorFor({
  required int status,
  required Object? body,
}) async {
  final api = SceneGenerationApi(
    authenticatedApiClient: AuthenticatedApiClient(
      apiService: _RefreshingAccountApiService(),
    ),
    dio: Dio(BaseOptions(baseUrl: 'http://localhost:8080'))
      ..httpClientAdapter = _SequenceAdapter(<_AdapterReply>[
        _AdapterReply(status, body),
      ]),
  );
  try {
    await api.generate(
      session: _session(),
      persistRefreshedSession: (session) async => session,
      request: SceneGenerationRequestDto(
        source: const CustomSceneGenerationSource('宝宝洗澡时一直躲水。'),
        locale: 'zh-CN',
        installationId: 'install_1',
        clientRequestId: 'scene_request_error',
      ),
    );
    fail('expected scene generation API failure');
  } on SceneGenerationApiException catch (error) {
    return error;
  }
}

Map<String, Object?> _standardError({
  required int status,
  required String code,
  Map<String, Object?>? details,
}) {
  final result = <String, Object?>{
    'timestamp': '2026-09-08T00:00:00Z',
    'status': status,
    'code': code,
    'message': 'controlled error',
    'details': details,
  };
  if (details == null) {
    result.remove('details');
  }
  return result;
}

Map<String, Object?> _versionError({
  required String code,
  required Map<String, Object?>? details,
}) {
  final result = <String, Object?>{
    'code': code,
    'message': 'upgrade required',
    'minimumSupportedVersion': '1.3.0',
    'upgradeUrl': 'https://example.test/upgrade',
    'details': details,
    'correlationId': 'err_1234567890abcdef',
  };
  if (details == null) {
    result.remove('details');
  }
  return result;
}

SceneGenerationRepositoryImpl _repositoryForRealApi(SceneGenerationApi api) {
  return SceneGenerationRepositoryImpl(
    api: api,
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: _session(),
    ),
    persistRefreshedSession: (session) async => session,
    localeLoader: () async => 'zh-CN',
    installationIdLoader: () async => 'install_1',
  );
}

Map<String, dynamic> _validResponse({Map<String, Object?>? source}) {
  final routeActivityId = source?['type'] == 'preset'
      ? source!['presetSceneId'] as String
      : 'activity_bath';
  return <String, dynamic>{
    'generatedContentId': 'gcn_1',
    'bundleSchemaVersion': generatedCareMomentSchemaVersion,
    'route': <String, Object?>{
      'sceneId': 'space_bath',
      'spaceId': 'space_bath',
      'momentId': routeActivityId,
      'activityId': routeActivityId,
      'phraseId': 'phrase_starter',
    },
    'scene': <String, Object?>{
      'spaceTitle': '日常照护',
      'activityTitle': '洗澡安抚',
      'sceneTag': 'bath',
    },
    'starter': _utterance(
      utteranceId: 'utt_starter',
      phraseId: 'phrase_starter',
      role: 'starter',
      reaction: null,
      displayOrder: 1,
      deliveryGuidanceZh: '慢慢说',
    ),
    'reactionSupports': <Map<String, Object?>>[
      _utterance(
        utteranceId: 'utt_cooperating',
        phraseId: 'phrase_cooperating',
        role: 'reaction_support',
        reaction: 'cooperating',
        displayOrder: 2,
      ),
      _utterance(
        utteranceId: 'utt_hesitant',
        phraseId: 'phrase_hesitant',
        role: 'reaction_support',
        reaction: 'hesitant',
        displayOrder: 3,
      ),
      _utterance(
        utteranceId: 'utt_resisting',
        phraseId: 'phrase_resisting',
        role: 'reaction_support',
        reaction: 'resisting',
        displayOrder: 4,
      ),
      _utterance(
        utteranceId: 'utt_no_response',
        phraseId: 'phrase_no_response',
        role: 'reaction_support',
        reaction: 'no_response',
        displayOrder: 5,
      ),
      _utterance(
        utteranceId: 'utt_other',
        phraseId: 'phrase_other',
        role: 'reaction_support',
        reaction: 'other',
        displayOrder: 6,
      ),
    ],
    'source':
        source ??
        <String, Object?>{
          'type': 'custom',
          'presetSceneId': null,
          'presetSceneVersion': null,
        },
  };
}

Map<String, Object?> _utterance({
  required String utteranceId,
  required String phraseId,
  required String role,
  required String? reaction,
  required int displayOrder,
  String deliveryGuidanceZh = '接住回应',
}) {
  return <String, Object?>{
    'utteranceId': utteranceId,
    'phraseId': phraseId,
    'english': 'I am here.',
    'chinese': '我在这里。',
    'pronunciation': 'aɪ æm hɪr',
    'tprActionZh': '靠近宝宝',
    'deliveryGuidanceZh': deliveryGuidanceZh,
    'difficulty': 'starter',
    'role': role,
    'reaction': reaction,
    'displayOrder': displayOrder,
    'providerProvenance': <String, Object?>{
      'origin': 'provider_generated',
      'providerName': 'provider',
      'modelName': 'model',
      'attemptNumber': 1,
    },
  };
}

AccountSession _session({String accessToken = 'access_live'}) {
  return AccountSession(
    accountId: 'account_1',
    sessionId: 'session_1',
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: accessToken,
    refreshToken: 'refresh_live',
    tokenType: 'Bearer',
    accessTokenExpiresAt: DateTime.utc(2026, 7, 28, 1),
    refreshTokenExpiresAt: DateTime.utc(2026, 8, 28),
  );
}

SceneGenerationRepositoryImpl _repositoryFor(
  _RecordingSceneGenerationGateway gateway,
) {
  return SceneGenerationRepositoryImpl(
    api: gateway,
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: _session(),
    ),
    persistRefreshedSession: (session) async => session,
    localeLoader: () async => 'zh-CN',
    installationIdLoader: () async => 'install_1',
  );
}

class _RecordingSceneGenerationGateway implements SceneGenerationApiGateway {
  _RecordingSceneGenerationGateway({this.error, this.source});

  final SceneGenerationApiException? error;
  final Map<String, Object?>? source;
  SceneGenerationRequestDto? request;
  int callCount = 0;

  @override
  Future<SceneGenerationResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required SceneGenerationRequestDto request,
  }) async {
    callCount += 1;
    this.request = request;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return SceneGenerationResponseDto.fromJson(_validResponse(source: source));
  }
}

class _RefreshingAccountApiService extends AccountApiService {
  int refreshCallCount = 0;

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) async {
    refreshCallCount += 1;
    return AccountSessionResponse(
      accountId: 'account_1',
      sessionId: 'session_1',
      maskedPhoneNumber: '138****1234',
      createdAt: DateTime.utc(2026, 7, 28),
      consentStatus: 'accepted',
      accessToken: 'access_new',
      refreshToken: 'refresh_new',
      tokenType: 'Bearer',
      accessTokenExpiresAt: DateTime.utc(2026, 8, 28),
      refreshTokenExpiresAt: DateTime.utc(2026, 9, 28),
    );
  }
}

class _AdapterReply {
  const _AdapterReply(this.statusCode, this.data);

  final int statusCode;
  final Object? data;
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.path,
    required this.headers,
    required this.data,
  });

  final String path;
  final Map<String, Object?> headers;
  final Object? data;
}

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.replies);

  final List<_AdapterReply> replies;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];
  var _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
      _RecordedRequest(
        path: options.path,
        headers: Map<String, Object?>.from(options.headers),
        data: options.data,
      ),
    );
    final reply = replies[_index++];
    return ResponseBody.fromString(
      jsonEncode(reply.data),
      reply.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
