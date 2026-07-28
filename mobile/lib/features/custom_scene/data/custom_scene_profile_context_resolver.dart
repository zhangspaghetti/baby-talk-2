import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/settings/data/repositories/settings_repository.dart';

class CustomSceneProfileContextUnavailableException implements Exception {
  const CustomSceneProfileContextUnavailableException();
}

abstract interface class CustomSceneProfileContextSource {
  Future<CustomSceneProfileContext> resolve();
}

/// Resolves generation context from completed onboarding and Settings profile
/// records. UI never supplies age, goal, locale, or backend profile IDs.
class CustomSceneProfileContextResolver
    implements CustomSceneProfileContextSource {
  CustomSceneProfileContextResolver({
    required OnboardingRepository onboardingRepository,
    required SettingsRepository settingsRepository,
  }) : _onboardingRepository = onboardingRepository,
       _settingsRepository = settingsRepository;

  final OnboardingRepository _onboardingRepository;
  final SettingsRepository _settingsRepository;

  @override
  Future<CustomSceneProfileContext> resolve() async {
    try {
      final onboarding = await _onboardingRepository.readCompletedSnapshot();
      if (onboarding == null) {
        throw const CustomSceneProfileContextUnavailableException();
      }
      final settings = await _settingsRepository.readSettings();
      final ageMonths = settings.childAgeMonths ?? onboarding.approxMonths;
      return CustomSceneProfileContext(
        ageRange: _ageRangeForMonths(ageMonths),
        parentGoal: _parentGoalFor(onboarding),
        locale: _localeFor(settings.preferredLanguage),
      );
    } on CustomSceneProfileContextUnavailableException {
      rethrow;
    } on Object {
      throw const CustomSceneProfileContextUnavailableException();
    }
  }

  String _ageRangeForMonths(int? value) {
    if (value == null || value < 0 || value > 36) {
      throw const CustomSceneProfileContextUnavailableException();
    }
    if (value <= 3) return 'm0_3';
    if (value <= 6) return 'm4_6';
    if (value <= 11) return 'm7_11';
    if (value <= 17) return 'm12_17';
    if (value <= 23) return 'm18_23';
    if (value <= 30) return 'm24_30';
    return 'm31_36';
  }

  String _parentGoalFor(OnboardingSnapshot snapshot) {
    return switch (snapshot.supportGoal) {
      OnboardingSupportGoal.firstWords => 'natural_opening',
      OnboardingSupportGoal.moreNatural => 'confident_pronunciation',
      OnboardingSupportGoal.dailyHabit => 'calmer_care',
    };
  }

  String _localeFor(String value) {
    switch (value.trim()) {
      case 'zh':
      case 'zh-CN':
        return 'zh-CN';
      default:
        throw const CustomSceneProfileContextUnavailableException();
    }
  }
}
