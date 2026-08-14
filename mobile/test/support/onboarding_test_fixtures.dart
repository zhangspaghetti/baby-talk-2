import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

Future<OnboardingSnapshot> saveCompletedOnboardingSnapshot(
  OnboardingRepository repository, {
  String childDisplayName = '米米',
  OnboardingAgeBucket ageBucket = OnboardingAgeBucket.zeroToSix,
  List<String> selectedSceneIds = const <String>['bath_time'],
  OnboardingSupportGoal supportGoal = OnboardingSupportGoal.firstWords,
  String starterSpaceId = 'daily_care',
  String starterActivityId = 'bath_time',
  String starterPhraseId = 'bath_time_warm_water',
  required String firstTraceEventKey,
  DateTime? completedAt,
}) {
  final stage = StageMatchCatalog.forAgeBucket(ageBucket);
  return repository.saveSnapshot(
    OnboardingSnapshot(
      schemaVersion: 2,
      childDisplayName: childDisplayName,
      ageBucket: ageBucket,
      approxMonths: stage.approxMonths,
      currentStage: stage.stageId,
      starterSpaceId: starterSpaceId,
      starterActivityId: starterActivityId,
      starterPhraseId: starterPhraseId,
      selectedSceneIds: selectedSceneIds,
      supportGoal: supportGoal,
      firstTraceEventKey: firstTraceEventKey,
      consentState: OnboardingConsentState.localOnly,
      completedAt: completedAt ?? DateTime.utc(2026, 8, 15),
    ),
  );
}
