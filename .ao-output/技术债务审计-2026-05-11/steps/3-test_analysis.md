### Step 3/4: test_analysis（测试结果分析师）

总体评估：这套 mobile 测试不是“薄弱型”，而是“单元与仓储层比较强，系统级自动化和覆盖率治理偏弱”。从 docs/e2e-test-report-2026-04-29.md 看，Flutter 单测是 223/223；同一份报告里还有 e2e_smoke、s01、s02、s03、s06 这些场景化集成测试。按目录统计，feature 源文件与测试文件的比例明显失衡，尤其 practice 模块代码量最大，但测试主要集中在 repository 和少数 ViewModel。结论上，我会给“中上基线、非稳态闭环”：日常小改动可用，涉及 boot、practice/home、真实 API、状态迁移的改动，不建议只靠默认 CI 放行。

已有较强实践也很明确：不是只测 happy path。现有仓储和集成测试已经覆盖了不少 fail-closed、malformed、timeout、blocked fallback、冷启动恢复这类边界；测试支撑文件也集中在 mobile/integration_test/support/e2e_test_harness.dart 和 mobile/test/smoke/app_boot_test.dart 这类 harness 上，维护性比常见 Flutter 项目更好；另外为保证 Windows 可靠性，smoke 已被显式串行化，见 mobile/dart_test.yaml#L3。

1. 优先级：高。影响：没有覆盖率基线，团队知道“跑过多少测试”，但不知道“关键代码到底覆盖了多少”，这会让通过数掩盖盲区。证据：mobile/README.md 只强调 flutter test 与 smoke 子目录；CI 实际只跑 ci/mobile-analyze.sh；未见 flutter test --coverage、lcov、genhtml 流程。改进建议：先为 mobile job 增加 coverage 产物与最低阈值，第一阶段只给 app、practice、account、shell 设门槛，不要一上来全仓统一阈值。

2. 优先级：高。影响：关键用户链路虽然有 integration_test 和真实后端 E2E，但它们没有进入默认 PR gate，意味着 onboarding、sync、mentor、cold boot 这类回归可能在合并后才暴露。证据：.github/workflows/ci.yml 触发 mobile-analyze；真实后端与全链路验证仍依赖 scripts/run-mobile-e2e.sh 和 scripts/run-full-e2e.sh。改进建议：把测试分成三层门禁，PR 必跑 analyze + targeted widget/unit + 1 条快速 integration_test，nightly 跑全量 integration_test，pre-release 再跑真实后端 E2E。

3. 优先级：高。影响：practice、home、garden 是最重的用户面，但直接测试明显不足，容易出现“数据层绿了，实际首屏/花园页回归了”的情况。证据：practice 模块 34 个 Dart 源文件，但对应 feature 测试只有 4 个；重 UI 文件包括 mobile/lib/features/practice/presentation/screens/home_screen.dart 和 mobile/lib/features/shell/presentation/screens/garden_growth_combined_screen.dart，现有直接测试更多落在 mobile/test/features/practice/practice_repository_test.dart 与 mobile/test/features/practice/garden_growth_repository_test.dart 这类数据层。改进建议：优先补 3 类 widget 测试，分别覆盖 home 最近结果卡、garden/growth 组合页、practice 结束返回首页后的 continuity 呈现。

4. 优先级：高。影响：启动、装配、依赖注入、路由切换大量集中在 app 层，一旦这里回归，影响面是全局，但当前更多靠 smoke 兜底，定位成本高。证据：mobile/lib/app/app.dart 约 1059 行，而 app 层主要测试资产集中在 mobile/test/smoke/app_boot_test.dart、mobile/test/smoke/reentry_orchestrator_test.dart 和 mobile/test/smoke/session_reset_test.dart。这说明编排层有测试，但颗粒度偏粗。改进建议：把 boot gate、repository wiring、route destination、resume/reentry 判定继续抽成更纯的 seam，再补纯 Dart 合约测试，降低每次只能跑 smoke 才知道是否破坏的风险。

5. 优先级：中。影响：网络与设备基础 seam 没有看到对应测试，最容易在平台差异、header 注入、持久化边界上出现低级回归。证据：mobile/lib/core/network/app_dio.dart、mobile/lib/core/network/auth_interceptor.dart、mobile/lib/core/device/installation_id_service.dart。我没有找到对应测试文件。改进建议：补一组很小的纯单元测试，验证超时配置、空 token 不注入 header、非空 token 注入、installation id 空文件/已有文件/损坏文件行为。

6. 优先级：中。影响：状态管理正处在 ViewModel 向 Notifier/Provider 迁移的双轨期，测试资产和运行时 owner 已经开始错位，未来最容易出现“旧测试仍绿，但实际运行路径已经换了”的漂移。证据：mobile/lib/app/app.dart 一边创建 legacy ViewModel，一边 override 新的 notifier provider；测试侧则仍明显偏向 mobile/test/features/household/household_view_model_test.dart、mobile/test/features/mentor/mentor_view_model_test.dart、mobile/test/features/share/share_view_model_test.dart，而未见对应 notifier 测试。改进建议：在继续迁移前，先决定单一状态 owner；如果短期不能收口，就为 notifier 增加与 legacy ViewModel 对齐的 parity tests。

7. 优先级：中。影响：E2E 资产是有的，但运行门槛偏高，导致它们更像“证明包”而不是“日常防线”，长期会出现报告是绿的、但实际没人常跑的问题。证据：scripts/run-mobile-e2e.sh 依赖 docker compose 后端，scripts/run-full-e2e.sh 依赖 k8s port-forward 与 emulator，docs/e2e-full-test-report-2026-04-29.md 记录的是真实全流证明。改进建议：保留这套 full-flow 作为 nightly 或 release gate，同时再抽一套 10 到 15 分钟内能跑完的 PR-tier integration pack，优先覆盖 onboarding、sign-in sync、mentor fallback 三条最值钱路径。

发布建议：如果变更只触达单个 repository、文案、或局部静态 UI，当前测试基线足够支撑放行；如果变更触达 mobile/lib/app/app.dart、practice/home/garden 主路径、认证同步链路，或 notifier 迁移面，我给出的建议是“有条件放行”，条件是至少把一条 integration_test 纳入 PR gate，或者补足直接 widget tests 后再放。