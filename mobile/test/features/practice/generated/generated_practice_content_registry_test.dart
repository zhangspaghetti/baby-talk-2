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
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
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
          localEventId: 'generated_event_1',
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
          await repository.findEventByLocalEventId('generated_event_1'),
          event,
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
  });
}

GeneratedCareMoment _moment(String generatedContentId) {
  GeneratedCareUtterance utterance(String suffix) {
    return GeneratedCareUtterance(
      utteranceId: 'utterance_$suffix',
      phraseId: 'phrase_$suffix',
      english: 'Warm water',
      chinese: '温水来了',
      pronunciation: 'wɔːm',
      difficulty: 'starter',
      source: 'generated',
    );
  }

  return GeneratedCareMoment(
    generatedContentId: generatedContentId,
    sceneId: 'scene_$generatedContentId',
    spaceId: 'space_$generatedContentId',
    momentId: 'moment_$generatedContentId',
    activityId: 'activity_$generatedContentId',
    title: '洗澡',
    sceneTag: 'bath',
    coachTip: '慢慢来',
    source: 'generated',
    starter: utterance('starter'),
    reactionSupports:
        GeneratedReactionSupportMap(<BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: utterance(reaction.name),
        }),
  );
}
