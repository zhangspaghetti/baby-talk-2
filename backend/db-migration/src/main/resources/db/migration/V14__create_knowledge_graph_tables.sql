-- Knowledge Graph 表结构：实体、关系、矛盾检测、管理员通知
-- pg_trgm 用于实体名称模糊搜索

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================================
-- kg_entities — 知识实体（概念、建议、里程碑、事实）
-- ============================================================
CREATE TABLE kg_entities (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(255) NOT NULL,
    entity_type      VARCHAR(20)  NOT NULL
        CHECK (entity_type IN ('concept', 'recommendation', 'milestone', 'fact')),
    source_book      VARCHAR(255),
    wing             VARCHAR(100),
    room             VARCHAR(100),
    description      TEXT,
    valid_from_months INTEGER,
    valid_to_months   INTEGER,
    created_at       TIMESTAMP   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMP   NOT NULL DEFAULT now()
);

CREATE INDEX idx_kg_entities_name_trgm ON kg_entities USING gin (name gin_trgm_ops);
CREATE INDEX idx_kg_entities_type ON kg_entities (entity_type);
CREATE INDEX idx_kg_entities_wing_room ON kg_entities (wing, room);

-- ============================================================
-- kg_relationships — 实体之间的关系
-- ============================================================
CREATE TABLE kg_relationships (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    source_entity_id UUID        NOT NULL REFERENCES kg_entities(id) ON DELETE CASCADE,
    target_entity_id UUID        NOT NULL REFERENCES kg_entities(id) ON DELETE CASCADE,
    relation_type    VARCHAR(30) NOT NULL
        CHECK (relation_type IN ('supports', 'contradicts', 'precedes', 'follows',
                                  'part_of', 'related_to', 'causes', 'prevents')),
    source_book      VARCHAR(255),
    confidence       NUMERIC(3,2) NOT NULL DEFAULT 1.00
        CHECK (confidence >= 0.00 AND confidence <= 1.00),
    context_note     TEXT,
    created_at       TIMESTAMP   NOT NULL DEFAULT now(),
    updated_at       TIMESTAMP   NOT NULL DEFAULT now()
);

CREATE INDEX idx_kg_relationships_source ON kg_relationships (source_entity_id);
CREATE INDEX idx_kg_relationships_target ON kg_relationships (target_entity_id);
CREATE INDEX idx_kg_relationships_type ON kg_relationships (relation_type);

-- ============================================================
-- kg_contradictions — 矛盾检测记录
-- ============================================================
CREATE TABLE kg_contradictions (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_topic        VARCHAR(255) NOT NULL,
    relationship_a_id   UUID        NOT NULL REFERENCES kg_relationships(id) ON DELETE CASCADE,
    relationship_b_id   UUID        NOT NULL REFERENCES kg_relationships(id) ON DELETE CASCADE,
    source_a_book       VARCHAR(255),
    source_b_book       VARCHAR(255),
    description         TEXT,
    status              VARCHAR(20) NOT NULL DEFAULT 'detected'
        CHECK (status IN ('detected', 'reviewing', 'escalated', 'resolved', 'dismissed')),
    agent_review_result TEXT,
    admin_notes         TEXT,
    detected_at         TIMESTAMP   NOT NULL DEFAULT now(),
    reviewed_at         TIMESTAMP,
    resolved_at         TIMESTAMP
);

CREATE INDEX idx_kg_contradictions_status ON kg_contradictions (status);

-- ============================================================
-- kg_admin_notifications — 管理员通知
-- ============================================================
CREATE TABLE kg_admin_notifications (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    contradiction_id  UUID        NOT NULL REFERENCES kg_contradictions(id) ON DELETE CASCADE,
    notification_type VARCHAR(30) NOT NULL,
    message           TEXT        NOT NULL,
    is_read           BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at        TIMESTAMP   NOT NULL DEFAULT now()
);

CREATE INDEX idx_kg_admin_notifications_unread ON kg_admin_notifications (is_read) WHERE is_read = FALSE;
CREATE INDEX idx_kg_admin_notifications_contradiction ON kg_admin_notifications (contradiction_id);
