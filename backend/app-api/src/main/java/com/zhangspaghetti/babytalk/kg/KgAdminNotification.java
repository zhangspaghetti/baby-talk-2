package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.UUID;

/**
 * 管理员通知 — 对应 kg_admin_notifications 表。
 *
 * <p>当矛盾需要管理员介入时，系统创建通知记录。
 */
public record KgAdminNotification(
        UUID id,
        UUID contradictionId,
        String notificationType,
        String message,
        boolean isRead,
        Instant createdAt
) {

    /** 创建新通知（未读状态） */
    public static KgAdminNotification create(UUID contradictionId,
                                              String notificationType,
                                              String message) {
        return new KgAdminNotification(UUID.randomUUID(), contradictionId,
                notificationType, message, false, Instant.now());
    }
}
