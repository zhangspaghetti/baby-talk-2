package com.zhangspaghetti.babytalk.kg;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Repository;

/**
 * kg_admin_notifications 表 CRUD — 使用 MyBatis mapper 操作。
 */
@Repository
public class KgAdminNotificationRepository {

    private final KgAdminNotificationMapper mapper;

    public KgAdminNotificationRepository(KgAdminNotificationMapper mapper) {
        this.mapper = mapper;
    }

    /** 插入新通知 */
    public void insert(KgAdminNotification notification) {
        mapper.insert(notification);
    }

    /** 查询所有未读通知 */
    public List<KgAdminNotification> findUnread() {
        return mapper.findUnread();
    }

    /** 标记为已读 */
    public void markRead(UUID id) {
        mapper.markRead(id);
    }

    /** 查询所有通知 */
    public List<KgAdminNotification> findAll() {
        return mapper.findAll();
    }

    /** 按 ID 查询 */
    public Optional<KgAdminNotification> findById(UUID id) {
        return Optional.ofNullable(mapper.findById(id));
    }

    /** 按矛盾 ID 查询通知 */
    public List<KgAdminNotification> findByContradictionId(UUID contradictionId) {
        return mapper.findByContradictionId(contradictionId);
    }
}
