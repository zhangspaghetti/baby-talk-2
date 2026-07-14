package com.zhangspaghetti.babytalk.practice.generated.model;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.OffsetDateTime;

@TableName("practice_generated_content")
public class PracticeGeneratedContentEntity {

    @TableId(value = "generated_content_id", type = IdType.INPUT)
    private String generatedContentId;
    private String ownerScope;
    private String ownerKey;
    private String ownerKeyVersion;
    private String accountId;
    private String installationRefHash;
    private String profileId;
    private String surface;
    private String mode;
    private String requestFingerprint;
    private String normalizedSceneText;
    private String ageRange;
    private String parentGoal;
    private String locale;
    private String spaceSlug;
    private String activitySlug;
    private String phraseSlug;
    private String spaceTitleZh;
    private String activityTitleZh;
    private String sceneTagEn;
    private String coachTipZh;
    private String englishText;
    private String chineseText;
    private String pronunciationHint;
    private String difficulty;
    private String generationSource;
    private String status;
    private String providerTraceId;
    private String retrievalTraceId;
    private String modelName;
    private String promptVersion;
    private String strategyVersion;
    private String policyVersion;
    private int contentVersion;
    private String generationErrorCode;
    private OffsetDateTime generationStartedAt;
    private OffsetDateTime generationExpiresAt;
    private OffsetDateTime retentionExpiresAt;
    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private OffsetDateTime updatedAt;

    public PracticeGeneratedContentEntity() {
    }

