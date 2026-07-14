import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/baby_talk_app.dart';
import 'package:mobile_v2/app/input/event_id_generator.dart';
import 'package:mobile_v2/app/localization/generated/app_localizations.dart';
import 'package:mobile_v2/app/providers/interaction_engine_providers.dart';
import 'package:mobile_v2/app/providers/ritual_room_data_providers.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/interaction_repository.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/ritual_room_repository.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_session_initializer.dart';
import 'package:mobile_v2/features/ritual_room/presentation/capability/interaction_capability_mask.dart';
import 'package:mobile_v2/features/ritual_room/presentation/screens/ritual_room_screen.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

import '../../../../fixtures/interaction_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'R058/R059 app opens direct loading then ready Ritual Room without navigation shell',
    (tester) async {
      await _setPhoneViewport(tester);
      final load = Completer<RitualRoomContent>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ritualRoomRepositoryProvider.overrideWithValue(
              _RoomRepository((_) => load.future),
            ),
            interactionSessionInitializerProvider.overrideWithValue(
              _Initializer((_) async => interactionSnapshot()),
            ),
          ],
          child: const BabyTalkApp(),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('First Entry'), findsNothing);
      expect(find.textContaining('Today Orientation'), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byKey(const Key('ritual-room-root')), findsOneWidget);
      expect(find.text('正在准备这句话…'), findsOneWidget);

      load.complete(_room());
      await tester.pumpAndSettle();

      expect(find.text('Let’s put your shoes on.'), findsOneWidget);
      expect(find.byKey(const Key('ritual-sentence-plane')), findsOneWidget);
    },
  );

  test('BabyTalkApp owns reaction intent but no command-envelope details', () {
    final source = File('lib/app/baby_talk_app.dart').readAsStringSync();

    expect(source, contains('submitReaction'));
    expect(source, contains('retryPendingEvent'));
    for (final forbidden in [
      'InputEvent',
      'interactionInputFactoryProvider',
      'eventId',
      'expectedRevision',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  testWidgets(
    'R067 reaction sheet submits typed events, preserves pending content, and applies two in-place revisions',
    (tester) async {
      await _setPhoneViewport(tester);
      final firstAdvance = Completer<AdvanceResult>();
      final repository = _InteractionRepository((call) {
        if (call == 1) {
          return firstAdvance.future;
        }
        return Future.value(
          AdvanceApplied(_snapshot(revision: 2, label: '想自己来')),
        );
      });
      await _pumpReadyApp(tester, repository: repository);

      await _ensureDockExpanded(tester);
      expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);
      await tester.tap(find.text('哭了'));
      await tester.pump();

      expect(find.text('Let’s put your shoes on.'), findsOneWidget);
      expect(find.text('正在换一种说法…'), findsOneWidget);
      expect(repository.inputs.single.payload, isA<ReactionSelectionPayload>());

      firstAdvance.complete(
        AdvanceApplied(_snapshot(revision: 1, label: '哭了')),
      );
      await tester.pumpAndSettle();
      expect(find.text('revised utterance 1'), findsOneWidget);

      await _ensureDockExpanded(tester);
      await tester.tap(find.text('想自己来'));
      await tester.pumpAndSettle();
      expect(find.text('revised utterance 2'), findsOneWidget);
      expect(repository.inputs, hasLength(2));
      expect(repository.expectedRevisions, [0, 1]);
    },
  );

  testWidgets(
    'R060 authoritative pipeline failure clears the old command and a later tap creates a new event',
    (tester) async {
      await _setPhoneViewport(tester);
      final repository = _InteractionRepository((call) async {
        if (call == 1) {
          return const AdvanceRejected(code: AdvanceErrorCode.pipelineFailed);
        }
        return AdvanceApplied(_snapshot(revision: 1, label: '还不想穿'));
      });
      await _pumpReadyApp(tester, repository: repository);

      await _ensureDockExpanded(tester);
      await tester.tap(find.byKey(const Key('ritual-context-choice-not_ready')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ritual-transient-notice-retry')), findsNothing);
      expect(find.text('Let’s put your shoes on.'), findsOneWidget);
      expect(find.byKey(const Key('ritual-context-entry')), findsOneWidget);

      await _ensureDockExpanded(tester);
      await tester.tap(find.byKey(const Key('ritual-context-choice-not_ready')));
      await tester.pumpAndSettle();

      expect(find.text('revised utterance 1'), findsOneWidget);
      expect(find.byKey(const Key('ritual-transient-notice-retry')), findsNothing);
      expect(repository.inputs, hasLength(2));
      expect(repository.inputs[0].eventId, isNot(repository.inputs[1].eventId));
    },
  );

  testWidgets(
    'submitting and unknown outcome lock reactions but preserve selected playback and exit',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final snapshot = interactionSnapshot();
      var listened = 0;
      var exited = 0;
      var retried = 0;

      for (final state in <RitualRoomUiState>[
        RitualRoomSubmitting(
          room: room,
          snapshot: snapshot,
          selectedReaction: 'not_ready',
        ),
        RitualRoomUnknownOutcome(
          room: room,
          snapshot: snapshot,
          selectedReaction: 'not_ready',
          isRetrying: false,
        ),
        RitualRoomUnknownOutcome(
          room: room,
          snapshot: snapshot,
          selectedReaction: 'not_ready',
          isRetrying: true,
        ),
      ]) {
        await tester.pumpWidget(
          _screenHost(
            RitualRoomScreen(
              state: state,
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) => fail('locked reaction emitted'),
              onRetry: () {},
              onRetryPendingEvent: () => retried += 1,
              onListen: () => listened += 1,
              listenAdapterInjected: true,
            ),
          ),
        );
        await tester.pump();

        await _ensureDockExpanded(tester);

        for (final key in const [
          Key('ritual-context-choice-not_ready'),
          Key('ritual-context-choice-self'),
          Key('ritual-context-choice-crying'),
        ]) {
          final button = tester.widget<ButtonStyleButton>(find.byKey(key));
          expect(button.onPressed, isNull);
        }
        if (state is RitualRoomUnknownOutcome) {
          expect(find.text('刚才的调整还没有确认。'), findsOneWidget);
          if (state.isRetrying) {
            expect(
              find.byKey(const Key('ritual-transient-notice-retry')),
              findsNothing,
            );
          } else {
            final retry = tester.widget<TextButton>(
              find.byKey(const Key('ritual-transient-notice-retry')),
            );
            expect(retry.onPressed, isNotNull);
            await tester.tap(
              find.byKey(const Key('ritual-transient-notice-retry')),
            );
            expect(retried, 1);
          }
        }

        await tester.tap(find.byKey(const Key('ritual-listen-control')));
        await tester.ensureVisible(find.byKey(const Key('ritual-quiet-exit')));
        await tester.tap(find.byKey(const Key('ritual-quiet-exit')));
        exited += 1;
      }

      expect(listened, 3);
      expect(exited, 3);
    },
  );

  testWidgets(
    'live-region is transient notice only during submitting and unknown-reconciling and no forced focus occurs',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final snapshot = interactionSnapshot();
      final semantics = tester.ensureSemantics();

      final submitting = RitualRoomSubmitting(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'not_ready',
      );
      await tester.pumpWidget(
        _screenHost(
          RitualRoomScreen(
            state: submitting,
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            listenAdapterInjected: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _ensureDockExpanded(tester);
      final focusBefore = FocusManager.instance.primaryFocus;

      expect(find.byKey(const Key('ritual-transient-notice')), findsOneWidget);
      final submittingNotice = tester.widget<Semantics>(
        find.byKey(const Key('ritual-transient-notice')),
      );
      expect(submittingNotice.properties.liveRegion, isTrue);

      final primary = tester.widget<Semantics>(
        find.byKey(const Key('ritual-primary-sentence')),
      );
      expect(primary.properties.liveRegion, isNot(true));

      final unknown = RitualRoomUnknownOutcome(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'not_ready',
        isRetrying: false,
      );
      await tester.pumpWidget(
        _screenHost(
          RitualRoomScreen(
            state: unknown,
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            listenAdapterInjected: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _ensureDockExpanded(tester);

      expect(find.byKey(const Key('ritual-transient-notice')), findsOneWidget);
      final unknownNotice = tester.widget<Semantics>(
        find.byKey(const Key('ritual-transient-notice')),
      );
      expect(unknownNotice.properties.liveRegion, isTrue);
      expect(find.byKey(const Key('ritual-transient-notice-retry')), findsOneWidget);

      final reconciling = RitualRoomUnknownOutcome(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'not_ready',
        isRetrying: true,
      );
      await tester.pumpWidget(
        _screenHost(
          RitualRoomScreen(
            state: reconciling,
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            listenAdapterInjected: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _ensureDockExpanded(tester);

      expect(find.byKey(const Key('ritual-transient-notice')), findsOneWidget);
      final reconcilingNotice = tester.widget<Semantics>(
        find.byKey(const Key('ritual-transient-notice')),
      );
      expect(reconcilingNotice.properties.liveRegion, isTrue);
      expect(find.byKey(const Key('ritual-transient-notice-retry')), findsNothing);

      await tester.pumpWidget(
        _screenHost(
          RitualRoomScreen(
            state: RitualRoomReady(room: room, snapshot: snapshot),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            listenAdapterInjected: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(FocusManager.instance.primaryFocus, same(focusBefore));
      expect(find.byKey(const Key('ritual-transient-notice')), findsNothing);
      expect(find.byKey(const Key('ritual-context-entry')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'already-open reaction sheet follows reaction lock and releases its listener lifecycle',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final snapshot = interactionSnapshot();
      final state = ValueNotifier<RitualRoomUiState>(
        RitualRoomReady(room: room, snapshot: snapshot),
      );
      addTearDown(state.dispose);
      final emitted = <String>[];

      await tester.pumpWidget(
        _screenHost(
          ValueListenableBuilder<RitualRoomUiState>(
            valueListenable: state,
            builder: (context, current, child) => RitualRoomScreen(
              state: current,
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: emitted.add,
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              listenAdapterInjected: true,
            ),
          ),
        ),
      );

      await _ensureDockExpanded(tester);
      expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);

      state.value = RitualRoomSubmitting(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'crying',
      );
      await tester.pump();

      final choices = find.byType(OutlinedButton);
      expect(choices, findsNWidgets(5));
      await tester.tap(choices.first, warnIfMissed: false);
      expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);
      expect(emitted, isEmpty);
      await tester.pump();
      for (final button in tester.widgetList<OutlinedButton>(choices)) {
        expect(button.onPressed, isNull);
      }
      for (var index = 0; index < choices.evaluate().length; index += 1) {
        await tester.tap(choices.at(index), warnIfMissed: false);
        await tester.pump();
        expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);
        expect(emitted, isEmpty);
      }

      state.value = RitualRoomReady(room: room, snapshot: snapshot);
      await tester.pump();
      await tester.pump();
      final enabledChoice = tester.widget<OutlinedButton>(choices.first);
      expect(enabledChoice.onPressed, isNotNull);
      await tester.tap(choices.first);
      await tester.pumpAndSettle();
      expect(emitted, ['not_ready']);
      expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();
      if (find.byKey(const Key('ritual-context-collapse')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('ritual-context-collapse')));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(emitted, ['not_ready']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dock expansion keeps ritual sentence plane geometry stable',
    (tester) async {
      await _setPhoneViewport(tester);
      await _pumpReadyApp(tester, repository: _InteractionRepository((_) async =>
          AdvanceApplied(_snapshot(revision: 1, label: '还不想穿'))));

      final before = tester.getRect(
        find.byKey(const Key('ritual-sentence-plane')),
      );
      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();
      final after = tester.getRect(
        find.byKey(const Key('ritual-sentence-plane')),
      );
      expect(after, before);
    },
  );

  testWidgets(
    'reduced motion stabilizes sentence replacement within 100ms and avoids SlideTransition',
    (tester) async {
      await _setPhoneViewport(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _screenHost(
            RitualRoomScreen(
              state: RitualRoomReady(
                room: _room(),
                snapshot: _snapshot(revision: 0, label: '还不想穿'),
              ),
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) {},
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              listenAdapterInjected: true,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _screenHost(
            RitualRoomScreen(
              state: RitualRoomReady(
                room: _room(),
                snapshot: _snapshot(revision: 1, label: '还不想穿'),
              ),
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) {},
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              listenAdapterInjected: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('revised utterance 1'), findsOneWidget);

      final switcher = find.descendant(
        of: find.byKey(const Key('ritual-sentence-plane')),
        matching: find.byType(AnimatedSwitcher),
      );
      expect(switcher, findsOneWidget);
      expect(
        find.descendant(of: switcher, matching: find.byType(SlideTransition)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submitting unknown and recoverable states keep previous sentence visible',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room();
      final stableSnapshot = _snapshot(revision: 7, label: '还不想穿');

      for (final state in <RitualRoomUiState>[
        RitualRoomSubmitting(
          room: room,
          snapshot: stableSnapshot,
          selectedReaction: 'not_ready',
        ),
        RitualRoomUnknownOutcome(
          room: room,
          snapshot: stableSnapshot,
          selectedReaction: 'not_ready',
          isRetrying: false,
        ),
        RitualRoomRecoverableFailure(
          room: room,
          snapshot: stableSnapshot,
          problem: const RitualRoomProblem(AdvanceErrorCode.pipelineFailed),
        ),
      ]) {
        await tester.pumpWidget(
          _screenHost(
            RitualRoomScreen(
              state: state,
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) {},
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              listenAdapterInjected: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('revised utterance 7'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'collapse during pending request does not cancel eventual update',
    (tester) async {
      await _setPhoneViewport(tester);
      final advance = Completer<AdvanceResult>();
      final repository = _InteractionRepository((_) => advance.future);
      await _pumpReadyApp(tester, repository: repository);

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ritual-context-choice-not_ready')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ritual-context-dock-collapsed')), findsOneWidget);

      advance.complete(AdvanceApplied(_snapshot(revision: 1, label: '还不想穿')));
      await tester.pumpAndSettle();

      expect(find.text('revised utterance 1'), findsOneWidget);
      expect(repository.inputs, hasLength(1));
    },
  );

  testWidgets('android back collapses dock first', (tester) async {
    await _setPhoneViewport(tester);
    await _pumpReadyApp(tester, repository: _InteractionRepository((_) async =>
        AdvanceApplied(_snapshot(revision: 1, label: '还不想穿'))));

    await tester.tap(find.byKey(const Key('ritual-context-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ritual-context-dock-collapsed')), findsOneWidget);
    expect(find.byType(BabyTalkApp), findsOneWidget);
  });

  testWidgets(
    'quiet exit does not trigger snackbar navigation or external callbacks',
    (tester) async {
      await _setPhoneViewport(tester);
      var completed = 0;
      final observer = _RecordingNavigatorObserver(
        didPopCallback: () => completed += 1,
      );

      await tester.pumpWidget(
        _screenHost(
          RitualRoomScreen(
            state: RitualRoomReady(room: _room(), snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            listenAdapterInjected: true,
          ),
          navigatorObservers: [observer],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ritual-quiet-exit')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const Key('ritual-context-dock-collapsed')), findsOneWidget);
      expect(observer.popCount, 0);
      expect(completed, 0);
    },
  );

  test('screen source forbids focus grabbing and semantic announcement apis', () {
    final source = File(
      'lib/features/ritual_room/presentation/screens/ritual_room_screen.dart',
    ).readAsStringSync();

    for (final forbidden in [
      'requestFocus',
      'FocusScope',
      'SemanticsService',
      'sendAnnouncement',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
  });

  testWidgets(
    'R058/R059 alternate repository payload substitutes visible content and forbidden scope stays absent',
    (tester) async {
      await _setPhoneViewport(tester);
      final alternate = _room(
        roomName: '雨天小声音',
        routineAnchor: '雨天出门',
        anchorPhrase: 'Boots on.',
        chineseHelper: '穿雨靴啦。',
        reassurance: '只说一句也可以。',
        quietExit: '今天先到这里',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ritualRoomRepositoryProvider.overrideWithValue(
              _RoomRepository((_) async => alternate),
            ),
            interactionSessionInitializerProvider.overrideWithValue(
              _Initializer(
                (_) async => _snapshot(
                  revision: 0,
                  anchor: 'Boots on.',
                  utterance: "Let's put your boots on.",
                  helper: '我们来穿雨靴吧。',
                  label: '雨天出门',
                  actionCue: '拿起雨靴时',
                ),
              ),
            ),
          ],
          child: const BabyTalkApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final text in [
        '雨天小声音',
        "Let's put your boots on.",
        '我们来穿雨靴吧。',
        '拿起雨靴时',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      for (final forbidden in [
        '下一句',
        '课程',
        '任务',
        '进度',
        '积分',
        '分数',
        'Garden',
        'Phase 42',
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(Slider), findsNothing);
    },
  );
}

Widget _screenHost(
  Widget child, {
  List<NavigatorObserver> navigatorObservers = const [],
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    navigatorObservers: navigatorObservers,
    home: child,
  );
}

final class _RecordingNavigatorObserver extends NavigatorObserver {
  _RecordingNavigatorObserver({required this.didPopCallback});

  final VoidCallback didPopCallback;
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    didPopCallback();
    super.didPop(route, previousRoute);
  }
}

Future<void> _pumpReadyApp(
  WidgetTester tester, {
  required InteractionRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ritualRoomRepositoryProvider.overrideWithValue(
          _RoomRepository((_) async => _room()),
        ),
        interactionSessionInitializerProvider.overrideWithValue(
          _Initializer((_) async => interactionSnapshot()),
        ),
        interactionRepositoryProvider.overrideWithValue(repository),
        interactionClockProvider.overrideWithValue(_Clock()),
        interactionEventIdGeneratorProvider.overrideWithValue(_EventIds()),
      ],
      child: const BabyTalkApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _ensureDockExpanded(WidgetTester tester) async {
  final expanded = find.byKey(const Key('ritual-context-dock-expanded'));
  if (expanded.evaluate().isNotEmpty) {
    return;
  }
  await tester.tap(find.byKey(const Key('ritual-context-entry')));
  await tester.pumpAndSettle();
}

final class _RoomRepository implements RitualRoomRepository {
  const _RoomRepository(this.load);
  final Future<RitualRoomContent> Function(String ritualRoomId) load;

  @override
  Future<RitualRoomContent> loadRoom(String ritualRoomId) => load(ritualRoomId);

  @override
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  }) => throw UnsupportedError('not used');
}

final class _Initializer implements InteractionSessionInitializer {
  const _Initializer(this.create);
  final Future<ProductSnapshot> Function(String ritualRoomId) create;

  @override
  Future<ProductSnapshot> initialize(String ritualRoomId) =>
      create(ritualRoomId);
}

typedef _Advance = Future<AdvanceResult> Function(int call);

final class _InteractionRepository implements InteractionRepository {
  _InteractionRepository(this.onAdvance);
  final _Advance onAdvance;
  final inputs = <InputEvent>[];
  final expectedRevisions = <int>[];

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) {
    inputs.add(input);
    expectedRevisions.add(expectedRevision);
    return onAdvance(inputs.length);
  }

  @override
  Future<ProductSnapshot> getSnapshot(String interactionId) =>
      throw UnsupportedError('not used');
}

final class _Clock implements InteractionClock {
  var calls = 0;
  @override
  DateTime now() => DateTime.utc(2026, 6, 21, 9, calls++);
}

final class _EventIds implements EventIdGenerator {
  var calls = 0;
  @override
  String nextEventId() => 'widget-event-${++calls}';
}

RitualRoomContent _room({
  String roomName = '出门小声音',
  String routineAnchor = '出门穿鞋',
  String anchorPhrase = 'Shoes on.',
  String chineseHelper = '穿鞋啦。',
  String reassurance = '不用每句都说，说一句就够了。',
  String quietExit = '先这样就好',
}) => RitualRoomContent(
  ritualRoomId: ritualRoomId,
  atmosphereTone: RitualAtmosphereTone.everydayCalm,
  roomName: roomName,
  routineAnchor: routineAnchor,
  anchorPhrase: anchorPhrase,
  chineseHelper: chineseHelper,
  illustration: const RitualIllustration(
    assetPath: 'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
    status: 'approved',
  ),
  audio: const RitualAudioContent(
    available: true,
    label: '听一遍',
    assetReference: 'assets/audio/current.mp3',
  ),
  reactionPrompt: '现在是什么情况？',
  reactionChoices: const [
    RitualReactionChoice(id: 'not_ready', label: '还不想穿'),
    RitualReactionChoice(id: 'self', label: '想自己来'),
    RitualReactionChoice(id: 'crying', label: '哭了'),
    RitualReactionChoice(id: 'moved_away', label: '跑开了'),
    RitualReactionChoice(id: 'finished', label: '已经穿好了'),
  ],
  pendingCopy: '正在换一种说法…',
  reassurance: reassurance,
  quietExit: quietExit,
  governanceEvidence: const RitualGovernanceEvidence(
    contextSeedId: 'screen-test-seed',
    joinabilityHypothesis: 'shared_action_available',
    governorDecision: 'allow_activation',
    productionGardenStatus: 'not_enabled',
  ),
);

ProductSnapshot _snapshot({
  required int revision,
  required String label,
  String anchor = 'Shoes on.',
  String? utterance,
  String helper = '我们来穿鞋吧。',
  String? actionCue,
}) {
  final base = interactionSnapshot(revision: revision);
  return ProductSnapshot(
    schemaVersion: base.schemaVersion,
    revision: revision,
    interactionId: base.interactionId,
    ritualRoomId: base.ritualRoomId,
    anchor: anchor,
    normalizedContext: interactionNormalizedInput(label),
    memory: base.memory,
    strategy: base.strategy,
    activeUtterance: ActiveUtterance(
      displayId: revision == 0
          ? 'shoes_on_ready_v1'
          : 'shoes_on_revised_$revision',
      primary:
          utterance ??
          (revision == 0
              ? 'Let’s put your shoes on.'
              : 'revised utterance $revision'),
      zhSupport: helper,
      actionCue: actionCue ?? (revision == 0 ? '拿起鞋时' : '宝宝停下来时'),
      audioAssetId: revision == 0 ? 'rr_shoes_001' : 'rr_shoes_002',
    ),
    metadata: base.metadata,
  );
}
