# MENTOR FEATURE

导师功能模块，AI 导师对话和指导。

## STRUCTURE

```
mentor/
├── data/
│   ├── local/          # 本地存储
│   └── repositories/   # 仓库实现
├── domain/
│   ├── models/         # 领域模型 (4 个)
│   └── services/       # 领域服务
└── presentation/
    ├── screens/        # 页面
    └── widgets/        # 组件
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 数据模型 | `domain/models/` | 4 个 Freezed 生成的数据类 |
| 导师服务 | `domain/services/` | AI 导师相关服务 |
| UI 组件 | `presentation/widgets/` | 导师对话界面组件 |

## CONVENTIONS

- **分层架构**：data → domain → presentation
- **AI 集成**：Spring AI 后端支持
