-- V10: Enable pgvector + uuid-ossp extensions, create vector_store table with HNSW index
-- 这是 AI 语义搜索和 RAG 功能的基础设施表

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Spring AI PgVectorStore 默认表结构
-- embedding 维度 1536 对应 OpenAI text-embedding-3-small / ada-002 模型
CREATE TABLE IF NOT EXISTS vector_store (
    id         UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    content    TEXT NOT NULL,
    metadata   JSONB,
    embedding  vector(1536)
);

-- HNSW 索引加速余弦相似度搜索
CREATE INDEX IF NOT EXISTS idx_vector_store_embedding
    ON vector_store USING hnsw (embedding vector_cosine_ops);
