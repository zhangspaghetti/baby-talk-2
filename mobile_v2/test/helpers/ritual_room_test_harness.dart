import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/app/localization/generated/app_localizations.dart';
import 'package:mobile_v2/app/theme/baby_talk_theme.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_atmosphere_tone.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/presentation/capability/interaction_capability_mask.dart';
import 'package:mobile_v2/features/ritual_room/presentation/screens/ritual_room_screen.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

Widget ritualRoomHarness({
  required Size viewport,
  required RitualRoomUiState state,
  double textScale = 1,
  bool disableAnimations = true,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: viewport,
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      theme: BabyTalkTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RitualRoomScreen(
        state: state,
        capabilityMask: InteractionCapabilityMask.phase41,
        onReactionSelected: (_) {},
        onRetry: () {},
        onRetryPendingEvent: () {},
        onQuietExit: () {},
        onListen: () {},
        listenAdapterInjected: _audioAvailable(state),
      ),
    ),
  );
}

Future<void> pumpRitualRoomGolden(
  WidgetTester tester, {
  required Size viewport,
  required RitualRoomUiState state,
  double textScale = 1,
  bool expandDock = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewport;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ritualRoomHarness(
      viewport: viewport,
      state: state,
      textScale: textScale,
    ),
  );
  await tester.pumpAndSettle();

  if (expandDock) {
    await tester.tap(find.byKey(const Key('ritual-context-entry')));
    await tester.pumpAndSettle();
  }
}

bool _audioAvailable(RitualRoomUiState state) => switch (state) {
  RitualRoomReady(:final room) => room.audio.available,
  RitualRoomSubmitting(:final room) => room.audio.available,
  RitualRoomUnknownOutcome(:final room) => room.audio.available,
  RitualRoomRecoverableFailure(:final room) => room.audio.available,
  _ => true,
};

RitualRoomContent ritualRoomTestRoom({bool audioAvailable = true}) {
  return RitualRoomContent(
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
    audio: RitualAudioContent(
      available: audioAvailable,
      label: audioAvailable ? '听一遍' : '暂时听不了',
      assetReference: audioAvailable ? 'assets/audio/current.mp3' : null,
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
    reassurance: '不用每句都说，说一句就够了。',
    quietExit: '先这样就好',
    governanceEvidence: const RitualGovernanceEvidence(
      contextSeedId: 'safe-test-seed',
      joinabilityHypothesis: 'shared_action_available',
      governorDecision: 'explore',
      productionGardenStatus: 'unchanged',
    ),
  );
}

ProductSnapshot ritualRoomTestSnapshot({
  int revision = 0,
  String displayId = 'shoes_on_ready_v1',
  String primary = 'Let’s put your shoes on.',
  String zhSupport = '我们来穿鞋吧。',
  String actionCue = '拿起鞋时',
}) {
  return ProductSnapshot(
    schemaVersion: ProductSnapshot.currentSchemaVersion,
    revision: revision,
    interactionId: 'interaction-shoes_on_room_v1',
    ritualRoomId: 'shoes_on_room_v1',
    anchor: 'Shoes on.',
    normalizedContext: NormalizedInput(
      semanticSignals: const ['shared_action'],
      intentEstimate: 'continue',
      momentHypothesis: 'shared action is available',
      contextFrame: const {
        'interactionType': 'caregiver_shared_action_support',
      },
      confidence: 0.8,
      eventSummary: '出门穿鞋',
    ),
    memory: ContextMemory(
      summary: 'shared action remains available',
      eventLog: const [],
      signalWeights: const {'shared_action': 0.8},
      interactionTrend: 'stable',
      contextStability: 0.8,
      narrative: 'the caregiver can continue with one simple line',
    ),
    strategy: StrategyDecision(
      primary: PressurePolicy.lowPressure,
      modifiers: const [StrategyModifier.continueInteraction],
      confidence: 0.8,
      rationale: 'one simple line fits the current moment',
      pressureLevel: 20,
      recommendedTone: 'soft',
      interactionHint: 'offer one line without requiring a response',
    ),
    activeUtterance: ActiveUtterance(
      displayId: displayId,
      primary: primary,
      zhSupport: zhSupport,
      actionCue: actionCue,
      audioAssetId: 'rr-shoes-$revision',
    ),
    metadata: ProductSnapshotMetadata(
      lastEventId: revision == 0 ? null : 'event-$revision',
      updatedAt: DateTime.utc(2026, 6, 23, 10, revision),
    ),
  );
}

RitualRoomUiState ritualRoomReadyState({bool audioAvailable = true}) => RitualRoomReady(
  room: ritualRoomTestRoom(audioAvailable: audioAvailable),
  snapshot: ritualRoomTestSnapshot(),
);

RitualRoomUiState ritualRoomSubmittingState() => RitualRoomSubmitting(
  room: ritualRoomTestRoom(),
  snapshot: ritualRoomTestSnapshot(
    revision: 1,
    displayId: 'shoes_on_submitting_v1',
  ),
  selectedReaction: 'not_ready',
);

RitualRoomUiState ritualRoomRevisedState() => RitualRoomReady(
  room: ritualRoomTestRoom(),
  snapshot: ritualRoomTestSnapshot(
    revision: 2,
    displayId: 'shoes_on_revised_v2',
    primary: 'You can hold your shoe.',
    zhSupport: '你可以拿着自己的鞋。',
    actionCue: '宝宝停下来时',
  ),
);

RitualRoomUiState ritualRoomRecoverableFailureState() => RitualRoomRecoverableFailure(
  room: ritualRoomTestRoom(),
  snapshot: ritualRoomTestSnapshot(
    revision: 3,
    displayId: 'shoes_on_failure_v1',
  ),
  problem: const RitualRoomProblem(AdvanceErrorCode.pipelineFailed),
);

RitualRoomUiState ritualRoomUnknownOutcomeState({bool retrying = false}) =>
    RitualRoomUnknownOutcome(
      room: ritualRoomTestRoom(),
      snapshot: ritualRoomTestSnapshot(
        revision: 4,
        displayId: 'shoes_on_unknown_v1',
      ),
      selectedReaction: 'not_ready',
      isRetrying: retrying,
    );

RitualRoomUiState ritualRoomAudioUnavailableState() => RitualRoomReady(
  room: ritualRoomTestRoom(audioAvailable: false),
  snapshot: ritualRoomTestSnapshot(
    revision: 5,
    displayId: 'shoes_on_audio_unavailable_v1',
  ),
);
