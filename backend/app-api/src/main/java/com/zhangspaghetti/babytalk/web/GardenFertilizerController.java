package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GardenFertilizerService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/v1/garden/fertilizer")
public class GardenFertilizerController {

    private final GardenFertilizerService gardenFertilizerService;

    public GardenFertilizerController(GardenFertilizerService gardenFertilizerService) {
        this.gardenFertilizerService = gardenFertilizerService;
    }

    @GetMapping
    public GardenFertilizerService.FertilizerStateResponse getState(JwtAuthenticationToken authentication) {
        return gardenFertilizerService.getState(sessionId(authentication));
    }

    @PostMapping("/claim")
    public GardenFertilizerService.ClaimResponse claim(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody ClaimRequest request
    ) {
        return gardenFertilizerService.claim(
                sessionId(authentication),
                request.eventKey(),
                request.requestId(),
                request.clientTime()
        );
    }

    @PostMapping("/apply")
    public GardenFertilizerService.ApplyResponse apply(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody ApplyRequest request
    ) {
        return gardenFertilizerService.apply(
                sessionId(authentication),
                request.requestId(),
                request.clientTime()
        );
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

    public record ClaimRequest(
            @NotBlank @Size(max = 128) String eventKey,
            @NotBlank @Size(max = 128) String requestId,
            Instant clientTime
    ) {
    }

    public record ApplyRequest(
            @NotBlank @Size(max = 128) String requestId,
            Instant clientTime
    ) {
    }
}
