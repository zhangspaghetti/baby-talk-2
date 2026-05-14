# APP MODULE

应用入口和全局组件。

## STRUCTURE

```
app/
├── app.dart            # BabyTalkApp 入口 (1059行)
├── widgets/            # 全局组件 (6 个)
└── ...
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 应用入口 | `app.dart` | BabyTalkApp、路由配置、DI 配置 |
| 全局组件 | `widgets/` | 6 个全局共享组件 |

## CONVENTIONS

- **入口**：app.dart 包含应用启动、路由、DI 配置
- **全局组件**：widgets/ 目录存放全局共享组件

## ANTI-PATTERNS

1. **大文件**：app.dart (1059行)，应拆分
