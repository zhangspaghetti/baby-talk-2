---
phase: "05"
plan: "01"
---

# T01: 创建 KG 数据层：V14 Flyway 迁移（pg_trgm + 4 表）、4 个 Java record、4 个 JdbcTemplate Repository、2 个集成测试类，编译全部通过

**创建 KG 数据层：V14 Flyway 迁移（pg_trgm + 4 表）、4 个 Java record、4 个 JdbcTemplate Repository、2 个集成测试类，编译全部通过**

## What Happened

建立 Knowledge Graph 完整数据层基础。

**V14 迁移文件**：创建 `pg_trgm` 扩展和 4 张表 — `kg_entities`（gin_trgm_ops 索引支持模糊搜索）、`kg_relationships`（带 confidence 和 relation_type CHECK）、`kg_contradictions`（状态机 detected→reviewing→escalated→resolved/dismissed）、`kg_admin_notifications`（部分索引 WHERE is_read = FALSE）。所有表使用 UUID PK + gen_random_uuid() 默认值，FK 级联删除。

**4 个 Java record**：`KgEntity`、`KgRelationship`、`KgContradiction`、`KgAdminNotification`，每个提供静态工厂方法（`create`/`detected`）自动生成 ID 和时间戳，包含状态/类型常量。

**4 个 Repository**：遵循 `IngestionRepository` 的 JdbcTemplate + RowMapper 模式。`KgEntityRepository` 提供 pg_trgm `ILIKE + similarity()` 模糊搜索；`KgRelationshipRepository` 提供 `findContradictionCandidatesForEntity` 查询同一 target 不同 source_book 的 supports 关系；`KgContradictionRepository` 提供 `findPendingReview(batchSize)` 批量获取待审查矛盾、`updateStatus`/`updateResolved` 状态变更方法；`KgAdminNotificationRepository` 提供 `findUnread`/`markRead` 通知管理。

**集成测试**：`KgEntityRepositoryTest` 验证 insert+findById 往返、pg_trgm 模糊搜索、wing/room 过滤、update 修改；`KgContradictionRepositoryTest` 验证完整矛盾生命周期（创建实体→关系→矛盾→状态更新→解决），覆盖 findByStatus 过滤和 findPendingReview 批量查询。

## Verification

`mvn compile test-compile -q` 在 backend 目录下静默编译成功（无错误输出），11 个目标文件全部就位。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `cd backend && mvn compile test-compile -q` | 0 | ✅ pass | 33300ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `backend/src/main/resources/db/migration/V14__create_knowledge_graph_tables.sql`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgEntity.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgRelationship.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradiction.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgAdminNotification.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgEntityRepository.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgRelationshipRepository.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgContradictionRepository.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/kg/KgAdminNotificationRepository.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgEntityRepositoryTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/kg/KgContradictionRepositoryTest.java`
