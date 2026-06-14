# S05 Research — Knowledge Graph + 矛盾检测

## 1. 现有代码模式摘要

### DB Migration 模式

- Flyway 管理，当前最新 V11
- S05 新迁移应为 **V12__create_knowledge_graph_tables.sql**
- 表名用 snake_case，UUID 主键（`uuid_generate_v4()`），`TIMESTAMP WITH TIME ZONE`，使用 CHECK 约束限定枚举值
- 示例：`ingestion_jobs` 表结构清晰，有状态约束 + 索引

### Repository 模式

- 纯 `JdbcTemplate`，无 Spring Data JPA
- `@Repository` 注解，构造函数注入 JdbcTemplate
- RowMapper 用静态方法或 lambda
- CRUD 拆为独立方法（insert / updateXxx / findByXxx）

### 异步处理模式

- `@EnableAsync` + `ThreadPoolTaskExecutor` bean
- `@Async("executorName")` 注解在 Service 方法上
- **没有 `@Scheduled` 基础设施** — S05 需要新增 `@EnableScheduling`

### AI 调用模式

- 手动构建 `OpenAiApi → OpenAiChatModel → ChatClient`（见 `MentorProviderConfiguration`）
- 配置通过 `@ConfigurationProperties` record 绑定
- 异常处理：递归搜索 cause chain + 语义化领域异常

### 通知基础设施

- **不存在** — 无任何 notification/email/push 代码
- S05 将是第一个引入通知概念的 slice

---

## 2. Knowledge Graph Schema 设计

### V12__create_knowledge_graph_tables.sql

```sql
-- ═══ kg_entities: 知识实体 ═══
CREATE TABLE IF NOT EXISTS kg_entities (
    id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name              VARCHAR(500) NOT NULL,       -- 实体名称（如 "婴儿6月龄可以开始辅食"）
    entity_type       VARCHAR(100) NOT NULL,       -- 类型：concept / recommendation / milestone / fact
    source_book       VARCHAR(300),                -- 来源书籍
    wing              VARCHAR(100),                -- 宫殿翼楼坐标
    room              VARCHAR(100),                -- 宫殿房间坐标
    description       TEXT,                        -- 详细描述
    valid_from_months INT,                         -- 适用起始月龄（可选）
    valid_to_months   INT,                         -- 适用终止月龄（可选）
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_kg_entities_type ON kg_entities (entity_type);
CREATE INDEX idx_kg_entities_wing_room ON kg_entities (wing, room);
CREATE INDEX idx_kg_entities_name_trgm ON kg_entities USING gin (name gin_trgm_ops);
-- 注意: 需要 CREATE EXTENSION IF NOT EXISTS pg_trgm; 放在迁移顶部

-- ═══ kg_relationships: 实体关系 ═══
CREATE TABLE IF NOT EXISTS kg_relationships (
    id                  UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    source_entity_id    UUID NOT NULL REFERENCES kg_entities(id),
    target_entity_id    UUID NOT NULL REFERENCES kg_entities(id),
    relation_type       VARCHAR(100) NOT NULL,     -- supports / contradicts / refines / supersedes / causes
    source_book         VARCHAR(300),              -- 产生该关系的来源
    confidence          NUMERIC(3,2) DEFAULT 0.80, -- 置信度 0.00-1.00
    context_note        TEXT,                      -- 关系上下文说明
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT chk_kg_rel_type CHECK (relation_type IN (
        'supports', 'contradicts', 'refines', 'supersedes', 'causes', 'related_to'
    )),
    CONSTRAINT chk_kg_confidence CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX idx_kg_relationships_source ON kg_relationships (source_entity_id);
CREATE INDEX idx_kg_relationships_target ON kg_relationships (target_entity_id);
CREATE INDEX idx_kg_relationships_type ON kg_relationships (relation_type);

-- ═══ kg_contradictions: 矛盾记录 ═══
CREATE TABLE IF NOT EXISTS kg_contradictions (
    id                  UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    entity_topic        VARCHAR(500) NOT NULL,     -- 矛盾主题
    relationship_a_id   UUID NOT NULL REFERENCES kg_relationships(id),
    relationship_b_id   UUID NOT NULL REFERENCES kg_relationships(id),
    source_a_book       VARCHAR(300),
    source_b_book       VARCHAR(300),
    description         TEXT NOT NULL,             -- 矛盾描述
    status              VARCHAR(20) NOT NULL DEFAULT 'detected',
    agent_review_result TEXT,                      -- agent 审查结论
    admin_notes         TEXT,                      -- 管理员备注
    detected_at         TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    reviewed_at         TIMESTAMP WITH TIME ZONE,
    resolved_at         TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_kg_contradiction_status CHECK (status IN (
        'detected', 'reviewing', 'resolved', 'escalated'
    ))
);

CREATE INDEX idx_kg_contradictions_status ON kg_contradictions (status);
CREATE INDEX idx_kg_contradictions_detected ON kg_contradictions (detected_at DESC);

-- ═══ kg_admin_notifications: 管理员通知 ═══
CREATE TABLE IF NOT EXISTS kg_admin_notifications (
    id                  UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    contradiction_id    UUID NOT NULL REFERENCES kg_contradictions(id),
    notification_type   VARCHAR(50) NOT NULL DEFAULT 'contradiction_escalated',
    message             TEXT NOT NULL,
    is_read             BOOLEAN NOT NULL DEFAULT false,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

CREATE INDEX idx_kg_notifications_unread ON kg_admin_notifications (is_read, created_at DESC);
```

