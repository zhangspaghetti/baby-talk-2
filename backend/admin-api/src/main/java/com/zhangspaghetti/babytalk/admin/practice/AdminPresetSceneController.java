package com.zhangspaghetti.babytalk.admin.practice;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/v1/practice/preset-scenes")
public class AdminPresetSceneController {

    private final AdminPresetSceneService service;

    public AdminPresetSceneController(AdminPresetSceneService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('practice:read')")
    public List<AdminPresetSceneService.SceneSummaryView> listScenes() {
        return service.listScenes();
    }

    @GetMapping("/{presetSceneId}")
    @PreAuthorize("hasAuthority('practice:read')")
    public AdminPresetSceneService.SceneDetailView getScene(@PathVariable String presetSceneId) {
        return service.getScene(presetSceneId);
    }

    @GetMapping("/{presetSceneId}/versions")
    @PreAuthorize("hasAuthority('practice:read')")
    public List<AdminPresetSceneService.PublishedView> versions(@PathVariable String presetSceneId) {
        return service.versions(presetSceneId);
    }

    @PostMapping("/{presetSceneId}/draft")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('practice:write')")
    public AdminPresetSceneService.DraftView createDraft(
            @PathVariable String presetSceneId,
            @Valid @RequestBody DraftRequest request,
            JwtAuthenticationToken authentication
    ) {
        return service.createDraft(presetSceneId, request.command(), principalId(authentication));
    }

    @PutMapping("/{presetSceneId}/draft")
    @PreAuthorize("hasAuthority('practice:write')")
    public AdminPresetSceneService.DraftView updateDraft(
            @PathVariable String presetSceneId,
            @Valid @RequestBody DraftRequest request,
            JwtAuthenticationToken authentication
    ) {
        return service.updateDraft(presetSceneId, request.command(), principalId(authentication));
    }

    @PostMapping("/{presetSceneId}/publish")
    @PreAuthorize("hasAuthority('practice:publish')")
    public AdminPresetSceneService.PublishedView publish(
            @PathVariable String presetSceneId,
            @Valid @RequestBody PublishRequest request,
            JwtAuthenticationToken authentication
    ) {
        return service.publish(
                presetSceneId,
                new AdminPresetSceneService.PublishCommand(request.lockVersion()),
                principalId(authentication));
    }

    @PostMapping("/{presetSceneId}/rollback/{version}")
    @PreAuthorize("hasAuthority('practice:publish')")
    public AdminPresetSceneService.PublishedView rollback(
            @PathVariable String presetSceneId,
            @PathVariable @Min(1) int version,
            JwtAuthenticationToken authentication
    ) {
        return service.rollback(presetSceneId, version, principalId(authentication));
    }

    private String principalId(JwtAuthenticationToken authentication) {
        return authentication.getToken().getSubject();
    }

    public record DraftRequest(
            @NotBlank(message = "title 不能为空。")
            @Size(max = 120, message = "title 过长。")
            String title,
            @NotBlank(message = "summary 不能为空。")
            @Size(max = 240, message = "summary 过长。")
            String summary,
            @NotBlank(message = "sceneTag 不能为空。")
            @Size(max = 120, message = "sceneTag 过长。")
            String sceneTag,
            @NotBlank(message = "coachTip 不能为空。")
            @Size(max = 240, message = "coachTip 过长。")
            String coachTip,
            @Min(value = 0, message = "sortOrder 不能小于 0。")
            int sortOrder,
            @NotBlank(message = "generationBrief 不能为空。")
            @Size(max = 1200, message = "generationBrief 过长。")
            String generationBrief,
            boolean enabled,
            @Min(value = 0, message = "lockVersion 不能小于 0。")
            int lockVersion
    ) {

        AdminPresetSceneService.DraftCommand command() {
            return new AdminPresetSceneService.DraftCommand(
                    title,
                    summary,
                    sceneTag,
                    coachTip,
                    sortOrder,
                    generationBrief,
                    enabled,
                    lockVersion);
        }
    }

    public record PublishRequest(
            @Min(value = 0, message = "lockVersion 不能小于 0。")
            @Max(value = Integer.MAX_VALUE, message = "lockVersion 过大。")
            int lockVersion
    ) {
    }
}
