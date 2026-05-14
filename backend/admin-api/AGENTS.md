# ADMIN-API

管理后台 API 服务，处理管理员业务逻辑。

## STRUCTURE

```
admin-api/
├── src/main/java/com/zhangspaghetti/babytalk/admin/
│   ├── auth/           # 认证模块 (8 个)
│   ├── knowledge/      # 知识库管理 (6 个)
│   ├── web/            # Web 控制器 (7 个)
│   └── AdminApiApplication.java
└── src/main/resources/
    └── application.yml
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 认证 | `auth/` | JWT 认证、登录/登出、Token 管理 |
| 知识库管理 | `knowledge/` | 知识库 CRUD 操作 |
| API 控制器 | `web/` | REST 端点 |

## CONVENTIONS

- **认证**：Spring Security + JWT
- **RBAC**：角色 × 资源 × 操作矩阵（待文档化）
- **审计**：审计落点 100% 覆盖