---

## 3. 矛盾检测算法设计

### 触发时机

当 `IngestionService` 或未来的 KG 写入管道新增一条 `relation_type = 'supports'` 的关系时：

```
检测逻辑：

1. 获取新关系的 target_entity（建议主题）
2. 查询 kg_relationships 中所有指向同一 target_entity 且 relation_type 为 'supports' 的现有关系
3. 对比新关系的 source_entity 与现有关系的 source_entity：
   - 如果两个 source_entity 的含义相反（需 LLM 判断或预定义规则）
   - 且来自不同 source_book
   → 标记为潜在矛盾

4. 插入 kg_contradictions 记录（status = 'detected'）

```

### 简化版（Phase 1）

Phase 1 不做实时 LLM 判断。改为：

- 当 `relation_type = 'contradicts'` 的关系被直接写入时，自动创建 contradiction 记录
- 批量扫描：定时任务扫描同一 topic 下的 supports 关系，按 source_book 分组，对比年龄窗口重叠时标记

---

## 4. Agent 自动审查设计

### KgContradictionReviewService

```java
@Service
public class KgContradictionReviewService {

    private final ChatClient chatClient;          // 复用 MentorProviderConfiguration 模式
    private final KgContradictionRepository repo;
    private final KgAdminNotificationRepository notifRepo;

    // 定时扫描 status='detected' 的矛盾记录
    @Scheduled(fixedDelayString = "${app.kg.review-interval:PT30M}")
    public void reviewPendingContradictions() { ... }

    // 单条审查
    public void reviewContradiction(UUID contradictionId) {
        // 1. 加载矛盾详情 + 两侧关系 + 实体
        // 2. 构建 prompt 让 LLM 判断
        // 3. LLM 判定结果：
        //    - "可消解" → status = resolved, agent_review_result = 理由
        //    - "确认矛盾" → status = escalated → 创建 admin_notification
        //    - "需要更多上下文" → status = escalated
    }
}
```

### Agent Review Prompt 模板

```
你是育儿知识图谱审查 agent。以下两条建议被标记为潜在矛盾：

来源A: 《{bookA}》— {entityA_description}
来源B: 《{bookB}》— {entityB_description}
主题: {topic}

请判断：

1. 这是否是真正的矛盾？（可能只是不同年龄段的建议、不同情境的建议、或互补而非冲突）
2. 如果是真矛盾，简要说明冲突点

输出 JSON：
{"verdict": "resolved|escalated", "reasoning": "..."}
```

---

## 5. 管理员通知设计

### REST API

```
GET  /api/v1/kg/notifications             — 获取通知列表（支持 ?unread=true 过滤）
PUT  /api/v1/kg/notifications/{id}/read    — 标记为已读
GET  /api/v1/kg/contradictions             — 获取矛盾列表（支持 ?status=escalated 过滤）
PUT  /api/v1/kg/contradictions/{id}/resolve — 管理员手动解决矛盾
```

### 通知触发流程

```
矛盾检测 → status=detected
    ↓
Agent 审查 → verdict=escalated
    ↓
KgAdminNotificationRepository.insert(contradictionId, message)
    ↓
管理员通过 API 查看 → is_read=true → 手动 resolve
```

**Phase 1 不做 email/push** — 纯 API + 审计表，管理员主动拉取。

