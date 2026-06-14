# Admin Web 回归收敛执行计划（Refactor 060 / QA）

## 0. 目标
- 环境目标：QA 命名空间 babytalk-qa
- 质量目标：全量回归 39/39 一次通过
- 执行原则：先环境，再契约，再功能；每批都要有证据

## 1. 批次拆分
### 批次 A：环境与种子可达性收敛
范围：
- 去除命名空间硬编码，改为可配置并默认 qa 目标
- 统一 seed 通道选择逻辑与失败报错

验收：
- 不再出现 namespace not found（babytalk）
- knowledge 相关用例可进入业务断言阶段

失败分流：
- 任何 seed 不可达均标记 infra blocker，暂停后续批次

### 批次 B：认证主链与会话契约收敛
范围：
- 对齐测试会话夹具与运行时真实会话载体
- 校准登录后导航、刷新重放、会话失效回退断言

验收：
- auth and rbac 模块全部通过
- 不再出现“本地会话存在性假设”失败

失败分流：
- 若再次出现路由预期与权限策略冲突，归类 contract 并先更新真相断言

### 批次 C：模块契约漂移清零（按优先顺序）
顺序：
1. overview-control-plane
2. users-management 与 admin-accounts
3. distribution-stats
4. mentor-audit 与 mentor-distribution-closure
5. knowledge-ops

每个模块执行节奏：
- 先跑模块用例
- 收敛断言或最小修复
- 模块复跑至清零
- 记录分类统计

验收：
- 模块级失败清零后再进入下一模块

### 批次 D：全量收口
范围：
- 执行全量 39 条
- 仅允许零失败、零阻断

验收：
- 39/39
- infra blocker = 0
- contract 失败 = 0
- functional 失败 = 0

## 2. 统一门禁规则
### 预检门
- 命名空间为 babytalk-qa
- 依赖服务与 seed 通道可达

### 过程门
- 每批必须提供：通过数、失败数、阻断数
- 失败必须标注类别：infra / contract / functional

### 终检门
- 全量一次 39/39
- 无阻断遗留项

## 3. 证据模板
每批完成后输出：
- 批次编号
- 执行命令
- total / passed / failed / blocked
- 失败分类明细
- 下一批是否可进入（yes / no）

## 4. 风险与应对
- 风险 1：环境漂移导致批次反复
  - 应对：将环境校验前置为硬门槛，不通过不进入功能修复
- 风险 2：断言持续滞后产品契约
  - 应对：先写当前真相，再改断言
- 风险 3：超时误判为性能问题
  - 应对：先检查登录态、权限与路由链路是否成立

## 5. 执行顺序清单
1. 批次 A
2. 批次 B
3. 批次 C（按模块顺序）
4. 批次 D

## 6. 完成定义
仅当以下全部满足，任务才算完成：
- 全量 39 条一次通过
- 无 infra blocker
- 无 contract 失败
- 无 functional 失败
- 输出最终证据摘要
