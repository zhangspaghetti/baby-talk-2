# 花园/成长后端持久化设计（强一致 + 业务API优先）

- 日期：2026-05-30
- 适用范围：mobile + backend（app-api）
- 设计目标：换设备后花园/成长状态立即一致；在不引入高耦合的前提下收敛本地真相源

## 1. 背景与问题

当前系统中：

1. 交互事件已支持上云与回放（`/sync/events` + `/bootstrap`）。
2. growth 统计可由事件重算。
3. fertilizer 的 claim/apply 主观操作未上云，跨设备会丢失。
4. share 存在陈旧快照副本风险，应改为实时读取权威源。

本设计遵循：

- 强一致体验：用户换设备后应看到一致状态。
- 业务 API 优先：语义清晰，边界明确，便于灰度治理。
- 分阶段落地：先增量，再切流，最后收口旧路径。

## 2. 设计决策（已确认）

1. 架构方案：采用分域资源 API（方案 B）。
2. 本轮范围：全量覆盖 fertilizer + growth + share 快照收敛。
3. share 与 fertilizer 解耦：share 不依赖 fertilizer 数据。
4. 兼容策略：灰度期间后端失败可回退本地缓存路径。

## 3. 目标架构

### 3.1 Fertilizer（后端权威状态）

- 权威源：后端
- 客户端角色：本地缓存与离线队列，不再是最终真相源

建议数据模型：

- `garden_fertilizer_state`
  - `user_id`（唯一）
  - `applied_count`
  - `last_claimed_at`
  - `last_applied_at`
  - `version`
  - `updated_at`
- `garden_fertilizer_claim_log`
  - `user_id`
  - `event_key`（唯一约束，防重复认领）
  - `claimed_at`
  - `request_id`
- `garden_fertilizer_apply_log`
  - `user_id`
  - `delta`
  - `applied_at`
  - `request_id`

幂等规则：

- claim：`(user_id, event_key)` 唯一约束
- apply：`request_id` 去重

### 3.2 Growth（后端聚合读模型）

- 输入事实：事件流
- 输出：`week/month/year` 聚合摘要
- 可选优化：`growth_summary_cache` 作为缓存层，可失效重算，不作为最终事实源

### 3.3 Share（去陈旧快照）

- 设计原则：分享构建时实时读取权威源
- v1：不引入 share draft 持久化
- v2（可选）：新增 `share_draft` 资源用于跨端恢复编辑态

## 4. API 契约

### 4.1 Fertilizer

- `GET /api/v1/garden/fertilizer`
  - 响应：`appliedCount`, `claimableCount`, `lastClaimedAt`, `lastAppliedAt`, `version`
- `POST /api/v1/garden/fertilizer/claim`
  - 请求：`eventKey`, `requestId`, `clientTime`
  - 语义：幂等认领
- `POST /api/v1/garden/fertilizer/apply`
  - 请求：`delta`, `requestId`, `clientTime`
  - 语义：幂等消费

### 4.2 Growth

- `GET /api/v1/growth/summary?period=week|month|year`
  - 响应：对应周期统计与趋势字段

### 4.3 Share

- v1：不新增 fertilizer 相关读取；分享仅拉取其自身所需权威数据
- v2（可选）：`GET/PUT /api/v1/share/draft/{sceneType}`

### 4.4 错误码与并发

- `400` 参数非法
- `401` 未认证
- `409` 幂等冲突/版本冲突
- 写接口必须携带 `requestId`

## 5. 迁移与灰度计划

### 阶段 0：后端能力上线（不切流量）

1. 发布 fertilizer 三接口 + 表结构 + 幂等约束
2. 发布 growth summary 只读接口

### 阶段 1：客户端双轨读写

1. 读：优先后端，失败回退本地
2. 写：后端写 + 本地镜像更新；失败进入重试队列
3. 通过 feature flag 分批开启

### 阶段 2：真相源切换

1. 将 fertilizer 本地存储降级为缓存
2. 清理 share 陈旧快照副本读取路径
3. 增加一致性对账

### 阶段 3：收口

1. 关闭旧本地写路径
2. 保留观测与告警，验证稳定性后再删除兼容代码

## 6. 风险与缓解

1. 幂等实现错误导致重复记账
- 缓解：数据库唯一约束 + 接口层 requestId 校验 + 回归测试

2. 灰度期间状态回退导致短时不一致
- 缓解：统一优先级（后端优先），并记录回退埋点

3. Growth 聚合成本上升
- 缓解：先实时聚合，后按热点加缓存

## 7. 测试策略

### 后端

1. 单元测试
- claim/apply 幂等性
- growth summary 周/月/年边界

2. 集成测试
- 多次重复 claim/apply 结果稳定
- bootstrap + growth 查询一致

### 移动端

1. 仓储层测试
- 后端成功/失败回退分支
- 离线重试队列正确出队

2. 界面流程测试
- 换设备后 fertilizer 与 growth 状态一致
- share 构建不依赖 fertilizer

## 8. 非目标

1. 本轮不改造 admin-web 的 token/权限码/轮询问题
2. 本轮不引入完整 CQRS 基础设施
3. 本轮不做 share draft 跨端编辑态（保留为 v2 可选）

## 9. 验收标准

1. 换设备登录后，fertilizer 状态与旧设备一致
2. growth 周/月/年统计在新设备可直接获取，且与旧设备同口径
3. share 流程无陈旧快照副本导致的滞后显示
4. 灰度期间无高频幂等冲突告警
