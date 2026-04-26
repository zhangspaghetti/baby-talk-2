-- V11: 创建 ingestion_jobs 表 — 文献导入任务状态跟踪
-- 用于知识宫殿 ingestion 管道，记录每个文件的处理状态

CREATE TABLE IF NOT EXISTS ingestion_jobs (
    id                UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    original_filename VARCHAR(500) NOT NULL,
    minio_object_key  VARCHAR(1000) NOT NULL,
    status            VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    total_chunks      INT          NOT NULL DEFAULT 0,
    error_message     TEXT,
    created_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at        TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 状态值约束：PENDING / PROCESSING / COMPLETED / FAILED
ALTER TABLE ingestion_jobs
    ADD CONSTRAINT chk_ingestion_jobs_status
    CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED'));

-- 按状态查询索引（批量查看待处理/失败的 job）
CREATE INDEX idx_ingestion_jobs_status ON ingestion_jobs (status);

-- 按创建时间排序索引
CREATE INDEX idx_ingestion_jobs_created_at ON ingestion_jobs (created_at DESC);
