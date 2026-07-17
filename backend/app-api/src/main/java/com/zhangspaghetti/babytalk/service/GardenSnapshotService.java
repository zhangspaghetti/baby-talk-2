package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.garden.mapper.GardenSnapshotMapper;
import com.zhangspaghetti.babytalk.garden.model.GardenSnapshotStatsProjection;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GardenSnapshotService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");

    private final GardenSnapshotMapper mapper;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    @Autowired
    public GardenSnapshotService(GardenSnapshotMapper mapper,
                                 AuthConsentSyncService authConsentSyncService) {
        this(mapper, authConsentSyncService, Clock.systemUTC());
    }

    GardenSnapshotService(GardenSnapshotMapper mapper,
                          AuthConsentSyncService authConsentSyncService,
                          Clock clock) {
        this.mapper = mapper;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GardenSnapshotResponse loadSnapshot(String sessionId) {
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);
        var today = now.atZone(SHANGHAI).toLocalDate();

        // --- aggregate stats ---
        var stats = mapper.loadStats(accountId);

        // --- current streak ---
        var currentStreakDays = computeCurrentStreak(accountId, today);

        // --- milestones ---
        var milestones = computeMilestones(accountId, stats, currentStreakDays, now);

        // --- pending event keys ---
        var pendingEventKeys = mapper.listPendingEventKeys(accountId);

        return new GardenSnapshotResponse(
                now,
                stats.knownEvents(),
                stats.coveredSpaceCount(),
                currentStreakDays,
                milestones,
                pendingEventKeys
        );
    }

    // ── streak ─────────────────────────────────────────────────────────────
    private int computeCurrentStreak(String accountId, LocalDate today) {
        var dates = mapper.listPracticeDates(accountId, today.atStartOfDay(SHANGHAI).toInstant());

        if (dates.isEmpty()) {
            return 0;
        }

        // If last practice was > 1 day ago, streak is 0
        long gapFromToday = ChronoUnit.DAYS.between(dates.get(0), today);
        if (gapFromToday > 1) {
            return 0;
        }

        // Count consecutive days from most recent going backwards
        int streak = 1;
        for (int i = 1; i < dates.size(); i++) {
            long gap = ChronoUnit.DAYS.between(dates.get(i), dates.get(i - 1));
            if (gap == 1) {
                streak++;
            } else {
                break;
            }
        }
        return streak;
    }

    // ── milestones ─────────────────────────────────────────────────────────
    private List<MilestoneEntry> computeMilestones(
            String accountId,
            GardenSnapshotStatsProjection stats,
            int currentStreakDays,
            Instant now
    ) {
        var milestones = new ArrayList<MilestoneEntry>();

        // 1. first_practice
        if (stats.knownEvents() >= 1) {
            milestones.add(new MilestoneEntry(
                    "first_practice", "初次练习", 1,
                    stats.firstEventAt(), null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "first_practice", "初次练习", 1, null,
                    "完成第一次练习即可解锁"
            ));
        }

        // 2. ten_phrases
        if (stats.uniquePhrases() >= 10) {
            var achievedAt = mapper.findTenthPhraseAchievedAt(accountId);
            milestones.add(new MilestoneEntry(
                    "ten_phrases", "十句达人", 2,
                    achievedAt, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "ten_phrases", "十句达人", 2, null,
                    "再学 " + (10 - stats.uniquePhrases()) + " 个短语即可解锁"
            ));
        }

        // 3. three_spaces
        if (stats.coveredSpaceCount() >= 3) {
            var achievedAt = mapper.findThirdSpaceAchievedAt(accountId);
            milestones.add(new MilestoneEntry(
                    "three_spaces", "三场景探索", 3,
                    achievedAt, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "three_spaces", "三场景探索", 3, null,
                    "再探索 " + (3 - stats.coveredSpaceCount()) + " 个场景即可解锁"
            ));
        }

        // 4. streak_7
        if (currentStreakDays >= 7) {
            var achievedAt = now.atZone(SHANGHAI).toLocalDate()
                    .minusDays(6)
                    .atStartOfDay(SHANGHAI).toInstant();
            milestones.add(new MilestoneEntry(
                    "streak_7", "连续七天", 4, achievedAt, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "streak_7", "连续七天", 4, null,
                    "再坚持 " + (7 - currentStreakDays) + " 天即可解锁"
            ));
        }

        // 5. fifty_events
        if (stats.knownEvents() >= 50) {
            var achievedAt = mapper.findFiftiethEventAt(accountId);
            milestones.add(new MilestoneEntry(
                    "fifty_events", "五十次里程碑", 5,
                    achievedAt, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "fifty_events", "五十次里程碑", 5, null,
                    "再练习 " + (50 - stats.knownEvents()) + " 次即可解锁"
            ));
        }

        return milestones;
    }

    // ── Records ────────────────────────────────────────────────────────────

    public record MilestoneEntry(
            String id,
            String title,
            int sortOrder,
            Instant achievedAt,
            String remainingHint
    ) {}

    public record GardenSnapshotResponse(
            Instant generatedAt,
            long knownEvents,
            int coveredSpaceCount,
            int currentStreakDays,
            List<MilestoneEntry> milestones,
            List<String> pendingEventKeys
    ) {}
}
