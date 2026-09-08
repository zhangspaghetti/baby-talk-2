import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_repository.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_input_screen.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  testWidgets(
    'input keeps privacy copy, keyboard-safe field, and preset return',
    (tester) async {
      var fallbackCount = 0;
      await _pump(
        tester,
        const CustomSceneInputScreen(
          routeArgs: CustomSceneRouteArgs(
            entrySource: CustomSceneEntrySource.today,
          ),
        ),
        onPresetFallback: () async => fallbackCount += 1,
      );

      expect(find.byKey(const Key('custom-scene-text-field')), findsOneWidget);
      expect(
        find.byKey(const Key('custom-scene-privacy-note')),
        findsOneWidget,
      );
      final privacySemantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == '隐私说明：请不要填写姓名、电话、地址或其他私密信息。',
        ),
      );
      expect(privacySemantics.properties.label, '隐私说明：请不要填写姓名、电话、地址或其他私密信息。');
      expect(find.textContaining('课程'), findsNothing);
      expect(find.textContaining('任务'), findsNothing);
      expect(
        find.byKey(const Key('custom-scene-submit-button')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('custom-scene-submit-button')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('custom-scene-preset-fallback')));
      await tester.pump();
      expect(fallbackCount, 1);
    },
  );

  testWidgets(
    'input submits one editable draft then only renders prepared state',
    (tester) async {
      final controller = _ImmediateSubmissionController();
      await _pump(
        tester,
        CustomSceneInputScreen(
          routeArgs: const CustomSceneRouteArgs(
            entrySource: CustomSceneEntrySource.scene,
          ),
          controller: controller,
          clientRequestIdGenerator: () => 'scene_request_1',
        ),
      );

      await tester.enterText(
        find.byKey(const Key('custom-scene-text-field')),
        '洗澡时宝宝不想碰水。',
      );
      await tester.tap(find.byKey(const Key('custom-scene-submit-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(controller.handoffIds, isEmpty);
      expect(find.text('打开已准备内容'), findsOneWidget);
      expect(
        find.byKey(const Key('custom-scene-abandon-prepared')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('custom-scene-cancel-retained-draft')),
        findsNothing,
      );
      expect(controller.submitted.single.text, '洗澡时宝宝不想碰水。');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('custom-scene-text-field')))
            .controller
            ?.text,
        '洗澡时宝宝不想碰水。',
      );
    },
  );

  testWidgets('prepared content tap and semantic tap use the same opener', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = _ImmediateSubmissionController();
    var openCalls = 0;
    await _pump(
      tester,
      CustomSceneInputScreen(
        routeArgs: const CustomSceneRouteArgs(
          entrySource: CustomSceneEntrySource.scene,
        ),
        controller: controller,
        onOpenPreparedContent: () async => openCalls += 1,
        clientRequestIdGenerator: () => 'scene_request_1',
      ),
    );
    await tester.enterText(
      find.byKey(const Key('custom-scene-text-field')),
      '洗澡时宝宝不想碰水。',
    );
    final action = find.byKey(const Key('custom-scene-submit-button'));
    await tester.tap(action);
    await tester.pump();

    await tester.tap(action);
    await tester.pump();
    expect(openCalls, 1);

    final semanticsNode = tester.getSemantics(action);
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        nodeId: semanticsNode.id,
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump();

    expect(openCalls, 2);
    semantics.dispose();
  });

  testWidgets(
    'response loss after restart reconciles once with original request identity',
    (tester) async {
      final controller = _ImmediateSubmissionController()
        ..publishUnknownOutcome();
      await _pump(
        tester,
        CustomSceneInputScreen(
          routeArgs: const CustomSceneRouteArgs(
            entrySource: CustomSceneEntrySource.scene,
          ),
          controller: controller,
          clientRequestIdGenerator: () =>
              throw StateError('reconciliation must reuse durable identity'),
        ),
      );

      expect(find.text('继续确认结果'), findsOneWidget);
      expect(
        find.byKey(const Key('custom-scene-cancel-retained-draft')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('custom-scene-submit-button')));
      await tester.pump();

      expect(controller.retryCalls, 1);
      expect(controller.submitted, isEmpty);
    },
  );

  testWidgets('terminal retained draft cancellation requires confirmation', (
    tester,
  ) async {
    final controller = _ImmediateSubmissionController()
      ..publishTerminalFailure();
    await _pump(
      tester,
      CustomSceneInputScreen(
        routeArgs: const CustomSceneRouteArgs(
          entrySource: CustomSceneEntrySource.scene,
        ),
        controller: controller,
      ),
    );
    await tester.enterText(
      find.byKey(const Key('custom-scene-text-field')),
      '宝宝洗澡后不愿意穿衣服。',
    );

    final cancelAction = find.byKey(
      const Key('custom-scene-cancel-retained-draft'),
    );
    expect(cancelAction, findsOneWidget);
    await tester.tap(cancelAction);
    await tester.pumpAndSettle();
    expect(find.text('取消这次描述？'), findsOneWidget);

    await tester.tap(find.text('继续保留'));
    await tester.pumpAndSettle();
    expect(controller.cancelCalls, 0);
    expect(controller.state.canCancelRetainedDraft, isTrue);

    await tester.tap(cancelAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();

    expect(controller.cancelCalls, 1);
    expect(controller.state.phase, CustomSceneSubmissionPhase.editing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('custom-scene-text-field')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('input fits phone viewport at 1.3 text scale', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _pump(
      tester,
      const CustomSceneInputScreen(
        routeArgs: CustomSceneRouteArgs(
          entrySource: CustomSceneEntrySource.today,
        ),
      ),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('custom-scene-input-scroll')), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  CustomSceneInputScreen screen, {
  CustomScenePresetFallback? onPresetFallback,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final resolved = onPresetFallback == null
      ? screen
      : CustomSceneInputScreen(
          routeArgs: screen.routeArgs,
          controller: screen.controller,
          clientRequestIdGenerator: screen.clientRequestIdGenerator,
          onPresetFallback: onPresetFallback,
        );
  return tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MaterialApp(theme: AppTheme.build(), home: resolved),
    ),
  );
}

class _ImmediateSubmissionController extends CustomSceneSubmissionController {
  _ImmediateSubmissionController()
    : super(
        repository: _FakeRepository(),
        draftStore: CustomSceneDraftStore(
          directoryResolver: () async => Directory.systemTemp,
        ),
        draftContinuationCoordinator: CustomSceneDraftContinuationCoordinator(
          draftStore: CustomSceneDraftStore(
            directoryResolver: () async => Directory.systemTemp,
          ),
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => Directory.systemTemp,
            ),
          ),
        ),
        approvedContentRegistrar: _FakeRegistrar(),
        accountContextLoader: () async => 'account_1',
      );

  CustomSceneSubmissionState _testState =
      const CustomSceneSubmissionState.editing();
  final List<CustomSceneDraft> submitted = <CustomSceneDraft>[];
  final List<String> handoffIds = <String>[];
  int retryCalls = 0;
  int cancelCalls = 0;

  @override
  CustomSceneSubmissionState get state => _testState;

  @override
  Future<void> submit(CustomSceneDraft draft) async {
    submitted.add(draft);
    _testState = const CustomSceneSubmissionState(
      phase: CustomSceneSubmissionPhase.readyForHandoff,
      generatedContentId: 'generated_1',
    );
    notifyListeners();
  }

  void publishUnknownOutcome() {
    _testState = const CustomSceneSubmissionState(
      phase: CustomSceneSubmissionPhase.unknownOutcome,
      message: '结果尚未确认，请重试以继续。',
    );
  }

  void publishTerminalFailure() {
    _testState = const CustomSceneSubmissionState(
      phase: CustomSceneSubmissionPhase.recoverableError,
      message: '这次生成已结束，请重新生成。',
      canCancelRetainedDraft: true,
    );
  }

  @override
  Future<void> retry() async {
    retryCalls += 1;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    _testState = const CustomSceneSubmissionState.editing();
    notifyListeners();
  }

  Future<void> handoffToCareTurn() async {
    handoffIds.add(_testState.generatedContentId!);
    _testState = const CustomSceneSubmissionState.editing();
    notifyListeners();
  }
}

class _FakeRepository implements CustomSceneRepository {
  @override
  Future<GeneratedCareMoment> generate(CustomSceneDraft draft) async {
    return _moment();
  }
}

class _FakeRegistrar implements CustomSceneApprovedContentRegistrar {
  @override
  Future<void> register({
    required String accountContext,
    required GeneratedCareMoment moment,
  }) async {}
}

GeneratedCareMoment _moment() {
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
    generatedContentId: 'generated_1',
    sceneId: 'scene_1',
    spaceId: 'space_1',
    momentId: 'moment_1',
    activityId: 'activity_1',
    title: '洗澡',
    sceneTag: 'bath',
    coachTip: '慢慢来',
    source: 'generated',
    inputSource: SceneGenerationSourceType.custom,
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
