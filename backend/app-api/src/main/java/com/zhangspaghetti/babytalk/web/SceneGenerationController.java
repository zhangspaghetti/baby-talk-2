package com.zhangspaghetti.babytalk.web;

import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationRequest;
import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationResponse;
import com.zhangspaghetti.babytalk.practice.scene.SceneGenerationService;
import jakarta.validation.Valid;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/practice/scene-generations")
public class SceneGenerationController {

    private final SceneGenerationService service;

    public SceneGenerationController(SceneGenerationService service) {
        this.service = service;
    }

    @PostMapping
    public SceneGenerationResponse generate(
            JwtAuthenticationToken authentication,
            @Valid @RequestBody SceneGenerationRequest request
    ) {
        if (request == null) {
            throw new SceneGenerationRequest.InvalidSceneSourceException();
        }
        return service.generate(request, sessionId(authentication));
    }

    private String sessionId(JwtAuthenticationToken authentication) {
        if (authentication == null || authentication.getToken() == null) {
            return null;
        }
        var sid = authentication.getToken().getClaimAsString("sid");
        return sid == null || sid.isBlank() ? null : sid;
    }
}
