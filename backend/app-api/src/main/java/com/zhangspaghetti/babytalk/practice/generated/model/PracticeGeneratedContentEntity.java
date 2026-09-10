package com.zhangspaghetti.babytalk.practice.generated.model;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.OffsetDateTime;
import java.util.List;

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
    private String inputSource;
    private Long presetActivityId;
    private Long presetSceneVersionId;
    private Integer profileVersion;
    private String householdContextVersion;
    private String requestFingerprint;
    private String clientRequestId;
    private String clientRequestFingerprint;
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
    private String tprActionZh;
    private String deliveryGuidanceZh;
    private String englishText;
    private String chineseText;
    private String pronunciationHint;
    private String difficulty;
    private String generationSource;
    private String status;
    private String generationProfileVersion;
    private String generationProfileHash;
    private String rubricVersion;
    private String rubricContentHash;
    private String evidencePolicyVersion;
    private String evidencePolicyContentHash;
    private String providerRoutingPolicyVersion;
    private String providerRoutingPolicyHash;
    private int generationAttemptLimit;
    private int contentRefreshEpoch;
    private int contentVersion;
    private String generationErrorCode;
    private Boolean generationErrorRetryable;
    private OffsetDateTime generationStartedAt;
    private OffsetDateTime generationExpiresAt;
    private OffsetDateTime retentionExpiresAt;
    @TableField(fill = FieldFill.INSERT)
    private OffsetDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private OffsetDateTime updatedAt;
    @TableField(exist = false)
    private List<PracticeGeneratedContentUtteranceEntity> approvedUtterances = List.of();

    public PracticeGeneratedContentEntity() {
    }

public String generatedContentId() {
        return generatedContentId;
    }
public String getGeneratedContentId() {
        return generatedContentId;
    }
public void setGeneratedContentId(String generatedContentId) {
        this.generatedContentId = generatedContentId;
    }
public String ownerScope() {
        return ownerScope;
    }
public String getOwnerScope() {
        return ownerScope;
    }
public void setOwnerScope(String ownerScope) {
        this.ownerScope = ownerScope;
    }
public String ownerKey() {
        return ownerKey;
    }
public String getOwnerKey() {
        return ownerKey;
    }
public void setOwnerKey(String ownerKey) {
        this.ownerKey = ownerKey;
    }
public String ownerKeyVersion() {
        return ownerKeyVersion;
    }
public String getOwnerKeyVersion() {
        return ownerKeyVersion;
    }
public void setOwnerKeyVersion(String ownerKeyVersion) {
        this.ownerKeyVersion = ownerKeyVersion;
    }
public String accountId() {
        return accountId;
    }
public String getAccountId() {
        return accountId;
    }
public void setAccountId(String accountId) {
        this.accountId = accountId;
    }
public String installationRefHash() {
        return installationRefHash;
    }
public String getInstallationRefHash() {
        return installationRefHash;
    }
public void setInstallationRefHash(String installationRefHash) {
        this.installationRefHash = installationRefHash;
    }
public String profileId() {
        return profileId;
    }
public String getProfileId() {
        return profileId;
    }
public void setProfileId(String profileId) {
        this.profileId = profileId;
    }
public String surface() {
        return surface;
    }
public String getSurface() {
        return surface;
    }
public void setSurface(String surface) {
        this.surface = surface;
    }
public String mode() {
        return mode;
    }
public String getMode() {
        return mode;
    }
public void setMode(String mode) {
        this.mode = mode;
    }
public String inputSource() {
        return inputSource;
    }
public String getInputSource() {
        return inputSource;
    }
public void setInputSource(String inputSource) {
        this.inputSource = inputSource;
    }
public Long presetActivityId() {
        return presetActivityId;
    }
public Long getPresetActivityId() {
        return presetActivityId;
    }
public void setPresetActivityId(Long presetActivityId) {
        this.presetActivityId = presetActivityId;
    }
public Long presetSceneVersionId() {
        return presetSceneVersionId;
    }
public Long getPresetSceneVersionId() {
        return presetSceneVersionId;
    }
public void setPresetSceneVersionId(Long presetSceneVersionId) {
        this.presetSceneVersionId = presetSceneVersionId;
    }
public Integer profileVersion() {
        return profileVersion;
    }
public Integer getProfileVersion() {
        return profileVersion;
    }
public void setProfileVersion(Integer profileVersion) {
        this.profileVersion = profileVersion;
    }
public String householdContextVersion() {
        return householdContextVersion;
    }
public String getHouseholdContextVersion() {
        return householdContextVersion;
    }
public void setHouseholdContextVersion(String householdContextVersion) {
        this.householdContextVersion = householdContextVersion;
    }
public String requestFingerprint() {
        return requestFingerprint;
    }
public String getRequestFingerprint() {
        return requestFingerprint;
    }
    public void setRequestFingerprint(String requestFingerprint) {
        this.requestFingerprint = requestFingerprint;
    }
