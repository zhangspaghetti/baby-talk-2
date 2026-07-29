import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

import '../../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('GeneratedPracticeContentRegistry', () {
    late Directory tempDir;
    late String accountContext;
    late GeneratedCareMomentLocalStore store;
    late GeneratedPracticeContentRegistry registry;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generated_care_moment_');
      accountContext = 'account_a';
      store = GeneratedCareMomentLocalStore(
        directoryResolver: () async => tempDir,
      );
      registry = GeneratedPracticeContentRegistry(
        store: store,
        accountContextLoader: () async => accountContext,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'approved bundle survives restart and only resolves for its account',
      () async {
        final moment = _moment('generated_1');
        await registry.register(accountContext: accountContext, moment: moment);

        final restartedRegistry = GeneratedPracticeContentRegistry(
          store: GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ),
          accountContextLoader: () async => accountContext,
        );
        final snapshot = await restartedRegistry.resolveGeneratedContent(
          generatedContentId: moment.generatedContentId,
        );

        expect(snapshot, isNotNull);
        expect(snapshot!.contentSource, PracticeContentSource.generated);
        expect(snapshot.generatedContentId, moment.generatedContentId);
        expect(snapshot.phrases, hasLength(1 + BabyReactionType.values.length));
        expect(snapshot.phrases.first.phraseId, moment.starter.phraseId);
        expect(
          snapshot.utteranceIdForPhrase(moment.starter.phraseId),
          moment.starter.utteranceId,
        );
        for (final reaction in BabyReactionType.values) {
          final support = moment.reactionSupports[reaction];
          expect(snapshot.reactionSupportPhraseId(reaction), support.phraseId);
          expect(
            snapshot.utteranceIdForPhrase(support.phraseId),
            support.utteranceId,
          );
        }

        accountContext = 'account_b';
        expect(
          await restartedRegistry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        expect(
          await restartedRegistry.resolveActivity(
            spaceId: moment.spaceId,
            activityId: moment.activityId,
          ),
          isNull,
        );
      },
    );

    test(
      'rejects account mismatch and lifecycle cleanup removes all content',
      () async {
        final moment = _moment('generated_2');
        accountContext = 'account_b';
        await expectLater(
          registry.register(accountContext: 'account_a', moment: moment),
          throwsStateError,
        );

        accountContext = 'account_a';
        await registry.register(accountContext: accountContext, moment: moment);
        await registry.clearForAccount(accountContext);
        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );

        await registry.register(accountContext: accountContext, moment: moment);
        await registry.clearForLifecycle();
        expect(await store.readAll(), isEmpty);
      },
    );

    test(
      'quarantines legacy data before any registry consumer can resolve it',
      () async {
        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}'
          '${store.fileName}',
        );
        await legacyFile.writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'records': <Object?>[
              <String, Object?>{'accountContext': accountContext},
            ],
          }),
        );

        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: 'legacy_generated_content',
          ),
          isNull,
        );
        expect(await store.readAll(), isEmpty);

        final diagnostics = await store.readQuarantineDiagnostics();
        expect(diagnostics, hasLength(1));
        expect(diagnostics.single.reasonCode, 'unsupported_store_schema');
        expect(diagnostics.single.schemaVersion, '1');
        expect(diagnostics.single.recordCount, 1);
        expect(diagnostics.single.irreversibleFingerprint, isNotEmpty);
        expect(
          await legacyFile.readAsString(),
          isNot(contains(accountContext)),
        );

        await store.purgeQuarantinedForAccount(accountContext);
        await store.purgeQuarantinedForAccount(accountContext);
        expect(await store.readQuarantineDiagnostics(), isEmpty);
      },
    );

    test(
      'quarantines malformed current bundle and removes its text before read',
      () async {
        final moment = _moment('invalid_current');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final records = root['records'] as List<dynamic>;
        final record = records.single as Map<String, dynamic>;
        final supports = record['reactionSupports'] as Map<String, dynamic>;
        final cooperating = supports['cooperating'] as Map<String, dynamic>;
        cooperating['role'] = 'starter';
        await file.writeAsString(jsonEncode(root));

        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        expect(await store.readAll(), isEmpty);
        final diagnostics = await store.readQuarantineDiagnostics();
        expect(diagnostics.single.reasonCode, 'invalid_generated_bundle');
        expect(
          await file.readAsString(),
          allOf(
            isNot(contains(moment.starter.english)),
            isNot(contains(accountContext)),
          ),
        );
      },
    );

    test(
      'quarantines persisted utterance sources outside generated before resolve',
      () async {
        final moment = _moment('invalid_utterance_source');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final records = root['records'] as List<dynamic>;
        final record = records.single as Map<String, dynamic>;
        final starter = record['starter'] as Map<String, dynamic>;
        starter['source'] = 'legacy';
        await file.writeAsString(jsonEncode(root));

        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        expect(await store.readAll(), isEmpty);
        expect(await store.readQuarantineDiagnostics(), hasLength(1));
        expect(
          await file.readAsString(),
          allOf(
            isNot(contains(moment.starter.english)),
            isNot(contains(accountContext)),
          ),
        );
      },
    );

    test(
      'quarantines persisted top-level sources outside generated before resolve',
      () async {
        final moment = _moment('invalid_top_level_source');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final records = root['records'] as List<dynamic>;
        final record = records.single as Map<String, dynamic>;
        record['source'] = 'legacy';
        await file.writeAsString(jsonEncode(root));

        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        expect(await store.readAll(), isEmpty);
        expect(await store.readQuarantineDiagnostics(), hasLength(1));
        expect(
          await file.readAsString(),
          allOf(
            isNot(contains(moment.starter.english)),
            isNot(contains(accountContext)),
          ),
        );
      },
    );

    test(
      'registration runs account-scoped quarantine metadata maintenance',
      () async {
        final legacyFile = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        await legacyFile.writeAsString(
          jsonEncode(<String, Object?>{
            'schemaVersion': 1,
            'records': <Object?>[
              <String, Object?>{'accountContext': accountContext},
            ],
          }),
        );
        expect(await store.readAll(), isEmpty);
        expect(await store.readQuarantineDiagnostics(), hasLength(1));

        final moment = _moment('post_quarantine_registration');
        await registry.register(accountContext: accountContext, moment: moment);

        expect(await store.readQuarantineDiagnostics(), isEmpty);
        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNotNull,
        );
      },
    );

    test('quarantine purge is account-scoped and idempotent', () async {
      final accountAMoment = _moment('account_a_invalid');
      await registry.register(
        accountContext: accountContext,
        moment: accountAMoment,
      );
      accountContext = 'account_b';
      final accountBMoment = _moment('account_b_valid');
      await registry.register(
        accountContext: accountContext,
        moment: accountBMoment,
      );

      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
      );
      final root =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final records = root['records'] as List<dynamic>;
      final firstRecord = records.first as Map<String, dynamic>;
      final starter = firstRecord['starter'] as Map<String, dynamic>;
      starter['reaction'] = 'cooperating';
      await file.writeAsString(jsonEncode(root));

      expect(
        await registry.resolveGeneratedContent(
          generatedContentId: accountBMoment.generatedContentId,
        ),
        isNotNull,
      );
      expect(await store.readQuarantineDiagnostics(), hasLength(1));

      await store.purgeQuarantinedForAccount('account_a');
      await store.purgeQuarantinedForAccount('account_a');

      expect(await store.readQuarantineDiagnostics(), isEmpty);
      expect(
        await registry.resolveGeneratedContent(
          generatedContentId: accountBMoment.generatedContentId,
        ),
        isNotNull,
      );
    });

    test(
      'PracticeRepository validates generated phrase through formal event path',
      () async {
        final localDataSource = await PracticeLocalDataSource.open(
          directory: tempDir.path,
          name: 'generated_${DateTime.now().microsecondsSinceEpoch}',
        );
        final repository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'generated_installation',
          ),
          contentResolver: registry,
        );
        addTearDown(() => repository.close(deleteFromDisk: true));

        final moment = _moment('generated_3');
        await registry.register(accountContext: accountContext, moment: moment);
        final snapshot = await repository.getGeneratedActivitySnapshot(
          generatedContentId: moment.generatedContentId,
        );
        final turn = await CarePathRepository(
          practiceRepository: repository,
        ).startGeneratedMoment(generatedContentId: moment.generatedContentId);
        final event = await repository.recordReaction(
          spaceId: snapshot.spaceId,
          activityId: snapshot.activityId,
          phraseId: moment.starter.phraseId,
          reactionType: BabyReactionType.cooperating,
          generatedContentId: moment.generatedContentId,
          utteranceId: moment.starter.utteranceId,
          localEventId: 'generated_event_1',
        );
        final replayedWithDifferentLocalId = await repository.recordReaction(
          spaceId: snapshot.spaceId,
          activityId: snapshot.activityId,
          phraseId: moment.starter.phraseId,
          reactionType: BabyReactionType.cooperating,
          generatedContentId: moment.generatedContentId,
          utteranceId: moment.starter.utteranceId,
          localEventId: 'generated_event_replay',
        );

        expect(event.phraseId, moment.starter.phraseId);
        expect(turn.moment.contentSource, PracticeContentSource.generated);
        expect(turn.moment.generatedContentId, moment.generatedContentId);
        expect(turn.currentUtterance?.phraseId, moment.starter.phraseId);
        expect(
          turn.currentUtterance?.audioSource,
          GeneratedCareAudioSource(
            generatedContentId: moment.generatedContentId,
            utteranceId: moment.starter.utteranceId,
          ),
        );
        expect(
          await repository.findEventByLocalEventId(event.localEventId),
          event,
        );
        expect(replayedWithDifferentLocalId, event);
        expect(
          await repository.listEventHistory(
            spaceId: snapshot.spaceId,
            activityId: snapshot.activityId,
          ),
          hasLength(1),
        );
        await expectLater(
          repository.getGeneratedActivitySnapshot(
            generatedContentId: 'missing',
          ),
          throwsFormatException,
        );
        await repository.close(deleteFromDisk: true);
        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
      },
    );

    test('generated Care Turn route carries only durable content identity', () {
      final entry = PracticeRouteEntry.fromObject(
        GeneratedCareTurnRouteArgs(generatedContentId: 'generated_4'),
      );

      expect(entry.hasValidArgs, isTrue);
      expect(entry.isGeneratedCareTurn, isTrue);
      expect(entry.generatedArgs?.generatedContentId, 'generated_4');
      expect(entry.args, isNull);
    });

    test(
      'canonical reactions branch through one event into Garden and Today',
      () async {
        final localDataSource = await PracticeLocalDataSource.open(
          directory: tempDir.path,
          name: 'generated_loop_${DateTime.now().microsecondsSinceEpoch}',
        );
        final repository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'generated_loop_installation',
          ),
          contentResolver: registry,
        );
        addTearDown(() => repository.close(deleteFromDisk: true));
        final garden = GardenGrowthRepository(
          practiceRepository: repository,
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
        );
        final carePath = CarePathRepository(
          practiceRepository: repository,
          gardenGrowthRepository: garden,
        );
        for (var index = 0; index < BabyReactionType.values.length; index++) {
          final reaction = BabyReactionType.values[index];
          final moment = _moment('generated_branch_${reaction.name}');
          final timestamp = DateTime.utc(2026, 5, 20, 10, 0, index);
          final localEventId = 'generated_branch_event_${reaction.name}';
          await registry.register(
            accountContext: accountContext,
            moment: moment,
          );

          final turn = await carePath.startGeneratedMoment(
            generatedContentId: moment.generatedContentId,
          );
          final recorded = await carePath.recordReaction(
            turn: turn,
            reactionType: reaction,
            clientTimestamp: timestamp,
            localEventId: localEventId,
          );
          final reconciled = await carePath.recordReaction(
            turn: turn,
            reactionType: reaction,
            clientTimestamp: timestamp,
            localEventId: localEventId,
          );

          expect(recorded.traceEventKey, isNotNull);
          expect(reconciled.traceEventKey, recorded.traceEventKey);
          expect(recorded.latestGardenImpact?.activityId, moment.activityId);
          expect(
            recorded.nextSupportUtterance?.phraseId,
            moment.reactionSupports[reaction].phraseId,
          );
          expect(
            reconciled.nextSupportUtterance?.phraseId,
            moment.reactionSupports[reaction].phraseId,
          );
          expect(
            recorded.nextSupportUtterance?.audioSource,
            GeneratedCareAudioSource(
              generatedContentId: moment.generatedContentId,
              utteranceId: moment.reactionSupports[reaction].utteranceId,
            ),
          );
          expect(
            reconciled.nextSupportUtterance?.audioSource,
            GeneratedCareAudioSource(
              generatedContentId: moment.generatedContentId,
              utteranceId: moment.reactionSupports[reaction].utteranceId,
            ),
          );
          expect(
            await repository.listEventHistory(
              spaceId: moment.spaceId,
              activityId: moment.activityId,
            ),
            hasLength(1),
          );
        }

        final lostMoment = _moment('generated_response_lost');
        final lostTimestamp = DateTime.utc(2026, 5, 20, 10, 0, 10);
        const lostLocalEventId = 'generated_response_lost_event';
        await registry.register(
          accountContext: accountContext,
          moment: lostMoment,
        );
        final responseLostCarePath = CarePathRepository(
          practiceRepository: repository,
          gardenGrowthRepository: garden,
          onReactionRecorded: (_) async {
            throw const CarePathResponseLostException();
          },
        );
        final lostTurn = await responseLostCarePath.startGeneratedMoment(
          generatedContentId: lostMoment.generatedContentId,
        );
        final unknownOutcome = await responseLostCarePath.recordReaction(
          turn: lostTurn,
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: lostTimestamp,
          localEventId: lostLocalEventId,
        );
        expect(unknownOutcome.phase, CareTurnPhase.error);
        expect(
          unknownOutcome.failureKind,
          CareTurnFailureKind.reactionUnknownOutcome,
        );

        final reconciledAfterLostResponse = await carePath.recordReaction(
          turn: lostTurn,
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: lostTimestamp,
          localEventId: lostLocalEventId,
        );
        expect(
          reconciledAfterLostResponse.nextSupportUtterance?.phraseId,
          lostMoment.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
        expect(
          await repository.listEventHistory(
            spaceId: lostMoment.spaceId,
            activityId: lostMoment.activityId,
          ),
          hasLength(1),
        );

        final latest = lostMoment;
        final gardenSnapshot = await garden.buildSnapshot();
        expect(gardenSnapshot.knownEvents, BabyReactionType.values.length + 1);
        expect(gardenSnapshot.skippedUnknownContentEvents, 0);
        expect(
          gardenSnapshot.diaryEntries,
          hasLength(BabyReactionType.values.length + 1),
        );
        expect(gardenSnapshot.latestImpact?.activityId, latest.activityId);
        expect(
          gardenSnapshot.spaces
              .expand((space) => space.activities)
              .map((activity) => activity.activityId),
          contains(latest.activityId),
        );

        final continuity = await repository.getContinuitySnapshot();
        expect(continuity.recommendedActivity.activityId, latest.activityId);
        expect(
          continuity.recommendedActivity.nextPhraseId,
          latest.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
        expect(
          continuity.catalog.findActivity(
            spaceId: latest.spaceId,
            activityId: latest.activityId,
          ),
          isNull,
        );

        final resumedTurn = await carePath.loadCurrentTurn();
        expect(
          resumedTurn.moment.generatedContentId,
          latest.generatedContentId,
        );
        expect(
          resumedTurn.currentUtterance?.phraseId,
          latest.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
      },
    );

    test(
      'generated tuple isolates exact-once trace, Garden, and Today continuity',
      () async {
        final localDataSource = await PracticeLocalDataSource.open(
          directory: tempDir.path,
          name: 'generated_identity_${DateTime.now().microsecondsSinceEpoch}',
        );
        final repository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'generated_identity_installation',
          ),
          contentResolver: registry,
        );
        addTearDown(() => repository.close(deleteFromDisk: true));
        final garden = GardenGrowthRepository(
          practiceRepository: repository,
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
        );
        final carePath = CarePathRepository(
          practiceRepository: repository,
          gardenGrowthRepository: garden,
        );
        final first = _moment(
          'generated_identity_a',
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );
        final second = _moment(
          'generated_identity_b',
          spaceId: first.spaceId,
          activityId: first.activityId,
        );
        await registry.register(accountContext: accountContext, moment: first);
        await registry.register(accountContext: accountContext, moment: second);

        final turn = await carePath.startGeneratedMoment(
          generatedContentId: first.generatedContentId,
        );
        final recorded = await carePath.recordReaction(
          turn: turn,
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 7, 29, 10),
        );
        final replayed = await carePath.recordReaction(
          turn: turn,
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 7, 29, 10, 1),
        );

        expect(
          recorded.phase,
          CareTurnPhase.nextSupportReady,
          reason: recorded.message,
        );
        expect(replayed.traceEventKey, recorded.traceEventKey);
        final events = await repository.listEventHistory(
          spaceId: first.spaceId,
          activityId: first.activityId,
        );
        expect(events, hasLength(1));
        expect(events.single.generatedContentId, first.generatedContentId);
        expect(events.single.utteranceId, first.starter.utteranceId);
        expect(events.single.reactionType, BabyReactionType.hesitant);

        final restored = await carePath.restoreConfirmedReaction(events.single);
        expect(restored.phase, CareTurnPhase.nextSupportReady);
        expect(restored.moment.generatedContentId, first.generatedContentId);
        expect(restored.currentUtterance?.phraseId, first.starter.phraseId);
        expect(
          restored.nextSupportUtterance?.phraseId,
          first.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
        final mismatchedUtterance = await carePath.restoreConfirmedReaction(
          events.single.copyWith(utteranceId: 'wrong_utterance_id'),
        );
        expect(mismatchedUtterance.phase, CareTurnPhase.error);
        expect(mismatchedUtterance.currentUtterance, isNull);

        final catalog = await repository.getActivityCatalog();
        expect(catalog.knownEvents, 1);
        expect(catalog.skippedUnknownContentEvents, 0);

        final gardenSnapshot = await garden.buildSnapshot();
        expect(
          gardenSnapshot.spaces.map((space) => space.spaceId),
          contains('generated_${first.generatedContentId}'),
        );
        expect(
          gardenSnapshot.spaces.map((space) => space.spaceId),
          isNot(contains('generated_${second.generatedContentId}')),
        );
        final trace = gardenSnapshot.diaryEntries.single;
        expect(trace.entryId, events.single.eventKey);
        expect(trace.body, '已记录本次照护回应：犹豫。');
        expect(gardenSnapshot.latestImpact?.headline, '已记下这次照护回应。');
        final generatedGardenPatch = gardenSnapshot.spaces.firstWhere(
          (space) => space.spaceId == 'generated_${first.generatedContentId}',
        );
        expect(generatedGardenPatch.completedActivityCount, 0);
        expect(
          generatedGardenPatch.activities.single.completedPhraseCount,
          0,
        );
        expect(
          gardenSnapshot.milestones.where((milestone) => milestone.isAchieved),
          isEmpty,
        );

        final continuity = await repository.getContinuitySnapshot();
        expect(
          continuity.recommendedActivity.generatedContentId,
          first.generatedContentId,
        );
        expect(
          continuity.recommendation.generatedContentId,
          first.generatedContentId,
        );
        expect(continuity.recommendedActivity.completedPhraseCount, 0);
        expect(continuity.recommendedActivity.completedPhraseIds, isEmpty);
        final generatedResume = await repository.getGeneratedResumeInfo(
          generatedContentId: first.generatedContentId,
        );
        expect(generatedResume.completedCount, 0);
        expect(generatedResume.completedPhraseIds, isEmpty);
        expect(
          generatedResume.nextPhraseId,
          first.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
        final continuityNotifier = PracticeContinuityNotifier(
          repository: repository,
        );
        await continuityNotifier.initialize();
        expect(
          continuityNotifier.generatedRecommendedArgs?.generatedContentId,
          first.generatedContentId,
        );
        expect(
          continuityNotifier.recommendedRoute?.scopeLabel,
          'generated:${first.generatedContentId}',
        );
        final resumed = await carePath.loadCurrentTurn();
        expect(resumed.moment.generatedContentId, first.generatedContentId);
        expect(
          resumed.currentUtterance?.phraseId,
          first.reactionSupports[BabyReactionType.hesitant].phraseId,
        );
      },
    );
  });
}

