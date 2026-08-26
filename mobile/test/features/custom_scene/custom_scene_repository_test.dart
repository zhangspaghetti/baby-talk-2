import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_api.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_mapper.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_profile_context_resolver.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_repository_impl.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';

void main() {
  test(
    'production request identity reaches gateway without exposing long digits',
    () async {
      final gateway = _RecordingGateway();
      final repository = _repository(gateway: gateway);
      final requestIdentity = CustomSceneRequestIdentity.create(
        now: DateTime.utc(2026, 7, 31, 2),
      );

      await expectLater(
        repository.generate(
          CustomSceneDraft(
            text: '宝宝洗澡时一直躲水。',
            entrySource: CustomSceneEntrySource.today,
            requestIdentity: requestIdentity,
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(gateway.callCount, 1);
      expect(gateway.request?.clientRequestId, requestIdentity.clientRequestId);
      expect(
        RegExp(r'[0-9]{11,}').hasMatch(requestIdentity.clientRequestId),
        isFalse,
      );
    },
  );

  test(
    'rejects phone-like request identity before network side effect',
    () async {
      final gateway = _RecordingGateway();
      final repository = _repository(gateway: gateway);

      await expectLater(
        repository.generate(
          CustomSceneDraft(
            text: '宝宝洗澡时一直躲水。',
            entrySource: CustomSceneEntrySource.today,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'custom_scene_13800138000',
            ),
          ),
        ),
        throwsA(
          isA<CustomSceneFailure>().having(
            (failure) => failure.kind,
            'kind',
            CustomSceneFailureKind.invalidDraft,
          ),
        ),
      );
      expect(gateway.callCount, 0);
    },
  );

  test(
    'rejects phone-like installation identity before network side effect',
    () async {
      final gateway = _RecordingGateway();
      final repository = _repository(
        gateway: gateway,
        installationIdLoader: () async => 'install_1722391920000000_dead_beef',
      );

      await expectLater(
        repository.generate(
          CustomSceneDraft(
            text: '宝宝洗澡时一直躲水。',
            entrySource: CustomSceneEntrySource.today,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'custom_scene_3',
            ),
          ),
        ),
        throwsA(
          isA<CustomSceneFailure>().having(
            (failure) => failure.kind,
            'kind',
            CustomSceneFailureKind.invalidDraft,
          ),
        ),
      );
      expect(gateway.callCount, 0);
    },
  );

  test('maps backend invalid installation ID to invalid draft', () async {
    final gateway = _RecordingGateway(
      error: const CustomSceneApiException(
        kind: CustomSceneApiFailureKind.http,
        statusCode: 400,
        code: 'invalid_installation_id',
      ),
    );
    final repository = _repository(gateway: gateway);

    await expectLater(
      repository.generate(
        CustomSceneDraft(
          text: '宝宝洗澡时一直躲水。',
          entrySource: CustomSceneEntrySource.today,
          requestIdentity: CustomSceneRequestIdentity(
            clientRequestId: 'custom_scene_4',
          ),
        ),
      ),
      throwsA(
        isA<CustomSceneFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              CustomSceneFailureKind.invalidDraft,
            )
            .having((failure) => failure.retryable, 'retryable', isFalse),
      ),
    );
    expect(gateway.callCount, 1);
  });

  test('uses account/profile sources and maps terminal retry safely', () async {
    final gateway = _RecordingGateway(
      error: const CustomSceneApiException(
        kind: CustomSceneApiFailureKind.http,
        statusCode: 409,
        code: 'client_request_terminal',
        generatedContentId: 'gcn_terminal',
        requiresNewClientRequestId: true,
      ),
    );
    final repository = _repository(gateway: gateway);
    final draft = CustomSceneDraft(
      text: '宝宝洗澡时一直躲水。',
      entrySource: CustomSceneEntrySource.today,
      requestIdentity: CustomSceneRequestIdentity(
        clientRequestId: 'custom_scene_1',
      ),
    );

    await expectLater(
      repository.generate(draft),
      throwsA(
        isA<CustomSceneFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              CustomSceneFailureKind.requestTerminal,
            )
            .having(
              (failure) => failure.requiresNewClientRequestId,
              'requires new id',
              isTrue,
            )
            .having(
              (failure) => failure.toString(),
              'safe toString',
              isNot(contains('宝宝洗澡时一直躲水。')),
            ),
      ),
    );
    expect(gateway.request?.installationId, 'install_1');
    expect(gateway.request?.ageRange, 'm7_11');
    expect(gateway.request?.parentGoal, 'natural_opening');
    expect(gateway.request?.locale, 'zh-CN');
    expect(gateway.request?.clientRequestId, 'custom_scene_1');
  });

  test(
    'fails before network side effect without an accepted account',
    () async {
      final gateway = _RecordingGateway();
      final repository = CustomSceneRepositoryImpl(
        api: gateway,
        mapper: const CustomSceneMapper(),
        profileContextResolver: _ProfileSource(),
        accountSnapshotLoader: () async => AccountLocalSnapshot.localOnly,
        persistRefreshedSession: (session) async => session,
        installationIdLoader: () async => 'install_1',
      );

      await expectLater(
        repository.generate(
          CustomSceneDraft(
            text: '宝宝不肯穿衣服。',
            entrySource: CustomSceneEntrySource.scene,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'custom_scene_2',
            ),
          ),
        ),
        throwsA(
          isA<CustomSceneFailure>().having(
            (failure) => failure.kind,
            'kind',
            CustomSceneFailureKind.authenticationRequired,
          ),
        ),
      );
      expect(gateway.callCount, 0);
    },
  );

  test(
    'maps profile network failure to network instead of profile unavailable',
    () async {
      final gateway = _RecordingGateway();
      final repository = _repository(
        gateway: gateway,
        profileContextResolver: _FailingProfileSource(
          const CustomSceneProfileContextException.network(),
        ),
      );

      await expectLater(
        repository.generate(
          CustomSceneDraft(
            text: '宝宝洗澡时一直躲水。',
            entrySource: CustomSceneEntrySource.scene,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'custom_scene_network',
            ),
          ),
        ),
        throwsA(
          isA<CustomSceneFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                CustomSceneFailureKind.network,
              )
              .having((failure) => failure.retryable, 'retryable', isTrue)
              .having(
                (failure) => failure.presentationMessage,
                'presentation message',
                '网络暂不可用，请检查后重试。',
              ),
        ),
      );
      expect(gateway.callCount, 0);
    },
  );
}

