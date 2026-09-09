import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/custom_scene_recovery_coordinator.dart';
import 'package:mobile/app/feature_gates.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_handoff_confirmation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

import '../../../support/isar_test_library.dart';
import '../../../support/generated_care_moment_fixture.dart';

const _expectedSupportIdentities =
    <BabyReactionType, ({String phraseId, String utteranceId})>{
      BabyReactionType.cooperating: (
        phraseId: 'phrase_cooperating',
        utteranceId: 'utterance_cooperating',
      ),
      BabyReactionType.hesitant: (
        phraseId: 'phrase_hesitant',
        utteranceId: 'utterance_hesitant',
      ),
      BabyReactionType.resisting: (
        phraseId: 'phrase_resisting',
        utteranceId: 'utterance_resisting',
      ),
      BabyReactionType.noResponse: (
        phraseId: 'phrase_noResponse',
        utteranceId: 'utterance_noResponse',
      ),
      BabyReactionType.other: (
        phraseId: 'phrase_other',
        utteranceId: 'utterance_other',
      ),
    };

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
    late GeneratedCareTurnResumeMarkerStore resumeStore;
    late GeneratedPracticeContentRegistry registry;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('generated_care_moment_');
      accountContext = 'account_a';
      store = GeneratedCareMomentLocalStore(
        directoryResolver: () async => tempDir,
      );
      resumeStore = GeneratedCareTurnResumeMarkerStore(
        directoryResolver: () async => tempDir,
      );
      registry = GeneratedPracticeContentRegistry(
        store: store,
        resumeStore: resumeStore,
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
          resumeStore: GeneratedCareTurnResumeMarkerStore(
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
      'persists preset source metadata while keeping both sources resolvable',
      () async {
        final custom = _moment('custom_round_trip');
        final preset = _moment(
          'preset_round_trip',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 7,
        );
        await registry.register(accountContext: accountContext, moment: custom);
        await registry.register(accountContext: accountContext, moment: preset);

        final restartedRegistry = GeneratedPracticeContentRegistry(
          store: GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ),
          resumeStore: resumeStore,
          accountContextLoader: () async => accountContext,
        );

        final resolvedCustom = await restartedRegistry.resolveGeneratedContent(
          generatedContentId: custom.generatedContentId,
        );
        final resolvedPreset = await restartedRegistry.resolveGeneratedContent(
          generatedContentId: preset.generatedContentId,
        );

        expect(resolvedCustom?.inputSource, SceneGenerationSourceType.custom);
        expect(resolvedCustom?.presetSceneId, isNull);
        expect(resolvedPreset?.inputSource, SceneGenerationSourceType.preset);
        expect(resolvedPreset?.presetSceneId, 'bath_time');
        expect(resolvedPreset?.presetSceneVersion, 7);
        expect(
          (await restartedRegistry.resolveActivity(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ))?.inputSource,
          SceneGenerationSourceType.preset,
        );
        expect(
          (await restartedRegistry.listGeneratedActivities()).map(
            (activity) => activity.generatedContentId,
          ),
          <String>[custom.generatedContentId],
        );
      },
    );

    test(
      'migrates legacy records without inputSource as custom history',
      () async {
        final moment = _moment('legacy_custom_round_trip');
        await registry.register(accountContext: accountContext, moment: moment);

        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        root['schemaVersion'] = 2;
        for (final value in root['records'] as List<dynamic>) {
          (value as Map<String, dynamic>)
            ..remove('inputSource')
            ..remove('presetSceneId')
            ..remove('presetSceneVersion');
        }
        await file.writeAsString(jsonEncode(root));

        final resolved = await registry.resolveGeneratedContent(
          generatedContentId: moment.generatedContentId,
        );

        expect(resolved?.inputSource, SceneGenerationSourceType.custom);
        final migrated =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(migrated['schemaVersion'], 3);
        final migratedRecord =
            (migrated['records'] as List<dynamic>).single
                as Map<String, dynamic>;
        expect(migratedRecord['inputSource'], 'custom');
        expect(migratedRecord['presetSceneId'], isNull);
        expect(migratedRecord['presetSceneVersion'], isNull);
        expect(await File('${file.path}.tmp').exists(), isFalse);
        expect(await File('${file.path}.bak').exists(), isFalse);
      },
    );

    test(
      'retains legacy schema file when migration replacement fails',
      () async {
        final moment = _moment('legacy_migration_failure');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        root['schemaVersion'] = 2;
        for (final value in root['records'] as List<dynamic>) {
          (value as Map<String, dynamic>)
            ..remove('inputSource')
            ..remove('presetSceneId')
            ..remove('presetSceneVersion');
        }
        await file.writeAsString(jsonEncode(root));

        var failNextReplacement = true;
        final failingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
          renameFile: (source, targetPath) async {
            if (failNextReplacement &&
                source.path.endsWith('.tmp') &&
                targetPath == file.path) {
              failNextReplacement = false;
              throw StateError('simulated migration rename failure');
            }
            return source.rename(targetPath);
          },
        );

        await expectLater(
          failingStore.readAll(),
          throwsA(isA<GeneratedCareMomentLocalStoreException>()),
        );
        final retained =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(retained['schemaVersion'], 2);
        expect(await File('${file.path}.bak').exists(), isFalse);
        expect(await File('${file.path}.tmp').exists(), isFalse);

        final recovered = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        expect(
          (await recovered.readAll()).single.moment.inputSource,
          SceneGenerationSourceType.custom,
        );
      },
    );

    test(
      'keeps current bundles readable when replacement rename fails',
      () async {
        final first = _moment('replacement_before');
        final second = _moment('replacement_after');
        await registry.register(accountContext: accountContext, moment: first);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        var failNextReplacement = true;
        final failingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
          renameFile: (source, targetPath) async {
            if (failNextReplacement &&
                source.path.endsWith('.tmp') &&
                targetPath == file.path) {
              failNextReplacement = false;
              throw StateError('simulated replacement rename failure');
            }
            return source.rename(targetPath);
          },
        );

        await expectLater(
          failingStore.upsert(
            StoredGeneratedCareMoment(
              accountContext: accountContext,
              moment: second,
            ),
          ),
          throwsA(isA<GeneratedCareMomentLocalStoreException>()),
        );
        final retained =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(retained['schemaVersion'], 3);
        final retainedIds = (retained['records'] as List<dynamic>)
            .map(
              (value) => (value as Map<String, dynamic>)['generatedContentId'],
            )
            .toList(growable: false);
        expect(retainedIds, <String>[first.generatedContentId]);
        expect(await File('${file.path}.bak').exists(), isFalse);
        expect(await File('${file.path}.tmp').exists(), isFalse);
      },
    );

    test(
      'restores old bundles when rotating target reports failure after moving it',
      () async {
        final first = _moment('rotation_before');
        final second = _moment('rotation_after');
        await registry.register(accountContext: accountContext, moment: first);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        var failAfterMove = true;
        final failingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
          renameFile: (source, targetPath) async {
            if (failAfterMove && source.path == file.path) {
              failAfterMove = false;
              await source.rename(targetPath);
              throw StateError('simulated rotation failure after move');
            }
            return source.rename(targetPath);
          },
        );

        await expectLater(
          failingStore.upsert(
            StoredGeneratedCareMoment(
              accountContext: accountContext,
              moment: second,
            ),
          ),
          throwsA(isA<GeneratedCareMomentLocalStoreException>()),
        );
        expect(await file.exists(), isTrue);
        expect(await File('${file.path}.bak').exists(), isFalse);
        expect(
          (await GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ).readAll()).single.moment.generatedContentId,
          first.generatedContentId,
        );
      },
    );

    test(
      'restores a backup left by an interrupted replacement before reading',
      () async {
        final moment = _moment('interrupted_replacement');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final backup = File('${file.path}.bak');
        await file.rename(backup.path);

        final recovered = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );

        expect(
          (await recovered.readAll()).single.moment.generatedContentId,
          moment.generatedContentId,
        );
        expect(await backup.exists(), isFalse);
      },
    );

    test(
      'lifecycle clear removes backup so cleared bundles cannot resurrect',
      () async {
        final moment = _moment('clear_interrupted_replacement');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final backup = File('${file.path}.bak');
        await file.rename(backup.path);

        await store.clearForLifecycle();

        expect(await file.exists(), isFalse);
        expect(await backup.exists(), isFalse);
        expect(await store.readAll(), isEmpty);
      },
    );

    test(
      'successful write removes stale clear marker before publishing state',
      () async {
        final first = _moment('clear_marker_stale_before_write');
        final second = _moment('clear_marker_stale_after_write');
        await registry.register(accountContext: accountContext, moment: first);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final marker = File('${file.path}.clear');
        await marker.writeAsString('clear');

        await store.upsert(
          StoredGeneratedCareMoment(
            accountContext: accountContext,
            moment: second,
          ),
        );

        expect(await marker.exists(), isFalse);
        expect(await store.readAll(), hasLength(2));
      },
    );

    test('clear keeps target when temporary-artifact deletion fails', () async {
      final moment = _moment('clear_temp_delete_failure');
      await registry.register(accountContext: accountContext, moment: moment);
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
      );
      final temporaryFile = File('${file.path}.tmp');
      await temporaryFile.writeAsString('stale temporary content');
      final failingStore = GeneratedCareMomentLocalStore(
        directoryResolver: () async => tempDir,
        deleteFile: (target) async {
          if (target.path == temporaryFile.path) {
            throw StateError('simulated temporary delete failure');
          }
          await target.delete();
        },
      );

      await expectLater(
        failingStore.clearForLifecycle(),
        throwsA(isA<GeneratedCareMomentLocalStoreException>()),
      );
      expect(await file.exists(), isTrue);
      expect(await temporaryFile.exists(), isTrue);
      expect(
        (await GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        ).readAll()).single.moment.generatedContentId,
        moment.generatedContentId,
      );
    });

    test(
      'account clear keeps target when temporary-artifact deletion fails',
      () async {
        final moment = _moment('account_clear_temp_delete_failure');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final temporaryFile = File('${file.path}.tmp');
        await temporaryFile.writeAsString('stale temporary content');
        final failingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
          deleteFile: (target) async {
            if (target.path == temporaryFile.path) {
              throw StateError(
                'simulated account clear temporary delete failure',
              );
            }
            await target.delete();
          },
        );

        await expectLater(
          failingStore.clearForAccount(accountContext),
          throwsA(isA<GeneratedCareMomentLocalStoreException>()),
        );
        expect(await file.exists(), isTrue);
        expect(
          (await GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ).readAll()).single.moment.generatedContentId,
          moment.generatedContentId,
        );
      },
    );

    test(
      'read ignores stale backup after clear fails before target deletion',
      () async {
        final moment = _moment('clear_backup_delete_failure');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final backup = File('${file.path}.bak');
        await file.rename(backup.path);
        final failingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
          deleteFile: (target) async {
            if (target.path == backup.path) {
              throw StateError('simulated backup delete failure');
            }
            await target.delete();
          },
        );

        await expectLater(
          failingStore.clearForLifecycle(),
          throwsA(isA<GeneratedCareMomentLocalStoreException>()),
        );
        expect(await file.exists(), isFalse);
        expect(await backup.exists(), isTrue);
        final recovered = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        expect(await recovered.readAll(), isEmpty);
        expect(await backup.exists(), isFalse);
      },
    );

    test('marker cleanup failure leaves no recoverable artifact', () async {
      final moment = _moment('clear_marker_delete_failure');
      await registry.register(accountContext: accountContext, moment: moment);
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
      );
      final marker = File('${file.path}.clear');
      final failingStore = GeneratedCareMomentLocalStore(
        directoryResolver: () async => tempDir,
        deleteFile: (target) async {
          if (target.path == marker.path) {
            throw StateError('simulated clear marker delete failure');
          }
          await target.delete();
        },
      );

      await expectLater(
        failingStore.clearForLifecycle(),
        throwsA(isA<GeneratedCareMomentLocalStoreException>()),
      );
      expect(await file.exists(), isFalse);
      expect(await File('${file.path}.tmp').exists(), isFalse);
      expect(await File('${file.path}.bak').exists(), isFalse);
      expect(await marker.exists(), isTrue);
      final recovered = GeneratedCareMomentLocalStore(
        directoryResolver: () async => tempDir,
      );
      expect(await recovered.readAll(), isEmpty);
      expect(await marker.exists(), isFalse);
    });

    test(
      'lifecycle clear is idempotent when the store directory is absent',
      () async {
        final missingDirectory = Directory(
          '${tempDir.path}${Platform.pathSeparator}missing_store_directory',
        );
        final missingStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => missingDirectory,
        );

        await missingStore.clearForLifecycle();

        expect(await missingDirectory.exists(), isFalse);
      },
    );

    test(
      'serializes concurrent writes from separate store instances by path',
      () async {
        final firstStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final secondStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final first = _moment('cross_instance_first');
        final second = _moment('cross_instance_second');

        await Future.wait(<Future<void>>[
          firstStore.upsert(
            StoredGeneratedCareMoment(
              accountContext: accountContext,
              moment: first,
            ),
          ),
          secondStore.upsert(
            StoredGeneratedCareMoment(
              accountContext: accountContext,
              moment: second,
            ),
          ),
        ]);

        final records = await GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        ).readAll();
        expect(
          records.map((record) => record.moment.generatedContentId),
          containsAll(<String>[
            first.generatedContentId,
            second.generatedContentId,
          ]),
        );
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${firstStore.fileName}',
        );
        expect(await File('${file.path}.tmp').exists(), isFalse);
        expect(await File('${file.path}.bak').exists(), isFalse);
      },
    );

    test(
      'serializes concurrent migration and clear without corrupt artifacts',
      () async {
        final moment = _moment('cross_instance_migration');
        await registry.register(accountContext: accountContext, moment: moment);
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        root['schemaVersion'] = 2;
        for (final value in root['records'] as List<dynamic>) {
          (value as Map<String, dynamic>)
            ..remove('inputSource')
            ..remove('presetSceneId')
            ..remove('presetSceneVersion');
        }
        await file.writeAsString(jsonEncode(root));
        final firstStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final secondStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );

        await Future.wait(<Future<void>>[
          firstStore.readAll().then<void>((_) {}),
          secondStore.clearForLifecycle(),
        ]);

        expect(await File('${file.path}.tmp').exists(), isFalse);
        expect(await File('${file.path}.bak').exists(), isFalse);
        expect(await File('${file.path}.clear').exists(), isFalse);
        if (await file.exists()) {
          final raw = await file.readAsString();
          expect(() => jsonDecode(raw), returnsNormally);
        }
      },
    );

    test(
      'resolves latest valid preset bundle by stable activity route',
      () async {
        final older = _moment(
          'preset_route_older',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 1,
        );
        final newer = _moment(
          'preset_route_newer',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 2,
        );
        await registry.register(accountContext: accountContext, moment: older);
        await registry.register(accountContext: accountContext, moment: newer);

        final resolved = await registry.resolveActivity(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(resolved?.generatedContentId, newer.generatedContentId);
        expect(resolved?.presetSceneVersion, 2);
        expect(
          (await registry.resolvePublishedActivity(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            publishedVersion: 1,
          ))?.generatedContentId,
          older.generatedContentId,
        );
        expect(
          (await registry.resolveActivity(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            publishedVersion: 1,
            enabled: true,
          ))?.generatedContentId,
          older.generatedContentId,
        );
        expect(
          await registry.resolveActivity(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            publishedVersion: 1,
            enabled: false,
          ),
          isNull,
        );
        expect(
          (await registry.resolveGeneratedContent(
            generatedContentId: older.generatedContentId,
          ))?.presetSceneVersion,
          1,
        );
      },
    );

    test(
      'quarantines a preset record missing source identity instead of decoding custom',
      () async {
        final moment = _moment(
          'malformed_preset_identity',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 1,
        );
        await registry.register(accountContext: accountContext, moment: moment);

        final file = File(
          '${tempDir.path}${Platform.pathSeparator}${store.fileName}',
        );
        final root =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        root['schemaVersion'] = 3;
        final record =
            (root['records'] as List<dynamic>).single as Map<String, dynamic>;
        record['inputSource'] = 'preset';
        record.remove('presetSceneId');
        record.remove('presetSceneVersion');
        await file.writeAsString(jsonEncode(root));

        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        final diagnostics = await store.readQuarantineDiagnostics();
        expect(diagnostics.single.reasonCode, 'invalid_generated_bundle');
        expect(
          await file.readAsString(),
          isNot(contains(moment.starter.english)),
        );
      },
    );

    test(
      'rejects preset source identity that disagrees with stable activity route',
      () {
        expect(
          () => _moment(
            'mismatched_preset_identity',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            inputSource: SceneGenerationSourceType.preset,
            presetSceneId: 'feeding_time',
            presetSceneVersion: 1,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'generated projection distinguishes unavailable account from empty',
      () async {
        final unavailableRegistry = GeneratedPracticeContentRegistry(
          store: store,
          resumeStore: resumeStore,
          accountContextLoader: () async => null,
        );

        await expectLater(
          unavailableRegistry.listGeneratedActivities(),
          throwsA(
            isA<GeneratedPracticeProjectionUnavailableException>().having(
              (error) => error.reason,
              'reason',
              GeneratedPracticeProjectionUnavailableReason.accountUnavailable,
            ),
          ),
        );
        expect(await registry.listGeneratedActivities(), isEmpty);
      },
    );

    test(
      'generated projection distinguishes account and content read errors',
      () async {
        final accountFailure = GeneratedPracticeContentRegistry(
          store: store,
          resumeStore: resumeStore,
          accountContextLoader: () async =>
              throw StateError('secure read failed'),
        );
        final contentFailure = GeneratedPracticeContentRegistry(
          store: _FailingReadGeneratedCareMomentLocalStore(tempDir),
          resumeStore: resumeStore,
          accountContextLoader: () async => accountContext,
        );

        await expectLater(
          accountFailure.listGeneratedActivities(),
          throwsA(
            isA<GeneratedPracticeProjectionUnavailableException>().having(
              (error) => error.reason,
              'reason',
              GeneratedPracticeProjectionUnavailableReason.accountLoadFailed,
            ),
          ),
        );
        await expectLater(
          contentFailure.listGeneratedActivities(),
          throwsA(
            isA<GeneratedPracticeProjectionUnavailableException>().having(
              (error) => error.reason,
              'reason',
              GeneratedPracticeProjectionUnavailableReason.contentLoadFailed,
            ),
          ),
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
        await resumeStore.write(
          accountContext: accountContext,
          generatedContentId: moment.generatedContentId,
          confirmedAt: DateTime.utc(2026, 8, 9),
        );
        await registry.clearForAccount(accountContext);
        expect(
          await registry.resolveGeneratedContent(
            generatedContentId: moment.generatedContentId,
          ),
          isNull,
        );
        expect(await resumeStore.readForAccount(accountContext), isNull);

        await registry.register(accountContext: accountContext, moment: moment);
        await resumeStore.write(
          accountContext: accountContext,
          generatedContentId: moment.generatedContentId,
          confirmedAt: DateTime.utc(2026, 8, 9),
        );
        await registry.clearForLifecycle();
        expect(await store.readAll(), isEmpty);
        expect(await resumeStore.readForAccount(accountContext), isNull);
      },
    );

    test(
      'resume marker is account isolated and invalid content removes it',
      () async {
        final moment = _moment('generated_isolated_resume');
        await registry.register(accountContext: accountContext, moment: moment);
        await resumeStore.write(
          accountContext: accountContext,
          generatedContentId: moment.generatedContentId,
          confirmedAt: DateTime.utc(2026, 8, 9),
        );
        final markerFile = File(
          '${tempDir.path}${Platform.pathSeparator}${resumeStore.fileName}',
        );
        final persisted = await markerFile.readAsString();
        expect(persisted, isNot(contains(accountContext)));
        final transientReadFailure = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
          fileReader: (_) async =>
              throw const FileSystemException('transient read failure'),
        );
        await expectLater(
          transientReadFailure.readForAccount(accountContext),
          throwsA(isA<FileSystemException>()),
        );
        expect(
          (await resumeStore.readForAccount(
            accountContext,
          ))?.generatedContentId,
          moment.generatedContentId,
        );

        accountContext = 'account_b';
        expect(await registry.loadGeneratedCareTurnResumeMarker(), isNull);
        accountContext = 'account_a';
        expect(
          (await registry.loadGeneratedCareTurnResumeMarker())
              ?.generatedContentId,
          moment.generatedContentId,
        );
        final transientContentRead = GeneratedPracticeContentRegistry(
          store: _FailingReadGeneratedCareMomentLocalStore(tempDir),
          resumeStore: resumeStore,
          accountContextLoader: () async => accountContext,
        );
        expect(
          await transientContentRead.loadGeneratedCareTurnResumeMarker(),
          isNull,
        );
        expect(
          (await resumeStore.readForAccount(
            accountContext,
          ))?.generatedContentId,
          moment.generatedContentId,
        );

        await store.clearForAccount(accountContext);
        expect(await registry.loadGeneratedCareTurnResumeMarker(), isNull);
        expect(await resumeStore.readForAccount(accountContext), isNull);
      },
    );

    test(
      'lifecycle cleanup attempts both stores and aggregates failed targets',
      () async {
        await resumeStore.write(
          accountContext: accountContext,
          generatedContentId: 'generated_cleanup',
          confirmedAt: DateTime.utc(2026, 8, 9),
        );
        final contentFailure = GeneratedPracticeContentRegistry(
          store: _FailingGeneratedCareMomentLocalStore(tempDir),
          resumeStore: resumeStore,
          accountContextLoader: () async => accountContext,
        );

        await expectLater(
          contentFailure.clearForLifecycle(),
          throwsA(
            isA<GeneratedPracticeContentClearanceException>().having(
              (error) => error.failedTargets,
              'failedTargets',
              <String>['generated_care_moments'],
            ),
          ),
        );
        expect(await resumeStore.readForAccount(accountContext), isNull);

        final bothFail = GeneratedPracticeContentRegistry(
          store: _FailingGeneratedCareMomentLocalStore(tempDir),
          resumeStore: _FailingGeneratedCareTurnResumeStore(),
          accountContextLoader: () async => accountContext,
        );
        await expectLater(
          bothFail.clearForLifecycle(),
          throwsA(
            isA<GeneratedPracticeContentClearanceException>().having(
              (error) => error.failedTargets,
              'failedTargets',
              <String>['generated_care_moments', 'generated_care_turn_resume'],
            ),
          ),
        );
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
      'producer handoff survives draft cleanup and rebuilt boot without regenerating',
      () async {
        final now = DateTime.utc(2026, 8, 9, 10);
        final moment = _moment('generated_force_stop');
        final generator = _GeneratedMomentRepository(moment);
        final draftStore = CustomSceneDraftStore(
          directoryResolver: () async => tempDir,
        );
        final continuation = _draftContinuation(
          draftStore: draftStore,
          tempDir: tempDir,
          now: now,
        );
        final producer = CustomSceneSubmissionController(
          repository: generator,
          draftStore: draftStore,
          draftContinuationCoordinator: continuation,
          approvedContentRegistrar: registry,
          accountContextLoader: () async => accountContext,
          clock: () => now,
          draftIdGenerator: () => 'draft_force_stop',
        );
        addTearDown(producer.dispose);

        await producer.submit(
          CustomSceneDraft(
            text: '出门前宝宝不想穿鞋。',
            entrySource: CustomSceneEntrySource.scene,
            requestIdentity: CustomSceneRequestIdentity(
              clientRequestId: 'request_force_stop',
            ),
          ),
        );
        expect(producer.state.generatedContentId, moment.generatedContentId);
        expect(generator.calls, 1);

        final confirmation = CustomSceneHandoffConfirmationCoordinator(
          draftContinuationCoordinator: continuation,
          accountContextLoader: () async => accountContext,
          generatedCareTurnResumeStore: resumeStore,
          clock: () => now,
        );
        expect(
          await confirmation.confirm(
            generatedContentId: moment.generatedContentId,
          ),
          isTrue,
        );
        expect(
          (await draftStore.readResult(now: now)).status,
          CustomSceneDraftReadStatus.notFound,
        );

        final localDataSource = await PracticeLocalDataSource.open(
          directory: tempDir.path,
          name: 'force_stop_${DateTime.now().microsecondsSinceEpoch}',
        );
        expect(await localDataSource.listRawEntities(), isEmpty);
        final restartedRegistry = GeneratedPracticeContentRegistry(
          store: GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ),
          resumeStore: GeneratedCareTurnResumeMarkerStore(
            directoryResolver: () async => tempDir,
          ),
          accountContextLoader: () async => accountContext,
        );
        final restartedRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'force_stop_installation',
          ),
          contentResolver: restartedRegistry,
        );
        addTearDown(() => restartedRepository.close(deleteFromDisk: true));
        final gates = await FeatureGates.resolve(
          practiceRepository: restartedRepository,
          completedSnapshot: _completedOnboarding(now),
          primarySpaceId: 'daily_care',
          primaryActivityId: 'bath_time',
        );
        expect(
          gates.continuitySeed?.generatedRecommendedArgs?.generatedContentId,
          moment.generatedContentId,
        );

        final restartedDraftStore = CustomSceneDraftStore(
          directoryResolver: () async => tempDir,
        );
        final restartedController = CustomSceneSubmissionController(
          repository: generator,
          draftStore: restartedDraftStore,
          draftContinuationCoordinator: _draftContinuation(
            draftStore: restartedDraftStore,
            tempDir: tempDir,
            now: now,
          ),
          approvedContentRegistrar: restartedRegistry,
          accountContextLoader: () async => accountContext,
          clock: () => now,
        );
        final handoff = _RecordingHandoffSink();
        final recovery = CustomSceneRecoveryCoordinator(
          controller: restartedController,
          handoffSink: handoff,
        );
        addTearDown(() {
          recovery.dispose();
          restartedController.dispose();
        });
        await recovery.recoverForAuthenticatedAccount(
          accountContext: accountContext,
          resumableGeneratedContentId: gates
              .continuitySeed
              ?.generatedRecommendedArgs
              ?.generatedContentId,
        );

        expect(handoff.ids, <String>[moment.generatedContentId]);
        expect(generator.calls, 1);
      },
    );

    test(
      'confirmed zero-event generated turn survives restart until first reaction',
      () async {
        final localDataSource = await PracticeLocalDataSource.open(
          directory: tempDir.path,
          name: 'generated_resume_${DateTime.now().microsecondsSinceEpoch}',
        );
        final repository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'generated_resume_installation',
          ),
          contentResolver: registry,
        );
        addTearDown(() => repository.close(deleteFromDisk: true));
        final moment = _moment('generated_resume');
        final confirmedAt = DateTime.utc(2026, 8, 9, 9);
        await registry.register(accountContext: accountContext, moment: moment);
        await resumeStore.write(
          accountContext: accountContext,
          generatedContentId: moment.generatedContentId,
          confirmedAt: confirmedAt,
        );

        final restartedRegistry = GeneratedPracticeContentRegistry(
          store: GeneratedCareMomentLocalStore(
            directoryResolver: () async => tempDir,
          ),
          resumeStore: GeneratedCareTurnResumeMarkerStore(
            directoryResolver: () async => tempDir,
          ),
          accountContextLoader: () async => accountContext,
        );
        final restartedRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'generated_resume_installation',
          ),
          contentResolver: restartedRegistry,
        );

        final recovered = await restartedRepository.getContinuitySnapshot();
        expect(
          recovered.recommendedActivity.generatedContentId,
          moment.generatedContentId,
        );
        expect(recovered.cadence.totalKnownEvents, 0);

        final snapshot = await restartedRepository.getGeneratedActivitySnapshot(
          generatedContentId: moment.generatedContentId,
        );
        await restartedRepository.recordReaction(
          spaceId: snapshot.spaceId,
          activityId: snapshot.activityId,
          phraseId: moment.starter.phraseId,
          reactionType: BabyReactionType.cooperating,
          generatedContentId: moment.generatedContentId,
          utteranceId: moment.starter.utteranceId,
          clientTimestamp: confirmedAt.add(const Duration(seconds: 1)),
        );

        expect(await resumeStore.readForAccount(accountContext), isNull);
        final eventContinuity = await restartedRepository
            .getContinuitySnapshot();
        expect(
          eventContinuity.recommendedActivity.generatedContentId,
          moment.generatedContentId,
        );
        expect(eventContinuity.cadence.totalKnownEvents, 1);
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
      'canonical reactions activate matching support without duplicate state',
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
          final expectedSupport = _expectedSupportIdentities[reaction]!;
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
          expect(recorded.phase, CareTurnPhase.nextSupportReady);
          expect(recorded.selectedReaction, reaction);
          expect(recorded.currentUtterance?.phraseId, expectedSupport.phraseId);
          expect(
            reconciled.currentUtterance?.phraseId,
            expectedSupport.phraseId,
          );
          expect(
            recorded.currentUtterance?.audioSource,
            GeneratedCareAudioSource(
              generatedContentId: moment.generatedContentId,
              utteranceId: expectedSupport.utteranceId,
            ),
          );
          expect(
            reconciled.currentUtterance?.audioSource,
            GeneratedCareAudioSource(
              generatedContentId: moment.generatedContentId,
              utteranceId: expectedSupport.utteranceId,
            ),
          );
          expect(recorded.nextSupportUtterance, isNull);
          expect(reconciled.nextSupportUtterance, isNull);
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
        final hesitantSupport =
            _expectedSupportIdentities[BabyReactionType.hesitant]!;
        expect(
          reconciledAfterLostResponse.currentUtterance?.phraseId,
          hesitantSupport.phraseId,
        );
        expect(
          reconciledAfterLostResponse.currentUtterance?.audioSource,
          GeneratedCareAudioSource(
            generatedContentId: lostMoment.generatedContentId,
            utteranceId: hesitantSupport.utteranceId,
          ),
        );
        expect(reconciledAfterLostResponse.nextSupportUtterance, isNull);
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
        final hesitantSupport =
            _expectedSupportIdentities[BabyReactionType.hesitant]!;
        expect(restored.phase, CareTurnPhase.nextSupportReady);
        expect(restored.moment.generatedContentId, first.generatedContentId);
        expect(restored.currentUtterance?.phraseId, hesitantSupport.phraseId);
        expect(
          restored.currentUtterance?.audioSource,
          GeneratedCareAudioSource(
            generatedContentId: first.generatedContentId,
            utteranceId: hesitantSupport.utteranceId,
          ),
        );
        expect(restored.nextSupportUtterance, isNull);
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
        expect(generatedGardenPatch.activities.single.completedPhraseCount, 0);
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
  SceneGenerationSourceType inputSource = SceneGenerationSourceType.custom,
  String? presetSceneId,
  int? presetSceneVersion,
}) {
  return generatedCareMomentFixture(
    generatedContentId: generatedContentId,
    spaceId: spaceId,
    activityId: activityId,
    inputSource: inputSource,
    presetSceneId: presetSceneId,
    presetSceneVersion: presetSceneVersion,
  );
}