GeneratedCareMoment _moment(
  String generatedContentId, {
  String? spaceId,
  String? activityId,
}) {
  GeneratedCareUtterance utterance(
    String suffix, {
    required GeneratedCareUtteranceRole role,
    required BabyReactionType? reaction,
    required int displayOrder,
  }) {
    return GeneratedCareUtterance(
      utteranceId: 'utterance_$suffix',
      phraseId: 'phrase_$suffix',
      english: 'Warm water',
      chinese: '温水来了',
      pronunciation: 'wɔːm',
      tprActionZh: '靠近宝宝',
      deliveryGuidanceZh: '慢慢说',
      difficulty: 'starter',
      source: 'generated',
      role: role,
      reaction: reaction,
      displayOrder: displayOrder,
      providerProvenance: GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.providerGenerated,
        providerName: 'provider',
        modelName: 'model',
        attemptNumber: 1,
      ),
    );
  }

  return GeneratedCareMoment(
    schemaVersion: generatedCareMomentSchemaVersion,
    generatedContentId: generatedContentId,
    sceneId: 'scene_$generatedContentId',
    spaceId: spaceId ?? 'space_$generatedContentId',
    momentId: 'moment_$generatedContentId',
    activityId: activityId ?? 'activity_$generatedContentId',
    title: '洗澡',
    sceneTag: 'bath',
    coachTip: '慢慢来',
    source: 'generated',
    starter: utterance(
      'starter',
      role: GeneratedCareUtteranceRole.starter,
      reaction: null,
      displayOrder: 1,
    ),
    reactionSupports:
        GeneratedReactionSupportMap(<BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: utterance(
              reaction.name,
              role: GeneratedCareUtteranceRole.reactionSupport,
              reaction: reaction,
              displayOrder: BabyReactionType.values.indexOf(reaction) + 2,
            ),
        }),
  );
}
