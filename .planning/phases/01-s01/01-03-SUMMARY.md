---
phase: "01"
plan: "03"
---

# T03: feat: MinIO 配置 Bean (Properties/Client/HealthIndicator) + Helm chart 添加 MinIO secrets + actuator/health 端到端验证 db+minio 均 UP

**feat: MinIO 配置 Bean (Properties/Client/HealthIndicator) + Helm chart 添加 MinIO secrets + actuator/health 端到端验证 db+minio 均 UP**

## What Happened

完成 MinIO 客户端 Spring Boot 集成和 Helm chart 更新，闭合 S01 全栈基础设施 slice。

**1. MinioProperties.java** — 使用项目统一的 record + @Validated + @ConfigurationProperties 模式，绑定 `app.minio.*` 前缀，包含 endpoint/accessKey/secretKey/bucketName 四个 @NotBlank 字段。由 @ConfigurationPropertiesScan 自动发现。

**2. MinioClientConfiguration.java** — @Configuration 类注册 MinioClient bean，使用 `MinioClient.builder().endpoint().credentials().build()` 标准构建模式。

**3. MinioHealthIndicator.java** — 实现 Spring Boot HealthIndicator 接口，通过 `minioClient.bucketExists()` 检测 MinIO 连通性。遵循约束：只检测连通性，不创建 bucket（bucket 创建由 S02 ingestion 管道负责）。健康响应包含 endpoint、bucket 名称和 bucketExists 状态。

**4. application.yml 更新** — 添加 `management.endpoint.health.show-details: always` 和 `show-components: always`，使 `/actuator/health` 返回完整组件详情（包含 db 和 minio 状态），满足 slice 验证要求。

**5. Helm values.yaml 和 values-production.yaml** — secret 块添加 BABY_TALK_MINIO_ENDPOINT / ACCESS_KEY / SECRET_KEY / BUCKET 四个条目，production 文件附带阿里云 OSS / AWS S3 兼容存储的注释说明。

**端到端验证：** docker-compose up postgres + minio → 本地 mvn package → java -jar 启动 backend → curl /actuator/health 返回 `{"status":"UP","components":{"db":{"status":"UP","details":{"database":"PostgreSQL"}},"minio":{"status":"UP","details":{"endpoint":"http://localhost:9000","bucket":"babytalk","bucketExists":false}}}}` — db 和 minio 均为 UP。Docker backend 镜像构建因 Docker Hub 镜像仓库 429 限流暂时失败，改用本地 JAR 验证等效功能。

## Verification

端到端验证全部通过：

1. docker-compose up -d postgres minio — 两个容器启动，状态均为 healthy
2. mvn package -DskipTests — 编译通过，MinioProperties/MinioClientConfiguration/MinioHealthIndicator 无编译错误
3. java -jar 启动 backend 连接 localhost:15432 (PostgreSQL) + localhost:9000 (MinIO) — 启动成功
4. curl /actuator/health — 返回 {"status":"UP"} 包含 db(UP, PostgreSQL) + minio(UP, endpoint=http://localhost:9000)
5. docker exec babytalk-postgres psql -U babytalk -c "SELECT extname FROM pg_extension" — 确认 pgvector + uuid-ossp 扩展
6. curl -v localhost:9000/minio/health/live — 返回 HTTP 200
7. Python assert 脚本验证 health JSON 包含 db + minio 组件且均为 UP

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `docker-compose up -d postgres minio && docker-compose ps` | 0 | ✅ pass | 17000ms |
| 2 | `cd backend && ./mvnw package -DskipTests -B -q` | 0 | ✅ pass | 15600ms |
| 3 | `java -jar target/babytalk-backend-0.0.1-SNAPSHOT.jar (startup)` | 0 | ✅ pass | 6000ms |
| 4 | `curl -sf http://localhost:8080/actuator/health | python3 assert db+minio UP` | 0 | ✅ pass | 500ms |
| 5 | `docker exec babytalk-postgres psql -U babytalk -c 'SELECT extname FROM pg_extension'` | 0 | ✅ pass — pgvector + uuid-ossp confirmed | 500ms |
| 6 | `curl -v http://localhost:9000/minio/health/live` | 0 | ✅ pass — HTTP 200 | 200ms |
| 7 | `docker-compose down -v` | 0 | ✅ pass | 8000ms |

## Deviations

Docker Hub 镜像仓库(docker.xuanyuan.me)返回 429 Too Many Requests 导致 docker-compose up --build 构建 backend 镜像失败，改用本地 mvn package + java -jar 方式验证等效功能。添加了 management.endpoint.health.show-details/show-components: always 配置（计划未明确提及但 slice 验证要求 /actuator/health 包含组件详情）。

## Known Issues

Docker Hub 镜像仓库 429 限流 — docker-compose up --build 构建 backend 容器镜像时拉取 maven:3-eclipse-temurin-17 基础镜像失败，属于瞬时网络问题，重试或切换镜像源可解决。T02 遗留的 Testcontainers + Docker Desktop 4.65.0 兼容性问题仍存在（mvn test 无法运行）。

## Files Created/Modified

- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MinioProperties.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MinioClientConfiguration.java`
- `backend/src/main/java/com/zhangspaghetti/babytalk/config/MinioHealthIndicator.java`
- `backend/src/main/resources/application.yml`
- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
