package com.zhangspaghetti.babytalk.admin.overview;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.constraints.Size;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@Validated
@RequestMapping("/api/admin/overview")
@PreAuthorize("hasAnyAuthority('rag:read', 'kg:read', 'mentor:audit', 'distribution:read')")
public class AdminOverviewController {

    private static final Set<String> SUMMARY_QUERY_PARAMS = Set.of();
    private static final Set<String> STREAM_QUERY_PARAMS = Set.of("sinceEventId");

    private final AdminOverviewService adminOverviewService;
    private final AdminOverviewStreamService adminOverviewStreamService;

    public AdminOverviewController(
            AdminOverviewService adminOverviewService,
            AdminOverviewStreamService adminOverviewStreamService
    ) {
        this.adminOverviewService = adminOverviewService;
        this.adminOverviewStreamService = adminOverviewStreamService;
    }

    @GetMapping("/summary")
    public AdminOverviewService.OverviewSummaryView getSummary(
            Authentication authentication,
            HttpServletRequest request
    ) {
        rejectUnknownQueryParams(request, SUMMARY_QUERY_PARAMS);
        return adminOverviewService.getSummary(authentication);
    }

    @GetMapping(path = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(
            Authentication authentication,
            HttpServletRequest request,
            @RequestParam(required = false) @Size(max = 64, message = "sinceEventId 过长。") String sinceEventId,
            @RequestHeader(value = "Last-Event-ID", required = false) String lastEventIdHeader
    ) {
        rejectUnknownQueryParams(request, STREAM_QUERY_PARAMS);
        if (authentication == null) {
            throw new AdminApiContractException(
                    HttpStatus.UNAUTHORIZED,
                    "admin_authentication_required",
                    "请先登录管理员账号。",
                    java.util.Map.of());
        }
        var effectiveSinceEventId = normalizeSinceEventId(sinceEventId, lastEventIdHeader);
        return adminOverviewStreamService.subscribe(effectiveSinceEventId);
    }

    private void rejectUnknownQueryParams(HttpServletRequest request, Set<String> allowedParameters) {
        var parameterNames = request.getParameterMap().keySet();
        for (var parameterName : parameterNames) {
            if (!allowedParameters.contains(parameterName)) {
                throw new AdminApiContractException(
                        HttpStatus.BAD_REQUEST,
                        "invalid_overview_query_param",
                        "overview query 不支持该参数。",
                        java.util.Map.of(
                                "parameter", parameterName,
                                "allowedParameters", allowedParameters
                        ));
            }
        }
    }

    private String normalizeSinceEventId(String queryValue, String headerValue) {
        var candidate = queryValue != null ? queryValue : headerValue;
        if (candidate == null) {
            return null;
        }
        if (candidate.isBlank()) {
            throw new AdminApiContractException(
                    HttpStatus.BAD_REQUEST,
                    "invalid_overview_since_event_id",
                    "sinceEventId 不能为空。",
                    java.util.Map.of());
        }
        return candidate.trim();
    }
}
