package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GardenSnapshotService;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/garden")
public class GardenSnapshotController {

    private final GardenSnapshotService gardenSnapshotService;

    public GardenSnapshotController(GardenSnapshotService gardenSnapshotService) {
        this.gardenSnapshotService = gardenSnapshotService;
    }

    @GetMapping("/snapshot")
    public GardenSnapshotService.GardenSnapshotResponse getSnapshot(
            JwtAuthenticationToken authentication
    ) {
        return gardenSnapshotService.loadSnapshot(sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid", "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        if (sid == null || sid.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "consumer_session_invalid", "访问令牌缺少 sid。", java.util.Map.of("field", "sid"));
        }
        return sid;
    }
}
