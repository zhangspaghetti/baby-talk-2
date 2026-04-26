package com.zhangspaghetti.babytalk.admin.overview;

import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.time.Clock;
import java.time.Instant;
import java.util.Objects;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class AdminOverviewStreamService {

    private static final Logger log = LoggerFactory.getLogger(AdminOverviewStreamService.class);

    private static final long EMITTER_TIMEOUT_MS = 30_000L;
    private static final long HEARTBEAT_INTERVAL_SECONDS = 10L;

    private final Clock clock;
    private final ScheduledExecutorService scheduler;
    private final ConcurrentMap<Long, Subscriber> subscribers = new ConcurrentHashMap<>();
    private final AtomicLong subscriberIds = new AtomicLong();
    private final AtomicLong eventIds = new AtomicLong();
    private final AtomicLong connectionCount = new AtomicLong();
    private final AtomicLong reconnectCount = new AtomicLong();

    private volatile TransportState state;

    public AdminOverviewStreamService(Clock clock) {
        this.clock = clock;
        this.scheduler = Executors.newSingleThreadScheduledExecutor(runnable -> {
            var thread = new Thread(runnable, "admin-overview-stream");
            thread.setDaemon(true);
            return thread;
        });
        this.state = new TransportState(nextEventId(), "live", null, Instant.now(clock), null);
    }

    public SseEmitter subscribe(String sinceEventId) {
        connectionCount.incrementAndGet();
        var replayed = sinceEventId != null && !sinceEventId.isBlank();
        if (replayed) {
            reconnectCount.incrementAndGet();
        }

        var subscriberId = subscriberIds.incrementAndGet();
        var emitter = new SseEmitter(EMITTER_TIMEOUT_MS);
        var subscriber = new Subscriber(subscriberId, emitter);
        subscribers.put(subscriberId, subscriber);

        emitter.onCompletion(() -> removeSubscriber(subscriberId, "complete"));
        emitter.onTimeout(() -> {
            emitter.complete();
            removeSubscriber(subscriberId, "timeout");
        });
        emitter.onError(error -> removeSubscriber(subscriberId, "error"));

        subscriber.heartbeat = scheduler.scheduleAtFixedRate(
                () -> sendHeartbeat(subscriberId),
                HEARTBEAT_INTERVAL_SECONDS,
                HEARTBEAT_INTERVAL_SECONDS,
                TimeUnit.SECONDS
        );

        sendTransport(subscriberId, replayed);
        log.info(
                "admin-overview stream subscribed. subscriberId={} replayed={} activeSubscribers={}",
                subscriberId,
                replayed,
                subscribers.size()
        );
        return emitter;
    }

    public TransportView markLive(Instant lastSuccessfulSnapshotAt, String reason) {
        return updateState("live", null, lastSuccessfulSnapshotAt, reason);
    }

    public TransportView markPollingRequired(Instant lastSuccessfulSnapshotAt, String reason) {
        return updateState("polling_required", reason, lastSuccessfulSnapshotAt, reason);
    }

    public TransportView currentView() {
        return state.toView(false, subscribers.size(), connectionCount.get(), reconnectCount.get());
    }

    @PreDestroy
    void shutdown() {
        for (var subscriberId : subscribers.keySet()) {
            removeSubscriber(subscriberId, "shutdown");
        }
        scheduler.shutdownNow();
    }

    private synchronized TransportView updateState(
            String mode,
            String degradedReason,
            Instant lastSuccessfulSnapshotAt,
            String reason
    ) {
        state = new TransportState(
                nextEventId(),
                mode,
                degradedReason,
                Instant.now(clock),
                lastSuccessfulSnapshotAt
        );
        var view = state.toView(false, subscribers.size(), connectionCount.get(), reconnectCount.get());
        broadcastTransport(view);
        log.info(
                "admin-overview transport updated. mode={} degradedReason={} lastSuccessfulSnapshotAt={} reason={}",
                mode,
                degradedReason,
                lastSuccessfulSnapshotAt,
                reason == null ? "n/a" : reason
        );
        return view;
    }

    private void broadcastTransport(TransportView view) {
        for (var subscriberId : subscribers.keySet()) {
            sendEvent(subscriberId, "transport", view, true);
        }
    }

    private void sendTransport(long subscriberId, boolean replayed) {
        var current = state.toView(replayed, subscribers.size(), connectionCount.get(), reconnectCount.get());
        sendEvent(subscriberId, "transport", current, true);
    }

    private void sendHeartbeat(long subscriberId) {
        var current = state.toView(false, subscribers.size(), connectionCount.get(), reconnectCount.get());
        sendEvent(
                subscriberId,
                "heartbeat",
                new HeartbeatView(
                        current.mode(),
                        current.degradedReason(),
                        current.emittedAt(),
                        current.lastSuccessfulSnapshotAt(),
                        current.activeSubscriberCount()
                ),
                false
        );
    }

    private void sendEvent(long subscriberId, String eventName, Object payload, boolean includeEventId) {
        var subscriber = subscribers.get(subscriberId);
        if (subscriber == null) {
            return;
        }

        try {
            var builder = SseEmitter.event().name(eventName);
            if (includeEventId && payload instanceof TransportView transportView) {
                builder.id(transportView.eventId());
            }
            subscriber.emitter.send(builder.data(payload));
        } catch (IOException | IllegalStateException exception) {
            removeSubscriber(subscriberId, "send-failed");
            log.info(
                    "admin-overview stream subscriber dropped. subscriberId={} event={} message={}",
                    subscriberId,
                    eventName,
                    exception.getMessage()
            );
        }
    }

    private void removeSubscriber(long subscriberId, String reason) {
        var subscriber = subscribers.remove(subscriberId);
        if (subscriber == null) {
            return;
        }
        var heartbeat = subscriber.heartbeat;
        if (heartbeat != null) {
            heartbeat.cancel(true);
        }
        log.info(
                "admin-overview stream unsubscribed. subscriberId={} reason={} activeSubscribers={}",
                subscriberId,
                reason,
                subscribers.size()
        );
    }

    private String nextEventId() {
        return Long.toString(eventIds.incrementAndGet());
    }

    private static final class Subscriber {

        private final long id;
        private final SseEmitter emitter;
        private volatile ScheduledFuture<?> heartbeat;

        private Subscriber(long id, SseEmitter emitter) {
            this.id = id;
            this.emitter = emitter;
        }
    }

    private record TransportState(
            String eventId,
            String mode,
            String degradedReason,
            Instant emittedAt,
            Instant lastSuccessfulSnapshotAt
    ) {

        private TransportView toView(
                boolean replayed,
                int activeSubscriberCount,
                long connectionCount,
                long reconnectCount
        ) {
            return new TransportView(
                    eventId,
                    mode,
                    degradedReason,
                    emittedAt,
                    lastSuccessfulSnapshotAt,
                    activeSubscriberCount,
                    connectionCount,
                    reconnectCount,
                    replayed
            );
        }
    }

    public record TransportView(
            String eventId,
            String mode,
            String degradedReason,
            Instant emittedAt,
            Instant lastSuccessfulSnapshotAt,
            int activeSubscriberCount,
            long connectionCount,
            long reconnectCount,
            boolean replayed
    ) {
        public TransportView {
            Objects.requireNonNull(eventId, "eventId");
            Objects.requireNonNull(mode, "mode");
            Objects.requireNonNull(emittedAt, "emittedAt");
        }
    }

    public record HeartbeatView(
            String mode,
            String degradedReason,
            Instant emittedAt,
            Instant lastSuccessfulSnapshotAt,
            int activeSubscriberCount
    ) {
    }
}
