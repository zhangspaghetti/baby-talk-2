import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/l10n/app_localizations.dart';

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
    final l =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('zh'));
    final isToday = source == CustomSceneEntrySource.today;
    final prompt = isToday
        ? l.customSceneTodayEntryPrompt
        : l.customSceneSceneEntryPrompt;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$prompt${l.customSceneDescribeMoment}',
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
            children: [Text(prompt), Text(l.customSceneDescribeMoment)],
          ),
        ),
      ),
    );
  }
}
