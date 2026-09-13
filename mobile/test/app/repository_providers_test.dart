import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_path/application/care_audio_session_coordinator.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';

void main() {
  test('care audio coordinator is shared for provider container lifetime', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final first = container.read(careAudioSessionCoordinatorProvider);
    final second = container.read(careAudioSessionCoordinatorProvider);

    expect(second, same(first));
  });

  test(
    'custom scene provider stops audio through shared coordinator',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'care_audio_provider_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final draftStore = CustomSceneDraftStore(
        directoryResolver: () async => tempDir,
      );
      final continuation = CustomSceneDraftContinuationCoordinator(
        draftStore: draftStore,
        authContinuationCoordinator: AuthContinuationCoordinator(
          store: AuthContinuationStore(directoryResolver: () async => tempDir),
          correlationIdGenerator: () => 'provider_auth_1',
        ),
      );
      final registry = GeneratedPracticeContentRegistry(
        store: GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        ),
        resumeStore: GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        ),
        accountContextLoader: () async => 'account_a',
      );
      final coordinator = CareAudioSessionCoordinator();
      final audio = _ProviderAudioController();
      coordinator.register(audio);
      addTearDown(audio.dispose);

      final container = ProviderContainer(
        overrides: [
          customSceneRepositoryProvider.overrideWith(
            (ref) async => _HealthSafetyRepository(),
          ),
          customSceneDraftStoreProvider.overrideWithValue(draftStore),
          customSceneDraftContinuationCoordinatorProvider.overrideWithValue(
            continuation,
          ),
          generatedPracticeContentRegistryProvider.overrideWithValue(registry),
          careAudioSessionCoordinatorProvider.overrideWithValue(coordinator),
        ],
      );
      addTearDown(container.dispose);

      final controller = await container.read(
        customSceneSubmissionControllerProvider.future,
      );
      await controller.submit(_ProviderDraft());

      expect(audio.stopCalls, 1);
      expect(controller.state.phase, CustomSceneSubmissionPhase.healthSafety);
    },
  );
}

class _HealthSafetyRepository implements CustomSceneRepository {
  @override
  Future<CustomSceneResult> generate(CustomSceneDraft draft) async {
    return const HealthSafetyResult(healthAssessmentUnavailableNotice);
  }
}

class _ProviderDraft extends CustomSceneDraft {
  _ProviderDraft()
    : super(
        text: '宝宝今天不舒服。',
        entrySource: CustomSceneEntrySource.scene,
        requestIdentity: CustomSceneRequestIdentity(
          clientRequestId: 'provider_request_1',
        ),
      );
}

class _ProviderAudioController implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  int stopCalls = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> dispose() async {
    await _completion.close();
  }
}
