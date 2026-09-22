import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';

import '../../../support/generated_care_moment_fixture.dart';

void main() {
  late Directory tempDir;
  late GeneratedCareMomentLocalStore store;
  late GeneratedCareTurnResumeMarkerStore resumeStore;
  late GeneratedPracticeAccessContext access;
  late GeneratedPracticeContentRegistry registry;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('generated_access_');
    store = GeneratedCareMomentLocalStore(
      directoryResolver: () async => tempDir,
    );
    resumeStore = GeneratedCareTurnResumeMarkerStore(
      directoryResolver: () async => tempDir,
    );
    access = GeneratedPracticeAccessContext.accepted(
      accountContext: 'account_a',
      householdScopeFingerprint: householdScopeFingerprint('household_a'),
    );
    registry = GeneratedPracticeContentRegistry(
      store: store,
      resumeStore: resumeStore,
      currentAccessContextLoader: () async => access,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'pending household transition hides old scope before disk cleanup',
    () async {
      final oldMoment = _moment(
        'old_scope',
        inputSource: SceneGenerationSourceType.preset,
        presetSceneId: 'bath_time',
        presetSceneVersion: 1,
      );
      await store.upsert(
        StoredGeneratedCareMoment(
          accountContext: 'account_a',
          householdScopeFingerprint: householdScopeFingerprint('household_a'),
          moment: oldMoment,
        ),
      );
      await resumeStore.write(
        accountContext: 'account_a',
        generatedContentId: oldMoment.generatedContentId,
        confirmedAt: DateTime.utc(2026, 9, 10),
      );
      access = GeneratedPracticeAccessContext.accepted(
        accountContext: 'account_a',
        householdScopeFingerprint: householdScopeFingerprint('household_b'),
        pendingClearHouseholdScopeFingerprint: householdScopeFingerprint(
          'household_a',
        ),
      );

      expect(
        await registry.resolveGeneratedContent(
          generatedContentId: oldMoment.generatedContentId,
        ),
        isNull,
      );
      expect(await registry.listGeneratedActivities(), isEmpty);
      expect(await registry.loadGeneratedCareTurnResumeMarker(), isNull);
    },
  );

  test('revoked access returns no generated content', () async {
    final moment = _moment('revoked');
    await store.upsert(
      StoredGeneratedCareMoment(
        accountContext: 'account_a',
        householdScopeFingerprint: householdScopeFingerprint('household_a'),
        moment: moment,
      ),
    );
    access = GeneratedPracticeAccessContext.denied(
      accountContext: 'account_a',
      reason: GeneratedPracticeAccessDeniedReason.consentRevoked,
    );

    expect(
      await registry.resolveGeneratedContent(
        generatedContentId: moment.generatedContentId,
      ),
      isNull,
    );
    expect(await registry.listGeneratedActivities(), isEmpty);
    expect(await registry.loadGeneratedCareTurnResumeMarker(), isNull);
  });

  test(
    'signed-out, consent-required, and deleted access all fail closed',
    () async {
      final moment = _moment('consent_states');
      await store.upsert(
        StoredGeneratedCareMoment(
          accountContext: 'account_a',
          householdScopeFingerprint: householdScopeFingerprint('household_a'),
          moment: moment,
        ),
      );
      for (final reason in <GeneratedPracticeAccessDeniedReason>[
        GeneratedPracticeAccessDeniedReason.signedOut,
        GeneratedPracticeAccessDeniedReason.consentRequired,
        GeneratedPracticeAccessDeniedReason.accountDeleted,
      ]) {
        access = GeneratedPracticeAccessContext.denied(
          accountContext: 'account_a',
          reason: reason,
        );
        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
          reason: reason.name,
        );
        expect(await registry.listGeneratedActivities(), isEmpty);
      }
    },
  );

  test(
    'legacy null-scope custom remains readable while null-scope preset fails closed',
    () async {
      final custom = _moment('legacy_custom');
      final preset = _moment(
        'unscoped_preset',
        spaceId: 'daily_care',
        activityId: 'bath_time',
        inputSource: SceneGenerationSourceType.preset,
        presetSceneId: 'bath_time',
        presetSceneVersion: 1,
      );
      await store.upsert(
        StoredGeneratedCareMoment(accountContext: 'account_a', moment: custom),
      );
      await store.upsert(
        StoredGeneratedCareMoment(accountContext: 'account_a', moment: preset),
      );

      expect(
        await registry.resolveGeneratedContent(
          generatedContentId: custom.generatedContentId,
        ),
        isNotNull,
      );
      expect(
        await registry.resolveGeneratedContent(
          generatedContentId: preset.generatedContentId,
        ),
        isNull,
      );
    },
  );

  test(
    'registration fails closed when durable household scope read is unavailable',
    () async {
      registry = GeneratedPracticeContentRegistry(
        store: store,
        resumeStore: resumeStore,
        currentAccessContextLoader: () async =>
            GeneratedPracticeAccessContext.householdReadUnavailable(
              accountContext: 'account_a',
            ),
      );

      await expectLater(
        registry.register(
          accountContext: 'account_a',
          moment: _moment('read_failure'),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await store.readAll(), isEmpty);
    },
  );
}

GeneratedCareMoment _moment(
  String id, {
  String? spaceId,
  String? activityId,
  SceneGenerationSourceType inputSource = SceneGenerationSourceType.custom,
  String? presetSceneId,
  int? presetSceneVersion,
}) {
  return generatedCareMomentFixture(
    generatedContentId: id,
    spaceId:
        spaceId ??
        (inputSource == SceneGenerationSourceType.preset ? 'daily_care' : null),
    activityId: activityId ?? presetSceneId,
    inputSource: inputSource,
    presetSceneId: presetSceneId,
    presetSceneVersion: presetSceneVersion,
  );
}
