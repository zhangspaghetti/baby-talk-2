import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/preset_scene_generation_gate_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/scene_generation/application/scene_generation_controller.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  test(
    'route entry policy distinguishes preset, generated, onboarding, invalid',
    () {
      final preset = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );
      final generated = PracticeRouteEntry.fromObject(
        GeneratedCareTurnRouteArgs(generatedContentId: 'generated_1'),
      );
      final onboarding = PracticeRouteEntry.fromObject(
        const OnboardingCareTurnRouteArgs(
          completionId: 'completion_1',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          entryTitle: '洗澡',
          utteranceId: 'utterance_1',
          english: 'Warm water.',
          chinese: '温水。',
          source: OnboardingCareTurnSource.localFallback,
        ),
      );

      expect(preset.kind, PracticeEntryKind.preset);
      expect(generated.kind, PracticeEntryKind.generated);
      expect(onboarding.kind, PracticeEntryKind.onboarding);
      expect(
        PracticeRouteEntry.fromObject(null).kind,
        PracticeEntryKind.invalid,
      );
    },
  );

  test('registers approved preset bundle before exposing success', () async {
    final generation = Completer<GeneratedCareMoment>();
    final repository = _FakeSceneGenerationRepository(
      onGenerate: ({required source, required clientRequestId}) =>
          generation.future,
    );
    final registration = <GeneratedCareMoment>[];
    final controller = SceneGenerationController(
      repository: repository,
      approvedBundleRegistrar: (moment) async {
        registration.add(moment);
      },
    );

    final operation = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_1',
    );

    expect(controller.state.status, SceneGenerationControllerStatus.submitting);
    generation.complete(_presetMoment());
    await operation;

    expect(registration, hasLength(1));
    expect(controller.state.status, SceneGenerationControllerStatus.success);
    expect(controller.state.moment?.generatedContentId, 'generated_preset_1');
  });

  test(
    'retry after unknown outcome reuses source and request identity',
    () async {
      var attempt = 0;
      final repository = _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          attempt += 1;
          if (attempt == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.timeout,
              retryable: true,
            );
          }
          return _presetMoment();
        },
      );
      final requests = <String>[];
      repository.onRequest = ({required source, required clientRequestId}) {
        requests.add(clientRequestId);
      };
      final controller = SceneGenerationController(
        repository: repository,
        approvedBundleRegistrar: (_) async {},
      );

      await controller.generate(
        source: const PresetSceneGenerationSource('bath_time'),
        clientRequestId: 'preset_request_2',
      );
      expect(
        controller.state.status,
        SceneGenerationControllerStatus.unknownOutcome,
      );

      await controller.retry();

      expect(requests, ['preset_request_2', 'preset_request_2']);
      expect(controller.state.status, SceneGenerationControllerStatus.success);
    },
  );

  test(
    'registration recovery retries registration without generating twice',
    () async {
      var registrationAttempts = 0;
      final repository = _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async =>
            _presetMoment(),
      );
      final controller = SceneGenerationController(
        repository: repository,
        approvedBundleRegistrar: (_) async {
          registrationAttempts += 1;
          if (registrationAttempts == 1) {
            throw StateError('registry unavailable');
          }
        },
      );

      await controller.generate(
        source: const PresetSceneGenerationSource('bath_time'),
        clientRequestId: 'preset_request_registration',
      );
      expect(
        controller.state.status,
        SceneGenerationControllerStatus.unknownOutcome,
      );

      await controller.retry();

      expect(repository.generateCount, 1);
      expect(registrationAttempts, 2);
      expect(controller.state.status, SceneGenerationControllerStatus.success);
    },
  );

  test('terminal recovery allocates a new logical request identity', () async {
    var attempts = 0;
    final requests = <String>[];
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          requests.add(clientRequestId);
          attempts += 1;
          if (attempts == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.requestTerminal,
              requiresNewClientRequestId: true,
            );
          }
          return _presetMoment();
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'terminal_request_1',
    );
    await controller.retry();

    expect(requests, hasLength(2));
    expect(requests[0], 'terminal_request_1');
    expect(requests[1], isNot('terminal_request_1'));
    expect(controller.state.status, SceneGenerationControllerStatus.success);
  });

  test(
    'retry only allocates a new request identity for flagged terminal failure',
    () async {
      for (final kind in <SceneGenerationFailureKind>[
        SceneGenerationFailureKind.network,
        SceneGenerationFailureKind.generationInProgress,
        SceneGenerationFailureKind.unexpected,
        SceneGenerationFailureKind.timeout,
        SceneGenerationFailureKind.requestTerminal,
      ]) {
        var attempts = 0;
        final requests = <String>[];
        final controller = SceneGenerationController(
          repository: _FakeSceneGenerationRepository(
            onGenerate: ({required source, required clientRequestId}) async {
              requests.add(clientRequestId);
              attempts += 1;
              if (attempts == 1) {
                throw SceneGenerationFailure(
                  kind: kind,
                  retryable: true,
                  requiresNewClientRequestId: true,
                );
              }
              return _presetMoment();
            },
          ),
          approvedBundleRegistrar: (_) async {},
        );

        await controller.generate(
          source: const PresetSceneGenerationSource('bath_time'),
          clientRequestId: 'request_identity_${kind.name}',
        );
        await controller.retry();

        if (kind == SceneGenerationFailureKind.requestTerminal) {
          expect(requests[1], isNot(requests[0]), reason: kind.name);
        } else {
          expect(requests[1], requests[0], reason: kind.name);
        }
        expect(
          controller.state.status,
          SceneGenerationControllerStatus.success,
        );
      }

      var terminalAttempts = 0;
      final terminalRequests = <String>[];
      final terminalWithoutFlag = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async {
            terminalRequests.add(clientRequestId);
            terminalAttempts += 1;
            if (terminalAttempts == 1) {
              throw const SceneGenerationFailure(
                kind: SceneGenerationFailureKind.requestTerminal,
                retryable: true,
              );
            }
            return _presetMoment();
          },
        ),
        approvedBundleRegistrar: (_) async {},
      );
      await terminalWithoutFlag.generate(
        source: const PresetSceneGenerationSource('bath_time'),
        clientRequestId: 'terminal_without_flag',
      );
      await terminalWithoutFlag.retry();
      expect(terminalRequests, [
        'terminal_without_flag',
        'terminal_without_flag',
      ]);
    },
  );

  test('recoverable failure keeps request identity when retrying', () async {
    var attempts = 0;
    final requests = <String>[];
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          requests.add(clientRequestId);
          attempts += 1;
          if (attempts == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.invalidInput,
            );
          }
          return _presetMoment();
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'recoverable_request_1',
    );
    expect(
      controller.state.status,
      SceneGenerationControllerStatus.recoverableError,
    );
    await controller.retry();

    expect(requests, ['recoverable_request_1', 'recoverable_request_1']);
    expect(controller.state.status, SceneGenerationControllerStatus.success);
  });

  test('reentrant generate calls share one logical request', () async {
    final generation = Completer<GeneratedCareMoment>();
    final repository = _FakeSceneGenerationRepository(
      onGenerate: ({required source, required clientRequestId}) =>
          generation.future,
    );
    final controller = SceneGenerationController(
      repository: repository,
      approvedBundleRegistrar: (_) async {},
    );

    final first = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_3',
    );
    final second = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_3',
    );

    expect(identical(first, second), isTrue);
    expect(repository.generateCount, 1);
    generation.complete(_presetMoment());
    await first;
  });

  testWidgets(
    'gate shows progress before generation and routes success as generated',
    (tester) async {
      final generation = Completer<GeneratedCareMoment>();
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              generation.future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      GeneratedCareTurnRouteArgs? generatedArgs;

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_widget_request',
            onGenerated: (args) async {
              generatedArgs = args;
            },
            bundledFallbackLoader: (_) async => false,
          ),
        ),
      );

      await tester.pump();
      expect(
        find.byKey(const Key('preset-generation-progress')),
        findsOneWidget,
      );
      expect(find.text('正在为宝宝准备个性化练习…'), findsOneWidget);

      generation.complete(_presetMoment());
      await tester.pumpAndSettle();

      expect(generatedArgs?.generatedContentId, 'generated_preset_1');
      expect(find.byKey(const Key('preset-generation-progress')), findsNothing);
    },
  );

  testWidgets(
    'gate offers local generic fallback only when bundled content exists',
    (tester) async {
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.network,
              retryable: true,
            );
          },
        ),
        approvedBundleRegistrar: (_) async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_fallback_request',
            bundledFallbackLoader: (_) async => true,
            fallbackBuilder: (_, _) => const Text('通用内容'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('preset-generation-retry')), findsOneWidget);
      expect(find.text('使用通用内容'), findsOneWidget);

      await tester.tap(find.text('使用通用内容'));
      await tester.pumpAndSettle();
      expect(find.text('通用内容'), findsOneWidget);
      expect(find.byKey(const Key('preset-generation-retry')), findsNothing);
    },
  );

  testWidgets('default generic fallback carries explicit bundled-only args', (
    tester,
  ) async {
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.network,
            retryable: true,
          );
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    final practiceRepository = Completer<PracticeRepository>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith(
            (ref) => practiceRepository.future,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_default_fallback_request',
            bundledFallbackLoader: (_) async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('使用通用内容'));
    await tester.pump();

    final session = tester.widget<PracticeSessionScreen>(
      find.byType(PracticeSessionScreen),
    );
    expect(
      session.genericFallbackArgs?.scopeLabel,
      'generic-fallback:daily_care/bath_time',
    );
  });

  testWidgets('remote-only preset does not offer generic fallback', (
    tester,
  ) async {
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.presetSceneUnavailable,
            retryable: true,
          );
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PresetSceneGenerationGateScreen(
          routeEntry: PracticeRouteEntry.fromObject(
            const PracticeRouteArgs(
              spaceId: 'remote_space',
              activityId: 'remote_only',
            ),
          ),
          controller: controller,
          clientRequestId: 'preset_remote_request',
          bundledFallbackLoader: (_) async => false,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('使用通用内容'), findsNothing);
  });

  testWidgets(
    'gate keeps default controller provider alive until it resolves',
    (tester) async {
      final controllerCompleter = Completer<SceneGenerationController>();
      var disposed = false;
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async =>
              _presetMoment(),
        ),
        approvedBundleRegistrar: (_) async {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationControllerProvider(
              'daily_care/bath_time',
            ).overrideWith((ref) {
              ref.onDispose(() => disposed = true);
              return controllerCompleter.future;
            }),
          ],
          child: MaterialApp(
            home: PresetSceneGenerationGateScreen(
              routeEntry: PracticeRouteEntry.fromObject(
                const PracticeRouteArgs(
                  spaceId: 'daily_care',
                  activityId: 'bath_time',
                ),
              ),
              clientRequestId: 'provider_lifecycle_request',
              presetDefinitionLoader: (args) async =>
                  _presetDefinition(args.normalizedActivityId),
              bundledFallbackLoader: (_) async => false,
              onGenerated: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(disposed, isFalse);

      controllerCompleter.complete(controller);
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'default controller provider completes success while gate watches it',
    (tester) async {
      final tempDir = (await tester.runAsync<Directory>(() async {
        final directory = Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}'
          'preset_gate_default_provider_${DateTime.now().microsecondsSinceEpoch}',
        );
        await directory.create(recursive: true);
        return directory;
      }))!;
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final registry = _NoOpGeneratedPracticeContentRegistry(
        store: GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        ),
        resumeStore: GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        ),
      );
      final repository = _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async =>
            _presetMoment(),
      );
      GeneratedCareTurnRouteArgs? generatedArgs;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            generatedPracticeContentRegistryProvider.overrideWithValue(
              registry,
            ),
          ],
          child: MaterialApp(
            home: PresetSceneGenerationGateScreen(
              routeEntry: PracticeRouteEntry.fromObject(
                const PracticeRouteArgs(
                  spaceId: 'daily_care',
                  activityId: 'bath_time',
                ),
              ),
              clientRequestId: 'default_provider_success',
              presetDefinitionLoader: (args) async =>
                  _presetDefinition(args.normalizedActivityId),
              bundledFallbackLoader: (_) async => false,
              onGenerated: (args) async {
                generatedArgs = args;
              },
            ),
          ),
        ),
      );
      for (var index = 0; index < 40; index += 1) {
        await tester.pump(const Duration(milliseconds: 25));
        if (generatedArgs != null) {
          break;
        }
      }

      expect(repository.generateCount, 1);
      expect(generatedArgs?.generatedContentId, 'generated_preset_1');
      expect(find.byKey(const Key('preset-generation-progress')), findsNothing);
    },
  );

  testWidgets(
    'default provider isolates concurrent preset A and B controllers',
    (tester) async {
      final repository = _SequencedSceneGenerationRepository([
        _presetMoment(generatedContentId: 'generated_bath'),
        _presetMoment(
          generatedContentId: 'generated_feeding',
          activityId: 'feeding_time',
        ),
      ]);
      final registry = _NoOpGeneratedPracticeContentRegistry(
        store: GeneratedCareMomentLocalStore(
          directoryResolver: () async => Directory.systemTemp,
        ),
        resumeStore: GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => Directory.systemTemp,
        ),
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      final routed = <String>[];

      PracticeRouteEntry entry(String activityId) =>
          PracticeRouteEntry.fromObject(
            PracticeRouteArgs(spaceId: 'daily_care', activityId: activityId),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
            generatedPracticeContentRegistryProvider.overrideWithValue(
              registry,
            ),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: PresetSceneGenerationGateScreen(
              routeEntry: entry('bath_time'),
              presetDefinitionLoader: (args) async =>
                  _presetDefinition(args.normalizedActivityId),
              onGenerated: (args) async {
                routed.add('A:${args.generatedContentId}');
              },
            ),
          ),
        ),
      );
      for (var index = 0; index < 40 && routed.isEmpty; index += 1) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => PresetSceneGenerationGateScreen(
            routeEntry: entry('feeding_time'),
            presetDefinitionLoader: (args) async =>
                _presetDefinition(args.normalizedActivityId),
            onGenerated: (args) async {
              routed.add('B:${args.generatedContentId}');
            },
          ),
        ),
      );
      for (var index = 0; index < 40 && routed.length < 2; index += 1) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      expect(repository.sources, hasLength(2));
      expect(repository.sources[0].presetSceneId, 'bath_time');
      expect(repository.sources[1].presetSceneId, 'feeding_time');
      expect(routed, ['A:generated_bath', 'B:generated_feeding']);
    },
  );

  testWidgets(
    'generated preset identity mismatch fails closed before registration',
    (tester) async {
      var registrations = 0;
      GeneratedCareTurnRouteArgs? routed;
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async =>
              _presetMoment(presetSceneVersion: 99),
        ),
        approvedBundleRegistrar: (_) async {
          registrations += 1;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            presetDefinitionLoader: (args) async =>
                _presetDefinition(args.normalizedActivityId),
            bundledFallbackLoader: (_) async => false,
            onGenerated: (args) async {
              routed = args;
            },
          ),
        ),
      );
      for (var index = 0; index < 40; index += 1) {
        await tester.pump(const Duration(milliseconds: 25));
      }

      expect(registrations, 0);
      expect(routed, isNull);
      expect(
        controller.status,
        SceneGenerationControllerStatus.recoverableError,
      );
      expect(find.byKey(const Key('preset-generation-error')), findsOneWidget);
    },
  );

  testWidgets(
    'switching route identity starts a fresh controller for preset B',
    (tester) async {
      final controllerA = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              Completer<GeneratedCareMoment>().future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      final controllerB = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async =>
              _presetMoment(activityId: 'feeding_time'),
        ),
        approvedBundleRegistrar: (_) async {},
      );

      PracticeRouteEntry entry(String activityId) =>
          PracticeRouteEntry.fromObject(
            PracticeRouteArgs(spaceId: 'daily_care', activityId: activityId),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('bath_time'),
            controller: controllerA,
            clientRequestId: 'route_a_request',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(controllerA.status, SceneGenerationControllerStatus.submitting);

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('feeding_time'),
            controller: controllerB,
            clientRequestId: 'route_b_request',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controllerB.status, SceneGenerationControllerStatus.success);
      expect(controllerB.clientRequestId, 'route_b_request');
    },
  );

  testWidgets(
    'queued success callback from preset A cannot navigate after switching to B',
    (tester) async {
      final generationA = Completer<GeneratedCareMoment>();
      final controllerA = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              generationA.future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      final generationB = Completer<GeneratedCareMoment>();
      final controllerB = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              generationB.future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      final navigatedScopes = <String>[];

      PracticeRouteEntry entry(String activityId) =>
          PracticeRouteEntry.fromObject(
            PracticeRouteArgs(spaceId: 'daily_care', activityId: activityId),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('bath_time'),
            controller: controllerA,
            clientRequestId: 'queued_a',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async => navigatedScopes.add('A'),
          ),
        ),
      );
      await tester.pump();
      generationA.complete(_presetMoment());
      await tester.idle();

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('feeding_time'),
            controller: controllerB,
            clientRequestId: 'queued_b',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async => navigatedScopes.add('B'),
          ),
        ),
      );
      await tester.pump();

      expect(navigatedScopes, isEmpty);
      expect(controllerB.status, SceneGenerationControllerStatus.submitting);
      generationB.complete(_presetMoment());
      await tester.pumpAndSettle();
    },
  );

  test(
    'bundled fallback seam never resolves generated or remote content',
    () async {
      final repository = _BundledOnlyPracticeRepository();
      final turn = await CarePathRepository(practiceRepository: repository)
          .startMoment(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            bundledOnly: true,
          );

      expect(repository.bundledCalls, 1);
      expect(repository.remoteCalls, 0);
      expect(turn.moment.contentSource, PracticeContentSource.seed);
    },
  );

  test(
    'generic fallback keeps bundled source through reaction despite same-scope generated bundle',
    () async {
      final repository = _ExistingGeneratedBundlePracticeRepository();
      final garden = _TrackingGardenGrowthRepository();
      final carePath = CarePathRepository(
        practiceRepository: repository,
        gardenGrowthRepository: garden,
      );

      final initial = await carePath.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        bundledOnly: true,
      );
      final afterReaction = await carePath.recordReaction(
        turn: initial.copyWith(phase: CareTurnPhase.reactionPrompt),
        reactionType: BabyReactionType.cooperating,
        localEventId: 'generic_fallback_reaction',
      );

      expect(initial.moment.contentSource, PracticeContentSource.seed);
      expect(initial.bundledOnly, isTrue);
      expect(afterReaction.moment.contentSource, PracticeContentSource.seed);
      expect(afterReaction.bundledOnly, isTrue);
      expect(afterReaction.currentUtterance, isNotNull);
      expect(afterReaction.nextSupportUtterance, isNotNull);
      expect(repository.generatedRegistryCalls, 0);
      expect(repository.bundledCalls, greaterThanOrEqualTo(3));
      expect(repository.recordedReactionCount, 1);
      expect(garden.buildCalls, 0);
    },
  );
}

