# RBAC 矩阵

## 角色定义

| 角色 | code | 说明 |
|---|---|---|
| 超级管理员 | `super_admin` | 拥有全部权限，可管理其他管理员 |
| 知识库管理员 | `knowledge_admin` | 管理 RAG 和知识图谱 |
| 运营管理员 | `ops_admin` | 查看数据统计、审核内容 |
| 只读管理员 | `read_only` | 仅查看，无写入权限 |

## 权限列表

| 权限 code | 说明 | 来源 |
|---|---|---|
| `rag:read` | 查看 RAG 知识库 | AdminKnowledgeOpsController |
| `rag:write` | 编辑 RAG 知识库 | AdminKnowledgeOpsController |
| `kg:read` | 查看知识图谱 | AdminKnowledgeOpsController |
| `kg:review` | 审核知识图谱 | AdminKnowledgeOpsController |
| `distribution:read` | 查看分发统计 | AdminDistributionStatsController |
| `mentor:audit` | 审核 Mentor 内容 | AdminMentorAuditController |
| `users:read` | 查看用户列表 | AdminUsersController |
| `users:write` | 管理用户 | AdminUsersController |
| `rbac:read` | 查看角色权限 | AdminRbacController |
| `rbac:write` | 管理角色权限 | AdminRbacController |
| `admins:read` | 查看管理员列表 | AdminRbacController |
| `admins:write` | 管理管理员 | AdminRbacController |

## 角色 × 权限矩阵

| 权限 \ 角色 | super_admin | knowledge_admin | ops_admin | read_only |
|---|:---:|:---:|:---:|:---:|
| `rag:read` | ✅ | ✅ | ✅ | ✅ |
| `rag:write` | ✅ | ✅ | ❌ | ❌ |
| `kg:read` | ✅ | ✅ | ✅ | ✅ |
| `kg:review` | ✅ | ✅ | ❌ | ❌ |
| `distribution:read` | ✅ | ❌ | ✅ | ✅ |
| `mentor:audit` | ✅ | ❌ | ✅ | ❌ |
| `users:read` | ✅ | ❌ | ✅ | ✅ |
| `users:write` | ✅ | ❌ | ❌ | ❌ |
| `rbac:read` | ✅ | ❌ | ❌ | ❌ |
| `rbac:write` | ✅ | ❌ | ❌ | ❌ |
| `admins:read` | ✅ | ❌ | ❌ | ❌ |
| `admins:write` | ✅ | ❌ | ❌ | ❌ |

## API 端点 × 权限映射

| 端点 | 方法 | 权限 | Controller |
|---|---|---|---|
| `/api/admin/auth/login` | POST | 公开 | AdminAuthController |
| `/api/admin/auth/refresh` | POST | 公开 | AdminAuthController |
| `/api/admin/auth/logout` | POST | 公开 | AdminAuthController |
| `/api/admin/me` | GET | 已认证 | AdminAuthController |
| `/api/admin/overview/summary` | GET | `rag:read` 或 `kg:read` 或 `mentor:audit` 或 `distribution:read` | AdminOverviewController |
| `/api/admin/distribution/stats` | GET | `distribution:read` | AdminDistributionStatsController |
| `/api/admin/knowledge/rag/*` | GET | `rag:read` | AdminKnowledgeOpsController |
| `/api/admin/knowledge/rag/*` | POST/PUT | `rag:write` | AdminKnowledgeOpsController |
| `/api/admin/knowledge/kg/*` | GET | `kg:read` | AdminKnowledgeOpsController |
| `/api/admin/knowledge/kg/*` | POST | `kg:review` | AdminKnowledgeOpsController |
| `/api/admin/mentor/audit/*` | GET | `mentor:audit` | AdminMentorAuditController |
| `/api/admin/users` | GET | `users:read` | AdminUsersController |
| `/api/admin/users` | POST | `users:write` | AdminUsersController |
| `/api/admin/permissions` | GET | `rbac:read` | AdminRbacController |
| `/api/admin/roles` | GET | `rbac:read` | AdminRbacController |
| `/api/admin/roles` | POST | `rbac:write` | AdminRbacController |
| `/api/admin/admins` | GET | `admins:read` | AdminRbacController |
| `/api/admin/admins` | POST | `admins:write` | AdminRbacController |

## 审计落点

| 操作 | who | what | when | where |
|---|---|---|---|---|
| 登录 | username | login success/failure | timestamp | IP + User-Agent |
| 角色变更 | admin_id | role CRUD | timestamp | endpoint + payload |
| 权限变更 | admin_id | permission grant/revoke | timestamp | endpoint + payload |
| 知识库操作 | admin_id | RAG/KG CRUD | timestamp | endpoint + resource_id |
| 用户管理 | admin_id | user CRUD | timestamp | endpoint + user_id |

## @PreAuthorize 覆盖率

当前 admin-api 共 **27** 个 `@PreAuthorize` 注解，覆盖所有非公开端点。

**100% 覆盖** ✅
