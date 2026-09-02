package com.zhangspaghetti.babytalk.practice.scene;

import java.time.DayOfWeek;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.temporal.IsoFields;
import java.time.temporal.TemporalAdjusters;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScenePersonalizationContextService {

    private static final Logger LOGGER = LoggerFactory.getLogger(ScenePersonalizationContextService.class);
    private static final int MAX_ACTIVITY_SUMMARY_ENTRIES = 5;
    /** Stable tie-break order for equal reaction counts. */
    private static final List<String> REACTION_PRIORITY = List.of(
            "cooperating",
            "hesitant",
            "resisting",
            "no_response",
            "other"
    );

    private final ScenePersonalizationContextMapper mapper;

    public ScenePersonalizationContextService(ScenePersonalizationContextMapper mapper) {
        this.mapper = Objects.requireNonNull(mapper, "mapper");
    }

    @Transactional(readOnly = true)
    public ScenePersonalizationContext build(
            GenerationSubject subject,
            String locale,
            OffsetDateTime now
    ) {
        Objects.requireNonNull(subject, "subject");
        var utcNow = Objects.requireNonNull(now, "now").withOffsetSameInstant(ZoneOffset.UTC);
        var weekStart = utcNow.toLocalDate()
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
                .atStartOfDay()
                .atOffset(ZoneOffset.UTC);
        var contextVersion = isoWeekVersion(utcNow);

        try {
            var counts = mapper.findWeeklyReactionCounts(
                    subject.householdId(),
                    subject.ownerAccountId(),
                    weekStart,
                    utcNow
            );
            var activities = mapper.findTopWeeklyActivities(
                    subject.householdId(),
                    subject.ownerAccountId(),
                    weekStart,
                    utcNow
            );
            return context(
                    subject,
                    locale,
                    counts,
                    activities,
                    contextVersion
            );
        } catch (RuntimeException exception) {
            // Keep the core profile usable when the optional aggregate path is unavailable.
            LOGGER.warn(
                    "weekly personalization aggregation unavailable; using zero-count context; errorType={}",
                    exception.getClass().getSimpleName()
            );
            return zeroCountContext(subject, locale, contextVersion);
        }
    }

    private ScenePersonalizationContext context(
            GenerationSubject subject,
            String locale,
            ScenePersonalizationContextMapper.WeeklyReactionCounts counts,
            List<ScenePersonalizationContextMapper.ActivityCount> activities,
            String contextVersion
    ) {
        var safeCounts = counts == null
                ? new ScenePersonalizationContextMapper.WeeklyReactionCounts(0, 0, 0, 0, 0, 0)
                : counts;
        return new ScenePersonalizationContext(
                subject.babyName(),
                subject.ageRange(),
                subject.parentGoal(),
                locale,
                subject.actorRole(),
                safeCounts.recentPracticeCount(),
                dominantReaction(safeCounts),
                activitySummary(activities),
                contextVersion
        );
    }

    private ScenePersonalizationContext zeroCountContext(
            GenerationSubject subject,
            String locale,
            String contextVersion
    ) {
        return new ScenePersonalizationContext(
                subject.babyName(),
                subject.ageRange(),
                subject.parentGoal(),
                locale,
                subject.actorRole(),
                0,
                null,
                "",
                contextVersion
        );
    }

    private String dominantReaction(ScenePersonalizationContextMapper.WeeklyReactionCounts counts) {
        var maximum = REACTION_PRIORITY.stream()
                .mapToInt(reaction -> reactionCount(counts, reaction))
                .max()
                .orElse(0);
        if (maximum <= 0) {
            return null;
        }
        return REACTION_PRIORITY.stream()
                .filter(reaction -> reactionCount(counts, reaction) == maximum)
                .findFirst()
                .orElse(null);
    }

    private int reactionCount(
            ScenePersonalizationContextMapper.WeeklyReactionCounts counts,
            String reaction
    ) {
        return switch (reaction) {
            case "cooperating" -> counts.cooperatingCount();
            case "hesitant" -> counts.hesitantCount();
            case "resisting" -> counts.resistingCount();
            case "no_response" -> counts.noResponseCount();
            case "other" -> counts.otherCount();
            default -> 0;
        };
    }

    private String activitySummary(List<ScenePersonalizationContextMapper.ActivityCount> activities) {
        if (activities == null || activities.isEmpty()) {
            return "";
        }
        return activities.stream()
                .filter(Objects::nonNull)
                .filter(activity -> activity.spaceId() != null && activity.activityId() != null)
                .sorted(Comparator.comparingInt(ScenePersonalizationContextMapper.ActivityCount::eventCount)
                        .reversed()
                        .thenComparing(ScenePersonalizationContextMapper.ActivityCount::spaceId)
                        .thenComparing(ScenePersonalizationContextMapper.ActivityCount::activityId))
                .limit(MAX_ACTIVITY_SUMMARY_ENTRIES)
                .map(activity -> activity.spaceId() + "/" + activity.activityId() + "=" + activity.eventCount())
                .reduce((left, right) -> left + "," + right)
                .orElse("");
    }

    private String isoWeekVersion(OffsetDateTime utcNow) {
        var date = utcNow.toLocalDate();
        return "%d-W%02d".formatted(
                date.get(IsoFields.WEEK_BASED_YEAR),
                date.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR)
        );
    }
}