class _FakeSceneGenerationRepository implements SceneGenerationRepository {
  _FakeSceneGenerationRepository({required this.onGenerate});

  Future<GeneratedCareMoment> Function({
    required SceneGenerationSource source,
    required String clientRequestId,
  })
  onGenerate;
  void Function({
    required SceneGenerationSource source,
    required String clientRequestId,
  })?
  onRequest;
  int generateCount = 0;

  @override
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) {
    generateCount += 1;
    onRequest?.call(source: source, clientRequestId: clientRequestId);
    return onGenerate(source: source, clientRequestId: clientRequestId);
  }
}

class _SequencedSceneGenerationRepository implements SceneGenerationRepository {
  _SequencedSceneGenerationRepository(this.moments);

  final List<GeneratedCareMoment> moments;
  final List<PresetSceneGenerationSource> sources =
      <PresetSceneGenerationSource>[];
  int _index = 0;

  @override
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) async {
    final presetSource = source as PresetSceneGenerationSource;
    sources.add(presetSource);
    return moments[_index++];
  }
}

PresetSceneDefinition _presetDefinition(String activityId) {
  return PresetSceneDefinition(
    presetSceneId: activityId,
    publishedVersion: 1,
    spaceId: 'daily_care',
    title: activityId,
    summary: activityId,
    sceneTag: activityId,
    coachTip: activityId,
    sortOrder: 1,
  );
}

