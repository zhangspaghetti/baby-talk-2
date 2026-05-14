# COMMON

共享工具和基础类模块。

## STRUCTURE

```
common/
├── src/main/java/com/zhangspaghetti/babytalk/
│   ├── crypto/         # 加密工具 (VoiceEncryptor)
│   ├── audit/          # 审计接口 (VoiceAuditService)
│   └── util/           # 工具类
└── src/main/resources/
    └── mapper/admin/   # MyBatis 映射文件
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 加密 | `crypto/` | VoiceEncryptor (AES-256-GCM) |
| 审计 | `audit/` | VoiceAuditService 接口 |
| 工具类 | `util/` | 通用工具 |
| MyBatis 映射 | `resources/mapper/admin/` | admin-api 的 SQL 映射 |
