# Garden V2 肥料系统实现计划

- 日期：2026-06-01
- 状态：待批准（动手前确认架构决策）
- 依据：specs/2026-05-28-flutter-mobile-garden-v2-design.md、completion-audit（Garden V2 🟡 部分）
- 核实结论：`GardenFertilizerService` 是纯逻辑层（算阶段/上限/过期/阈值）；当前 Garden 数据是**事件投影只读模型**（`GardenGrowthRepository.buildSnapshot` 从 Isar `InteractionEventEntity` 事件日志派生）；**无任何可变肥料状态、无领取/施肥 UI**。

## 现状架构（已核实）
- 持久化：Isar（`practice_local_data_source.dart`，collection `InteractionEventEntity`）。
- 数据流：`practiceRepository.inspectEventLog()` → `GardenGrowthRepository.buildSnapshot()` → `GardenGrowthNotifier` → `garden_growth_combined_screen` 的 garden tab。
- 现有 garden tab：花圃卡片（per-space patches）、事件投影阶段（seed/sprout/growing/blooming/fullBloom），**非**施肥次数模型。

## 规格要求（Garden V2）
- Phase 1 单株花；阶段由**累计施肥次数**驱动：0/3/10/25/50 → 种子/发芽/含苞/盛开/结果。
- 核心循环：说英文→产肥料（每句 1 包）→手动领取→手动施肥（每次耗 1 包）→花成长。
- 页面：花可视化+进度条、背包（数量+[施肥]）、肥料来源列表（待领取[领取]/已领取灰色）、空态。
- 持久化、离线、红点、动画（施肥 0.5s / 阶段 1.5s）、Home 摘要联动。

## 关键决策（请拍板）

### 决策 1 — 肥料状态持久化
- **(A) 新增 Isar 实体 `FertilizerStateEntity`**（单行：`appliedCount`、`claimedEventKeys`、`lastClaimedAt`）。干净、显式；需注册 schema + 跑 build_runner codegen。**（推荐）**
- (B) 复用事件日志：把领取/施肥写成新的 `InteractionEventEntity` 记录。无需新 schema，但污染事件日志、投影逻辑复杂化。

### 决策 2 — 与现有阶段模型的关系
- **(A) 新增「单株花」肥料区，叠加在 garden tab 顶部**，与现有花圃卡片并存（改动隔离、低回归）。**（推荐）**
- (B) 用施肥模型**替换**现有 garden tab 花可视化（改动大、波及现有测试）。

### 决策 3 — 分期
- **Phase 1（本次）**：数据层（Isar 实体 + repo `claim()/apply()` + 持久化）+ 状态层（FertilizerNotifier/provider）+ 核心 UI（花可视化+进度+背包+施肥按钮+待领取/已领取列表+空态）+ 单元/widget 测试。花用分阶段 widget（非 Lottie，符合规格）。
- Phase 2：施肥动画 / 阶段庆祝（复用已接入的 confetti）/ 红点 / 自动滚动 / Home 摘要联动。

## Phase 1 落地步骤（待批准后执行）
1. `garden/data/local/fertilizer_state_entity.dart`（Isar @collection）+ 注册到 practice Isar opener schemas。
2. `garden/data/repositories/garden_fertilizer_repository.dart`：读/写肥料状态；`availablePacks`（= 未领取练习事件数）、`claim(eventKey)`、`apply()`。
3. `garden/presentation/garden_fertilizer_notifier.dart` + provider（复用 `GardenFertilizerService` 算阶段/阈值）。
4. UI：`garden/presentation/widgets/` 新增花可视化、背包、肥料来源条目；接入 garden tab 顶部。
5. 测试：repository（领取/施肥/上限/持久化）、notifier、widget（待领取→领取→施肥→进度推进）。
6. 针对性跑新增测试 + 受影响的 garden_growth_combined_screen_test（不全量）。

## 风险与缓解
- codegen：新增 Isar 实体需 `build_runner build`（项目已有 freezed/isar codegen 流程）。
- 回归：决策 2(A) 隔离改动；不动现有事件投影与花圃卡片。
- 数据语义：「待领取肥料数」如何映射到练习事件——Phase 1 用「已记录但未领取的 known practice 事件数」近似（每事件=1 包），claimedEventKeys 去重。