public String clientRequestId() {
        return clientRequestId;
    }
public String getClientRequestId() {
        return clientRequestId;
    }
public void setClientRequestId(String clientRequestId) {
        this.clientRequestId = clientRequestId;
    }
public String clientRequestFingerprint() {
        return clientRequestFingerprint;
    }
public String getClientRequestFingerprint() {
        return clientRequestFingerprint;
    }
public void setClientRequestFingerprint(String clientRequestFingerprint) {
        this.clientRequestFingerprint = clientRequestFingerprint;
    }
public String normalizedSceneText() {
        return normalizedSceneText;
    }
public String getNormalizedSceneText() {
        return normalizedSceneText;
    }
public void setNormalizedSceneText(String normalizedSceneText) {
        this.normalizedSceneText = normalizedSceneText;
    }
public String ageRange() {
        return ageRange;
    }
public String getAgeRange() {
        return ageRange;
    }
public void setAgeRange(String ageRange) {
        this.ageRange = ageRange;
    }
public String parentGoal() {
        return parentGoal;
    }
public String getParentGoal() {
        return parentGoal;
    }
public void setParentGoal(String parentGoal) {
        this.parentGoal = parentGoal;
    }
public String locale() {
        return locale;
    }
public String getLocale() {
        return locale;
    }
public void setLocale(String locale) {
        this.locale = locale;
    }
public String spaceSlug() {
        return spaceSlug;
    }
public String getSpaceSlug() {
        return spaceSlug;
    }
public void setSpaceSlug(String spaceSlug) {
        this.spaceSlug = spaceSlug;
    }
public String activitySlug() {
        return activitySlug;
    }
public String getActivitySlug() {
        return activitySlug;
    }
public void setActivitySlug(String activitySlug) {
        this.activitySlug = activitySlug;
    }
public String phraseSlug() {
        return phraseSlug;
    }
public String getPhraseSlug() {
        return phraseSlug;
    }
public void setPhraseSlug(String phraseSlug) {
        this.phraseSlug = phraseSlug;
    }
public String spaceTitleZh() {
        return spaceTitleZh;
    }
public String getSpaceTitleZh() {
        return spaceTitleZh;
    }
public void setSpaceTitleZh(String spaceTitleZh) {
        this.spaceTitleZh = spaceTitleZh;
    }
public String activityTitleZh() {
        return activityTitleZh;
    }
public String getActivityTitleZh() {
        return activityTitleZh;
    }
public void setActivityTitleZh(String activityTitleZh) {
        this.activityTitleZh = activityTitleZh;
    }
public String sceneTagEn() {
        return sceneTagEn;
    }
public String getSceneTagEn() {
        return sceneTagEn;
    }
public void setSceneTagEn(String sceneTagEn) {
        this.sceneTagEn = sceneTagEn;
    }
public String tprActionZh() {
        return tprActionZh;
    }
public String getTprActionZh() {
        return tprActionZh;
    }
public void setTprActionZh(String tprActionZh) {
        this.tprActionZh = tprActionZh;
    }
public String deliveryGuidanceZh() {
        return deliveryGuidanceZh;
    }
public String getDeliveryGuidanceZh() {
        return deliveryGuidanceZh;
    }
public void setDeliveryGuidanceZh(String deliveryGuidanceZh) {
        this.deliveryGuidanceZh = deliveryGuidanceZh;
    }
public String englishText() {
        return englishText;
    }
public String getEnglishText() {
        return englishText;
    }
public void setEnglishText(String englishText) {
        this.englishText = englishText;
    }
public String chineseText() {
        return chineseText;
    }
public String getChineseText() {
        return chineseText;
    }
public void setChineseText(String chineseText) {
        this.chineseText = chineseText;
    }
public String pronunciationHint() {
        return pronunciationHint;
    }
public String getPronunciationHint() {
        return pronunciationHint;
    }
public void setPronunciationHint(String pronunciationHint) {
        this.pronunciationHint = pronunciationHint;
    }
public String difficulty() {
        return difficulty;
    }
public String getDifficulty() {
        return difficulty;
    }
public void setDifficulty(String difficulty) {
        this.difficulty = difficulty;
    }
public String generationSource() {
        return generationSource;
    }
public String getGenerationSource() {
        return generationSource;
    }
public void setGenerationSource(String generationSource) {
        this.generationSource = generationSource;
    }
public String status() {
        return status;
    }
public String getStatus() {
        return status;
    }
public void setStatus(String status) {
        this.status = status;
    }
public String generationProfileVersion() {
        return generationProfileVersion;
    }
public String getGenerationProfileVersion() {
        return generationProfileVersion;
    }
public void setGenerationProfileVersion(String generationProfileVersion) {
        this.generationProfileVersion = generationProfileVersion;
    }
public String generationProfileHash() {
        return generationProfileHash;
    }
public String getGenerationProfileHash() {
        return generationProfileHash;
    }
public void setGenerationProfileHash(String generationProfileHash) {
        this.generationProfileHash = generationProfileHash;
    }
