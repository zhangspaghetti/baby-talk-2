package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Repository;

@Repository
public class DistributionRepository {

    private final DistributionMapper mapper;

    public DistributionRepository(DistributionMapper mapper) {
        this.mapper = mapper;
    }

    public void insertEvent(EventRow row) {
        mapper.insertEvent(row);
    }

    public List<EventRow> listRecentEvents() {
        return mapper.listRecentEvents();
    }

    public record EventRow(
            String entrypoint,
            String releaseChannel,
            String source,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
    }
}
