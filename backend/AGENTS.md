# BACKEND

Spring Boot 多模块后端，Java 17 + Spring Boot 3.4.4。

## STRUCTURE

```
backend/
├── common/             # 共享工具和基础类
├── app-api/            # C端 API (家长/儿童)
├── admin-api/          # 管理后台 API
├── gateway/            # Spring Cloud Gateway
├── db-migration/       # Flyway 数据库迁移
└── pom.xml             # 父 POM (依赖管理)
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 共享工具 | `common/` | 加密、审计、工具类 |
| C端业务 | `app-api/src/main/java/.../service/` | 23 个服务类 |
| 管理后台 | `admin-api/src/main/java/.../admin/` | 认证、用户、知识库管理 |
| 网关路由 | `gateway/src/main/resources/application.yml` | 路由配置、限流 |
| 数据库迁移 | `db-migration/src/main/resources/` | Flyway SQL 脚本 |
| 配置 | `*/src/main/resources/application.yml` | 各模块配置 |

## CONVENTIONS

- **依赖管理**：父 POM 统一版本（Spring AI 1.1.4, MyBatis-Plus 3.5.9, Druid 1.2.23）
- **数据库**：PostgreSQL + Flyway 迁移
- **ORM**：MyBatis-Plus
- **缓存**：Redis
- **对象存储**：MinIO
- **AI 集成**：Spring AI
- **安全**：Spring Security + JWT

## MODULES

### common (共享)
- 加密工具（VoiceEncryptor）
- 审计接口（VoiceAuditService）
- 基础实体类

### app-api (C端)
- 服务层：23 个服务类（CaregiverInviteService, MentorService, ShareLandingService 等）
- 配置层：19 个配置类
- 知识图谱：kg/ 目录
- 宫殿记忆：palace/ 目录

### admin-api (管理)
- 认证：admin/auth/
- 用户管理：admin/user/
- 知识库管理：admin/knowledge/

### gateway (网关)
- Spring Cloud Gateway
- 路由配置
- 限流策略

### db-migration (数据库)
- Flyway 迁移脚本
- CLI 风格应用（WebApplicationType.NONE）

## ANTI-PATTERNS

1. **大文件**：CaregiverInviteService.java (1540行)、MentorService.java (1102行)
2. **双真相源**：部分服务存在 ViewModel + Notifier 双写
3. **缺少 RBAC 矩阵**：admin-api 角色 × 资源 × 操作矩阵未文档化

## COMMANDS

```bash
mvn clean install              # 构建所有模块
mvn spring-boot:run -pl app-api    # 启动 C端 API
mvn spring-boot:run -pl admin-api  # 启动管理 API
mvn spring-boot:run -pl gateway    # 启动网关
mvn test                       # 运行测试
mvn checkstyle:check           # 代码风格检查
```
