package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.ApiVersionService;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/config")
@CrossOrigin(originPatterns = "*")
public class ConfigController {

    private final ApiVersionService apiVersionService;

    public ConfigController(ApiVersionService apiVersionService) {
        this.apiVersionService = apiVersionService;
    }

    @GetMapping("/version")
    public BabyTalkPayloads.ApiVersionResponse versionStatus(
            @RequestHeader(value = "X-App-Version", required = false) String requestedVersion
    ) {
        return apiVersionService.versionStatus(requestedVersion);
    }
}