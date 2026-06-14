---
phase: "01"
plan: "02"
---

# T02: feat: 创建 AbstractIntegrationTest 基类 + application-test.yml，迁移全部 16 个测试类从 H2 到 Testcontainers PostgreSQL（验证待 Docker 兼容性修复）

**feat: 创建 AbstractIntegrationTest 基类 + application-test.yml，迁移全部 16 个测试类从 H2 到 Testcontainers PostgreSQL（验证待 Docker 兼容性修复）**

## What Happened

## 已完成的工作

### 1. 创建 AbstractIntegrationTest 共享基类

- 路径: `backend/src/test/java/com/zhangspaghetti/babytalk/AbstractIntegrationTest.java`
- Singleton container pattern: static `PostgreSQLContainer` 使用 `pgvector/pgvector:pg16` 镜像
- `@DynamicPropertySource` 动态注入 `spring.datasource.url/username/password`
- `@SpringBootTest` + `@ActiveProfiles("test")` 基础注解
- static initializer block 中调用 `POSTGRES.start()`

### 2. 创建 application-test.yml

- 路径: `backend/src/test/resources/application-test.yml`
- 配置 `spring.datasource.driver-class-name: org.postgresql.Driver`
- 配置 `spring.flyway.clean-disabled: false`（测试环境允许 clean）

### 3. 迁移 5 个 service 测试类

每个文件: 删除 H2 datasource 三行, 添加 `extends AbstractIntegrationTest`, 添加 import

- AuthConsentSyncServiceTest
- MentorServiceTest
- MentorRateLimitConcurrencyTest
- MentorTransactionBoundaryTest
- VerifyChallengeConcurrencyTest

### 4. 迁移 10 个 web 测试类

同样模式: 删除 datasource 三行, extends AbstractIntegrationTest, import

- ApiVersionHandshakeWebTest, AuthConsentSyncWebTest, CaregiverInviteApiWebTest
- CaregiverInviteLandingWebTest, CaregiverPracticeAttributionWebTest
- DistributionPageWebTest, MentorWebTest, SecurityHeadersWebTest
- ShareLandingWebTest, ShareLinkApiWebTest

### 5. 迁移 MentorProviderConfigurationTest（特殊处理）

- 外层类 extends AbstractIntegrationTest
- 两个 @Nested 子类的 @SpringBootTest(properties) 中删除 datasource 三行
- 保留第三个非 Spring 上下文的 unknownMode 单元测试不变

### 6. SpringAiMentorProviderTest 无需改动（纯单元测试，无 Spring 上下文）

## 验证结果

**代码变更验证通过:** `grep -r "h2:mem" backend/src/test/java/` 返回 CLEAN，全部 16 个类正确 extends AbstractIntegrationTest。

**Maven verify 未通过:** Testcontainers 无法连接 Docker Desktop。

## 未解决的阻塞问题

Docker Desktop 4.65.0 (Windows) + Testcontainers 1.20.6 (docker-java 3.4.1) 存在兼容性问题:

- Docker CLI (`docker version`) 正常工作
- Testcontainers 通过 `npipe:////./pipe/dockerDesktopLinuxEngine` 和 `npipe:////./pipe/docker_engine` 均收到 HTTP 400 + 空 info JSON
- 尝试了 `~/.testcontainers.properties` 配置 docker.host、DOCKER_HOST 环境变量、DOCKER_API_VERSION=1.44 均无效
- 根因: Docker Desktop 4.65.0 使用 API version 1.53 (minimum 1.44)，docker-java 3.4.1 可能发送了不兼容的请求

### 解决方案建议（下一个任务可尝试）:

1. **升级 Testcontainers** 到 1.21.x+ 或更新的 docker-java（需检查 Spring Boot BOM 兼容性）
2. **在 Docker Desktop 中启用 TCP socket** (Settings > General > Expose daemon on tcp://localhost:2375) 然后设置 `docker.host=tcp://localhost:2375`
3. **降级 Docker Desktop** 到已知兼容版本

## Verification

代码变更验证: grep -r "h2:mem" backend/src/test/java/ 返回 CLEAN (0 matches)，确认全部 H2 引用已清除。grep -r "extends AbstractIntegrationTest" 返回 16 个匹配。Maven verify 因 Testcontainers 无法连接 Docker Desktop 而失败 (57 errors, 0 failures)。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -r h2:mem backend/src/test/java/` | 1 | ✅ pass — no H2 references remain | 100ms |
| 2 | `grep -c 'extends AbstractIntegrationTest' backend/src/test/java/ (recursive)` | 0 | ✅ pass — 16 classes migrated | 100ms |
| 3 | `cd backend && ./mvnw verify` | 1 | ❌ fail — Testcontainers cannot connect to Docker Desktop 4.65.0 (BadRequestException Status 400) | 38000ms |

## Deviations

Maven verify 未能通过 — Testcontainers 1.20.6 (docker-java 3.4.1) 无法连接 Docker Desktop 4.65.0 (API 1.53)，收到 HTTP 400 空 info 响应。代码变更本身已完成且正确。

## Known Issues

Docker Desktop 4.65.0 + Testcontainers 1.20.6 兼容性问题: docker-java 3.4.1 通过 named pipe 连接时收到 400 BadRequest。需要升级 Testcontainers 或启用 Docker TCP socket 或降级 Docker Desktop。~/.testcontainers.properties 已创建但需进一步调试。

## Files Created/Modified

- `backend/src/test/java/com/zhangspaghetti/babytalk/AbstractIntegrationTest.java`
- `backend/src/test/resources/application-test.yml`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/AuthConsentSyncServiceTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
- `backend/src/test/java/com/zhangspaghetti/babytalk/web/MentorWebTest.java`
