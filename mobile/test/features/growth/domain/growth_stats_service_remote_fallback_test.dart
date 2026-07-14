import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/data/remote/growth_summary_api_service.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';

void main() {
  group('GrowthStatsService.loadSummary', () {
    test('reads remote summary first when available', () async {
      final remote = _FakeGrowthSummaryRemoteDataSource(
        response: const GrowthSummaryPayload(
          totalEvents: 12,
          uniquePhrases: 6,
          uniqueActivities: 3,
          cooperatingCount: 4,
          practicedDays: 5,
        ),
      );
      var fallbackCalls = 0;
      final service = GrowthStatsService.remoteFirst(
        remoteDataSource: remote,
        localPeriodLoader: ({required period}) async {
          fallbackCalls += 1;
          return const PeriodStats(
            totalEvents: 1,
            uniquePhrases: 1,
            uniqueActivities: 1,
            cooperatingCount: 0,
            firstEventAt: null,
            lastEventAt: null,
            practicedDays: 1,
          );
        },
      );

      final result = await service.loadSummary(
        period: GrowthSummaryPeriod.week,
      );

      expect(result.source, GrowthSummarySource.remote);
      expect(result.stats.totalEvents, 12);
      expect(remote.lastPeriod, GrowthSummaryPeriod.week);
      expect(fallbackCalls, 0);
    });

    test('falls back to local summary when remote throws', () async {
      final remote = _FakeGrowthSummaryRemoteDataSource(
        error: const GrowthSummaryApiException.network(message: 'offline'),
      );
      var fallbackCalls = 0;
      final service = GrowthStatsService.remoteFirst(
        remoteDataSource: remote,
        localPeriodLoader: ({required period}) async {
          fallbackCalls += 1;
          expect(period, GrowthSummaryPeriod.month);
          return const PeriodStats(
            totalEvents: 7,
            uniquePhrases: 4,
            uniqueActivities: 2,
            cooperatingCount: 2,
            firstEventAt: null,
            lastEventAt: null,
            practicedDays: 3,
          );
        },
      );

      final result = await service.loadSummary(
        period: GrowthSummaryPeriod.month,
      );

      expect(result.source, GrowthSummarySource.localFallback);
      expect(result.stats.totalEvents, 7);
      expect(fallbackCalls, 1);
    });
  });
}

class _FakeGrowthSummaryRemoteDataSource
    implements GrowthSummaryRemoteDataSource {
  _FakeGrowthSummaryRemoteDataSource({this.response, this.error});

  final GrowthSummaryPayload? response;
  final Object? error;
  GrowthSummaryPeriod? lastPeriod;

  @override
  Future<GrowthSummaryPayload> fetchSummary({
    required GrowthSummaryPeriod period,
  }) async {
    lastPeriod = period;
    if (error != null) {
      throw error!;
    }
    return response ??
        const GrowthSummaryPayload(
          totalEvents: 0,
          uniquePhrases: 0,
          uniqueActivities: 0,
          cooperatingCount: 0,
          practicedDays: 0,
        );
  }
}
