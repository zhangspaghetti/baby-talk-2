# QA APK 独立安装脚本 + 启动异常根因摘要（Debug Only）设计

日期：2026-05-25  
状态：Approved（待实现）

## 1. 背景与目标

当前 `./scripts/qa-up-helm.sh` 负责 QA 全链路（Helm 部署 + port-forward + APK build/install）。

本次需要：

1. 新增一个“只负责 Flutter APK 安装到安卓模拟器”的独立脚本，不依赖整套 Helm 启动流程。
2. 在 Flutter 启动异常页增加“真实根因摘要（仅 debug 构建可见）”，避免未来同类问题被统一文案掩盖。
3. 实现后可通过新脚本完成安装并验证行为。

非目标：

- 不重构 `qa-up-helm.sh` 的部署职责。
- 不改变 release/profile 下的用户可见错误文案策略。
- 不引入与本需求无关的大范围架构重构。

## 2. 方案选择

已比较方案：

- A（采用）：新增独立 `scripts/qa-install-apk.sh`，处理 build + install。
- B：抽公共函数并让 `qa-up-helm.sh` 与新脚本复用。
- C：只做安装，不做 build。

采用 A 的原因：

- 改动面最小，风险可控。
- 与“只安装 App”的需求直接对齐。
- 保持现有 QA 一键脚本稳定。

## 3. 架构与组件边界

### 3.1 新脚本：`scripts/qa-install-apk.sh`

职责：

- 仅处理 Flutter debug APK 构建与 adb 安装。
- 可选协助启动/等待指定 AVD。
- 输出可读且可机读的结果摘要。

不负责：

- Helm 安装/升级。
- Kubernetes rollout 验证。
- 端口转发管理。

### 3.2 Flutter 启动失败页改动

改动点：`mobile/lib/app/app.dart`

职责：

- 保持现有失败路由和主文案不变：`本地档案读取失败，请重试。`
- 在 `kDebugMode` 下显示异常根因摘要（脱敏、截断、可定位）。
- 在 release/profile 下不显示摘要。

## 4. 数据流设计

### 4.1 `qa-install-apk.sh`

1. Preflight
- 检查 `flutter`、`adb` 命令可用。
- 检查 `mobile/` 与目标 APK 路径。

2. 设备解析优先级
- 若传 `--device <serial>`，直接使用。
- 否则若传 `--avd <name>`，尝试启动模拟器并等待设备上线。
- 否则自动选择 `adb devices` 中第一个 `device` 状态设备。

3. APK 构建
- 默认执行：
  - `flutter build apk --debug --dart-define=BABY_TALK_API_BASE_URL=http://127.0.0.1:<gateway-port>`
- 支持 `--skip-build`：跳过构建，仅安装已存在 APK。

4. APK 安装
- 执行：`adb -s <serial> install -r <apk>`

5. 摘要输出
- `install_status=ok|failed`
- `apk_path=...`
- `target_device=...`
- `gateway_port=...`
- `next_action=...`（失败时给下一步）

### 4.2 启动异常根因摘要（Debug Only）

1. `_loadLaunchState()` 抛错后仍进入既有 `boot-route-gate-failed`。
2. `BootFailureScreen` 接收可选 `debugDetails`。
3. `snapshot.hasError` 分支内：
- `kDebugMode == true`：构造摘要并渲染。
- 其他模式：不渲染摘要。
4. 摘要字段：
- `error.runtimeType`
- `error.toString()`（长度上限，如 240 字符）
- 可选分类标签（directory/permission/unimplemented/persistence 等）

## 5. 错误处理与可观测性

### 5.1 脚本错误处理

- 每个失败点打印明确原因。
- 失败时统一包含 `next_action`。
- 不 silent fail。

### 5.2 应用侧错误显示

- 主文案保持稳定，避免产品文案回归。
- 根因摘要仅 debug 可见，避免生产信息泄漏。

## 6. 测试与验收

### 6.1 脚本

- 有在线设备：成功 build + install。
- 无设备：给出启动模拟器与重试指令，退出码非 0。
- `--skip-build` 且 APK 缺失：明确报错 + next_action。
- 可覆盖 `--gateway-port` 注入。

### 6.2 Flutter

- 保持 `boot-route-gate-failed` 不变。
- debug 显示摘要，release/profile 不显示。
- `mobile/test/smoke/app_boot_test.dart` 相关用例继续通过。

### 6.3 端到端收口

- 用新脚本安装改动后的 APK 到安卓模拟器。
- 在模拟器验证启动异常可见真实根因摘要（debug）。

## 7. 变更范围

预计涉及文件：

- `scripts/qa-install-apk.sh`（新增）
- `README.md`（新增该脚本用法）
- `mobile/lib/app/app.dart`（debug 根因摘要）
- `mobile/test/smoke/app_boot_test.dart`（必要时补充断言）

## 8. 风险与缓解

风险：

- 不同开发机的 Android SDK/emulator 路径差异导致自动启动失败。
- 调试摘要暴露过多内部信息。

缓解：

- 自动启动失败时退化为“手动启动 + 明确 next_action”。
- 摘要内容截断，并仅在 debug 构建显示。

## 9. 实施前置结论

该设计满足：

1. 独立安装脚本与 QA 全链路解耦。
2. 启动异常可诊断性增强且不影响生产信息面。
3. 具备清晰验收标准，可进入 implementation planning。