    public PracticeGeneratedContentEntity(
            String generatedContentId,
            String ownerScope,
            String ownerKey,
            String accountId,
            String installationRefHash,
            String profileId,
            String surface,
            String mode,
            String requestFingerprint,
            String normalizedSceneText,
            String ageRange,
            String parentGoal,
            String locale,
            String spaceSlug,
            String activitySlug,
            String phraseSlug,
            String spaceTitleZh,
            String activityTitleZh,
            String sceneTagEn,
            String coachTipZh,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String difficulty,
            String generationSource,
            String status,
            String providerTraceId,
            String retrievalTraceId,
            String modelName,
            String promptVersion,
            String strategyVersion,
            int contentVersion,
            String generationErrorCode,
            OffsetDateTime generationStartedAt,
            OffsetDateTime generationExpiresAt,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
        this.generatedContentId = generatedContentId;
        this.ownerScope = ownerScope;
        this.ownerKey = ownerKey;
        this.accountId = accountId;
        this.installationRefHash = installationRefHash;
        this.profileId = profileId;
        this.surface = surface;
        this.mode = mode;
        this.requestFingerprint = requestFingerprint;
        this.normalizedSceneText = normalizedSceneText;
        this.ageRange = ageRange;
        this.parentGoal = parentGoal;
        this.locale = locale;
        this.spaceSlug = spaceSlug;
        this.activitySlug = activitySlug;
        this.phraseSlug = phraseSlug;
        this.spaceTitleZh = spaceTitleZh;
        this.activityTitleZh = activityTitleZh;
        this.sceneTagEn = sceneTagEn;
        this.coachTipZh = coachTipZh;
        this.englishText = englishText;
        this.chineseText = chineseText;
        this.pronunciationHint = pronunciationHint;
        this.difficulty = difficulty;
        this.generationSource = generationSource;
        this.status = status;
        this.providerTraceId = providerTraceId;
        this.retrievalTraceId = retrievalTraceId;
        this.modelName = modelName;
        this.promptVersion = promptVersion;
        this.strategyVersion = strategyVersion;
        this.contentVersion = contentVersion;
        this.generationErrorCode = generationErrorCode;
        this.generationStartedAt = generationStartedAt;
        this.generationExpiresAt = generationExpiresAt;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public String generatedContentId() { return generatedContentId; }
    public String ownerScope() { return ownerScope; }
    public String ownerKey() { return ownerKey; }
    public String ownerKeyVersion() { return ownerKeyVersion; }
    public String accountId() { return accountId; }
    public String installationRefHash() { return installationRefHash; }
    public String profileId() { return profileId; }
    public String surface() { return surface; }
    public String mode() { return mode; }
    public String requestFingerprint() { return requestFingerprint; }
    public String normalizedSceneText() { return normalizedSceneText; }
    public String ageRange() { return ageRange; }
    public String parentGoal() { return parentGoal; }
    public String locale() { return locale; }
    public String spaceSlug() { return spaceSlug; }
    public String activitySlug() { return activitySlug; }
    public String phraseSlug() { return phraseSlug; }
    public String spaceTitleZh() { return spaceTitleZh; }
    public String activityTitleZh() { return activityTitleZh; }
    public String sceneTagEn() { return sceneTagEn; }
    public String coachTipZh() { return coachTipZh; }
    public String englishText() { return englishText; }
    public String chineseText() { return chineseText; }
    public String pronunciationHint() { return pronunciationHint; }
    public String difficulty() { return difficulty; }
    public String generationSource() { return generationSource; }
    public String status() { return status; }
    public String providerTraceId() { return providerTraceId; }
    public String retrievalTraceId() { return retrievalTraceId; }
    public String modelName() { return modelName; }
    public String promptVersion() { return promptVersion; }
    public String strategyVersion() { return strategyVersion; }
    public String policyVersion() { return policyVersion; }
    public int contentVersion() { return contentVersion; }
    public String generationErrorCode() { return generationErrorCode; }
    public OffsetDateTime generationStartedAt() { return generationStartedAt; }
    public OffsetDateTime generationExpiresAt() { return generationExpiresAt; }
    public OffsetDateTime retentionExpiresAt() { return retentionExpiresAt; }
    public OffsetDateTime createdAt() { return createdAt; }
    public OffsetDateTime updatedAt() { return updatedAt; }

    public String getGeneratedContentId() { return generatedContentId; }
    public void setGeneratedContentId(String generatedContentId) { this.generatedContentId = generatedContentId; }
    public String getOwnerScope() { return ownerScope; }
    public void setOwnerScope(String ownerScope) { this.ownerScope = ownerScope; }
    public String getOwnerKey() { return ownerKey; }
    public void setOwnerKey(String ownerKey) { this.ownerKey = ownerKey; }
    public void setOwnerKeyVersion(String ownerKeyVersion) { this.ownerKeyVersion = ownerKeyVersion; }
    public String getAccountId() { return accountId; }
    public void setAccountId(String accountId) { this.accountId = accountId; }
    public String getInstallationRefHash() { return installationRefHash; }
    public void setInstallationRefHash(String installationRefHash) { this.installationRefHash = installationRefHash; }
    public String getProfileId() { return profileId; }
    public void setProfileId(String profileId) { this.profileId = profileId; }
    public String getSurface() { return surface; }
    public void setSurface(String surface) { this.surface = surface; }
    public String getMode() { return mode; }
    public void setMode(String mode) { this.mode = mode; }
    public String getRequestFingerprint() { return requestFingerprint; }
    public void setRequestFingerprint(String requestFingerprint) { this.requestFingerprint = requestFingerprint; }
    public String getNormalizedSceneText() { return normalizedSceneText; }
    public void setNormalizedSceneText(String normalizedSceneText) { this.normalizedSceneText = normalizedSceneText; }
    public String getAgeRange() { return ageRange; }
    public void setAgeRange(String ageRange) { this.ageRange = ageRange; }
    public String getParentGoal() { return parentGoal; }
    public void setParentGoal(String parentGoal) { this.parentGoal = parentGoal; }
    public String getLocale() { return locale; }
    public void setLocale(String locale) { this.locale = locale; }
    public String getSpaceSlug() { return spaceSlug; }
    public void setSpaceSlug(String spaceSlug) { this.spaceSlug = spaceSlug; }
    public String getActivitySlug() { return activitySlug; }
    public void setActivitySlug(String activitySlug) { this.activitySlug = activitySlug; }
    public String getPhraseSlug() { return phraseSlug; }
    public void setPhraseSlug(String phraseSlug) { this.phraseSlug = phraseSlug; }
    public String getSpaceTitleZh() { return spaceTitleZh; }
    public void setSpaceTitleZh(String spaceTitleZh) { this.spaceTitleZh = spaceTitleZh; }
    public String getActivityTitleZh() { return activityTitleZh; }
    public void setActivityTitleZh(String activityTitleZh) { this.activityTitleZh = activityTitleZh; }
    public String getSceneTagEn() { return sceneTagEn; }
    public void setSceneTagEn(String sceneTagEn) { this.sceneTagEn = sceneTagEn; }
    public String getCoachTipZh() { return coachTipZh; }
    public void setCoachTipZh(String coachTipZh) { this.coachTipZh = coachTipZh; }
    public String getEnglishText() { return englishText; }
    public void setEnglishText(String englishText) { this.englishText = englishText; }
    public String getChineseText() { return chineseText; }
    public void setChineseText(String chineseText) { this.chineseText = chineseText; }
    public String getPronunciationHint() { return pronunciationHint; }
    public void setPronunciationHint(String pronunciationHint) { this.pronunciationHint = pronunciationHint; }
    public String getDifficulty() { return difficulty; }
    public void setDifficulty(String difficulty) { this.difficulty = difficulty; }
    public String getGenerationSource() { return generationSource; }
    public void setGenerationSource(String generationSource) { this.generationSource = generationSource; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public String getProviderTraceId() { return providerTraceId; }
    public void setProviderTraceId(String providerTraceId) { this.providerTraceId = providerTraceId; }
    public String getRetrievalTraceId() { return retrievalTraceId; }
    public void setRetrievalTraceId(String retrievalTraceId) { this.retrievalTraceId = retrievalTraceId; }
    public String getModelName() { return modelName; }
    public void setModelName(String modelName) { this.modelName = modelName; }
    public String getPromptVersion() { return promptVersion; }
    public void setPromptVersion(String promptVersion) { this.promptVersion = promptVersion; }
    public String getStrategyVersion() { return strategyVersion; }
    public void setStrategyVersion(String strategyVersion) { this.strategyVersion = strategyVersion; }
    public void setPolicyVersion(String policyVersion) { this.policyVersion = policyVersion; }
    public int getContentVersion() { return contentVersion; }
    public void setContentVersion(int contentVersion) { this.contentVersion = contentVersion; }
    public String getGenerationErrorCode() { return generationErrorCode; }
    public void setGenerationErrorCode(String generationErrorCode) { this.generationErrorCode = generationErrorCode; }
    public OffsetDateTime getGenerationStartedAt() { return generationStartedAt; }
    public void setGenerationStartedAt(OffsetDateTime generationStartedAt) { this.generationStartedAt = generationStartedAt; }
    public OffsetDateTime getGenerationExpiresAt() { return generationExpiresAt; }
    public void setGenerationExpiresAt(OffsetDateTime generationExpiresAt) { this.generationExpiresAt = generationExpiresAt; }
    public OffsetDateTime getRetentionExpiresAt() { return retentionExpiresAt; }
    public void setRetentionExpiresAt(OffsetDateTime retentionExpiresAt) { this.retentionExpiresAt = retentionExpiresAt; }
    public OffsetDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
    public OffsetDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(OffsetDateTime updatedAt) { this.updatedAt = updatedAt; }
}
