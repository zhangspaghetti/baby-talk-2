# Admin Web 全量回归收敛设计（Refactor 060 / QA）

## 1. 背景与目标
当前 admin-web 全量 Playwright 回归存在多类失败，用户目标为：
- 运行环境：QA 命名空间 `babytalk-qa`
- 验收标准：全量 39 条一次通过（39/39）

本设计先完成失败分层与收敛路径定义，再进入实现。

## 2. 已确认约束
- 采用两阶段收敛策略（先打通主链，再清零模块漂移）。
- 种子与环境必须 namespace 可配置，禁止硬编码。
- 错误必须分层归类，不允许混合统计。
- 放行标准以全量 39/39 为唯一最终目标。

## 3. 失败分层模型
### 3.1 环境层（Infra）
判定特征：
- namespace not found
- seed 通道不可达
- 依赖服务未就绪

处理原则：
- 立即标注为 infra blocker
- 暂停功能修复扩散，先恢复环境可用性

### 3.2 契约层（Contract）
判定特征：
- 测试断言与当前产品契约不一致
- 路由/权限预期与现网行为漂移
- UI testid 或文案断言失配
- 会话载体假设与运行时实现不一致

处理原则：
- 先确认当前产品真相
- 再更新断言与测试夹具，避免反向修改产品行为

### 3.3 功能层（Functional）
判定特征：
- 业务行为错误
- 接口状态码与业务预期不符
- 权限决策逻辑错误

处理原则：
- 最小修复，限定影响面
- 修复后立即执行模块级回归验证

## 4. 组件与数据流
### 4.1 组件划分
1. 会话契约适配层
- 统一测试与运行时会话读写协议
- 消除“测试读 localStorage、运行时不落盘”断层

2. 环境执行适配层
- 根据运行标志选择 seed 通道（k8s / compose）
- 外置 namespace（默认 qa 为 `babytalk-qa`）

3. 模块断言适配层
- 将断言收敛到当前产品契约
- 明确路由、权限、元素与文案的可维护基线

### 4.2 关键数据流
- 登录主链：login -> session establish -> me/bootstrap -> route authorization -> UI assertions
- 种子主链：test setup -> namespace-aware seed -> UI trigger -> API observation -> assertion
- 失败主链：failure detect -> classify(infra/contract/functional) -> route to corresponding fix queue

## 5. 回归与门禁策略
### 5.1 预检门
- 固定 QA 目标命名空间：`babytalk-qa`（支持环境变量覆盖）
- 运行前验证 seed 通道可达
- 不可达时直接记为 infra blocker，并中止功能统计

### 5.2 分层回归门
- Layer A：auth 主链（登录、刷新、回退）
- Layer B：业务模块（overview、users、distribution、mentor、knowledge）
- Layer C：全量 39 条

### 5.3 统计口径
每轮输出必须包含：
- total
- passed
- failed
- blocked
- failed 分类占比（infra / contract / functional）

### 5.4 最终放行标准
全部满足才放行：
- infra blocker = 0
- contract 失败 = 0
- functional 失败 = 0
- 全量 39/39 一次通过

## 6. 风险与止损
- 新增 infra blocker：立即停止扩散修复，优先恢复环境稳定。
- 契约漂移反复出现：要求先产出“当前真相”对照表，再继续改测。
- 长超时集中出现：先验证前置链路（登录态/权限/路由）是否成立，再排查具体接口。

## 7. 执行入口（下一步）
进入实现时按以下顺序执行：
1. 修复 namespace 硬编码，切换 qa 命名空间可配置。
2. 收敛会话载体契约（测试夹具与运行时一致）。
3. 按模块清理断言漂移。
4. 每批回归后输出分层统计。
5. 全量 39 条收口。

## 8. 设计结论
该设计将“环境阻断、契约漂移、功能缺陷”解耦，采用分层门禁与两阶段收敛路径，以最小风险达成 QA 目标 39/39。
