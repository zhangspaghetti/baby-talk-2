import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';
import 'package:mobile/features/care_entry/presentation/onboarding_conversation_controller.dart';
import 'package:mobile/features/care_entry/presentation/widgets/care_entry_entry_surface.dart';

void main() {
  testWidgets(
    'renders four entries, tile only selects, and primary CTA reveals exact first utterance',
    (tester) async {
      final repository = _MemoryConversationRepository();
      final scheduler = _ManualScheduler();
      final ids = <String>[
        'event.phrase_said.widget',
        'completion.widget',
        'completion.widget.retry',
      ];
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: repository,
        scheduler: scheduler,
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => ids.removeAt(0),
      );
      final audioPlayer = _RecordingAudioPlayer();
      var todayExits = 0;
      var gardenExits = 0;
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      await tester.pumpWidget(
        MaterialApp(
          home: CareEntryEntrySurface(
            controller: controller,
            audioControllerFactory: () => audioPlayer,
            onToday: () => todayExits += 1,
            onGarden: () => gardenExits += 1,
          ),
        ),
      );

      expect(find.byKey(const Key('care-entry-grid')), findsOneWidget);
      expect(find.byType(CareEntryTile), findsNWidgets(4));
      expect(find.text("I'm right here."), findsNothing);
      expect(
        find.byKey(const Key('care-entry-primary-action')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-tile-care.post_cry_soothing')),
      );
      await tester.pump();

      expect(controller.state.phase, OnboardingConversationPhase.selection);
      expect(controller.state.selectedEntryId?.value, 'care.post_cry_soothing');
      expect(find.text("I'm right here."), findsNothing);

      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pump();

      expect(
        controller.state.phase,
        OnboardingConversationPhase.firstUtterance,
      );
      expect(find.text("I'm right here."), findsOneWidget);
      expect(find.text('我就在这里。'), findsOneWidget);
      expect(find.text('aɪm raɪt hɪr'), findsOneWidget);
      expect(
        find.byKey(const Key('care-entry-first-utterance-audio')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await tester.pump();

      expect(audioPlayer.playedAssets, <String>['audio/phrases/test_3.mp3']);

      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await tester.pumpAndSettle();

      expect(repository.phraseSaidWrites, 1);
      expect(
        controller.state.phase,
        OnboardingConversationPhase.reactionPrompt,
      );
      expect(
        find.byKey(const Key('care-entry-reaction-prompt')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('care-entry-reaction-other-text')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('care-entry-reaction-other')));
      await tester.pump();

      expect(controller.state.selectedReaction, isNull);
      expect(
        find.byKey(const Key('care-entry-reaction-other-text')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('care-entry-reaction-hesitant')));
      await tester.pump();
      expect(find.byKey(const Key('care-entry-next-support')), findsNothing);

      scheduler.elapse(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-entry-next-support')), findsOneWidget);
      expect(find.text('Support hesitant.'), findsOneWidget);
      expect(find.text('继续说下去'), findsOneWidget);
      expect(find.text('今天先到这里'), findsOneWidget);

      repository.failNextCompletion = true;
      await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('care-entry-garden-trace')), findsNothing);
      expect(todayExits, 0);
      expect(gardenExits, 0);

      await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
      await tester.pumpAndSettle();

      expect(repository.completionWrites, 1);
      expect(find.byKey(const Key('care-entry-garden-trace')), findsOneWidget);
      expect(find.text('第一句已经留在你的小花园里。'), findsOneWidget);
      expect(find.textContaining('宝宝'), findsOneWidget);
      expect(find.text('开始今天的小时间'), findsOneWidget);
      expect(find.text('看看花园'), findsOneWidget);
      await tester.tap(find.byKey(const Key('care-entry-open-today-action')));
      await tester.tap(find.byKey(const Key('care-entry-open-garden-action')));
      expect(todayExits, 1);
      expect(gardenExits, 1);
    },
  );

  testWidgets(
    'remote playback failure degrades gently and keeps said enabled',
    (tester) async {
      final controller = OnboardingConversationController(
        registry: _MemoryRegistry(_resolution()),
        repository: _MemoryConversationRepository(),
        scheduler: _ManualScheduler(),
        clock: () => DateTime.utc(2026, 8, 14, 12),
        idGenerator: () => 'request.remote.audio',
        conversationGateway: _ImmediateConversationGateway(),
        installationIdLoader: () async => 'install-test-1234',
      );
      final audioPlayer = _FailingAudioPlayer();
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await controller.startSelected();

      await tester.pumpWidget(
        MaterialApp(
          home: CareEntryEntrySurface(
            controller: controller,
            audioControllerFactory: () => audioPlayer,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      await tester.pumpAndSettle();

      expect(find.text('今天先看着读也可以。'), findsOneWidget);
      final said = tester.widget<FilledButton>(
        find.byKey(const Key('care-entry-said-action')),
      );
      expect(said.onPressed, isNotNull);
      expect(audioPlayer.conversationId, 'onbc_remote_1');
      expect(audioPlayer.utteranceId, 'utterance-remote-1');
    },
  );

  testWidgets('leaving first utterance stops in-flight audio', (tester) async {
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: _MemoryConversationRepository(),
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 12),
      idGenerator: () => 'event.audio.stop',
    );
    final audioPlayer = _BlockingAudioPlayer();
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    await controller.startSelected();

    await tester.pumpWidget(
      MaterialApp(
        home: CareEntryEntrySurface(
          controller: controller,
          audioControllerFactory: () => audioPlayer,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('care-entry-first-utterance-audio')));
    await tester.pump();
    expect(audioPlayer.playStarted, isTrue);

    await tester.tap(find.byKey(const Key('care-entry-said-action')));
    await tester.pump();

    expect(audioPlayer.stopCalls, 1);
    expect(controller.state.phase, OnboardingConversationPhase.reactionPrompt);
    audioPlayer.completePlay();
    await tester.pump();
  });

  testWidgets('defer navigates only after the checkpoint is durable', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 20),
      idGenerator: () => 'defer-widget-1',
      visibleSlots: 4,
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    var exits = 0;
    repository.failNextDefer = true;

    await tester.pumpWidget(
      MaterialApp(
        home: CareEntryEntrySurface(
          controller: controller,
          onDefer: () async {
            if (await controller.defer()) exits += 1;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await tester.pumpAndSettle();
    expect(exits, 0);
    expect(repository.snapshot?.status, OnboardingConversationStatus.active);

    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(repository.snapshot?.status, OnboardingConversationStatus.deferred);
  });

  testWidgets(
    'selection stays 2x2 within 430 px and remains complete at large text',
    (tester) async {
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));

      await _pumpSurface(
        tester,
        controller: controller,
        size: const Size(800, 844),
      );
      expect(
        tester.getSize(find.byKey(const Key('care-entry-content'))).width,
        430,
      );

      await _pumpSurface(
        tester,
        controller: controller,
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(2),
      );

      final grid = tester.widget<GridView>(
        find.byKey(const Key('care-entry-grid')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(
        tester
            .widgetList<CareEntryTile>(find.byType(CareEntryTile))
            .where((tile) => tile.selected),
        hasLength(1),
      );
      expect(find.text("I'm right here."), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();
      expect(find.text('直接从现在开始'), findsOneWidget);
      expect(
        tester
            .widgetList<Text>(find.text('现在就能说'))
            .every((text) => text.overflow == null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TalkBack exposes unambiguous selection and speaker-only actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = _controller();
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await _pumpSurface(tester, controller: controller);

      final recommended = tester.getSemantics(
        find.byKey(const Key('care-entry-tile-care.bedtime_soothing')),
      );
      expect(recommended.label, contains('哄睡中'));
      expect(recommended.label, contains('现在推荐'));
      expect(recommended.label, contains('现在就能说'));
      expect(recommended.label, isNot(contains('已选择')));
      expect(recommended.label, isNot(contains('未选择')));
      expect(recommended.flagsCollection.isSelected, Tristate.isTrue);
      _expectNoBannedVisibleCopy(tester);

      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pumpAndSettle();

      final audio = tester.getSemantics(
        find.byKey(const Key('care-entry-first-utterance-audio')),
      );
      expect(audio.label, '播放标准发音');
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.graphic_eq), findsNothing);
      expect(find.byKey(const Key('care-entry-reaction-prompt')), findsNothing);
      _expectNoBannedVisibleCopy(tester);

      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await tester.pumpAndSettle();

      expect(find.text('宝宝现在怎么了？'), findsOneWidget);
      for (final label in const <String>['配合', '犹豫', '不想', '没反应', '其他']) {
        expect(find.text(label), findsOneWidget);
      }
      _expectNoBannedVisibleCopy(tester);
      semantics.dispose();
    },
  );

  testWidgets('reaction and next-support exits require gentle confirmation', (
    tester,
  ) async {
    final repository = _MemoryConversationRepository();
    final controller = OnboardingConversationController(
      registry: _MemoryRegistry(_resolution()),
      repository: repository,
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 20),
      idGenerator: () => 'event.pop.route',
    );
    addTearDown(controller.dispose);
    await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
    await controller.startSelected();
    await controller.markPhraseSaid();
    var exits = 0;
    await _pumpSurface(
      tester,
      controller: controller,
      onDefer: () async {
        if (await controller.defer()) exits += 1;
      },
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-entry-exit-sheet')), findsOneWidget);
    expect(find.text('好的，宝宝的小花园等你。'), findsOneWidget);
    expect(exits, 0);

    await tester.tap(find.byKey(const Key('care-entry-exit-stay-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('care-entry-exit-sheet')), findsNothing);

    await _pumpSurface(
      tester,
      controller: controller,
      size: const Size(320, 480),
      textScaler: const TextScaler.linear(2),
      onDefer: () async {
        if (await controller.defer()) exits += 1;
      },
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const Key('care-entry-exit-confirm-action')),
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('care-entry-exit-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.byKey(const Key('care-entry-exit-confirm-action')));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(repository.snapshot?.status, OnboardingConversationStatus.deferred);
  });

  testWidgets('loading and failure can exit without a durable checkpoint', (
    tester,
  ) async {
    var exits = 0;
    final loading = _controller();
    addTearDown(loading.dispose);
    await _pumpSurface(
      tester,
      controller: loading,
      onDefer: () async {},
      onExit: () => exits += 1,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 1);

    final failure = OnboardingConversationController(
      registry: const _FailingRegistry(),
      repository: _MemoryConversationRepository(),
      scheduler: _ManualScheduler(),
      clock: () => DateTime.utc(2026, 8, 14, 20),
      idGenerator: () => 'unused.failure',
    );
    addTearDown(failure.dispose);
    await failure.initialize(localTime: DateTime(2026, 8, 14, 20));
    await _pumpSurface(
      tester,
      controller: failure,
      onDefer: () async {},
      onExit: () => exits += 1,
    );

    expect(failure.state.phase, OnboardingConversationPhase.failure);
    await tester.tap(find.byKey(const Key('care-entry-defer-action')));
    await tester.pump();
    expect(exits, 2);
  });

  testWidgets(
    'Xiaohe uses initials, next support explains continuity, and keyboard scrolls',
    (tester) async {
      final scheduler = _ManualScheduler();
      final controller = _controller(scheduler: scheduler);
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await _pumpSurface(
        tester,
        controller: controller,
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(1.6),
      );

      expect(
        find.byKey(const Key('care-entry-xiaohe-initials')),
        findsOneWidget,
      );
      expect(find.text('小禾'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('care-entry-reaction-other')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('care-entry-reaction-other')));
      await tester.pump();
      await _pumpSurface(
        tester,
        controller: controller,
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(1.6),
        viewInsets: const EdgeInsets.only(bottom: 260),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('care-entry-reaction-other-text')),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('care-entry-reaction-other-text')),
        '轻轻看着我',
      );
      await tester.ensureVisible(
        find.byKey(const Key('care-entry-reaction-other-submit')),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('care-entry-reaction-other-submit')),
      );
      scheduler.elapse(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-entry-next-support')), findsOneWidget);
      expect(find.text('这句是接着刚才来的。'), findsOneWidget);
      expect(
        find.byKey(const Key('care-entry-xiaohe-initials')),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'visual evidence covers selection, first, reaction, next, exit, and Trace',
    (tester) async {
      await _loadGoldenFonts();
      final scheduler = _ManualScheduler();
      final controller = _controller(scheduler: scheduler);
      addTearDown(controller.dispose);
      await controller.initialize(localTime: DateTime(2026, 8, 14, 20));
      await _pumpSurface(
        tester,
        controller: controller,
        onDefer: () async {},
        onToday: () {},
        onGarden: () {},
      );

      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/care_entry_selection.png'),
      );

      await tester.tap(find.byKey(const Key('care-entry-primary-action')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/care_entry_first_ready.png'),
      );

      await tester.tap(find.byKey(const Key('care-entry-said-action')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/care_entry_reaction_prompt.png'),
      );

      await tester.tap(find.byKey(const Key('care-entry-reaction-hesitant')));
      scheduler.elapse(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/care_entry_next_ready.png'),
      );

      await tester.tap(find.byKey(const Key('care-entry-defer-action')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('care-entry-exit-sheet')),
        matchesGoldenFile('goldens/care_entry_exit_sheet.png'),
      );
      await tester.tap(find.byKey(const Key('care-entry-exit-stay-action')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('goldens/care_entry_trace_confirmation.png'),
      );
    },
  );
}

OnboardingConversationController _controller({
  OnboardingDelayScheduler? scheduler,
}) => OnboardingConversationController(
  registry: _MemoryRegistry(_resolution()),
  repository: _MemoryConversationRepository(),
  scheduler: scheduler ?? _ManualScheduler(),
  clock: () => DateTime.utc(2026, 8, 14, 20),
  idGenerator: () => 'event.widget.${DateTime.now().microsecondsSinceEpoch}',
);

Future<void> _pumpSurface(
  WidgetTester tester, {
  required OnboardingConversationController controller,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Future<void> Function()? onDefer,
  VoidCallback? onExit,
  VoidCallback? onToday,
  VoidCallback? onGarden,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: _themeWithGoldenCjkFallback(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: textScaler, viewInsets: viewInsets),
        child: child!,
      ),
      home: CareEntryEntrySurface(
        controller: controller,
        onDefer: onDefer,
        onExit: onExit,
        onToday: onToday,
        onGarden: onGarden,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _loadGoldenFonts() async {
  final fontAssets = <String, List<String>>{
    'DM Sans': <String>[
      'assets/fonts/dm_sans/DMSans-Regular.ttf',
      'assets/fonts/dm_sans/DMSans-Bold.ttf',
    ],
    'Fraunces': <String>[
      'assets/fonts/fraunces/Fraunces-Regular.ttf',
      'assets/fonts/fraunces/Fraunces-Bold.ttf',
    ],
    'JetBrains Mono': <String>[
      'assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf',
      'assets/fonts/jetbrains_mono/JetBrainsMono-Medium.ttf',
    ],
    'MaterialIcons': <String>['fonts/MaterialIcons-Regular.otf'],
    'Golden CJK': <String>['test/fonts/NotoSansSC-CareEntrySubset.otf'],
  };
  for (final entry in fontAssets.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(
        asset.startsWith('test/')
            ? Future<ByteData>.value(
                ByteData.sublistView(File(asset).readAsBytesSync()),
              )
            : rootBundle.load(asset),
      );
    }
    await loader.load();
  }
}

ThemeData _themeWithGoldenCjkFallback() {
  const fallback = <String>['Golden CJK'];
  final base = AppTheme.build();
  TextStyle? withFallback(TextStyle? style) =>
      style?.copyWith(fontFamilyFallback: fallback);

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamilyFallback: fallback),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          withFallback(base.filledButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: base.elevatedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          withFallback(base.elevatedButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          withFallback(base.outlinedButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        textStyle: WidgetStatePropertyAll(
          withFallback(base.textButtonTheme.style?.textStyle?.resolve({})),
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: withFallback(base.chipTheme.labelStyle),
      secondaryLabelStyle: withFallback(base.chipTheme.secondaryLabelStyle),
    ),
  );
}

void _expectNoBannedVisibleCopy(WidgetTester tester) {
  final visible = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .join('\n');
  for (final term in const <String>[
    '练习',
    '课程',
    '任务',
    '评分',
    '得分',
    '分数',
    '完成压力',
    'Skip',
    '2 of 3',
    'AI',
    'LLM',
    'prompt',
  ]) {
    expect(visible.toLowerCase(), isNot(contains(term.toLowerCase())));
  }
}

final class _MemoryConversationRepository
    implements OnboardingConversationRepository {
  OnboardingConversationSnapshot? snapshot;
  int phraseSaidWrites = 0;
  int completionWrites = 0;
  bool failNextDefer = false;
  bool failNextCompletion = false;

  @override
  Future<OnboardingConversationSnapshot?> read() async => snapshot;

  @override
  Future<OnboardingConversationSnapshot> save(
    OnboardingConversationSnapshot checkpoint,
  ) async => snapshot = checkpoint;

  @override
  Future<OnboardingConversationSnapshot?> saveNextSupport(
    OnboardingConversationSnapshot checkpoint, {
    required bool Function() commitIfCurrent,
  }) async => commitIfCurrent() ? snapshot = checkpoint : snapshot;

  @override
  Future<OnboardingConversationSnapshot> defer({
    required OnboardingConversationSnapshot checkpoint,
    required DateTime deferredAt,
  }) async {
    if (failNextDefer) {
      failNextDefer = false;
      throw StateError('simulated defer failure');
    }
    return snapshot = checkpoint.copyWith(
      status: OnboardingConversationStatus.deferred,
      deferredAt: deferredAt,
    );
  }

  @override
  Future<OnboardingConversationSnapshot> recordPhraseSaid({
    required OnboardingConversationSnapshot checkpoint,
    required String eventId,
    required DateTime occurredAt,
  }) async {
    phraseSaidWrites += 1;
    return snapshot = checkpoint.copyWith(
      phase: OnboardingCheckpointPhase.reactionPrompt,
      phraseSaidEventId: eventId,
      phraseSaidAt: occurredAt,
    );
  }

  @override
  Future<OnboardingConversationSnapshot> complete({
    required OnboardingConversationSnapshot checkpoint,
    required String completionId,
    required DateTime completedAt,
  }) async {
    if (failNextCompletion) {
      failNextCompletion = false;
      throw StateError('simulated completion failure');
    }
    final existing = snapshot;
    if (existing?.completionId != null) return existing!;
    completionWrites += 1;
    return snapshot = checkpoint.copyWith(
      status: OnboardingConversationStatus.completed,
      phase: OnboardingCheckpointPhase.completed,
      completionId: completionId,
      gardenTraceId: checkpoint.phraseSaidEventId,
      completedAt: completedAt,
      deferredAt: null,
    );
  }
}

final class _ManualScheduler implements OnboardingDelayScheduler {
  final List<_ManualScheduledTask> _tasks = <_ManualScheduledTask>[];

  @override
  OnboardingScheduledTask schedule(Duration delay, void Function() action) {
    final task = _ManualScheduledTask(delay, action);
    _tasks.add(task);
    return task;
  }

  void elapse(Duration duration) {
    for (final task in List<_ManualScheduledTask>.from(_tasks)) {
      task.elapse(duration);
    }
    _tasks.removeWhere((task) => !task.isActive);
  }
}

final class _ManualScheduledTask implements OnboardingScheduledTask {
  _ManualScheduledTask(this._remaining, this._action);

  Duration _remaining;
  final void Function() _action;
  bool isActive = true;

  void elapse(Duration duration) {
    if (!isActive) return;
    _remaining -= duration;
    if (_remaining <= Duration.zero) {
      isActive = false;
      _action();
    }
  }

  @override
  void cancel() => isActive = false;
}

final class _RecordingAudioPlayer implements CareEntryAudioPlayer {
  final List<String> playedAssets = <String>[];

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) async {
    playedAssets.add(utterance.localAudioAsset!.replaceFirst('assets/', ''));
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _FailingAudioPlayer implements CareEntryAudioPlayer {
  String? conversationId;
  String? utteranceId;

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) async {
    this.conversationId = conversationId;
    utteranceId = utterance.utteranceId;
    throw StateError('simulated audio failure');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

final class _BlockingAudioPlayer implements CareEntryAudioPlayer {
  final Completer<void> _play = Completer<void>();
  bool playStarted = false;
  int stopCalls = 0;

  void completePlay() => _play.complete();

  @override
  Future<void> play({
    required OnboardingUtterance utterance,
    required String? conversationId,
  }) {
    playStarted = true;
    return _play.future;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    throw StateError('simulated stop failure');
  }

  @override
  Future<void> dispose() async {}
}

final class _ImmediateConversationGateway
    implements GuestOnboardingConversationGateway {
  @override
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  ) async => GuestOnboardingConversation(
    conversationId: 'onbc_remote_1',
    expiresAt: DateTime.utc(2026, 8, 15),
    utterance: const OnboardingUtterance(
      utteranceId: 'utterance-remote-1',
      english: 'Remote hello.',
      chinese: '远端首句。',
      pronunciation: 'remote',
      source: OnboardingUtteranceSource.remoteGenerated,
      remoteAudioAvailable: true,
    ),
  );

  @override
  Future<GuestOnboardingConversation> nextSupport(
    NextGuestOnboardingTurn request,
  ) async => throw StateError('not used');
}

final class _MemoryRegistry implements CareEntryRegistry {
  const _MemoryRegistry(this.resolution);

  final CareEntryResolution resolution;

  @override
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  }) async => resolution;
}

final class _FailingRegistry implements CareEntryRegistry {
  const _FailingRegistry();

  @override
  Future<CareEntryResolution> resolve({
    required CareEntryPlacementId placement,
    required int visibleSlots,
    required DateTime localTime,
  }) async => throw StateError('simulated registry failure');
}

CareEntryResolution _resolution() {
  final entries = <ResolvedCareEntry>[
    _entry(
      id: 'care.bedtime_soothing',
      title: '哄睡中',
      english: 'Time to sleep.',
      chinese: '该睡觉啦。',
      pronunciation: 'taɪm tə sliːp',
      visualToken: 'route.moon',
      order: 1,
      recommended: true,
    ),
    _entry(
      id: 'care.feeding_now',
      title: '正在喂奶',
      english: 'Open wide.',
      chinese: '张大嘴巴。',
      pronunciation: 'ˈoʊ.pən waɪd',
      visualToken: 'route.bottle',
      order: 2,
      recommended: false,
    ),
    _entry(
      id: 'care.post_cry_soothing',
      title: '宝宝刚哭过',
      english: "I'm right here.",
      chinese: '我就在这里。',
      pronunciation: 'aɪm raɪt hɪr',
      visualToken: 'route.soothing',
      order: 3,
      recommended: false,
    ),
    _entry(
      id: 'care.diaper_change',
      title: '换尿布',
      english: 'Clean bottom.',
      chinese: '擦干净屁屁。',
      pronunciation: 'kliːn ˈbɑː.t̬əm',
      visualToken: 'route.diaper',
      order: 4,
      recommended: false,
    ),
  ];
  return CareEntryResolution(
    schemaVersion: 1,
    revision: 'test.1',
    placement: const CareEntryPlacementId('onboarding.primary'),
    entries: entries,
    recommendedEntryId: entries.first.id,
  );
}

ResolvedCareEntry _entry({
  required String id,
  required String title,
  required String english,
  required String chinese,
  required String pronunciation,
  required String visualToken,
  required int order,
  required bool recommended,
}) {
  return ResolvedCareEntry(
    id: CareEntryId(id),
    title: title,
    subtitle: '现在就能说',
    visualToken: visualToken,
    order: order,
    isRecommended: recommended,
    seed: CareMomentSeed(
      generationRef: GenerationSceneRef(
        id: GenerationSceneId('generation.$order'),
        namespace: 'babytalk.care',
        key: 'scene_$order',
        version: 1,
        facets: const <String, String>{'parentTonePreference': 'short_gentle'},
      ),
      fallback: CatalogFallbackRef(
        id: CatalogFallbackId('fallback.$order'),
        spaceId: 'space',
        activityId: 'activity',
        phraseId: 'phrase_$order',
      ),
      firstUtterance: CareFirstUtterance(
        english: english,
        chinese: chinese,
        pronunciation: pronunciation,
        audioAsset: 'assets/audio/phrases/test_$order.mp3',
        audioReview: AudioReview.reviewed,
      ),
      nextSupports: CareLocalNextSupportSet(
        whenAbsent: CareNextSupportUtterance(
          id: CareSupportId('support.$order.absent'),
          english: 'Support absent.',
          chinese: '没有选择也可以。',
        ),
        byReaction: <CareReaction, CareNextSupportUtterance>{
          for (final reaction in CareReaction.values)
            reaction: CareNextSupportUtterance(
              id: CareSupportId('support.$order.${reaction.wireValue}'),
              english: 'Support ${reaction.wireValue}.',
              chinese: '接住这一刻。',
            ),
        },
      ),
    ),
  );
}