CustomSceneRepositoryImpl _repository({
  required _RecordingGateway gateway,
  Future<String> Function()? installationIdLoader,
  CustomSceneProfileContextSource? profileContextResolver,
}) {
  return CustomSceneRepositoryImpl(
    api: gateway,
    mapper: const CustomSceneMapper(),
    profileContextResolver: profileContextResolver ?? _ProfileSource(),
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: _session(),
    ),
    persistRefreshedSession: (session) async => session,
    installationIdLoader: installationIdLoader ?? () async => 'install_1',
  );
}

class _ProfileSource implements CustomSceneProfileContextSource {
  @override
  Future<CustomSceneProfileContext> resolve() async {
    return CustomSceneProfileContext(
      ageRange: 'm7_11',
      parentGoal: 'natural_opening',
      locale: 'zh-CN',
    );
  }
}

class _FailingProfileSource implements CustomSceneProfileContextSource {
  _FailingProfileSource(this.error);

  final CustomSceneProfileContextException error;

  @override
  Future<CustomSceneProfileContext> resolve() async => throw error;
}

class _RecordingGateway implements CustomSceneDiscoveryGateway {
  _RecordingGateway({this.error});

  final CustomSceneApiException? error;
  CustomSceneRequestDto? request;
  int callCount = 0;

  @override
  Future<CustomSceneDiscoveryResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required CustomSceneRequestDto request,
  }) async {
    callCount += 1;
    this.request = request;
    throw error ?? StateError('unexpected network call');
  }
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
