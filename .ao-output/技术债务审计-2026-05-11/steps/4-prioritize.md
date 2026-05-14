1. **P0｜统一状态 Owner，关闭 ViewModel/Notifier 双真相源**
问题描述：同一 feature 同时维护 legacy ViewModel/Provider 与 Notifier/Riverpod，两套状态长期并存；深链接、分享回流、邀请接受等关键流程仍直接修改旧对象，迁移边界没有闭合。
影响范围：启动后状态恢复、深链接回流、分享/邀请链路、mentor/account/shell/practice 主路径，以及所有仍双写状态的 feature。
修复成本估算：10-14 人天
建议的修复方案：确定单一状态主栈并停止继续双写，优先把回流编排、分享接受、首页承接等关键链路迁到统一 command/use case 入口；按 feature 完成“迁一个、删一个”，迁完即删除旧 ViewModel/Provider 接线与镜像 API。

2. **P0｜建立默认 PR 稳定性门禁与覆盖率基线**
问题描述：现有 mobile 默认门禁缺少覆盖率基线、快速 integration pack 和关键主路径断言，团队知道“测试跑过了”，但无法确认关键代码是否被有效覆盖。
影响范围：boot/reentry、practice 结束回首页连续性、home/garden 关键卡片、状态迁移兼容、network/device seam、PR 回归发现能力。
修复成本估算：6-9 人天
建议的修复方案：在 PR gate 中固定执行 analyze + targeted unit/widget + 1 条 10-15 分钟内的 quick integration pack，并产出 coverage 及最低阈值；nightly 跑全量 integration_test，pre-release 跑真实后端 E2E；优先补 boot/reentry、home/garden、practice continuity、network/device seam 的测试。

3. **P1｜把 app 层收口为纯 composition root**
问题描述：启动、依赖装配、会话恢复、重入编排、路由与根组件职责都堆在 app 层，导致 app.dart 成为全局热点，任何新 feature 都容易回到根部改 wiring。
影响范围：app 启动链路、repository wiring、路由判定、会话恢复、多人并行开发时的合并冲突与回归风险。
修复成本估算：7-10 人天
建议的修复方案：把 app 层限制为 boot、router、root widget；将启动期编排、session/reentry 判定、依赖装配拆到独立 application/boot 模块和 coordinator；为 boot gate、route destination、resume/reentry 规则补纯 Dart 合约测试。

4. **P1｜建立 bounded context contract，切断横向打穿的 feature 依赖**
问题描述：practice、onboarding、mentor、household、share 虽然按 feature 分目录，但实际直接引用彼此内部类型，甚至依赖别的 feature 的 presentation 类型，限界上下文已经被打穿。
影响范围：practice、mentor、onboarding、household、share 的模型演进、模块解耦、并行开发效率和后续抽包/拆模块能力。
修复成本估算：8-12 人天
建议的修复方案：为每个 bounded context 定义公开 facade、DTO 或 application service，禁止跨 feature 直接引用内部实现；把 home/garden 这类跨域编排页面上移到 shell/application 层，跨域协作统一走 contract。

5. **P1｜补齐 application/view state 层，移除 UI 对 data 与路由细节的直连**
问题描述：多个页面和组件直接依赖 repository、本地存储、快照类型、route args，桥接层还用 dynamic 同时兼容两套对象，类型系统和分层边界都被绕开。
影响范围：practice session/home、household 共享卡片、share callout、garden hero/continue 卡片、路由参数校验与页面装配逻辑。
修复成本估算：7-10 人天
建议的修复方案：补一个轻量 application 层，统一输出 view state 和 command；route args 下沉到 app/router contract；widget 只消费只读 DTO 或 interface，不再直接碰 repository/local store；逐步消灭 dynamic 兼容桥。

6. **P1｜统一错误处理与故障上报，清理静默降级**
问题描述：插件故障、数据损坏、本地 I/O 问题、状态异常在多处被吞掉或伪装成在线、空摘要、已登出等“正常结果”，真实故障原因被隐藏。
影响范围：repository providers、account/practice 仓储、会话页面、离线态判断、线上排障效率和数据一致性判断。
修复成本估算：4-6 人天
建议的修复方案：建立统一的错误分类与上报机制，保留原始异常原因；在应用层明确区分 offline、unauthorized、data corruption、empty state 等状态；对关键失败给出可恢复提示和结构化日志，禁止无痕吞错。

7. **P2｜拆分超大仓储与协调器热点文件**
问题描述：practice_repository、account_repository、mentor_view_model、app.dart 等已膨胀为高复杂度热点，业务规则、装配逻辑和副作用混在一起，测试粒度过粗。
影响范围：practice、account、mentor、app 层的开发速度、review 成本、合并冲突概率和局部改动安全性。
修复成本估算：5-8 人天
建议的修复方案：按用例拆分 query/write service、coordinator、domain service 和 mapper；把副作用和组合逻辑从超大文件中剥离；为抽出的 seam 补单元测试，并设定热点文件持续拆分的阈值。

8. **P2｜收敛技术栈与依赖治理，消除长期兼容补丁**
问题描述：状态层、路由层、Hook 层多套依赖并存，pubspec 中已经出现 dependency_overrides 固定版本，说明技术选型尚未收敛，升级成本会持续抬高。
影响范围：依赖升级、Flutter 版本演进、团队心智负担、排障效率，以及新代码继续扩散 legacy 写法的风险。
修复成本估算：3-5 人天
建议的修复方案：补一份 ADR，明确状态层、路由层、网络层的唯一主栈与禁用栈；把 dependency_overrides 作为有截止日期的临时债登记；必须保留的 legacy 兼容代码只允许留在 adapter 层，并在 code review 中阻止新混用。

9. **P3｜清理半迁移残留、废弃页面和未实现 CTA**
问题描述：未接入主路径的新 provider、已废弃但仍留在主代码树中的页面，以及可点击但未实现的 CTA 持续制造噪音和误导。
影响范围：mentor 迁移残留、shell 废弃页面、QA 测试路径、代码搜索噪音和后续清理成本。
修复成本估算：1-3 人天
建议的修复方案：先做引用审计，再删除或迁入 legacy 目录；未实现 CTA 要么补齐路由与能力，要么在发布前隐藏；将“半迁移但未接入”的 provider 从主路径移除，避免继续误导开发。