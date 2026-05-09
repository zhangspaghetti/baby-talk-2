package com.zhangspaghetti.babytalk.ingestion;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.zhangspaghetti.babytalk.config.MinioProperties;
import io.minio.MinioClient;
import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.time.Duration;
import java.util.UUID;
import java.util.concurrent.Executor;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.context.ApplicationEventPublisher;

class IngestionServiceTest {

    @Test
    void completeProcessingPublishesCompletedEventAfterRepositoryUpdate() throws Exception {
        IngestionRepository repository = mock(IngestionRepository.class);
        ApplicationEventPublisher publisher = mock(ApplicationEventPublisher.class);
        IngestionService service = newService(repository, publisher);
        UUID jobId = UUID.randomUUID();

        invokeCompleteProcessing(service, jobId, "Book Title", null, processingOutcome(7));

        ArgumentCaptor<IngestionCompletedEvent> eventCaptor = ArgumentCaptor.forClass(IngestionCompletedEvent.class);
        InOrder inOrder = inOrder(repository, publisher);
        inOrder.verify(repository).updateCompleted(jobId, 7);
        inOrder.verify(publisher).publishEvent(eventCaptor.capture());
        verify(repository, never()).updateFailed(any(), any());

        IngestionCompletedEvent event = eventCaptor.getValue();
        assertThat(event.jobId()).isEqualTo(jobId);
        assertThat(event.bookTitle()).isEqualTo("Book Title");
        assertThat(event.totalChunks()).isEqualTo(7);
    }

    @Test
    void completeProcessingDoesNotPublishEventWhenProcessingFails() throws Exception {
        IngestionRepository repository = mock(IngestionRepository.class);
        ApplicationEventPublisher publisher = mock(ApplicationEventPublisher.class);
        IngestionService service = newService(repository, publisher);
        UUID jobId = UUID.randomUUID();

        invokeCompleteProcessing(service, jobId, "Book Title", new RuntimeException("boom"), null);

        verify(repository).updateFailed(eq(jobId), eq("VECTOR_STORE: boom"));
        verify(publisher, never()).publishEvent(any());
    }

    private IngestionService newService(IngestionRepository repository, ApplicationEventPublisher publisher) {
        MinioClient minioClient = mock(MinioClient.class);
        VectorStore vectorStore = mock(VectorStore.class);
        Executor executor = Runnable::run;
        return new IngestionService(
                minioClient,
                new MinioProperties("http://localhost:9000", "access", "secret", "bucket"),
                repository,
                vectorStore,
                executor,
                Duration.ofSeconds(5),
                50,
                5_000_000L,
                publisher
        );
    }

    private void invokeCompleteProcessing(IngestionService service,
                                          UUID jobId,
                                          String bookTitle,
                                          Throwable throwable,
                                          Object outcome) throws Exception {
        Method method = IngestionService.class.getDeclaredMethod(
                "completeProcessing",
                UUID.class,
                String.class,
                Throwable.class,
                outcomeClass()
        );
        method.setAccessible(true);
        method.invoke(service, jobId, bookTitle, throwable, outcome);
    }

    private Object processingOutcome(int totalChunks) throws Exception {
        Constructor<?> constructor = outcomeClass().getDeclaredConstructor(int.class);
        constructor.setAccessible(true);
        return constructor.newInstance(totalChunks);
    }

    private Class<?> outcomeClass() throws ClassNotFoundException {
        return Class.forName("com.zhangspaghetti.babytalk.ingestion.IngestionService$ProcessingOutcome");
    }
}