public String rubricVersion() {
        return rubricVersion;
    }
public String getRubricVersion() {
        return rubricVersion;
    }
public void setRubricVersion(String rubricVersion) {
        this.rubricVersion = rubricVersion;
    }
public String rubricContentHash() {
        return rubricContentHash;
    }
public String getRubricContentHash() {
        return rubricContentHash;
    }
public void setRubricContentHash(String rubricContentHash) {
        this.rubricContentHash = rubricContentHash;
    }
public String evidencePolicyVersion() {
        return evidencePolicyVersion;
    }
public String getEvidencePolicyVersion() {
        return evidencePolicyVersion;
    }
public void setEvidencePolicyVersion(String evidencePolicyVersion) {
        this.evidencePolicyVersion = evidencePolicyVersion;
    }
public String evidencePolicyContentHash() {
        return evidencePolicyContentHash;
    }
public String getEvidencePolicyContentHash() {
        return evidencePolicyContentHash;
    }
public void setEvidencePolicyContentHash(String evidencePolicyContentHash) {
        this.evidencePolicyContentHash = evidencePolicyContentHash;
    }
public String providerRoutingPolicyVersion() {
        return providerRoutingPolicyVersion;
    }
public String getProviderRoutingPolicyVersion() {
        return providerRoutingPolicyVersion;
    }
public void setProviderRoutingPolicyVersion(String providerRoutingPolicyVersion) {
        this.providerRoutingPolicyVersion = providerRoutingPolicyVersion;
    }
public String providerRoutingPolicyHash() {
        return providerRoutingPolicyHash;
    }
public String getProviderRoutingPolicyHash() {
        return providerRoutingPolicyHash;
    }
public void setProviderRoutingPolicyHash(String providerRoutingPolicyHash) {
        this.providerRoutingPolicyHash = providerRoutingPolicyHash;
    }
public int generationAttemptLimit() {
        return generationAttemptLimit;
    }
public int getGenerationAttemptLimit() {
        return generationAttemptLimit;
    }
public void setGenerationAttemptLimit(int generationAttemptLimit) {
        this.generationAttemptLimit = generationAttemptLimit;
    }
public int contentRefreshEpoch() {
        return contentRefreshEpoch;
    }
public int getContentRefreshEpoch() {
        return contentRefreshEpoch;
    }
public void setContentRefreshEpoch(int contentRefreshEpoch) {
        this.contentRefreshEpoch = contentRefreshEpoch;
    }
public int contentVersion() {
        return contentVersion;
    }
public int getContentVersion() {
        return contentVersion;
    }
public void setContentVersion(int contentVersion) {
        this.contentVersion = contentVersion;
    }
public String generationErrorCode() {
        return generationErrorCode;
    }
public String getGenerationErrorCode() {
        return generationErrorCode;
    }
public void setGenerationErrorCode(String generationErrorCode) {
        this.generationErrorCode = generationErrorCode;
    }
public Boolean generationErrorRetryable() {
        return generationErrorRetryable;
    }
public Boolean getGenerationErrorRetryable() {
        return generationErrorRetryable;
    }
public void setGenerationErrorRetryable(Boolean generationErrorRetryable) {
        this.generationErrorRetryable = generationErrorRetryable;
    }
public OffsetDateTime generationStartedAt() {
        return generationStartedAt;
    }
public OffsetDateTime getGenerationStartedAt() {
        return generationStartedAt;
    }
public void setGenerationStartedAt(OffsetDateTime generationStartedAt) {
        this.generationStartedAt = generationStartedAt;
    }
public OffsetDateTime generationExpiresAt() {
        return generationExpiresAt;
    }
public OffsetDateTime getGenerationExpiresAt() {
        return generationExpiresAt;
    }
public void setGenerationExpiresAt(OffsetDateTime generationExpiresAt) {
        this.generationExpiresAt = generationExpiresAt;
    }
public OffsetDateTime retentionExpiresAt() {
        return retentionExpiresAt;
    }
public OffsetDateTime getRetentionExpiresAt() {
        return retentionExpiresAt;
    }
public void setRetentionExpiresAt(OffsetDateTime retentionExpiresAt) {
        this.retentionExpiresAt = retentionExpiresAt;
    }
public OffsetDateTime createdAt() {
        return createdAt;
    }
public OffsetDateTime getCreatedAt() {
        return createdAt;
    }
public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
public OffsetDateTime updatedAt() {
        return updatedAt;
    }
public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }
public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
public List<PracticeGeneratedContentUtteranceEntity> approvedUtterances() {
        return approvedUtterances;
    }
public List<PracticeGeneratedContentUtteranceEntity> getApprovedUtterances() {
        return approvedUtterances;
    }
public void setApprovedUtterances(List<PracticeGeneratedContentUtteranceEntity> approvedUtterances) {
        this.approvedUtterances = approvedUtterances == null ? List.of() : List.copyOf(approvedUtterances);
    }
}
