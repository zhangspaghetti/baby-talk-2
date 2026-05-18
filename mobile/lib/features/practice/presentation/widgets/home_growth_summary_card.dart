import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Accepts either a [GardenGrowthNotifier] or [GardenGrowthNotifier].
///
/// Both expose the same API surface (snapshot, status, message, etc.),
/// so we accept `dynamic` and access properties dynamically.
class HomeGrowthSummaryCard extends StatelessWidget {
  const HomeGrowthSummaryCard({super.key, required this.notifier});

  final dynamic notifier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final effectiveNotifier = notifier;
    final snapshot =
        effectiveNotifier?.snapshot ?? GardenGrowthSnapshot.empty();
    final impact = snapshot.latestImpact;

    String title;
    String body;

    if (effectiveNotifier?.hasError ?? false) {
      title = l.homeGrowthUnavailable;
      body = effectiveNotifier?.message ?? l.homeGrowthFallback;
    } else if (impact == null ||
        effectiveNotifier == null ||
        effectiveNotifier.isEmpty) {
      title = l.homeGrowthPlaceholder;
      body = l.homeGrowthAfterPractice;
    } else {
      title = impact.headline;
      body = impact.detail;
    }

    return AppSurfaceCard(
      key: const Key('home-growth-summary'),
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
          if (effectiveNotifier?.hasError ?? false) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const Key('home-growth-summary-retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.warning,
                  side: BorderSide(color: colors.warning),
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onPressed: effectiveNotifier != null
                    ? () => effectiveNotifier.refresh()
                    : null,
                child: Text(l.homeReorganize),
              ),
            ),
          ],
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
