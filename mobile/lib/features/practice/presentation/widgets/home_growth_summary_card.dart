import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeGrowthSummaryCard extends StatelessWidget {
  const HomeGrowthSummaryCard({super.key, required this.viewModel});

  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final impact = snapshot.latestImpact;

    String title;
    String body;

    if (effectiveViewModel?.hasError ?? false) {
      title = l.homeGrowthUnavailable;
      body = effectiveViewModel?.message ?? l.homeGrowthFallback;
    } else if (impact == null ||
        effectiveViewModel == null ||
        effectiveViewModel.isEmpty) {
      title = l.homeGrowthPlaceholder;
      body = l.homeGrowthAfterPractice;
    } else {
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('home-growth-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeGrowthSummaryLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            key: const Key('home-growth-summary-title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
            const SizedBox(height: 10),
            Text(
              snapshot.projectionWarning!,
              key: const Key('home-growth-summary-warning'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
