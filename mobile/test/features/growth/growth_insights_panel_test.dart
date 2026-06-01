import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/growth/presentation/widgets/growth_insights_panel.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  GrowthInsightsViewState contentView(
    GrowthPeriod period, {
    required int currentStreak,
    GrowthNextStepSuggestion? suggestion,
    GrowthRecentActivity? recentActivity,
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
      scenes: const [
        SceneDistribution(
          sceneTag: '喂饭',
          spaceId: 'space_1',
          eventCount: 8,
          activityCount: 3,
          percentage: 0.66,
        ),
        SceneDistribution(
          sceneTag: '洗澡',
          spaceId: 'space_2',
          eventCount: 4,
          activityCount: 2,
          percentage: 0.34,
        ),
      ],
      windowStart: DateTime(2026, 5, 18),
      windowEnd: DateTime(2026, 5, 20, 12),
      suggestion: suggestion,
      recentActivity: recentActivity,
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

  Future<void> pump(
    WidgetTester tester,
    _StubNotifier stub, {
    List<GrowthMilestoneSnapshot> milestones = const [],
    void Function(PracticeRouteArgs args)? onStartSuggestedPractice,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          growthInsightsNotifierProvider.overrideWith((ref) => stub),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowthInsightsPanel(
                milestones: milestones,
                onStartSuggestedPractice: onStartSuggestedPractice,
              ),
            ),
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

  testWidgets('renders scene distribution rows for content view', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-scenes')), findsOneWidget);
    expect(find.text('场景分布'), findsOneWidget);
    expect(find.text('喂饭'), findsOneWidget);
    expect(find.text('洗澡'), findsOneWidget);
  });

  testWidgets('hides scene distribution for empty view', (tester) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: emptyView(GrowthPeriod.week),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-scenes')), findsNothing);
  });

  testWidgets('renders milestones achieved within the active window', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(
      tester,
      stub,
      milestones: [
        GrowthMilestoneSnapshot(
          id: 'm-in',
          title: '开始照料"喂饭"',
          body: '本周达成',
          sortOrder: 0,
          achievedAt: DateTime(2026, 5, 19),
        ),
        const GrowthMilestoneSnapshot(
          id: 'm-locked',
          title: '尚未达成',
          body: '锁定',
          sortOrder: 1,
          achievedAt: null,
        ),
        GrowthMilestoneSnapshot(
          id: 'm-out',
          title: '窗口之外',
          body: '上个月',
          sortOrder: 2,
          achievedAt: DateTime(2026, 4, 1),
        ),
      ],
    );

    expect(find.byKey(const Key('growth-insights-milestones')), findsOneWidget);
    expect(find.text('开始照料"喂饭"'), findsOneWidget);
    expect(find.text('尚未达成'), findsNothing);
    expect(find.text('窗口之外'), findsNothing);
  });

  testWidgets('hides milestones when none fall in the active window', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(
      tester,
      stub,
      milestones: [
        GrowthMilestoneSnapshot(
          id: 'm-out',
          title: '窗口之外',
          body: '上个月',
          sortOrder: 0,
          achievedAt: DateTime(2026, 4, 1),
        ),
      ],
    );

    expect(find.byKey(const Key('growth-insights-milestones')), findsNothing);
  });

  testWidgets('tapping a bar shows the selected detail caption', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(tester, stub);

    expect(
      find.byKey(const Key('growth-insights-chart-caption')),
      findsNothing,
    );

    // Tap inside the chart to select a bar.
    await tester.tap(find.byKey(const Key('growth-insights-chart')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('growth-insights-chart-caption')),
      findsOneWidget,
    );
    // Caption text follows "<label> · <count> 次练习".
    expect(find.textContaining('次练习'), findsOneWidget);
  });

  testWidgets('empty hint copy is period specific', (tester) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: emptyView(GrowthPeriod.week),
      GrowthPeriod.month: emptyView(GrowthPeriod.month),
      GrowthPeriod.year: emptyView(GrowthPeriod.year),
    });
    await pump(tester, stub);

    expect(find.textContaining('本周还没有练习记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('growth-insights-period-month')));
    await tester.pumpAndSettle();
    expect(find.textContaining('本月还没有练习记录'), findsOneWidget);

    await tester.tap(find.byKey(const Key('growth-insights-period-year')));
    await tester.pumpAndSettle();
    expect(find.textContaining('今年还没有练习记录'), findsOneWidget);
  });

  testWidgets('renders next-step suggestion and forwards practice args on tap', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(
        GrowthPeriod.week,
        currentStreak: 11,
        suggestion: const GrowthNextStepSuggestion(
          sceneLabel: '洗澡',
          phraseEnglish: 'Splash splash',
          spaceId: 'space_2',
          activityId: 'activity_bath',
        ),
      ),
    });
    PracticeRouteArgs? captured;
    await pump(
      tester,
      stub,
      onStartSuggestedPractice: (args) => captured = args,
    );

    expect(find.byKey(const Key('growth-insights-next-step')), findsOneWidget);
    expect(find.textContaining('你还没试过洗澡场景'), findsOneWidget);
    expect(find.textContaining('Splash splash'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('growth-insights-next-step-try')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('growth-insights-next-step-try')));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.spaceId, 'space_2');
    expect(captured!.activityId, 'activity_bath');
  });

  testWidgets('hides next-step suggestion when none is provided', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-next-step')), findsNothing);
  });

  testWidgets('renders recent activity with a gentle increase trend', (
    tester,
  ) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(
        GrowthPeriod.week,
        currentStreak: 11,
        recentActivity: const GrowthRecentActivity(
          thisWeekCount: 5,
          lastWeekCount: 2,
        ),
      ),
    });
    await pump(tester, stub);

    final recent = find.byKey(const Key('growth-insights-recent'));
    expect(recent, findsOneWidget);
    expect(
      find.byKey(const Key('growth-insights-recent-trend')),
      findsOneWidget,
    );
    expect(find.text('本周比上周多说了 3 句。'), findsOneWidget);
  });

  testWidgets('hides recent activity when none is provided', (tester) async {
    final stub = _StubNotifier({
      GrowthPeriod.week: contentView(GrowthPeriod.week, currentStreak: 11),
    });
    await pump(tester, stub);

    expect(find.byKey(const Key('growth-insights-recent')), findsNothing);
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
    : super(apiService: _FakeApiService());

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

class _FakeApiService implements GrowthInsightsApiService {
  @override
  String get appVersion => '1.0.0';

  @override
  Future<GrowthInsightsPayload> fetchInsights(String period) async =>
      throw UnimplementedError('not expected in panel tests');

  @override
  void close() {}
}
