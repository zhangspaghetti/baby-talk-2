# E2E Smoke Test Runbook

## 目标

验证 Flutter App 与真实 Spring Boot 后端（Docker Compose, dev 模式）端到端可用：

1. 入职流程 → 版本协商 + stage-match API 成功
2. 启动练习 → 事件 sync API 成功
3. 导师聊天 → mentor chat API 返回 dev 模式响应并在 UI 展示

这份 runbook **不需要真实 LLM / SMS**；后端以 `provider-mode=dev` 运行，响应快速且确定。

---

## 前置条件

| 工具 | 版本要求 |
|------|---------|
| Docker Desktop | 已运行 |
| Flutter SDK | 已在 PATH |
| 设备 | Android 设备（USB 调试已开）或 Android 模拟器 |

---

## 1. 快速运行（推荐）

```cmd
REM Windows — 连接 Android 设备后执行
adb reverse tcp:8080 tcp:8080
scripts\run-mobile-e2e.cmd -d <device-id>
```

```bash
# Unix/macOS
adb reverse tcp:8080 tcp:8080
./scripts/run-mobile-e2e.sh -d <device-id>
```

脚本自动完成：
1. `docker compose up -d postgres minio backend`（dev 模式）
2. 轮询 `/actuator/health` 最长 60 秒
3. `flutter test integration_test/e2e_smoke_test.dart`
4. `docker compose stop backend`（退出时清理）

---

## 2. 手动逐步运行

### 2.1 查找设备 ID

```bash
flutter devices
# 示例输出: VOG AL10 (mobile) • APH0219717004019 • android-arm64
```

### 2.2 启动后端

```bash
# 从仓库根目录
docker compose up -d postgres minio backend

# 等待后端就绪（约 6-10 秒）
curl http://localhost:8080/actuator/health
# 期望: {"status":"UP",...}
```

### 2.3 设置 Android 端口转发

> 物理设备必须执行此步骤；Android 模拟器使用 10.0.2.2 时可跳过。

```bash
adb reverse tcp:8080 tcp:8080
# 输出: 8080  (表示成功)
```

### 2.4 运行 E2E 测试

```bash
cd mobile
flutter test integration_test/e2e_smoke_test.dart \
  -d <device-id> \
  --dart-define=BABY_TALK_API_BASE_URL=http://localhost:8080 \
  --dart-define=BABY_TALK_E2E=true \
  --reporter=expanded
```

期望输出：

```
+0: E2E smoke onboarding completes against real backend and shell is ready
+1: E2E smoke mentor chat returns dev-mode response from real backend
+2: All tests passed!
```

### 2.5 清理

```bash
docker compose stop backend
# 如需完全销毁数据：
docker compose down -v
```

---

## 3. 测试覆盖点

### Test 1: `onboarding completes against real backend and shell is ready`

| 步骤 | 验证的 API |
|------|-----------|
| 入职 → 填写姓名 + 年龄 | `GET /api/v1/sync/version` (版本协商) |
| 点击"提交" | `POST /api/v1/sync/bootstrap` (阶段匹配) |
| 等待 `shell-ready` key | bootstrap 响应正确解析 |

### Test 2: `mentor chat returns dev-mode response from real backend`

| 步骤 | 验证的 API |
|------|-----------|
| 完成入职（同上） | 同上 |
| 完成启动练习（3 句反应） | `POST /api/v1/sync/events` |
| 导师聊天：输入"宝宝哭了怎么回应" | `POST /api/v1/mentor/chat` |
| 断言 `chatResponsePhase == response_delivered` | dev 模式响应正常到达 |
| 断言 `mentor-chat-response-card` 可见 | 响应文本在 UI 正确渲染 |

---

## 4. 后端 dev 模式说明

Docker Compose 默认配置（已满足 E2E 需求）：

```yaml
BABY_TALK_SMS_PROVIDER_MODE: "dev"       # 不发真实短信
BABY_TALK_MENTOR_PROVIDER_MODE: "dev"    # DevMentorProvider，响应 < 100ms
```

dev 模式 SMS 验证码：`246810`（如未来 E2E 需要登录）

---

## 5. 模拟器说明

Android 模拟器（如 emulator-5554）的 `localhost` 实际上是模拟器内部网络。
有两种方案：

**方案 A（推荐）：`adb reverse`**
```bash
adb reverse tcp:8080 tcp:8080
# 然后使用 http://localhost:8080 -- 与物理设备一致
```

**方案 B：Android 模拟器专用 IP**
```bash
# 将 BABY_TALK_API_BASE_URL 改为宿主机 IP
--dart-define=BABY_TALK_API_BASE_URL=http://10.0.2.2:8080
```

---

## 6. 相关文件

| 文件 | 说明 |
|------|------|
| [mobile/integration_test/e2e_smoke_test.dart](../../mobile/integration_test/e2e_smoke_test.dart) | 测试入口（2 个 testWidgets） |
| [mobile/integration_test/support/e2e_test_harness.dart](../../mobile/integration_test/support/e2e_test_harness.dart) | E2E 测试框架（无 InMemoryDemoBackend） |
| [scripts/run-mobile-e2e.sh](../../scripts/run-mobile-e2e.sh) | Unix/macOS 一键运行脚本 |
| [scripts/run-mobile-e2e.cmd](../../scripts/run-mobile-e2e.cmd) | Windows 一键运行脚本 |
| [docker-compose.yml](../../docker-compose.yml) | 后端基础设施（dev 模式已配置） |