---

## 6. S03 Agentic Tool 集成点

S03 的 agentic search 注册了 `kg_query_entity` 工具。S05 需要提供：

```java
/**

 * 供 Agentic Search (S03) 调用的 KG 查询工具。
 * 注册为 Spring AI @Tool 或 Function bean，让 ChatClient.tools() 可使用。
 */
@Service
public class KgQueryTool {

    private final KgEntityRepository entityRepo;
    private final KgRelationshipRepository relRepo;

    /**

     * 查询指定实体的知识图谱关系。
     * @param entityName 实体名称（模糊匹配）
     * @return 结构化的实体 + 关系 JSON
     */
    public String queryEntity(String entityName) {
        // 1. pg_trgm 模糊搜索 entity
        // 2. 获取该 entity 的所有关系
        // 3. 拼装为 LLM 可读的文本
        return formatted;
    }
}
```

注册方式：在 S03 的 Agentic config 中 `.tools(kgQueryTool)` — 但 S03 尚未实现 agentic 调用层，所以 S05 先实现 tool service，S03 后续集成。

---

## 7. 配置属性设计

```yaml

# application.yml 新增

app:
  kg:
    review-interval: ${BABY_TALK_KG_REVIEW_INTERVAL:PT30M}    # agent 审查轮询间隔
    review-enabled: ${BABY_TALK_KG_REVIEW_ENABLED:true}       # 是否开启自动审查
    review-batch-size: ${BABY_TALK_KG_REVIEW_BATCH_SIZE:10}   # 每轮最多审查条数
```

对应 ConfigurationProperties record:

```java
@ConfigurationProperties(prefix = "app.kg")
public record KgProperties(
    Duration reviewInterval,
    boolean reviewEnabled,
    int reviewBatchSize
) {}
```

---

## 8. 包结构建议

```
com.zhangspaghetti.babytalk.kg/
├── KgEntity.java                    // record
├── KgRelationship.java              // record
├── KgContradiction.java             // record
├── KgAdminNotification.java         // record
├── KgEntityRepository.java          // JdbcTemplate
├── KgRelationshipRepository.java    // JdbcTemplate
├── KgContradictionRepository.java   // JdbcTemplate
├── KgAdminNotificationRepository.java
├── KgContradictionDetector.java     // 矛盾检测逻辑
├── KgContradictionReviewService.java // agent 自动审查（@Scheduled）
├── KgQueryTool.java                 // S03 agentic tool 入口
├── KgProperties.java                // 配置属性
├── KgConfiguration.java             // @EnableScheduling + beans
└── KgController.java                // REST endpoints
```

---

## 9. 关键设计决策（供 Planner 参考）

| 决策点 | 建议 | 理由 |
|--------|------|------|
| entity_type 枚举 | DB CHECK 约束 + Java enum | 防止脏数据，但允许迁移扩展 |
| 矛盾检测触发 | 写入时 + 定时批量 | 写入时捕获明确 contradicts 关系；批量扫描捕获隐式冲突 |
| Agent 审查 LLM 实例 | 复用 MentorProviderConfiguration 模式 | 代码复用，配置统一 |
| 管理员通知 | 纯 DB + REST API | Phase 1 无 email/push，YAGNI |
| pg_trgm 模糊搜索 | entity name 索引 | 支持 `kg_query_entity` 工具的模糊匹配 |
| @EnableScheduling | 新增到 KgConfiguration | 首次引入定时任务；如果 review-enabled=false 则跳过 |

---

## 10. 风险与注意事项

1. **pg_trgm 扩展** — 需在迁移中 `CREATE EXTENSION IF NOT EXISTS pg_trgm`，docker-compose 的 PostgreSQL 镜像默认支持
2. **ChatClient 并发** — `@Scheduled` 审查与 Mentor 请求共享 AI API key，需注意速率限制。建议 KG review 使用独立 ChatClient 实例或更低优先级模型
3. **循环依赖** — KgContradictionDetector 在 IngestionService 调用链内触发时，避免形成 Service 循环引用。用事件（ApplicationEventPublisher）解耦
4. **测试策略** — Repository 层用 `@JdbcTest`；DetectionService / ReviewService 用 Mockito mock Repository + ChatClient
5. **S03 集成** — `KgQueryTool` 对外接口先稳定，S03 agentic 层后续通过 `.tools(kgQueryTool)` 注册
