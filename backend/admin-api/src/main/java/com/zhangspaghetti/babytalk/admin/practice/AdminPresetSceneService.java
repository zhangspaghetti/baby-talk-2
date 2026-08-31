package com.zhangspaghetti.babytalk.admin.practice;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.text.Normalizer;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.sql.SQLException;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminPresetSceneService {

    private static final Pattern SCENE_ID = Pattern.compile("[a-z0-9][a-z0-9_-]{0,63}");
    private static final Pattern PHONE_LIKE = Pattern.compile(
            "(?<!\\d)(?:\\+?\\d[\\d\\s().-]{6,}\\d)(?!\\d)");

    private final AdminPresetSceneRepository repository;
    private final Clock clock;

    public AdminPresetSceneService(AdminPresetSceneRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<SceneSummaryView> listScenes() {
        return repository.findScenes().stream()
                .map(this::toSummaryView)
                .toList();
    }

    @Transactional(readOnly = true)
    public SceneDetailView getScene(String presetSceneId) {
        requireSceneId(presetSceneId);
        var scene = repository.findScene(presetSceneId).orElseThrow(this::sceneNotFound);
        return new SceneDetailView(
                scene.presetSceneId(),
                scene.spaceId(),
                scene.publishedVersion(),
                scene.title(),
                scene.summary(),
                scene.sceneTag(),
                scene.coachTip(),
                scene.sortOrder(),
                scene.generationBrief(),
                scene.enabled(),
                scene.createdAt(),
                scene.updatedAt(),
                scene.publishedAt(),
                repository.findDraft(presetSceneId).map(this::toDraftView).orElse(null));
    }

    @Transactional
    public DraftView createDraft(String presetSceneId, DraftCommand command, String adminId) {
        requireSceneId(presetSceneId);
        requireAdminId(adminId);
        var write = normalizeDraft(command, ValidationMode.DRAFT);
        if (repository.findScene(presetSceneId).isEmpty()) {
            throw sceneNotFound();
        }
        if (repository.findDraft(presetSceneId).isPresent()) {
            throw new AdminApiContractException(
                    HttpStatus.CONFLICT,
                    "practice_draft_version_conflict",
                    "预置场景草稿已被其他管理员创建或修改。",
                    Map.of());
        }
        try {
            var draft = repository.createDraft(presetSceneId, write, adminId, now());
            if (draft == null) {
                throw sceneNotFound();
            }
            return toDraftView(draft);
        } catch (DataIntegrityViolationException exception) {
            if (!isSingleDraftUniqueConstraint(exception)) {
                throw exception;
            }
            throw new AdminApiContractException(
                    HttpStatus.CONFLICT,
                    "practice_draft_version_conflict",
                    "预置场景草稿已被其他管理员创建或修改。",
                    Map.of());
        }
    }

    @Transactional
    public DraftView updateDraft(
            String presetSceneId,
            DraftCommand command,
            String adminId
    ) {
        requireSceneId(presetSceneId);
        requireAdminId(adminId);
        var write = normalizeDraft(command, ValidationMode.DRAFT);
        if (repository.findScene(presetSceneId).isEmpty()) {
            throw sceneNotFound();
        }
        var draft = repository.updateDraft(
                presetSceneId,
                command.lockVersion(),
                write,
                adminId,
                now());
        if (draft == null) {
            throw draftVersionConflict();
        }
        return toDraftView(draft);
    }

    @Transactional
    public PublishedView publish(
            String presetSceneId,
            PublishCommand command,
            String adminId
    ) {
        requireSceneId(presetSceneId);
        requireAdminId(adminId);
        requireLockVersion(command.lockVersion());
        if (repository.findScene(presetSceneId).isEmpty()) {
            throw sceneNotFound();
        }
        var published = repository.publish(
                presetSceneId,
                command.lockVersion(),
                adminId,
                now(),
                this::validatePublishedDraft);
        if (published == null) {
            throw draftVersionConflict();
        }
        return toPublishedView(published);
    }

    @Transactional
    public PublishedView rollback(String presetSceneId, int sourceVersion, String adminId) {
        requireSceneId(presetSceneId);
        requireAdminId(adminId);
        if (sourceVersion <= 0) {
            throw invalid("version", "version 必须是正整数。");
        }
        if (repository.findScene(presetSceneId).isEmpty()) {
            throw sceneNotFound();
        }
        if (repository.findDraft(presetSceneId).isPresent()) {
            throw draftVersionConflict();
        }
        var published = repository.rollback(presetSceneId, sourceVersion, adminId, now());
        if (published == null) {
            throw new AdminApiContractException(
                    HttpStatus.NOT_FOUND,
                    "practice_preset_scene_not_found",
                    "预置场景版本不存在。",
                    Map.of("version", sourceVersion));
        }
        return toPublishedView(published);
    }

    @Transactional(readOnly = true)
    public List<PublishedView> versions(String presetSceneId) {
        requireSceneId(presetSceneId);
        if (repository.findScene(presetSceneId).isEmpty()) {
            throw sceneNotFound();
        }
        return repository.findVersions(presetSceneId).stream()
                .map(this::toPublishedView)
                .toList();
    }

    private AdminPresetSceneRepository.DraftWrite normalizeDraft(DraftCommand command, ValidationMode mode) {
        if (command == null) {
            throw invalid("request", "请求参数不能为空。");
        }
        if (command.lockVersion() < 0) {
            throw invalid("lockVersion", "lockVersion 不能小于 0。");
        }
        if (command.sortOrder() < 0) {
            throw invalid("sortOrder", "sortOrder 不能小于 0。");
        }
        return new AdminPresetSceneRepository.DraftWrite(
                normalizeText("title", command.title(), 120, mode),
                normalizeText("summary", command.summary(), 240, mode),
                normalizeText("sceneTag", command.sceneTag(), 120, mode),
                normalizeText("coachTip", command.coachTip(), 240, mode),
                command.sortOrder(),
                normalizeText("generationBrief", command.generationBrief(), 1200, mode),
                command.enabled());
    }

    private String normalizeText(String field, String raw, int maxLength, ValidationMode mode) {
        if (raw == null || raw.isBlank()) {
            throw invalid(field, field + " 不能为空。");
        }
        var normalized = Normalizer.normalize(raw, Normalizer.Form.NFC);
        if (containsControlCharacter(normalized)) {
            throw invalid(field, field + " 不得包含控制字符。");
        }
        normalized = normalized.trim();
        if (normalized.isEmpty()) {
            throw invalid(field, field + " 不能为空。");
        }
        if (normalized.length() > maxLength) {
            throw invalid(field, field + " 过长。");
        }
        if (PHONE_LIKE.matcher(normalized).find()) {
            throw invalid(field, field + " 不得包含手机号样式的数字序列。");
        }
        return normalized;
    }

    private boolean isSingleDraftUniqueConstraint(DataIntegrityViolationException exception) {
        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof SQLException sqlException
                    && sqlException.getMessage() != null
                    && sqlException.getMessage().contains("uq_practice_preset_scene_versions_one_draft")) {
                return true;
            }
        }
        return false;
    }

    private boolean containsControlCharacter(String value) {
        for (int offset = 0; offset < value.length();) {
            var codePoint = value.codePointAt(offset);
            if (Character.isISOControl(codePoint)) {
                return true;
            }
            offset += Character.charCount(codePoint);
        }
        return false;
    }

    private void validatePublishedDraft(AdminPresetSceneRepository.DraftRow draft) {
        try {
            normalizeDraft(
                    new DraftCommand(
                            draft.title(),
                            draft.summary(),
                            draft.sceneTag(),
                            draft.coachTip(),
                            draft.sortOrder(),
                            draft.generationBrief(),
                            draft.enabled(),
                            draft.lockVersion()),
                    ValidationMode.PUBLISH);
        } catch (AdminApiContractException exception) {
            throw new AdminApiContractException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "practice_publish_validation_failed",
                    "预置场景发布校验失败。",
                    exception.details());
        }
    }

    private void requireSceneId(String presetSceneId) {
        if (presetSceneId == null || !SCENE_ID.matcher(presetSceneId).matches()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "validation_failed",
                    "presetSceneId 不合法。",
                    Map.of());
        }
    }

    private void requireAdminId(String adminId) {
        if (adminId == null || adminId.isBlank()) {
            throw new AdminApiContractException(
                    HttpStatus.UNAUTHORIZED,
                    "admin_authentication_required",
                    "请先登录管理员账号。",
                    Map.of());
        }
    }

    private void requireLockVersion(int lockVersion) {
        if (lockVersion < 0) {
            throw invalid("lockVersion", "lockVersion 不能小于 0。");
        }
    }

    private AdminApiContractException draftVersionConflict() {
        return new AdminApiContractException(
                HttpStatus.CONFLICT,
                "practice_draft_version_conflict",
                "预置场景草稿版本已变化，请刷新后重试。",
                Map.of());
    }

    private AdminApiContractException sceneNotFound() {
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "practice_preset_scene_not_found",
                "预置场景不存在。",
                Map.of());
    }

    private AdminApiContractException invalid(String field, String message) {
        return new AdminApiContractException(
                HttpStatus.BAD_REQUEST,
                "validation_failed",
                "请求参数不合法。",
                Map.of("fields", Map.of(field, message)));
    }

    private OffsetDateTime now() {
        return OffsetDateTime.now(clock).withOffsetSameInstant(ZoneOffset.UTC);
    }

    private SceneSummaryView toSummaryView(AdminPresetSceneRepository.SceneSummaryRow row) {
        return new SceneSummaryView(
                row.presetSceneId(),
                row.spaceId(),
                row.publishedVersion(),
                row.title(),
                row.summary(),
                row.sceneTag(),
                row.coachTip(),
                row.sortOrder(),
                row.enabled(),
                row.draftLockVersion(),
                row.publishedAt(),
                row.updatedAt(),
                row.draftUpdatedAt());
    }

    private DraftView toDraftView(AdminPresetSceneRepository.DraftRow row) {
        return new DraftView(
                row.presetSceneId(),
                row.spaceId(),
                row.title(),
                row.summary(),
                row.sceneTag(),
                row.coachTip(),
                row.sortOrder(),
                row.generationBrief(),
                row.enabled(),
                row.lockVersion(),
                row.createdAt(),
                row.updatedAt());
    }

    private PublishedView toPublishedView(AdminPresetSceneRepository.PublishedRow row) {
        return new PublishedView(
                row.presetSceneId(),
                row.spaceId(),
                row.version(),
                row.title(),
                row.summary(),
                row.sceneTag(),
                row.coachTip(),
                row.sortOrder(),
                row.generationBrief(),
                row.enabled(),
                row.lockVersion(),
                row.createdAt(),
                row.updatedAt(),
                row.publishedAt());
    }

    private enum ValidationMode {
        DRAFT,
        PUBLISH
    }

    public record DraftCommand(
            String title,
            String summary,
            String sceneTag,
            String coachTip,
            int sortOrder,
            String generationBrief,
            boolean enabled,
            int lockVersion
    ) {
    }

    public record PublishCommand(int lockVersion) {
    }

    public record SceneSummaryView(
            String presetSceneId,
            String spaceId,
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
    }

    public record SceneDetailView(
            String presetSceneId,
            String spaceId,
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
            OffsetDateTime publishedAt,
            DraftView draft
    ) {
    }

    public record DraftView(
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
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }

    public record PublishedView(
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
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt,
            OffsetDateTime publishedAt
    ) {
    }
}
