# PRACTICE FEATURE

练习功能模块，儿童学习练习的核心功能。

## STRUCTURE

```
practice/
├── data/
│   ├── local/          # 本地存储 (Isar 实体)
│   └── repositories/   # 仓库实现 (1169行)
├── domain/
│   ├── models/         # 领域模型 (10 个 Freezed 类)
│   └── services/       # 领域服务
└── presentation/
    ├── screens/        # 页面
    └── widgets/        # 组件 (9 个)
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 数据模型 | `domain/models/` | 10 个 Freezed 生成的数据类 |
| 本地存储 | `data/local/` | Isar 实体和 DAO |
| 仓库 | `data/repositories/` | practice_repository.dart (1169行) |
| UI 组件 | `presentation/widgets/` | 9 个练习相关组件 |

## CONVENTIONS

- **分层架构**：data → domain → presentation
- **数据类**：Freezed 代码生成
- **本地存储**：Isar 数据库