class _BundledOnlyPracticeRepository implements PracticeRepository {
  int bundledCalls = 0;
  int remoteCalls = 0;

  @override
  Future<PracticeActivitySnapshot> getBundledActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    bundledCalls += 1;
    return const PracticeActivitySnapshot(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      title: '洗澡时间',
      summary: '通用内容',
      sceneTag: 'bath',
      coachTip: '慢慢说',
      phrases: <PracticePhrase>[
        PracticePhrase(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          step: 1,
          english: 'Warm water.',
          chinese: '水暖暖的。',
          pronunciation: 'wɔːm',
          difficulty: 'starter',
          audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
        ),
      ],
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    remoteCalls += 1;
    throw StateError('remote activity must not be read for generic fallback');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOpGeneratedPracticeContentRegistry
    extends GeneratedPracticeContentRegistry {
  _NoOpGeneratedPracticeContentRegistry({
    required super.store,
    required super.resumeStore,
  }) : super(accountContextLoader: _accountContext);

  static Future<String?> _accountContext() async => 'default_provider_account';

  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {}
}

class _TrackingGardenGrowthRepository implements GardenGrowthRepository {
  int buildCalls = 0;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async {
    buildCalls += 1;
    throw StateError('generic fallback must not resolve Garden catalog');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ExistingGeneratedBundlePracticeRepository
    extends _BundledOnlyPracticeRepository
    implements BundledPracticeReactionRecorder {
  static const _generatedActivity = PracticeActivitySnapshot(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    title: '已生成洗澡时间',
    summary: 'generated same scope',
    sceneTag: 'generated',
    coachTip: 'generated coach',
    contentSource: PracticeContentSource.generated,
    generatedContentId: 'generated_same_scope',
    phrases: <PracticePhrase>[
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'generated_phrase',
        step: 1,
        english: 'Generated.',
        chinese: '生成内容。',
        pronunciation: 'generated',
        difficulty: 'starter',
        audioAsset: '',
      ),
    ],
  );

  int generatedRegistryCalls = 0;
  int recordedReactionCount = 0;

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    generatedRegistryCalls += 1;
    return _generatedActivity;
  }

  @override
  Future<InteractionEventPayload> recordBundledReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    recordedReactionCount += 1;
    await getBundledActivitySnapshot(spaceId: spaceId, activityId: activityId);
    return InteractionEventPayload.validated(
      localEventId: localEventId ?? 'generic_fallback_reaction',
      installationId: 'generic_fallback_installation',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.utc(2026, 9, 9),
    );
  }
}

GeneratedCareMoment _presetMoment({
  String generatedContentId = 'generated_preset_1',
  String spaceId = 'daily_care',
  String activityId = 'bath_time',
  String? presetSceneId,
  int presetSceneVersion = 1,
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
    sceneId: spaceId,
    spaceId: spaceId,
    momentId: activityId,
    activityId: activityId,
    title: '洗澡时间',
    sceneTag: 'bath',
    coachTip: '慢慢说',
    source: 'generated',
    inputSource: SceneGenerationSourceType.preset,
    presetSceneId: presetSceneId ?? activityId,
    presetSceneVersion: presetSceneVersion,
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
