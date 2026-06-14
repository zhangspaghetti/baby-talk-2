---
phase: "01"
plan: "01"
---

# T01: feat: 基础设施层从 H2 切换到 PostgreSQL(pgvector) + MinIO，POM 依赖更新 + docker-compose 添加服务 + V10 迁移

**feat: 基础设施层从 H2 切换到 PostgreSQL(pgvector) + MinIO，POM 依赖更新 + docker-compose 添加服务 + V10 迁移**

## What Happened

将项目数据库基础设施从 H2 完整切换到 PostgreSQL，包含四大部分改动：

**1. pom.xml 依赖切换**

- 移除 H2 数据库依赖
- 添加 PostgreSQL JDBC driver (runtime scope，版本由 Spring Boot 管理)
- 添加 flyway-database-postgresql（Flyway 10.x 必须的 PostgreSQL dialect 模块）
- 添加 spring-ai-starter-vector-store-pgvector（版本由 Spring AI 1.1.4 BOM 管理）
- 添加 MinIO Java SDK 8.5.14
- 添加 Testcontainers（postgresql + junit-jupiter + spring-boot-testcontainers，test scope）

**2. application.yml 配置更新**

- datasource driver 从 org.h2.Driver 切换到 org.postgresql.Driver
- 默认 URL 改为 jdbc:postgresql://localhost:15432/babytalk（15432 是 docker-compose 映射端口）
- 默认 username/password 改为 babytalk/babytalk
- 添加 PgVectorStoreAutoConfiguration 到 autoconfigure exclude 列表（当前不需要自动配置）
- 添加 app.minio 配置块（endpoint, access-key, secret-key, bucket-name）

**3. docker-compose.yml 完整重写**

- 新增 postgres 服务：pgvector/pgvector:pg16 镜像，端口映射 15432:5432（避免 Windows Hyper-V 端口冲突），pg_isready 健康检查
- 新增 minio 服务：minio/minio:latest，MINIO_ROOT_USER/PASSWORD 环境变量，端口 9000(API)+9001(Console)，mc ready local 健康检查
- backend 服务添加 depends_on（postgres + minio 必须 healthy），环境变量注入 PG JDBC URL 和 MinIO 连接信息
- 移除旧的 babytalk-data volume，新增 postgres-data + minio-data volumes

**4. V10 Flyway 迁移**

- CREATE EXTENSION vector + uuid-ossp
- CREATE TABLE vector_store（id UUID + content TEXT + metadata JSONB + embedding vector(1536)）
- CREATE INDEX HNSW idx_vector_store_embedding（vector_cosine_ops）

**端口冲突处理：** 发现 Windows Hyper-V 保留了 5000-5754 端口范围导致 5432/5433 映射均失败，改用 15432。Docker 内部服务间通信不受影响（backend→postgres 仍使用 5432）。

## Verification

Docker 验证全部通过：

1. docker-compose up -d postgres minio — 两个容器成功启动
2. docker-compose ps — postgres 和 minio 均显示 healthy 状态
3. docker exec babytalk-postgres psql -U babytalk -c "SELECT 1" — PostgreSQL 连接正常
4. CREATE EXTENSION vector + uuid-ossp — 扩展加载成功
5. V10 迁移 SQL 手动执行验证 — vector_store 表和 HNSW 索引创建成功
6. curl localhost:9000/minio/health/live — MinIO 健康检查通过
7. \d vector_store — 表结构确认（id UUID, content TEXT, metadata JSONB, embedding vector(1536)）+ HNSW 索引

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `docker-compose up -d postgres minio` | 0 | ✅ pass | 5000ms |
| 2 | `docker-compose ps (check healthy)` | 0 | ✅ pass | 15000ms |
| 3 | `docker exec babytalk-postgres psql -U babytalk -c "SELECT 1"` | 0 | ✅ pass | 500ms |
| 4 | `docker exec babytalk-postgres psql -U babytalk -c "CREATE EXTENSION ... vector_store ..."` | 0 | ✅ pass | 800ms |
| 5 | `curl -sf http://localhost:9000/minio/health/live` | 0 | ✅ pass | 200ms |
| 6 | `docker-compose down -v` | 0 | ✅ pass | 8000ms |

## Deviations

PostgreSQL 端口映射从计划的 5432 改为 15432（Windows Hyper-V 端口保留冲突）

## Known Issues

现有测试仍使用 H2 内存数据库配置（@SpringBootTest properties 中硬编码 h2 URL），需要 T02 切换到 Testcontainers

## Files Created/Modified

- `backend/pom.xml`
- `backend/src/main/resources/application.yml`
- `docker-compose.yml`
- `backend/src/main/resources/db/migration/V10__create_pgvector_and_minio_infra.sql`
