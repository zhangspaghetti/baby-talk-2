# MOBILE

Flutter 移动端，Riverpod 状态管理 + Isar 本地数据库 + GoRouter 路由。

## STRUCTURE

```
mobile/
├── lib/
│   ├── app/                    # 应用入口和全局组件
│   ├── core/                   # 核心模块 (auth, navigation, theme)
│   ├── features/               # 功能模块 (按领域划分)
│   │   ├── practice/           # 练习功能
│   │   ├── mentor/             # 导师功能
│   │   ├── shell/              # 外壳/导航
│   │   ├── household/          # 家庭管理
│   │   ├── account/            # 账户管理
│   │   └── onboarding/         # 引导流程
│   ├── l10n/                   # 国际化
│   └── main.dart               # 入口
├── assets/                     # 资源文件 (音频、字体、JSON)
├── test/                       # 单元测试
├── integration_test/           # 集成测试
└── pubspec.yaml                # 依赖配置
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 应用入口 | `lib/main.dart` → `lib/app/app.dart` | BabyTalkApp 和路由/DI 配置 |
| 状态管理 | `lib/core/` | Riverpod Notifiers + Providers |
| 功能模块 | `lib/features/` | 按领域划分：practice, mentor, shell, household, account, onboarding |
| 数据模型 | `lib/features/*/domain/models/` | Freezed 生成的数据类 |
| 本地存储 | `lib/features/*/data/local/` | Isar 实体和 DAO |
| 路由 | `lib/core/navigation/` | GoRouter 配置 |
| 主题 | `lib/core/theme/` | Design Token |
| 国际化 | `lib/l10n/` | app_localizations.dart (2466行，生成文件) |

## CONVENTIONS

- **状态管理**：Riverpod 2.6.1 + Freezed 代码生成
- **路由**：GoRouter 14.8.1
- **本地数据库**：Isar 3.1.0
- **HTTP 客户端**：Dio 5.7.0
- **代码生成**：build_runner + freezed + json_serializable + riverpod_generator
- **分析**：analysis_options.yaml (flutter_lints)

## FEATURE STRUCTURE

每个 feature 模块遵循分层架构：
```
features/[name]/
├── data/           # 数据层 (repositories, local, remote)
├── domain/         # 领域层 (models, services)
└── presentation/   # 表现层 (screens, widgets, viewmodels)
```

## ANTI-PATTERNS

1. **双真相源**：ViewModel + Notifier 双写（5-10 处）
2. **大文件**：app.dart (1059行)、practice_repository.dart (1169行)
3. **生成文件**：*.g.dart / *.freezed.dart 文件很大（应排除在分析之外）
4. **跨 feature import**：features/ 之间存在直接 import（应通过 contract 通信）

## COMMANDS

```bash
flutter run                  # 运行应用
flutter test                 # 运行测试
flutter test --coverage      # 运行测试并生成覆盖率
flutter analyze              # 静态分析
flutter pub get              # 安装依赖
dart run build_runner build  # 运行代码生成
```
