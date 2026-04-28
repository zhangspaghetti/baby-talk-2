package com.zhangspaghetti.babytalk.ingestion;

import java.util.UUID;

public record IngestionCompletedEvent(UUID jobId, String bookTitle, int totalChunks) {
}
