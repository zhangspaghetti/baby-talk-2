package com.zhangspaghetti.babytalk.admin.practice;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;
import org.springframework.stereotype.Component;

/**
 * Typed persistence facade for versioned preset-scene metadata.
 *
 * <p>Callers that combine multiple mutations (notably publish and rollback)
 * own the surrounding transaction. Each mutation still uses one mapper
 * statement per state transition so it can participate in that transaction.
 */
@Component
public final class AdminPresetSceneRepository {

    private static final String DRAFT_CHANGED_FIELDS =
            "[\"title_zh\",\"summary_zh\",\"scene_tag_en\",\"coach_tip_zh\",\"sort_order\",\"generation_brief\",\"enabled\"]";
    private static final String PUBLISHED_CHANGED_FIELDS =
            "[\"state\",\"version\",\"published_by_admin_id\",\"published_at\",\"current_published_version_id\"]";

    private final AdminPresetSceneMapper mapper;

    public AdminPresetSceneRepository(AdminPresetSceneMapper mapper) {
        this.mapper = mapper;
    }

    public List<SceneSummaryRow> findScenes() {
        return mapper.findScenes();
    }

    public Optional<SceneDetailRow> findScene(String presetSceneId) {
        return Optional.ofNullable(mapper.findScene(presetSceneId));
    }

    public Optional<DraftRow> findDraftForUpdate(String presetSceneId) {
        return Optional.ofNullable(mapper.findDraftForUpdate(presetSceneId));
    }

    public Optional<DraftRow> findDraft(String presetSceneId) {
        return Optional.ofNullable(mapper.findDraft(presetSceneId));
    }

    public DraftRow createDraft(
            String presetSceneId,
            DraftWrite write,
            String adminId,
            OffsetDateTime now
    ) {
        if (mapper.lockActivityForUpdate(presetSceneId) == null) {
            return null;
        }
        var draft = mapper.createDraft(presetSceneId, write, adminId, now);
        if (draft != null) {
            insertAudit(
                    draft.activityId(),
                    "create_draft",
                    null,
                    draft.versionId(),
                    adminId,
                    draftAuditSummary("create_draft", draft.lockVersion()),
                    now);
        }
        return draft;
    }

    public DraftRow updateDraft(
            String presetSceneId,
            int expectedLockVersion,
            DraftWrite write,
            String adminId,
            OffsetDateTime now
    ) {
        if (mapper.lockActivityForUpdate(presetSceneId) == null) {
            return null;
        }
        var draft = mapper.updateDraft(presetSceneId, expectedLockVersion, write, adminId, now);
        if (draft != null) {
            insertAudit(
                    draft.activityId(),
                    "update_draft",
                    draft.versionId(),
                    draft.versionId(),
                    adminId,
                    draftAuditSummary("update_draft", draft.lockVersion()),
                    now);
        }
        return draft;
    }

    public PublishedRow publish(
            String presetSceneId,
            int expectedLockVersion,
            String adminId,
            OffsetDateTime now
    ) {
        return publish(presetSceneId, expectedLockVersion, adminId, now, draft -> {
        });
    }

    public PublishedRow publish(
            String presetSceneId,
            int expectedLockVersion,
            String adminId,
            OffsetDateTime now,
            Consumer<DraftRow> draftValidator
    ) {
        var activityId = mapper.lockActivityForUpdate(presetSceneId);
        if (activityId == null) {
            return null;
        }

        var draft = mapper.findDraftForUpdate(presetSceneId);
        if (draft == null || draft.lockVersion() != expectedLockVersion) {
            return null;
        }
        draftValidator.accept(draft);

        var nextVersion = mapper.findNextPublishedVersion(activityId);
        if (nextVersion == null) {
            throw new IllegalStateException("published preset scene version sequence is unavailable");
        }

        var published = mapper.publishDraft(
                presetSceneId,
                expectedLockVersion,
                nextVersion,
                adminId,
                now);
        if (published == null) {
            return null;
        }

        if (mapper.updateCurrentPublishedVersion(activityId, published.versionId()) != 1) {
            throw new IllegalStateException("published preset scene pointer update affected no activity");
        }
        insertAudit(
                activityId,
                published.enabled() ? "publish" : "disable",
                published.versionId(),
                published.versionId(),
                adminId,
                publishedAuditSummary(
                        published.enabled() ? "publish" : "disable",
                        published.lockVersion(),
                        published.version()),
                now);
        return published;
    }

    /**
     * Copies a historical published version into a new published version.
     *
     * <p>The activity row is locked before the optional draft row so publish
     * and rollback use the same lock order. Rollback owns one audit action;
     * it must not call {@link #publish(String, int, String, OffsetDateTime)}.
     */
    public RollbackResult rollback(
            String presetSceneId,
            int sourceVersion,
            String adminId,
            OffsetDateTime now
    ) {
        var activityId = mapper.lockActivityForUpdate(presetSceneId);
        if (activityId == null) {
            return RollbackResult.Failure.ACTIVITY_NOT_FOUND;
        }

        if (mapper.findDraftForUpdate(presetSceneId) != null) {
            return RollbackResult.Failure.DRAFT_EXISTS;
        }

        var sourceVersionId = mapper.findPublishedVersionId(presetSceneId, sourceVersion);
        if (sourceVersionId == null) {
            return RollbackResult.Failure.SOURCE_VERSION_NOT_FOUND;
        }

        var nextVersion = mapper.findNextPublishedVersion(activityId);
        if (nextVersion == null) {
            throw new IllegalStateException("published preset scene version sequence is unavailable");
        }

        var published = mapper.rollbackPublished(
                presetSceneId,
                sourceVersion,
                nextVersion,
                adminId,
                now);
        if (published == null) {
            return RollbackResult.Failure.SOURCE_VERSION_NOT_FOUND;
        }

        if (mapper.updateCurrentPublishedVersion(activityId, published.versionId()) != 1) {
            throw new IllegalStateException("published preset scene pointer update affected no activity");
        }
        insertAudit(
                activityId,
                "rollback",
                sourceVersionId,
                published.versionId(),
                adminId,
                rollbackPublishedAuditSummary(sourceVersion, published.lockVersion(), published.version()),
                now);
        return new RollbackResult.Completed(published);
    }

