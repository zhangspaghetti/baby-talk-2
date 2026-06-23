import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/localization/generated/app_localizations.dart';
import 'package:mobile_v2/app/theme/baby_talk_theme.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/presentation/capability/interaction_capability_mask.dart';
import 'package:mobile_v2/features/ritual_room/presentation/screens/ritual_room_screen.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

import '../../../fixtures/interaction_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'semantic order stays 1..6 for primary support timing listen context entry quiet exit',
    (tester) async {
      await _setPhoneViewport(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: BabyTalkTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RitualRoomScreen(
            state: RitualRoomReady(room: _room(), snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            onQuietExit: () {},
            listenAdapterInjected: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pumpAndSettle();

      final primary = tester.widget<Semantics>(
        find.byKey(const Key('ritual-primary-sentence')),
      );
      final support = tester.widget<Semantics>(
        find.byKey(const Key('ritual-zh-support')),
      );
      final listen = tester.widget<Semantics>(
        find.ancestor(
          of: find.byKey(const Key('ritual-listen-control')),
          matching: find.byType(Semantics),
        ).first,
      );
      final timing = tester.widget<Semantics>(
        find.byKey(const Key('ritual-action-cue')),
      );
      final contextEntry = tester.widget<Semantics>(
        find.byKey(const Key('ritual-context-entry')),
      );
      final quietExit = tester.widget<Semantics>(
        find.byKey(const Key('ritual-quiet-exit')),
      );

      expect(primary.properties.sortKey, const OrdinalSortKey(1));
      expect(support.properties.sortKey, const OrdinalSortKey(2));
      expect(timing.properties.sortKey, const OrdinalSortKey(3));
      expect(
        find.bySemanticsLabel(
          '说这句话的时机：${interactionSnapshot().activeUtterance.actionCue}',
        ),
        findsOneWidget,
      );
      expect(listen.properties.sortKey, const OrdinalSortKey(4));
      expect(contextEntry.properties.sortKey, const OrdinalSortKey(5));
      expect(quietExit.properties.sortKey, const OrdinalSortKey(6));
    },
  );

  test('source contract forbids forced focus and announcement apis', () {
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
    'R058/R060 ready screen has semantic labels and 48x48 targets at 390x844',
    (tester) async {
      await _setPhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final room = _room();

      await tester.pumpWidget(
        MaterialApp(
          theme: BabyTalkTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RitualRoomScreen(
            state: RitualRoomReady(room: room, snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            onQuietExit: () {},
            listenAdapterInjected: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pump();

      expect(find.bySemanticsLabel('播放这句话'), findsOneWidget);
      for (final key in const [
        Key('ritual-listen-control'),
        Key('ritual-context-entry'),
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'R059 long payload at text scale 1.3 wraps without clipping or forbidden controls',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room(
        actionCue: '把鞋放在身边以后，停一下，再慢慢说出这一句。',
        reassurance: '不用要求孩子回应，也不用催促，只要自然地说一句就够了。',
      );
      final snapshot = _longSnapshot(actionCue: room.actionCue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            theme: BabyTalkTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RitualRoomScreen(
              state: RitualRoomReady(room: room, snapshot: snapshot),
              capabilityMask: InteractionCapabilityMask.phase41,
              onReactionSelected: (_) {},
              onRetry: () {},
              onRetryPendingEvent: () {},
              onListen: () {},
              onQuietExit: () {},
              listenAdapterInjected: true,
            ),
          ),
        ),
      );

      expect(find.text(snapshot.activeUtterance.primary), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.zhSupport), findsOneWidget);
      expect(find.text(snapshot.activeUtterance.actionCue), findsOneWidget);
      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pump();

      expect(find.text(room.reassurance), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('下一句'), findsNothing);
      expect(find.textContaining('课程'), findsNothing);
      expect(find.textContaining('任务'), findsNothing);
      expect(find.textContaining('进度'), findsNothing);
      expect(find.textContaining('分数'), findsNothing);
      expect(find.textContaining('Garden'), findsNothing);
      expect(find.textContaining('Phase 42'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'viewport and text scale matrix stays reachable without overflow and scale 2 supports vertical scrolling only',
    (tester) async {
      const viewports = [Size(427, 952), Size(390, 844)];
      const textScales = [1.0, 1.3, 2.0];
      final room = _room(
        actionCue: '把鞋放在身边以后，停一下，再慢慢说出这一句。',
        reassurance: '不用要求孩子回应，也不用催促，只要自然地说一句就够了。',
      );
      final snapshot = _longSnapshot(actionCue: room.actionCue);

      for (final viewport in viewports) {
        for (final scale in textScales) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport;

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: viewport,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: BabyTalkTheme.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: KeyedSubtree(
                  key: ValueKey('${viewport.width}x${viewport.height}-$scale'),
                  child: RitualRoomScreen(
                    state: RitualRoomReady(room: room, snapshot: snapshot),
                    capabilityMask: InteractionCapabilityMask.phase41,
                    onReactionSelected: (_) {},
                    onRetry: () {},
                    onRetryPendingEvent: () {},
                    onListen: () {},
                    onQuietExit: () {},
                    listenAdapterInjected: true,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('ritual-context-entry')), findsOneWidget);
          if (find.byKey(const Key('ritual-context-dock-expanded')).evaluate().isEmpty) {
            await tester.tap(find.byKey(const Key('ritual-context-entry')));
            await tester.pumpAndSettle();
          }
          expect(find.byKey(const Key('ritual-context-dock-expanded')), findsOneWidget);
          if (scale <= 1.3) {
            for (final key in const [
              Key('ritual-sentence-plane'),
              Key('ritual-primary-sentence'),
              Key('ritual-zh-support'),
              Key('ritual-action-cue'),
              Key('ritual-listen-control'),
              Key('ritual-context-entry'),
              Key('ritual-quiet-exit'),
            ]) {
              expect(find.byKey(key), findsOneWidget);
            }
            for (final key in const [
              Key('ritual-listen-control'),
              Key('ritual-context-entry'),
              Key('ritual-quiet-exit'),
            ]) {
              final size = tester.getSize(find.byKey(key));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
          }
          final logicalWidth = viewport.width;
          final contextSize = tester.getSize(
            find.byKey(const Key('ritual-context-dock-expanded')),
          );
          final sentenceSize = tester.getSize(
            find.byKey(const Key('ritual-sentence-plane')),
          );
          expect(contextSize.width, lessThanOrEqualTo(logicalWidth));
          expect(sentenceSize.width, lessThanOrEqualTo(logicalWidth));

          await tester.ensureVisible(find.byKey(const Key('ritual-quiet-exit')));
          expect(find.byKey(const Key('ritual-quiet-exit')), findsOneWidget);
          expect(tester.takeException(), isNull);

          if (scale == 2.0) {
            final horizontalScrollables = find.byWidgetPredicate(
              (widget) =>
                  widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
            );
            expect(horizontalScrollables, findsNothing);

            await tester.drag(
              find.byKey(const Key('ritual-context-dock-expanded')),
              const Offset(0, -180),
            );
            await tester.pumpAndSettle();
            await tester.drag(
              find.byKey(const Key('ritual-context-dock-expanded')),
              const Offset(0, 180),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
      }

      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
    },
  );

  testWidgets(
    'unknown outcome message and retry action remain semantically reachable',
    (tester) async {
      await _setPhoneViewport(tester);
      final semantics = tester.ensureSemantics();
      final room = _room();
      var retries = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: BabyTalkTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RitualRoomScreen(
            state: RitualRoomUnknownOutcome(
              room: room,
              snapshot: interactionSnapshot(),
              selectedReaction: 'not_ready',
              isRetrying: false,
            ),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () => retries += 1,
            onListen: () {},
            onQuietExit: () {},
            listenAdapterInjected: true,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('ritual-context-entry')));
      await tester.pump();

      final retryFinder = find.byKey(const Key('ritual-transient-notice-retry'));
      expect(retryFinder, findsOneWidget);
      expect(tester.getSize(retryFinder).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(retryFinder).height, greaterThanOrEqualTo(48));
      await tester.tap(retryFinder);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'production unavailable audio never exposes an enabled no-op listen control',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room(audioAvailable: false);
      var listenCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: BabyTalkTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RitualRoomScreen(
            state: RitualRoomReady(room: room, snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () => listenCalls += 1,
            onQuietExit: () {},
          ),
        ),
      );

      expect(find.text('暂时听不了，你也可以直接照着说。'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('ritual-listen-control')),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.byKey(const Key('ritual-listen-control')));
      expect(listenCalls, 0);
    },
  );

  testWidgets(
    'available audio without an injected adapter still fails closed',
    (tester) async {
      await _setPhoneViewport(tester);
      final room = _room(audioAvailable: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: BabyTalkTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RitualRoomScreen(
            state: RitualRoomReady(room: room, snapshot: interactionSnapshot()),
            capabilityMask: InteractionCapabilityMask.phase41,
            onReactionSelected: (_) {},
            onRetry: () {},
            onRetryPendingEvent: () {},
            onListen: () {},
            onQuietExit: () {},
          ),
        ),
      );

      final button = tester.widget<IconButton>(
        find.byKey(const Key('ritual-listen-control')),
      );
      expect(button.onPressed, isNull);
      expect(find.text('暂时听不了，你也可以直接照着说。'), findsOneWidget);
    },
  );
}

Future<void> _setPhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

RitualRoomContent _room({
  String actionCue = '拿起鞋时',
  String reassurance = '不用每句都说，说一句就够了。',
  bool audioAvailable = true,
}) => RitualRoomContent(
  ritualRoomId: 'shoes_on_room_v1',
  atmosphereTone: RitualAtmosphereTone.everydayCalm,
  roomName: '出门小声音',
  routineAnchor: '出门穿鞋',
  anchorPhrase: 'Shoes on.',
  chineseHelper: '穿鞋啦。',
  illustration: const RitualIllustration(
    assetPath: 'assets/illustrations/rituals/shoes_on/shoes_on_approved_v1.png',
    status: 'approved',
  ),
  actionCue: actionCue,
  audio: RitualAudioContent(
    available: audioAvailable,
    label: '听一遍',
    assetReference: 'assets/audio/current.mp3',
  ),
  reactionPrompt: '现在是什么情况？',
  reactionChoices: const [
    RitualReactionChoice(id: 'not_ready', label: '还不想穿'),
    RitualReactionChoice(id: 'self', label: '想自己来'),
    RitualReactionChoice(id: 'crying', label: '哭了'),
  ],
  pendingCopy: '正在换一种说法…',
  reassurance: reassurance,
  quietExit: '先这样就好',
  governanceEvidence: const RitualGovernanceEvidence(
    contextSeedId: 'accessibility-test-seed',
    joinabilityHypothesis: 'shared_action_available',
    governorDecision: 'allow_activation',
    productionGardenStatus: 'not_enabled',
  ),
);

ProductSnapshot _longSnapshot({required String actionCue}) {
  final base = interactionSnapshot();
  return ProductSnapshot(
    schemaVersion: base.schemaVersion,
    revision: base.revision,
    interactionId: base.interactionId,
    ritualRoomId: base.ritualRoomId,
    anchor: base.anchor,
    normalizedContext: base.normalizedContext,
    memory: base.memory,
    strategy: base.strategy,
    activeUtterance: ActiveUtterance(
      displayId: 'shoes_on_long_v1',
      primary:
          'Let us place one shoe beside you and wait together until this shared moment feels easier to enter.',
      zhSupport: '我们先把一只鞋放在你身边，一起等一等，等这个共同的时刻更容易加入。',
      actionCue: actionCue,
      audioAssetId: 'rr_shoes_001',
    ),
    metadata: base.metadata,
  );
}