CustomSceneDraftContinuationCoordinator _draftContinuation({
  required CustomSceneDraftStore draftStore,
  required Directory tempDir,
  required DateTime now,
}) {
  return CustomSceneDraftContinuationCoordinator(
    draftStore: draftStore,
    authContinuationCoordinator: AuthContinuationCoordinator(
      store: AuthContinuationStore(directoryResolver: () async => tempDir),
      clock: () => now,
      correlationIdGenerator: () => 'force_stop_auth_continuation',
    ),
    clock: () => now,
    draftIdGenerator: () => 'draft_force_stop',
  );
}

OnboardingSnapshot _completedOnboarding(DateTime now) {
  return OnboardingSnapshot(
    childDisplayName: '宝宝',
    ageBucket: OnboardingAgeBucket.oneToTwo,
    approxMonths: 18,
    currentStage: 'first_words',
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: now,
  );
}

class _GeneratedMomentRepository implements CustomSceneRepository {
  _GeneratedMomentRepository(this.moment);

  final GeneratedCareMoment moment;
  int calls = 0;

  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) async {
    calls += 1;
    return moment;
  }
}

class _RecordingHandoffSink implements CustomSceneCareTurnHandoffSink {
  final List<String> ids = <String>[];

  @override
  Future<CustomSceneCareTurnRouteAttempt> handoff(
    CustomSceneCareTurnHandoff handoff,
  ) async {
    ids.add(handoff.generatedContentId);
    return CustomSceneCareTurnRouteAttempt(
      routeCompletion: Future<void>.value(),
    );
  }
}

