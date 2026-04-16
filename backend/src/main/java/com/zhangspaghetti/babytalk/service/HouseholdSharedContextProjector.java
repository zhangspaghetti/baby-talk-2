package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
class HouseholdSharedContextProjector {

    private static final DateTimeFormatter SUMMARY_TIME_FORMATTER =
            DateTimeFormatter.ofPattern("M月d日 HH:mm").withZone(ZoneOffset.UTC);
    private static final String ACTOR_SOURCE_SYNC_EVENT = "sync_event";

    private final CaregiverInviteRepository repository;

    HouseholdSharedContextProjector(CaregiverInviteRepository repository) {
        this.repository = repository;
    }

    CaregiverInviteRepository.SharedContextRow refreshForHousehold(String householdId, Instant now) {
        var projection = repository.findHouseholdProjection(householdId)
                .orElseThrow(() -> new ContractException(
                        HttpStatus.SERVICE_UNAVAILABLE,
                        "shared_context_unavailable",
                        "共享上下文尚未准备好，请主照护者先完成一次同步后再重试。",
                        Map.of("retryable", true, "reason", "no_household_activity")
                ));
        var latestSpaceId = normalizeRouteArg(projection.latestSpaceId(), "spaceId");
        var latestActivityId = normalizeRouteArg(projection.latestActivityId(), "activityId");
        var nextStepSpaceId = normalizeRouteArg(projection.nextStepSpaceId(), "spaceId");
        var nextStepActivityId = normalizeRouteArg(projection.nextStepActivityId(), "activityId");
        var latestTime = SUMMARY_TIME_FORMATTER.format(projection.latestInteractionAt());
        var latestActorLabel = roleLabel(projection.latestActorRole());
        var nextStepReason = latestSpaceId.equals(nextStepSpaceId) && latestActivityId.equals(nextStepActivityId)
                ? "latest_activity"
                : "top_activity";

        return new CaregiverInviteRepository.SharedContextRow(
                householdId,
                truncate("共享宝宝档案：家庭已同步 %d 条互动，当前由 %d 位照护者共看护。".formatted(
                        projection.totalEvents(),
                        projection.activeMemberCount()
                ), 240),
                truncate("最近 continuity：%s在 %s 完成了 %s/%s，反馈为 %s。".formatted(
                        latestActorLabel,
                        latestTime,
                        latestSpaceId,
                        latestActivityId,
                        projection.latestActorResult()
                ), 240),
                truncate("花园上下文：下一步可继续 %s/%s；该 activity 已累计 %d 条互动。".formatted(
                        nextStepSpaceId,
                        nextStepActivityId,
                        projection.nextStepEventCount()
                ), 240),
                latestSpaceId,
                latestActivityId,
                projection.latestInteractionAt(),
                now,
                projection.latestActorRole(),
                ACTOR_SOURCE_SYNC_EVENT,
                projection.latestActorResult(),
                nextStepSpaceId,
                nextStepActivityId,
                nextStepReason
        );
    }

    java.util.Optional<CaregiverInviteRepository.SharedContextRow> refreshForAccount(String accountId, Instant now) {
        return repository.findActiveMembershipByAccount(accountId)
                .map(member -> refreshForHousehold(member.householdId(), now));
    }

    private String normalizeRouteArg(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "shared_context_unavailable",
                    "共享上下文缺少安全路由参数，已拒绝输出 deep link。",
                    Map.of("retryable", true, "reason", fieldName + "_missing", "field", fieldName)
            );
        }
        var normalized = value.trim();
        if (normalized.length() > 64) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "shared_context_unavailable",
                    "共享上下文缺少安全路由参数，已拒绝输出 deep link。",
                    Map.of("retryable", true, "reason", fieldName + "_too_long", "field", fieldName)
            );
        }
        return normalized;
    }

    private String roleLabel(String role) {
        return switch (role) {
            case "primary_caregiver" -> "主照护者";
            case "caregiver" -> "协作照护者";
            default -> role == null ? "家庭成员" : "家庭成员";
        };
    }

    private String truncate(String value, int maxLength) {
        if (value == null || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
