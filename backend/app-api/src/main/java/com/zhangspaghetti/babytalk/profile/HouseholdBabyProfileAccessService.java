package com.zhangspaghetti.babytalk.profile;

import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.profile.model.BabyProfileRow;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import com.zhangspaghetti.babytalk.service.CaregiverInviteRepository;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Resolves the server-owned profile used by scene generation.
 *
 * <p>Access state is resolved before any profile lookup. This ordering keeps
 * an inactive household link from silently becoming a standalone profile
 * lookup, and keeps a caregiver's own historical profile out of the path.</p>
 */
@Service
public class HouseholdBabyProfileAccessService {

    private static final String ACCESS_STATE_NEVER_MEMBER = "never_member";
    private static final String ACCESS_STATE_ACTIVE_MEMBERSHIP = "active_membership";
    private static final String ACCESS_STATE_INACTIVE_MEMBERSHIP = "inactive_membership";
    private static final String ACCESS_STATE_INACTIVE_HOUSEHOLD = "inactive_household";
    private static final String ROLE_PRIMARY_CAREGIVER = "primary_caregiver";
    private static final String ROLE_CAREGIVER = "caregiver";
    private static final String PROFILE_PURPOSE = "生成自定义练习场景";
    private static final int MAX_IDENTIFIER_LENGTH = 64;

    private final AuthConsentSyncService authConsentSyncService;
    private final CaregiverInviteRepository caregiverInviteRepository;
    private final BabyProfileMapper babyProfileMapper;

    public HouseholdBabyProfileAccessService(
            AuthConsentSyncService authConsentSyncService,
            CaregiverInviteRepository caregiverInviteRepository,
            BabyProfileMapper babyProfileMapper
    ) {
        this.authConsentSyncService = authConsentSyncService;
        this.caregiverInviteRepository = caregiverInviteRepository;
        this.babyProfileMapper = babyProfileMapper;
    }

    @Transactional(readOnly = true)
    public GenerationSubject resolve(String sessionId) {
        var session = authConsentSyncService.requireAcceptedConsumerSession(sessionId, PROFILE_PURPOSE);
        if (session == null) {
            throw invalidSession();
        }
        var actorAccountId = normalizeIdentifier(session.accountId());
        if (actorAccountId == null) {
            throw invalidSession();
        }

        var accessStateResult = caregiverInviteRepository.findGenerationAccessStateByAccount(actorAccountId);
        if (accessStateResult == null || accessStateResult.isEmpty()) {
            throw householdAccessRequired();
        }
        var accessState = accessStateResult.get();
        if (!actorAccountId.equals(normalizeIdentifier(accessState.accountId()))) {
            throw householdAccessRequired();
        }
        var state = normalize(accessState.accessState());
        if (ACCESS_STATE_INACTIVE_MEMBERSHIP.equals(state)
                || ACCESS_STATE_INACTIVE_HOUSEHOLD.equals(state)) {
            throw householdAccessRequired();
        }
        if (ACCESS_STATE_NEVER_MEMBER.equals(state)) {
            return resolveOwnProfile(actorAccountId, null, ROLE_PRIMARY_CAREGIVER);
        }
        if (!ACCESS_STATE_ACTIVE_MEMBERSHIP.equals(state)) {
            throw householdAccessRequired();
        }

        var role = normalizeRole(accessState.role());
        var householdId = normalizeIdentifier(accessState.householdId());
        if (householdId == null) {
            throw householdAccessRequired();
        }
        if (ROLE_CAREGIVER.equals(role)) {
            // Deliberately do not call findByAccountId for a caregiver.
            var sharedProfile = Optional.ofNullable(
                            babyProfileMapper.findSharedByHouseholdMemberAccountId(actorAccountId))
                    .orElseThrow(this::sharedProfileUnavailable);
            return toSubject(
                    actorAccountId,
                    sharedProfile,
                    householdId,
                    ROLE_CAREGIVER,
                    this::sharedProfileUnavailable
            );
        }
        if (ROLE_PRIMARY_CAREGIVER.equals(role)) {
            return resolveOwnProfile(actorAccountId, householdId, ROLE_PRIMARY_CAREGIVER);
        }
        throw householdAccessRequired();
    }

    private GenerationSubject resolveOwnProfile(
            String actorAccountId,
            String householdId,
            String actorRole
    ) {
        var profile = Optional.ofNullable(babyProfileMapper.findByAccountId(actorAccountId))
                .orElseThrow(this::profileUnavailable);
        return toSubject(actorAccountId, profile, householdId, actorRole, this::profileUnavailable);
    }

    private GenerationSubject toSubject(
            String actorAccountId,
            BabyProfileRow profile,
            String householdId,
            String actorRole,
            ErrorFactory unavailable
    ) {
        var ownerAccountId = normalizeIdentifier(profile.accountId());
        var profileId = normalizeIdentifier(profile.profileId());
        var babyName = normalize(profile.babyName());
        var ageRange = normalize(profile.ageRange());
        var parentGoal = normalize(profile.parentGoal());
        if (ownerAccountId == null
                || (ROLE_PRIMARY_CAREGIVER.equals(actorRole) && !ownerAccountId.equals(actorAccountId))
                || (ROLE_CAREGIVER.equals(actorRole) && ownerAccountId.equals(actorAccountId))
                || profileId == null
                || profile.version() < 1
                || !isValidBabyName(babyName)
                || ageRange == null
                || !BabyProfileOptions.AGE_RANGES.contains(ageRange)
                || parentGoal == null
                || !BabyProfileOptions.PARENT_GOALS.contains(parentGoal)
                || (householdId != null && normalizeIdentifier(householdId) == null)) {
            throw unavailable.create();
        }
        return new GenerationSubject(
                actorAccountId,
                ownerAccountId,
                profileId,
                profile.version(),
                babyName,
                ageRange,
                parentGoal,
                normalizeIdentifier(householdId),
                actorRole
        );
    }

    private boolean isValidBabyName(String babyName) {
        return babyName == null || babyName.codePointCount(0, babyName.length()) <= 40;
    }

    private String normalize(String value) {
        if (value == null) {
            return null;
        }
        var normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String normalizeIdentifier(String value) {
        var normalized = normalize(value);
        if (normalized == null || normalized.length() > MAX_IDENTIFIER_LENGTH) {
            return null;
        }
        return normalized;
    }

    private String normalizeRole(String value) {
        return normalize(value);
    }

    private ContractException invalidSession() {
        return new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。");
    }

    private ContractException householdAccessRequired() {
        return new ContractException(
                HttpStatus.FORBIDDEN,
                "household_access_required",
                "当前账号没有可用的家庭档案访问权限。"
        );
    }

    private ContractException sharedProfileUnavailable() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "shared_profile_unavailable",
                "共享宝宝档案暂不可用，请让主照护者先完成档案后再试。"
        );
    }

    private ContractException profileUnavailable() {
        return new ContractException(
                HttpStatus.NOT_FOUND,
                "profile_unavailable",
                "宝宝档案暂不可用，请先完善宝宝档案后再试。"
        );
    }

    @FunctionalInterface
    private interface ErrorFactory {

        ContractException create();
    }
}
