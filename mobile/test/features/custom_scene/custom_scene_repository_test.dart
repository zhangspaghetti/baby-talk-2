import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_repository_impl.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_failure.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

void main() {
  test(
    'delegates one custom source request without profile or household preflight',
    () async {
      var babyProfileLoadCount = 0;
      var householdApiRequestCount = 0;
      final sceneGenerationRepository = _RecordingSceneGenerationRepository();
      final repository = CustomSceneRepositoryImpl(
        sceneGenerationRepository: sceneGenerationRepository,
      );
      final draft = _draft('custom_scene_1');

      await expectLater(repository.generate(draft), throwsA(isA<StateError>()));

      expect(sceneGenerationRepository.sources, hasLength(1));
      expect(
        sceneGenerationRepository.sources.single,
        isA<CustomSceneGenerationSource>().having(
          (source) => source.text,
          'text',
          draft.text,
        ),
      );
      expect(sceneGenerationRepository.clientRequestIds, <String>[
        draft.requestIdentity.clientRequestId,
      ]);
      expect(babyProfileLoadCount, 0);
      expect(householdApiRequestCount, 0);
    },
  );

  test(
    'rejects phone-like request identity before unified generation request',
    () async {
      final sceneGenerationRepository = _RecordingSceneGenerationRepository();
      final repository = CustomSceneRepositoryImpl(
        sceneGenerationRepository: sceneGenerationRepository,
      );

      await expectLater(
        repository.generate(_draft('custom_scene_13800138000')),
        throwsA(
          isA<CustomSceneFailure>().having(
            (failure) => failure.kind,
            'kind',
            CustomSceneFailureKind.invalidDraft,
          ),
        ),
      );
      expect(sceneGenerationRepository.sources, isEmpty);
    },
  );

  test('maps unified failure while preserving recovery metadata', () async {
    final sceneGenerationRepository = _RecordingSceneGenerationRepository(
      failure: const SceneGenerationFailure(
        kind: SceneGenerationFailureKind.requestTerminal,
        generatedContentId: 'gcn_terminal',
        retryable: true,
        requiresNewClientRequestId: true,
      ),
    );
    final repository = CustomSceneRepositoryImpl(
      sceneGenerationRepository: sceneGenerationRepository,
    );

    await expectLater(
      repository.generate(_draft('custom_scene_2')),
      throwsA(
        isA<CustomSceneFailure>()
            .having(
              (failure) => failure.kind,
              'kind',
              CustomSceneFailureKind.requestTerminal,
            )
            .having(
              (failure) => failure.generatedContentId,
              'generated content ID',
              'gcn_terminal',
            )
            .having((failure) => failure.retryable, 'retryable', isTrue)
            .having(
              (failure) => failure.requiresNewClientRequestId,
              'requires new ID',
              isTrue,
            ),
      ),
    );
  });

  test('maps each deterministic unified profile/household failure', () async {
    const cases = <(SceneGenerationFailureKind, CustomSceneFailureKind)>[
      (
        SceneGenerationFailureKind.profileUnavailable,
        CustomSceneFailureKind.profileUnavailable,
      ),
      (
        SceneGenerationFailureKind.sharedProfileUnavailable,
        CustomSceneFailureKind.sharedProfileUnavailable,
      ),
      (
        SceneGenerationFailureKind.householdAccessRequired,
        CustomSceneFailureKind.householdAccessRequired,
      ),
      (
        SceneGenerationFailureKind.presetSceneUnavailable,
        CustomSceneFailureKind.presetSceneUnavailable,
      ),
    ];

    for (final (sceneKind, customKind) in cases) {
      final repository = CustomSceneRepositoryImpl(
        sceneGenerationRepository: _RecordingSceneGenerationRepository(
          failure: SceneGenerationFailure(kind: sceneKind),
        ),
      );

      await expectLater(
        repository.generate(_draft('custom_scene_${sceneKind.name}')),
        throwsA(
          isA<CustomSceneFailure>().having(
            (failure) => failure.kind,
            'kind',
            customKind,
          ),
        ),
      );
    }
  });
}

CustomSceneDraft _draft(String clientRequestId) {
  return CustomSceneDraft(
    text: '宝宝洗澡时一直躲水。',
    entrySource: CustomSceneEntrySource.today,
    requestIdentity: CustomSceneRequestIdentity(
      clientRequestId: clientRequestId,
    ),
  );
}

class _RecordingSceneGenerationRepository implements SceneGenerationRepository {
  _RecordingSceneGenerationRepository({this.failure});

  final SceneGenerationFailure? failure;
  final List<SceneGenerationSource> sources = <SceneGenerationSource>[];
  final List<String> clientRequestIds = <String>[];

  @override
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) async {
    sources.add(source);
    clientRequestIds.add(clientRequestId);
    if (failure != null) {
      throw failure!;
    }
    throw StateError('sentinel: unified generation request observed');
  }
}
