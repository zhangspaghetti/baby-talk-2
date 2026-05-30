package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.service.GardenFertilizerService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
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
        return authentication.getToken().getClaimAsString("sid");
    }

    public record ClaimRequest(
            @NotBlank String eventKey,
            @NotBlank String requestId,
            Instant clientTime
    ) {
    }

    public record ApplyRequest(
            @NotBlank String requestId,
            Instant clientTime
    ) {
    }
}
