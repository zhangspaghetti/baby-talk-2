# APP-API

C端 API 服务，处理家长/儿童业务逻辑。

## STRUCTURE

```
app-api/
├── src/main/java/com/zhangspaghetti/babytalk/
│   ├── service/        # 业务服务 (23 个)
│   ├── config/         # 配置类 (19 个)
│   ├── kg/             # 知识图谱 (18 个)
│   ├── palace/         # 宫殿记忆 (10 个)
│   │   └── projection/ # 投影 (8 个)
│   ├── web/            # Web 控制器 (7 个)
│   └── AppApiApplication.java
└── src/main/resources/
    └── application.yml
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 业务逻辑 | `service/` | CaregiverInviteService (1540行), MentorService (1102行), ShareLandingService (1041行) |
| 配置 | `config/` | Spring 配置类 |
| 知识图谱 | `kg/` | 知识图谱相关服务 |
| 宫殿记忆 | `palace/` | 宫殿记忆系统 |
| API 控制器 | `web/` | REST 端点 |

## CONVENTIONS

- **服务层**：业务逻辑封装在 service/ 目录
- **配置**：Spring 配置类在 config/ 目录
- **知识图谱**：独立模块 kg/
- **宫殿记忆**：独立模块 palace/，包含 projection 子目录

## ANTI-PATTERNS

1. **大文件**：CaregiverInviteService.java (1540行)、MentorService.java (1102行)
2. **服务臃肿**：部分服务类职责过重
