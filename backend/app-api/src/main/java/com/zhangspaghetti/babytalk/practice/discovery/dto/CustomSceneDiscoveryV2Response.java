package com.zhangspaghetti.babytalk.practice.discovery.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public record CustomSceneDiscoveryV2Response(
        String schemaVersion,
        String discoveryTraceId,
        String resultType,
        String policyVersion,
        PracticeDiscoveryResponse scene,
        SafetyResponse safety
) {

    public record SafetyResponse(
            String action,
            String templateId,
            String policyVersion,
            String locale,
            String titleZh,
            String messageZh
    ) {
    }
}
