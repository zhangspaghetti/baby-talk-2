# PROJECT KNOWLEDGE BASE

**Generated:** 2026-05-13
**Commit:** c8e2e5b
**Branch:** Develop

## OVERVIEW

BabyTalk 2 是一个三端应用（Flutter mobile + Spring Boot backend + React admin-web），采用 monorepo 结构。核心栈：Flutter/Riverpod、Spring Boot 3.4.4/Java 17、React 18/Vite 5/AntD 5。

## STRUCTURE

```
baby-talk-2/
├── admin-web/          # React 管理后台 (Vite + AntD + Playwright)
├── backend/            # Spring Boot 多模块 (common/app-api/admin-api/gateway/db-migration)
├── mobile/             # Flutter 移动端 (Riverpod + Isar + GoRouter)
├── deploy/helm/        # Helm charts (babytalk-infra + babytalk-app)
├── scripts/            # 构建/部署/测试脚本
├── docs/               # 文档
├── tool/               # 工具脚本
└── test/               # 测试文件
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| Flutter 开发 | `mobile/lib/` | Riverpod 状态管理，features/ 目录按功能划分 |
| Spring Boot 开发 | `backend/` | 多模块：common (共享) / app-api (C端) / admin-api (管理) / gateway (网关) / db-migration (数据库) |
| React 管理后台 | `admin-web/src/` | Vite + React + AntD + ProComponents |
| Helm 部署 | `deploy/helm/` | babytalk-infra (基础设施) + babytalk-app (应用) |
| CI/脚本 | `scripts/` | qa-up-helm.sh / dev-up-helm-demo.sh / run-full-e2e.sh |
| 设计系统 | `DESIGN.md` | warmPaperAdmin tokens |
| 重构计划 | `REFACTOR-PLAN.md` | 三端重构路线图 |

## CONVENTIONS

### Monorepo 配置
- **pnpm-workspace.yaml**：workspace 仅包含 admin-web（backend/mobile 未纳入 Node workspace）
- **根 pubspec.yaml**：用于 test delegation（非标准：flutter test 从根目录委托到 mobile/）
- **根 tsconfig.json**：TypeScript 配置（非标准：通常在各包内）
- **scripts/tsc-proxy.cjs**：tsc 代理（非标准：tsc 通常在各包 devDependencies）

### 三端分离
- **admin-web**：pnpm workspace 包，有自己的 package.json
- **backend**：Maven 多模块，根 pom.xml 管理依赖
- **mobile**：独立 Flutter 包，有自己的 pubspec.yaml

### 代码规范
- **Flutter**：analysis_options.yaml（flutter_lints），Riverpod 代码生成
- **Java**：Spring Boot 3.4.4，Java 17，MyBatis-Plus
- **TypeScript**：Vite 5，React 18，AntD 5

## ANTI-PATTERNS (THIS PROJECT)

1. **双真相源**：ViewModel + Notifier 双写（5-10 处，待修复）
2. **手写轮询**：admin-web 手写 setInterval 轮询（应改 React Query/SWR）
3. **localStorage token**：admin-web 将 token 存 localStorage（应改 HttpOnly Cookie）
4. **前端权限码**：admin-web 前端持有 ADMIN_ROUTE_PERMISSION_CODES（应改服务端 /me 拉取）
5. **大文件超载**：backend/.../CaregiverInviteService.java (1540行)、mobile/lib/app/app.dart (1059行)

## COMMANDS

```bash
# Flutter
cd mobile && flutter run
cd mobile && flutter test
cd mobile && flutter test --coverage

# Backend
cd backend && mvn clean install
cd backend && mvn spring-boot:run -pl app-api
cd backend && mvn spring-boot:run -pl admin-api
cd backend && mvn spring-boot:run -pl gateway

# Admin-Web
pnpm --filter admin-web dev
pnpm --filter admin-web typecheck
pnpm --filter admin-web build
pnpm --filter admin-web test:e2e

# Helm Deploy
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -n babytalk --create-namespace -f deploy/helm/babytalk-infra/values-kind.yaml
helm upgrade --install babytalk-app deploy/helm/babytalk-app -n babytalk -f deploy/helm/babytalk-app/values-kind.yaml -f deploy/helm/babytalk-app/values-kind-secrets.yaml

# QA
./scripts/qa-up-helm.sh
```

## NOTES

1. **部署环境**：prod ns `babytalk` (gateway 8090 / admin-web 3000)；QA ns `babytalk-qa` (8091/3001)
2. **数据库**：PostgreSQL + Flyway 迁移
3. **缓存**：Redis
4. **对象存储**：MinIO
5. **AI 集成**：Spring AI 1.1.4
6. **Flutter 状态管理**：Riverpod 2.6.1 + Freezed
7. **Spring Boot 版本**：3.4.4 (Java 17)
8. **React 版本**：18.3.1 + Vite 5.4 + AntD 5.27
