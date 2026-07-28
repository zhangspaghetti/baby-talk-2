import 'dart:io';

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
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
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

  testWidgets('input submits one editable draft and hands off once', (
    tester,
  ) async {
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

    expect(controller.handoffIds, <String>['generated_1']);
    expect(controller.submitted.single.text, '洗澡时宝宝不想碰水。');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('custom-scene-text-field')))
          .controller
          ?.text,
      '洗澡时宝宝不想碰水。',
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
        handoffSink: _FakeHandoffSink(),
        accountContextLoader: () async => 'account_1',
      );

  CustomSceneSubmissionState _testState =
      const CustomSceneSubmissionState.editing();
  final List<CustomSceneDraft> submitted = <CustomSceneDraft>[];
  final List<String> handoffIds = <String>[];

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

  @override
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

class _FakeHandoffSink implements CustomSceneCareTurnHandoffSink {
  final List<String> ids = <String>[];

  @override
  Future<void> handoff(CustomSceneCareTurnHandoff handoff) async {
    ids.add(handoff.generatedContentId);
  }
}

GeneratedCareMoment _moment() {
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
    generatedContentId: 'generated_1',
    sceneId: 'scene_1',
    spaceId: 'space_1',
    momentId: 'moment_1',
    activityId: 'activity_1',
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
