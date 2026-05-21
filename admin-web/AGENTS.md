# ADMIN-WEB

React 管理后台，Vite 5 + AntD 5 + ProComponents。

## STRUCTURE

```
admin-web/
├── src/
│   ├── app/            # 应用入口 (App.tsx, main.tsx)
│   ├── auth/           # 认证模块 (session-store.ts, auth-api.ts, access.ts)
│   ├── layout/         # 布局组件 (AdminLayout)
│   ├── pages/          # 页面组件 (Overview, Users, MentorAudit, DistributionStats, KnowledgeOps, PalaceRag)
│   ├── components/     # 共享组件 (workbench/)
│   └── lib/            # 工具库 (api-client.ts)
├── tests/              # Playwright e2e 测试
├── package.json        # 依赖和脚本
├── vite.config.ts      # Vite 配置
├── tsconfig.json       # TypeScript 配置
└── playwright.config.ts # Playwright 配置
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 认证逻辑 | `src/auth/` | session-store.ts (token 存储), auth-api.ts (登录/登出), access.ts (权限) |
| API 客户端 | `src/lib/api-client.ts` | Axios 实例，拦截器，错误处理 |
| 页面组件 | `src/pages/` | 6 大页面：Overview, Users, MentorAudit, DistributionStats, KnowledgeOps, PalaceRag |
| 布局 | `src/layout/AdminLayout.tsx` | 主布局，侧边栏，头部 |
| 工作台 | `src/components/workbench/` | 工作台组件 |
| E2E 测试 | `tests/` | 10 个 Playwright spec |

## CONVENTIONS

- **状态管理**：React Query/SWR（待引入），当前使用手写轮询
- **路由**：react-router-dom v6
- **UI 库**：AntD 5 + ProComponents
- **HTTP 客户端**：axios，拦截器处理 401 → refresh
- **类型检查**：TypeScript 5.8，strict 模式
- **测试**：Playwright e2e，baseURL `http://127.0.0.1:3000`

## ANTI-PATTERNS

1. **localStorage token**：token 存 localStorage（应改 HttpOnly Cookie）
2. **手写轮询**：OverviewPage.tsx:16 / IngestionSurface.tsx:27 手写 setInterval
3. **前端权限码**：ADMIN_ROUTE_PERMISSION_CODES 硬编码（应改服务端 /me 拉取）
4. **大文件**：PalaceRagSurface.tsx / UsersPage.tsx / OverviewPage.tsx 超 500 行
5. **内联样式**：adminSurfaceStyles.page 内联样式（应改 Design Token）

## COMMANDS

```bash
pnpm run dev          # 启动开发服务器 (localhost:3000)
pnpm run typecheck    # TypeScript 类型检查
pnpm run build        # 构建生产版本
pnpm run test:e2e     # 运行 Playwright e2e 测试
```
