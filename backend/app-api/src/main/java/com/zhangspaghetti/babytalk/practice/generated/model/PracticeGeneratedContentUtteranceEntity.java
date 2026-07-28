package com.zhangspaghetti.babytalk.practice.generated.model;

import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import java.time.OffsetDateTime;

@TableName("practice_generated_content_utterances")
public class PracticeGeneratedContentUtteranceEntity {

    @TableId
    private String utteranceId;
    private String generatedContentId;
    private String role;
    private String reactionType;
    private String englishText;
    private String chineseText;
    private String pronunciationHint;
    private String tprActionZh;
    private String deliveryGuidanceZh;
    private String difficulty;
    private int displayOrder;
    private String approvalStatus;
    private int approvedContentVersion;
    private String bundleSchemaVersion;
    private String providerOrigin;
    private String providerName;
    private String providerModelName;
    private int providerAttemptNumber;
    private OffsetDateTime createdAt;

    public String utteranceId() { return utteranceId; }
    public void setUtteranceId(String utteranceId) { this.utteranceId = utteranceId; }
    public String generatedContentId() { return generatedContentId; }
    public void setGeneratedContentId(String generatedContentId) { this.generatedContentId = generatedContentId; }
    public String role() { return role; }
    public void setRole(String role) { this.role = role; }
    public String reactionType() { return reactionType; }
    public void setReactionType(String reactionType) { this.reactionType = reactionType; }
    public String englishText() { return englishText; }
    public void setEnglishText(String englishText) { this.englishText = englishText; }
    public String chineseText() { return chineseText; }
    public void setChineseText(String chineseText) { this.chineseText = chineseText; }
    public String pronunciationHint() { return pronunciationHint; }
    public void setPronunciationHint(String pronunciationHint) { this.pronunciationHint = pronunciationHint; }
    public String tprActionZh() { return tprActionZh; }
    public void setTprActionZh(String tprActionZh) { this.tprActionZh = tprActionZh; }
    public String deliveryGuidanceZh() { return deliveryGuidanceZh; }
    public void setDeliveryGuidanceZh(String deliveryGuidanceZh) { this.deliveryGuidanceZh = deliveryGuidanceZh; }
    public String difficulty() { return difficulty; }
    public void setDifficulty(String difficulty) { this.difficulty = difficulty; }
    public int displayOrder() { return displayOrder; }
    public void setDisplayOrder(int displayOrder) { this.displayOrder = displayOrder; }
    public String approvalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }
    public int approvedContentVersion() { return approvedContentVersion; }
    public void setApprovedContentVersion(int approvedContentVersion) { this.approvedContentVersion = approvedContentVersion; }
    public String bundleSchemaVersion() { return bundleSchemaVersion; }
    public void setBundleSchemaVersion(String bundleSchemaVersion) { this.bundleSchemaVersion = bundleSchemaVersion; }
    public String providerOrigin() { return providerOrigin; }
    public void setProviderOrigin(String providerOrigin) { this.providerOrigin = providerOrigin; }
    public String providerName() { return providerName; }
    public void setProviderName(String providerName) { this.providerName = providerName; }
    public String providerModelName() { return providerModelName; }
    public void setProviderModelName(String providerModelName) { this.providerModelName = providerModelName; }
    public int providerAttemptNumber() { return providerAttemptNumber; }
    public void setProviderAttemptNumber(int providerAttemptNumber) { this.providerAttemptNumber = providerAttemptNumber; }
    public OffsetDateTime createdAt() { return createdAt; }
    public void setCreatedAt(OffsetDateTime createdAt) { this.createdAt = createdAt; }
}
