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
}

CustomSceneRepositoryImpl _repository({required _RecordingGateway gateway}) {
  return CustomSceneRepositoryImpl(
    api: gateway,
    mapper: const CustomSceneMapper(),
    profileContextResolver: _ProfileSource(),
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: _session(),
    ),
    persistRefreshedSession: (session) async => session,
    installationIdLoader: () async => 'install_1',
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
