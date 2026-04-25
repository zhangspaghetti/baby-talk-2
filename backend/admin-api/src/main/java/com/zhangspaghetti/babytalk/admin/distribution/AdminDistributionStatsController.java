package com.zhangspaghetti.babytalk.admin.distribution;

import jakarta.validation.constraints.Size;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/distribution")
@Validated
@PreAuthorize("hasAuthority('distribution:read')")
public class AdminDistributionStatsController {

    private final AdminDistributionStatsService adminDistributionStatsService;

    public AdminDistributionStatsController(AdminDistributionStatsService adminDistributionStatsService) {
        this.adminDistributionStatsService = adminDistributionStatsService;
    }

    @GetMapping("/stats")
    public AdminDistributionStatsService.DistributionStatsView getStats(
            @RequestParam(required = false) @Size(max = 8, message = "range 过长。") String range,
            @RequestParam(required = false) @Size(max = 16, message = "channel 过长。") String channel
    ) {
        return adminDistributionStatsService.getStats(range, channel);
    }
}
