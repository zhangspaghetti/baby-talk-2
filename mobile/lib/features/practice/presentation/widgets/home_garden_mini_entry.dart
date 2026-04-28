import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeGardenMiniEntry extends StatelessWidget {
  const HomeGardenMiniEntry({super.key, required this.viewModel});

  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final primarySpace = snapshot.primarySpace;
    final primaryActivity = snapshot.primaryActivity;
    final status = effectiveViewModel?.status ?? GardenGrowthLoadStatus.empty;

    String title;
    String body;
    Color backgroundColor = colors.successSoft;
    Color foregroundColor = colors.success;

    switch (status) {
      case GardenGrowthLoadStatus.loading:
      case GardenGrowthLoadStatus.idle:
        title = l.homeGardenOrganizing;
        body = l.homeGardenProjecting;
        backgroundColor = colors.bgSunken;
        foregroundColor = colors.textSecondary;
        break;
      case GardenGrowthLoadStatus.error:
        title = l.homeGardenNotReady;
        body = effectiveViewModel?.message ?? l.homeGardenKeepStable;
        backgroundColor = colors.warningSoft;
        foregroundColor = colors.warning;
        break;
      case GardenGrowthLoadStatus.empty:
        title = l.homeGardenStartFirst;
        body = l.homeGardenNoPractice;
        backgroundColor = colors.bgAccentSoft;
        foregroundColor = colors.accentDark;
        break;
      case GardenGrowthLoadStatus.ready:
        title = primarySpace == null
            ? l.homeGardenReady
            : l.homeGardenSpaceStage(
                primarySpace.title,
                primarySpace.stage.label,
              );
        body = primaryActivity == null
            ? l.homeGardenChanges
            : l.homeGardenActivityDetail(
                primaryActivity.title,
                primaryActivity.stage.label,
                primaryActivity.careNote,
              );
        break;
    }

    return Semantics(
      label: '成长花园: $title',
      child: Container(
        key: const Key('home-garden-mini-entry'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.homeGrowthGarden,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              key: const Key('home-garden-mini-entry-title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: foregroundColor),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foregroundColor),
            ),
            if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
              const SizedBox(height: 10),
              Text(
                snapshot.projectionWarning!,
                key: const Key('home-garden-mini-entry-warning'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foregroundColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