    public DraftRow copyPublishedToDraft(
            String presetSceneId,
            int sourceVersion,
            String adminId,
            OffsetDateTime now
    ) {
        var activityId = mapper.lockActivityForUpdate(presetSceneId);
        if (activityId == null) {
            return null;
        }
        var sourceVersionId = mapper.findPublishedVersionId(presetSceneId, sourceVersion);
        if (sourceVersionId == null) {
            return null;
        }
        var draft = mapper.copyPublishedToDraft(presetSceneId, sourceVersion, adminId, now);
        if (draft != null) {
            insertAudit(
                    activityId,
                    "rollback",
                    sourceVersionId,
                    draft.versionId(),
                    adminId,
                    rollbackAuditSummary(sourceVersion, draft.lockVersion()),
                    now);
        }
        return draft;
    }

    public List<PublishedRow> findVersions(String presetSceneId) {
        return mapper.findVersions(presetSceneId);
    }

    private void insertAudit(
            long activityId,
            String action,
            Long sourceVersionId,
            Long targetVersionId,
            String adminId,
            String changeSummary,
            OffsetDateTime now
    ) {
        if (mapper.insertAudit(
                activityId,
                action,
                sourceVersionId,
                targetVersionId,
                adminId,
                changeSummary,
                now) != 1) {
            throw new IllegalStateException("preset scene audit insert affected no row");
        }
    }

    private String draftAuditSummary(String action, int lockVersion) {
        return "{\"action\":\"" + action + "\",\"lock_version\":" + lockVersion
                + ",\"fields\":" + DRAFT_CHANGED_FIELDS + "}";
    }

    private String publishedAuditSummary(String action, int lockVersion, int version) {
        return "{\"action\":\"" + action + "\",\"lock_version\":" + lockVersion
                + ",\"version\":" + version + ",\"fields\":" + PUBLISHED_CHANGED_FIELDS + "}";
    }

    private String rollbackAuditSummary(int sourceVersion, int lockVersion) {
        return "{\"action\":\"rollback\",\"source_version\":" + sourceVersion
                + ",\"lock_version\":" + lockVersion + ",\"fields\":" + DRAFT_CHANGED_FIELDS + "}";
    }

    private String rollbackPublishedAuditSummary(int sourceVersion, int lockVersion, int version) {
        return "{\"action\":\"rollback\",\"source_version\":" + sourceVersion
                + ",\"target_version\":" + version + ",\"lock_version\":" + lockVersion
                + ",\"fields\":" + PUBLISHED_CHANGED_FIELDS + "}";
    }

    public sealed interface RollbackResult
            permits RollbackResult.Completed, RollbackResult.Failure {

        enum Failure implements RollbackResult {
            ACTIVITY_NOT_FOUND,
            DRAFT_EXISTS,
            SOURCE_VERSION_NOT_FOUND
        }

        record Completed(PublishedRow published) implements RollbackResult {
        }
    }

    public record DraftWrite(
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief,
            boolean enabled
    ) {

        public String titleZh() {
            return title;
        }

        public String summaryZh() {
            return summary;
        }

        public String sceneTagEn() {
            return sceneTag;
        }

        public String coachTipZh() {
            return coachTip;
        }
    }

    public record SceneSummaryRow(
            long activityId,
            String presetSceneId,
            String spaceId,
            long publishedVersionId,
            int publishedVersion,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            boolean enabled,
            Integer draftLockVersion,
            OffsetDateTime publishedAt,
            OffsetDateTime updatedAt,
            OffsetDateTime draftUpdatedAt
    ) {

        public String titleZh() {
            return title;
        }

        public String summaryZh() {
            return summary;
        }

        public String sceneTagEn() {
            return sceneTag;
        }

        public String coachTipZh() {
            return coachTip;
        }
    }

    public record SceneDetailRow(
            long activityId,
            String presetSceneId,
            String spaceId,
            long publishedVersionId,
            int publishedVersion,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief,
            boolean enabled,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            OffsetDateTime publishedAt
    ) {

        public String titleZh() {
            return title;
        }

        public String summaryZh() {
            return summary;
        }

        public String sceneTagEn() {
            return sceneTag;
        }

        public String coachTipZh() {
            return coachTip;
        }

        public int version() {
            return publishedVersion;
        }
    }

    public record DraftRow(
            long versionId,
            long activityId,
            String presetSceneId,
            String spaceId,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief,
            boolean enabled,
            int lockVersion,
            String createdByAdminId,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {

        public String titleZh() {
            return title;
        }

        public String summaryZh() {
            return summary;
        }

        public String sceneTagEn() {
            return sceneTag;
        }

        public String coachTipZh() {
            return coachTip;
        }
    }

    public record PublishedRow(
            long versionId,
            long activityId,
            String presetSceneId,
            String spaceId,
            int version,
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief,
            boolean enabled,
            int lockVersion,
            String createdByAdminId,
            String publishedByAdminId,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            OffsetDateTime publishedAt
    ) {

        public String titleZh() {
            return title;
        }

        public String summaryZh() {
            return summary;
        }

        public String sceneTagEn() {
            return sceneTag;
        }

        public String coachTipZh() {
            return coachTip;
        }
    }
}
