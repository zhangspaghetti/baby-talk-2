import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';

typedef CustomSceneEntryOpener =
    Future<void> Function(BuildContext context, CustomSceneEntrySource source);

/// Today stays focused on its recommended care moment. This entry is available
/// only when that route cannot serve the current moment or the caregiver has
/// explicitly moved away from it.
class CustomSceneTodayEntryContext {
  const CustomSceneTodayEntryContext({
    required this.currentRecommendationMatches,
    required this.userSkippedRecommendation,
    required this.hasOpenableMoment,
  });

  final bool currentRecommendationMatches;
  final bool userSkippedRecommendation;
  final bool hasOpenableMoment;
}

bool shouldOfferCustomSceneFromToday(CustomSceneTodayEntryContext context) {
  return context.userSkippedRecommendation ||
      !context.currentRecommendationMatches ||
      !context.hasOpenableMoment;
}

/// Custom-scene generation needs the current account's own baby profile.
/// Secondary caregivers are read-only and must use the shared next-step entry.
bool isCustomSceneEntryAllowedForRole(HouseholdRole? role) {
  return role != HouseholdRole.caregiver;
}

class CustomSceneEntryLink extends StatelessWidget {
  const CustomSceneEntryLink({
    super.key,
    required this.source,
    required this.onOpen,
  });

  final CustomSceneEntrySource source;
  final CustomSceneEntryOpener onOpen;

  @override
  Widget build(BuildContext context) {
    final isToday = source == CustomSceneEntrySource.today;
    final prompt = isToday ? '不是正在发生的事？' : '没找到正在发生的场景？';
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$prompt描述一下此刻',
      button: true,
      enabled: true,
      onTap: () => onOpen(context, source),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: Key('custom-scene-entry-${source.wireValue}'),
          onPressed: () => onOpen(context, source),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayoutConstants.spacingXs,
              vertical: AppLayoutConstants.spacingXs,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(prompt), const Text('描述一下此刻')],
          ),
        ),
      ),
    );
  }
}
