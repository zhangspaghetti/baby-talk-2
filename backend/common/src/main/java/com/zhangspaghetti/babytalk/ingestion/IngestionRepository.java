package com.zhangspaghetti.babytalk.ingestion;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

@Repository
public class IngestionRepository {

    private final IngestionMapper ingestionMapper;

    public IngestionRepository(IngestionMapper ingestionMapper) {
        this.ingestionMapper = ingestionMapper;
    }

    public void insert(IngestionJob job) {
        ingestionMapper.insert(job);
    }

    public void updateStatusProcessing(UUID jobId) {
        ingestionMapper.updateStatusProcessing(jobId, Instant.now());
    }

    public void updateCompleted(UUID jobId, int totalChunks) {
        ingestionMapper.updateCompleted(jobId, totalChunks, Instant.now());
    }

    public void updateFailed(UUID jobId, String errorMessage) {
        ingestionMapper.updateFailed(jobId, truncate(errorMessage), Instant.now());
    }

    public Optional<IngestionJob> findById(UUID jobId) {
        return Optional.ofNullable(ingestionMapper.findById(jobId));
    }

    public List<IngestionJob> findAll() {
        return ingestionMapper.findAll();
    }

    public void updateStatusPending(UUID jobId) {
        ingestionMapper.updateStatusPending(jobId, Instant.now());
    }

    public List<IngestionJob> findByStatus(String status) {
        return ingestionMapper.findByStatus(status);
    }

    private static String truncate(String errorMessage) {
        if (errorMessage == null) {
            return null;
        }
        return errorMessage.substring(0, Math.min(errorMessage.length(), 2000));
    }
}