class _FailingGeneratedCareMomentLocalStore
    extends GeneratedCareMomentLocalStore {
  _FailingGeneratedCareMomentLocalStore(Directory directory)
    : super(directoryResolver: () async => directory);

  @override
  Future<void> clearForLifecycle() async {
    throw StateError('generated content clear failed');
  }
}

class _FailingReadGeneratedCareMomentLocalStore
    extends GeneratedCareMomentLocalStore {
  _FailingReadGeneratedCareMomentLocalStore(Directory directory)
    : super(directoryResolver: () async => directory);

  @override
  Future<List<StoredGeneratedCareMoment>> readAll() async {
    throw const GeneratedCareMomentLocalStoreException();
  }
}

class _FailingGeneratedCareTurnResumeStore
    implements GeneratedCareTurnResumeStore {
  @override
  Future<void> clearForAccount(String accountContext) async {
    throw StateError('resume clear failed');
  }

  @override
  Future<void> clearForLifecycle() async {
    throw StateError('resume clear failed');
  }

  @override
  Future<void> clearMatching({
    required String accountContext,
    required String generatedContentId,
  }) async {}

  @override
  Future<GeneratedCareTurnResumeMarker?> readForAccount(
    String accountContext,
  ) async => null;

  @override
  Future<void> write({
    required String accountContext,
    required String generatedContentId,
    required DateTime confirmedAt,
  }) async {}
}
