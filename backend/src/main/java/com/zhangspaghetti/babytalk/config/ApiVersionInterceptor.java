package com.zhangspaghetti.babytalk.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.service.ApiVersionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class ApiVersionInterceptor implements HandlerInterceptor {

    private final ApiVersionService apiVersionService;
    private final ObjectMapper objectMapper;

    public ApiVersionInterceptor(ApiVersionService apiVersionService, ObjectMapper objectMapper) {
        this.apiVersionService = apiVersionService;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }

        String requestedVersion = request.getHeader("X-App-Version");
        if (apiVersionService.isSupported(requestedVersion)) {
            return true;
        }

        response.setStatus(426);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setHeader("X-Current-Version", apiVersionService.currentVersion());
        response.setHeader("X-Min-Supported-Version", apiVersionService.minSupportedVersion());
        objectMapper.writeValue(response.getWriter(), apiVersionService.upgradeRequiredResponse(requestedVersion));
        return false;
    }
}