package com.zhangspaghetti.babytalk.config;

import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;
import com.zhangspaghetti.babytalk.web.SafeCorrelationId;

@Component
public class ApiVersionInterceptor implements HandlerInterceptor {

    public static final String VERSION_HEADER = "X-App-Version";
    public static final String MIN_VERSION_HEADER = "X-Min-Supported-Version";
    public static final String UPGRADE_URL_HEADER = "X-Upgrade-Url";

    private final ApiContractProperties properties;
    private final ApiVersionService apiVersionService;
    private final ObjectMapper objectMapper;

    public ApiVersionInterceptor(
            ApiContractProperties properties,
            ApiVersionService apiVersionService,
            ObjectMapper objectMapper
    ) {
        this.properties = properties;
        this.apiVersionService = apiVersionService;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        var providedVersion = request.getHeader(VERSION_HEADER);
        if (providedVersion == null || providedVersion.isBlank()) {
            writeError(response, 426, "app_version_required", "缺少 X-App-Version，请升级客户端。", null);
            return false;
        }

        try {
            if (!apiVersionService.isSupported(providedVersion, properties.minSupportedVersion())) {
                writeError(
                        response,
                        426,
                        "app_version_unsupported",
                        "客户端版本过旧，请升级后再试。",
                        Map.of("providedVersion", providedVersion)
                );
                return false;
            }
        } catch (IllegalArgumentException exception) {
            writeError(response, 400, "invalid_app_version", exception.getMessage(), null);
            return false;
        }

        return true;
    }

    private void writeError(
            HttpServletResponse response,
            int status,
            String code,
            String message,
            Map<String, Object> details
    ) throws Exception {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding("UTF-8");
        response.setHeader(MIN_VERSION_HEADER, properties.minSupportedVersion());
        response.setHeader(UPGRADE_URL_HEADER, properties.upgradeUrl());
        var correlationId = SafeCorrelationId.create();
        response.setHeader("X-Correlation-Id", correlationId);
        objectMapper.writeValue(
                response.getWriter(),
                Map.of(
                        "code", code,
                        "message", message,
                        "minimumSupportedVersion", properties.minSupportedVersion(),
                        "upgradeUrl", properties.upgradeUrl(),
                        "details", details == null ? Map.of() : details,
                        "correlationId", correlationId
                )
        );
    }
}
