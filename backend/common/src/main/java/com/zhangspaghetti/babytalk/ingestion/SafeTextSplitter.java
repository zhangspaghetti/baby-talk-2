package com.zhangspaghetti.babytalk.ingestion;

import java.util.ArrayList;
import java.util.List;
import org.springframework.ai.document.Document;

/**
 * Simple text splitter that avoids regex catastrophic backtracking in TokenTextSplitter.
 * Splits by character count with overlap.
 */
public class SafeTextSplitter {

    private final int chunkSize;
    private final int overlap;

    public SafeTextSplitter(int chunkSize, int overlap) {
        this.chunkSize = chunkSize;
        this.overlap = overlap;
    }

    public List<Document> apply(List<Document> documents) {
        List<Document> chunks = new ArrayList<>();
        for (Document doc : documents) {
            String text = doc.getText();
            if (text == null || text.isEmpty()) {
                continue;
            }
            int start = 0;
            while (start < text.length()) {
                int end = Math.min(start + chunkSize, text.length());
                String chunkText = text.substring(start, end);
                Document chunk = new Document(chunkText, doc.getMetadata());
                chunks.add(chunk);
                start += chunkSize - overlap;
            }
        }
        return chunks;
    }
}
