import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';

/// Time window the growth insights view aggregates over.
enum GrowthPeriod { week, month, year }

extension GrowthPeriodInfo on GrowthPeriod {
  /// Short Chinese label shown on the period selector.
  String get label {
    switch (this) {
      case GrowthPeriod.week:
        return '本周';
      case GrowthPeriod.month:
        return '本月';
      case GrowthPeriod.year:
        return '今年';
    }
  }
}

/// A single bar in the trend chart: a labelled time bucket and its event count.
class GrowthBarBucket {
  const GrowthBarBucket({required this.label, required this.count});

  final String label;
  final int count;
}

/// Immutable view-state for the growth insights panel for one selected period.
class GrowthInsightsViewState {
  const GrowthInsightsViewState({
    required this.isLoading,
    required this.hasError,
    required this.period,
    required this.streak,
    required this.stats,
    required this.bars,
  });

  const GrowthInsightsViewState.loading(this.period)
    : isLoading = true,
      hasError = false,
      streak = const StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalDaysPracticed: 0,
        lastPracticedAt: null,
      ),
      stats = const PeriodStats(
        totalEvents: 0,
        uniquePhrases: 0,
        uniqueActivities: 0,
        imitationCount: 0,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 0,
      ),
      bars = const <GrowthBarBucket>[];

  final bool isLoading;
  final bool hasError;
  final GrowthPeriod period;
  final StreakResult streak;
  final PeriodStats stats;
  final List<GrowthBarBucket> bars;

  /// Loaded, no events recorded for the selected period.
  bool get isEmpty => !isLoading && !hasError && stats.totalEvents == 0;

  /// Highest bar value, used to scale the chart (min 1 to avoid /0).
  int get maxBarCount {
    var maxValue = 0;
    for (final bar in bars) {
      if (bar.count > maxValue) maxValue = bar.count;
    }
    return maxValue < 1 ? 1 : maxValue;
  }
}
