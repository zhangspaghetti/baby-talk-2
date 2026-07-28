import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

RegistryLocalSensitiveDataClearanceOrchestrator
createLocalSensitiveDataClearanceOrchestrator({
  required AccountRepository accountRepository,
  required OnboardingRepository onboardingRepository,
  required HouseholdRepository householdRepository,
  required PracticeRepository practiceRepository,
  required MentorRepository mentorRepository,
  required AuthContinuationCoordinator authContinuationCoordinator,
  required CustomSceneDraftContinuationCoordinator
  customSceneDraftContinuationCoordinator,
  required GeneratedPracticeContentRegistry generatedPracticeContentRegistry,
}) {
  return RegistryLocalSensitiveDataClearanceOrchestrator(
    steps: createLocalSensitiveDataClearanceSteps(
      accountRepository: accountRepository,
      onboardingRepository: onboardingRepository,
      householdRepository: householdRepository,
      practiceRepository: practiceRepository,
      mentorRepository: mentorRepository,
      authContinuationCoordinator: authContinuationCoordinator,
      customSceneDraftContinuationCoordinator:
          customSceneDraftContinuationCoordinator,
      generatedPracticeContentRegistry: generatedPracticeContentRegistry,
    ),
  );
}

List<LocalSensitiveDataClearanceStep> createLocalSensitiveDataClearanceSteps({
  required AccountRepository accountRepository,
  required OnboardingRepository onboardingRepository,
  required HouseholdRepository householdRepository,
  required PracticeRepository practiceRepository,
  required MentorRepository mentorRepository,
  required AuthContinuationCoordinator authContinuationCoordinator,
  required CustomSceneDraftContinuationCoordinator
  customSceneDraftContinuationCoordinator,
  required GeneratedPracticeContentRegistry generatedPracticeContentRegistry,
}) {
  return <LocalSensitiveDataClearanceStep>[
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.accountLocalSnapshot,
      primitiveName: 'AccountRepository.deleteLocalSnapshotForLifecycle',
      clear: accountRepository.deleteLocalSnapshotForLifecycle,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.authContinuation,
      primitiveName: 'AuthContinuationCoordinator.clear',
      clear: authContinuationCoordinator.clear,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.customSceneDraft,
      primitiveName:
          'CustomSceneDraftContinuationCoordinator.clearForLifecycle',
      clear: customSceneDraftContinuationCoordinator.clearForLifecycle,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.generatedCareMoments,
      primitiveName: 'GeneratedPracticeContentRegistry.clearForLifecycle',
      clear: generatedPracticeContentRegistry.clearForLifecycle,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.onboardingSnapshot,
      primitiveName: 'OnboardingRepository.clearAllLocalState',
      clear: onboardingRepository.clearAllLocalState,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.householdSnapshot,
      primitiveName: 'HouseholdRepository.deleteLocalSnapshotForLifecycle',
      clear: householdRepository.deleteLocalSnapshotForLifecycle,
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.practiceInteractionEvents,
      primitiveName: 'PracticeRepository.close(deleteFromDisk: true)',
      clear: () => practiceRepository.close(deleteFromDisk: true),
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.mentorFactEvents,
      primitiveName: 'MentorRepository.close(deleteFromDisk: true)',
      clear: () => mentorRepository.close(deleteFromDisk: true),
    ),
    LocalSensitiveDataClearanceStep(
      target: LocalSensitiveDataTarget.installationId,
      primitiveName: 'PracticeRepository.deleteInstallationIdForLifecycle',
      clear: practiceRepository.deleteInstallationIdForLifecycle,
    ),
  ];
}
