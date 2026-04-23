-- V12: 为 vector_store 添加 PostgreSQL 全文搜索支持
-- tsvector 计算列 + GIN 索引，用于关键词检索（与向量检索互补）
-- 使用 'simple' 配置：不做词干提取，适合中英混合文本

ALTER TABLE vector_store
    ADD COLUMN content_tsv tsvector
    GENERATED ALWAYS AS (to_tsvector('simple', coalesce(content, ''))) STORED;

CREATE INDEX idx_vector_store_content_tsv
    ON vector_store USING gin (content_tsv);
