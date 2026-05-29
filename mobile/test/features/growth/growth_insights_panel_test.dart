import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/growth/presentation/widgets/growth_insights_panel.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

void main() {
  GrowthInsightsViewState contentView(
    GrowthPeriod period, {
    required int currentStreak,
  }) {
    return GrowthInsightsViewState(
      isLoading: false,
      hasError: false,
      period: period,
      streak: StreakResult(
        currentStreak: currentStreak,
        longestStreak: 99,
        totalDaysPracticed: 88,
        lastPracticedAt: DateTime(2026, 5, 20),
      ),
      stats: const PeriodStats(
        totalEvents: 12,
        uniquePhrases: 4,
        uniqueActivities: 5,
        imitationCount: 6,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 7,
      ),
      bars: const [
        GrowthBarBucket(label: '一', count: 2),
        GrowthBarBucket(label: '二', count: 3),
        GrowthBarBucket(label: '三', count: 1),
      ],
    );
  }

  GrowthInsightsViewState emptyView(GrowthPeriod period) {
    return GrowthInsightsViewState(
      isLoading: false,
      hasError: false,
      period: period,
      streak: const StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalDaysPracticed: 0,
        lastPracticedAt: null,
      ),
      stats: const PeriodStats(
        totalEvents: 0,
        uniquePhrases: 0,
        uniqueActivities: 0,
        imitationCount: 0,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 0,
      ),
      bars: const [],
    );
  }

  Future<void> pump(WidgetTester tester, _StubNotifier stub) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthInsightsNotifierProvider.overrideWith((ref) => stub),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const Scaffold(
            body: SingleChildScrollView(child: GrowthInsightsPanel()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders streak card and trend chart for content view', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-panel')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-streak')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-chart')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-empty')), findsNothing);
    expect(find.byKey(const Key('growth-insights-loading')), findsNothing);
  });

  testWidgets('renders empty state without chart when there is no data', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: emptyView(GrowthPeriod.week),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-panel')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-empty')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-chart')), findsNothing);
    expect(find.byKey(const Key('growth-insights-streak')), findsNothing);
  });

  testWidgets('renders loading shimmer for loading view', (tester) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: GrowthInsightsViewState.loading(GrowthPeriod.week),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-loading')), findsOneWidget);
    expect(find.byKey(const Key('growth-insights-chart')), findsNothing);
  });

  testWidgets('tapping a period selector requests that period', (tester) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
      GrowthPeriod.month: contentView(GrowthPeriod.month, currentStreak: 22),
      GrowthPeriod.year: contentView(GrowthPeriod.year, currentStreak: 33),
    });
    await pump(tester, stub);

    expect(stub.requested.contains(GrowthPeriod.month), isFalse);

    await tester.tap(find.byKey(const Key('growth-insights-period-month')));
    await tester.pumpAndSettle();

    expect(stub.requested.contains(GrowthPeriod.month), isTrue);

    await tester.tap(find.byKey(const Key('growth-insights-period-year')));
    await tester.pumpAndSettle();

    expect(stub.requested.contains(GrowthPeriod.year), isTrue);
  });
}

class _StubNotifier extends GrowthInsightsNotifier {
  _StubNotifier(this._views)
    : super(repositoryFuture: Completer<PracticeRepository>().future);

  final Map<GrowthPeriod, GrowthInsightsViewState> _views;
  final List<GrowthPeriod> requested = [];

  @override
  Future<void> initialize() async {}

  @override
  GrowthInsightsViewState viewFor(GrowthPeriod period) {
    requested.add(period);
    return _views[period] ?? emptyFor(period);
  }

  GrowthInsightsViewState emptyFor(GrowthPeriod period) =>
      GrowthInsightsViewState.loading(period);
}
