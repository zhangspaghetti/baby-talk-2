# Dispatch Contract

## 概述

本文档定义应用启动恢复、首页、Practice 三个关键场景的 dispatch contract。每个 contract 明确输入、输出、边界条件和错误处理。

## 1. 启动恢复（Launch Recovery）

### Contract

```
输入: AppBootState (seed content + asset phrase service)
输出: _AppLaunchState (repositories + destination + starter args)
```

### 流程

```
AppBootState.load(bundle)
  → 加载 seed content
  → 创建 AssetPhraseService
  → 返回 AppBootState

_loadLaunchState()
  → 创建 PracticeRepository
  → 创建 AccountRepository
  → 创建 HouseholdRepository
  → 创建 MentorRepository
  → 读取 onboarding snapshot
  → 决定 destination (onboarding / shell)
  → 返回 _AppLaunchState
```

### 边界条件

| 条件 | 行为 |
|---|---|
| seed content 加载失败 | 显示 BootFailureScreen，允许重试 |
| 网络不可用 | 使用本地缓存，标记 offline |
| onboarding snapshot 不存在 | 进入 onboarding 流程 |
| onboarding snapshot 存在 | 进入 shell 首页 |

### 错误处理

| 错误 | 处理 |
|---|---|
| AssetBundle 读取失败 | 返回 AppBootState(isReady: false) |
| Repository 创建失败 | 显示 BootFailureScreen |
| 数据库初始化失败 | 显示 BootFailureScreen |

## 2. 首页（Shell Home）

### Contract

```
输入: _AppLaunchState (repositories + destination)
输出: ShellScreen (tabs + garden + growth)
```

### 流程

```
_AppLaunchState.destination == shell
  → 创建 AppShellScreen
  → 加载 garden growth data
  → 加载 practice continuity data
  → 显示首页 tabs
```

### 边界条件

| 条件 | 行为 |
|---|---|
| garden data 加载失败 | 显示空状态 + 重试 |
| practice data 加载失败 | 显示离线降级 |
| 家庭组数据加载失败 | 显示个人模式 |

### 错误处理

| 错误 | 处理 |
|---|---|
| API 超时 | 显示离线提示 |
| 数据解析失败 | 显示空状态 |
| 权限不足 | 显示登录提示 |

## 3. Practice

### Contract

```
输入: PracticeRouteArgs (spaceId + activityId + phrases)
输出: PracticeSession (audio + recording + scoring)
```

### 流程

```
PracticeRouteArgs
  → 创建 PracticeSession
  → 加载 phrase audio
  → 显示练习界面
  → 录音 + 评分
  → 保存练习记录
```

### 边界条件

| 条件 | 行为 |
|---|---|
| phrase audio 加载失败 | 显示文字 + 跳过音频 |
| 录音权限被拒 | 显示权限引导 |
| 网络不可用 | 本地记录，稍后同步 |

### 错误处理

| 错误 | 处理 |
|---|---|
| 音频播放失败 | 显示文字，继续练习 |
| 录音失败 | 显示错误，允许重试 |
| 评分 API 失败 | 使用本地评分 |

## 单测覆盖

每个 contract 需要以下单测：

### 启动恢复

- [ ] 正常启动 → shell destination
- [ ] 无 onboarding snapshot → onboarding destination
- [ ] seed content 加载失败 → BootFailureScreen
- [ ] 网络离线 → 使用本地缓存

### 首页

- [ ] 正常加载 → 显示 garden + growth
- [ ] API 超时 → 显示离线提示
- [ ] 数据为空 → 显示空状态

### Practice

- [ ] 正常练习 → 完成 + 保存
- [ ] 音频失败 → 显示文字
- [ ] 录音失败 → 允许重试
