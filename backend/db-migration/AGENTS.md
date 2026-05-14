# DB-MIGRATION

Flyway 数据库迁移模块。

## STRUCTURE

```
db-migration/
├── src/main/java/com/zhangspaghetti/babytalk/migration/
│   └── DbMigrationApplication.java
└── src/main/resources/
    ├── application.yml
    └── db/migration/   # Flyway SQL 脚本
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 迁移脚本 | `resources/db/migration/` | Flyway SQL 脚本 |
| 启动类 | `DbMigrationApplication.java` | CLI 风格，WebApplicationType.NONE |

## CONVENTIONS

- **CLI 应用**：WebApplicationType.NONE，验证迁移后退出
- **Flyway**：SQL 迁移脚本在 `db/migration/` 目录
