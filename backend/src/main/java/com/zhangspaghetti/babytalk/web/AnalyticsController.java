package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.AnalyticsService;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/analytics")
@CrossOrigin(originPatterns = "*")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    @PostMapping("/events")
    public BabyTalkPayloads.AnalyticsIngestResponse ingestEvents(
            @RequestHeader("X-Session-Id") String sessionId,
            @RequestBody BabyTalkPayloads.AnalyticsBatchRequest request
    ) {
        return analyticsService.ingestEvents(sessionId, request);
    }

    @GetMapping("/retention")
    public BabyTalkPayloads.RetentionSummaryResponse retentionSummary() {
        return analyticsService.retentionSummary();
    }
}