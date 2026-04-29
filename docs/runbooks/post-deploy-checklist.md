# BabyTalk 部署后测试清单

本文记录每次 `helm upgrade` 部署到本地 k8s（Docker Desktop / kind）后应运行的测试，确认无 regression。  
按顺序执行：越靠前的越快，失败后优先修复再继续。

---

## 前置条件

| 条件 | 验证命令 |
|------|---------|
| kubectl 已连接本地集群 | `kubectl config current-context` → 应为 `docker-desktop` 或 `kind-*` |
| 所有 pod Running | `kubectl get pods -n babytalk` → 全部 `1/1 Running` |
| gateway port-forward 已启动 | `kubectl -n babytalk port-forward svc/babytalk-app-gateway 8090:8090` |
| admin-web port-forward 已启动 | `kubectl -n babytalk port-forward svc/babytalk-app-admin-web 3000:80` |

---

## 第 1 层：纯离线 / 不需要集群（最快，<2 min）

### 1-A  Helm template 预检（CI smoke）

```bash
bash ci/k8s-smoke.sh
```

验证内容：
- infra chart 无 migration Job  
- app chart 保留 migration hook 语义（`pre-install,pre-upgrade`、`before-hook-creation,hook-succeeded`）  
- values 文件语义一致  
- runbook 文档引用完整  

通过标志：最后一行输出 `PASS`，exit code 0。

---

### 1-B  后端单元测试

```bash
bash ci/backend-test.sh
```

Windows 等效：

```bat
cd backend && mvnw.cmd -f pom.xml -B test
```

通过标志：`BUILD SUCCESS`，exit code 0。

---

### 1-C  Flutter 单元 + Widget 测试

```bash
cd mobile && flutter test
```

通过标志：全绿，exit code 0。

---

### 1-D  Flutter 单元 smoke

```bash
cd mobile && flutter test test/smoke/
```

通过标志：全绿，exit code 0（比完整单测更快，用于快速验证 app boot）。

---

## 第 2 层：需要集群运行（需 port-forward，5–10 min）

### 2-A  Gateway smoke（最小集群验证）

```bat
scripts\dev-verify-helm-demo.cmd
```

或等效 Dart 命令：

```bash
dart run tool/verify_m007_s01_helm_baseline.dart smoke
```

验证内容：
- `GET http://127.0.0.1:8090/actuator/health` → `200 OK`  
- release boundary contract 未 drift

通过标志：最后一行 `demo_status=success`，exit code 0。

---

### 2-B  MinIO /data 挂载验证

```bash
kubectl exec -n babytalk deployment/babytalk-infra-minio -- df -h /data
```

通过标志：输出包含 `/data` 行，不是 `No such file or directory`。

---

### 2-C  Postgres pgvector 扩展验证

```bash
kubectl exec -n babytalk deployment/babytalk-infra-postgres -- \
  psql -U babytalk -d babytalk -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
```

通过标志：输出一行 `vector | <version>`。

---

## 第 3 层：Admin-web Playwright 测试（需浏览器，~15 min）

**前置**：确认 `http://127.0.0.1:3000` 可访问，`http://127.0.0.1:8090` 可访问（均通过 port-forward）。

```bash
cd admin-web && npx playwright test
```

主要 spec 文件（按依赖顺序）：

| Spec | 功能 |
|------|------|
| `admin-login.spec.ts` | 登录 / 登出 / 凭证错误 |
| `auth-and-rbac.spec.ts` | JWT refresh、token revoke、RBAC 权限边界 |
| `admin-accounts.spec.ts` | Super admin 创建管理员、禁用账号 |
| `overview-control-plane.spec.ts` | 控制平面概览、stale domain、realtime loss |
| `distribution-stats.spec.ts` | Mentor 分布统计、filter URL |
| `knowledge-ops.spec.ts` | 知识库上传、RBAC scoped 访问 |
| `mentor-audit.spec.ts` | Mentor audit 事件、403/401 场景 |
| `mentor-distribution-closure.spec.ts` | 跨模块 closure 验证 |
| `users-management.spec.ts` | 用户列表、管理员管理 |
| `access-and-landing.spec.ts` | 未认证重定向、403 无权限 |

通过标志：`X passed`，exit code 0，HTML report 生成在 `admin-web/playwright-report/`。

---

## 第 4 层：Flutter 集成测试（需 Android 模拟器，~20 min）

**前置**：  
- Android 模拟器已启动（`emulator-5554`）  
- `adb devices` 能看到设备  
- 后端 port-forward 运行中  

### 4-A  单个 integration test 场景

```bash
cd mobile && flutter test integration_test/s01_guest_practice_flow_test.dart \
  --device-id emulator-5554 \
  --dart-define=BACKEND_URL=http://10.0.2.2:8090
```

### 4-B  完整 E2E 流程测试

```bash
cd mobile && flutter test integration_test/e2e_full_flow_test.dart \
  --device-id emulator-5554 \
  --dart-define=BACKEND_URL=http://10.0.2.2:8090
```

通过标志：`All tests passed`，exit code 0。

---

## 第 5 层：全栈 E2E（Admin-web + Mobile，~35 min）

```bat
scripts\run-full-e2e.cmd
```

**前置**：所有第 3 层和第 4 层前置条件均满足。

验证内容：
1. 后端连通性（`/actuator/health`）
2. ADB reverse port-forward（模拟器 → host）
3. Playwright admin-web 全套 spec（`screenshot: on`）
4. Flutter mobile `e2e_full_flow_test`
5. 生成合并 Markdown report：`docs/e2e-full-test-report-<date>.md`

通过标志：report 文件生成，exit code 0。

---

## 快速参考：哪些测试不需要集群

| 测试 | 需要集群 | 需要模拟器 | 时长参考 |
|------|---------|-----------|---------|
| 1-A ci/k8s-smoke.sh | ❌ | ❌ | <1 min |
| 1-B backend 单元测试 | ❌ | ❌ | ~2 min |
| 1-C flutter test | ❌ | ❌ | ~1 min |
| 2-A gateway smoke | ✅ | ❌ | ~30 s |
| 2-B MinIO 挂载 | ✅ | ❌ | <5 s |
| 2-C pgvector 扩展 | ✅ | ❌ | <5 s |
| 3 Playwright | ✅ | ❌ | ~15 min |
| 4 Flutter 集成 | ✅ | ✅ | ~20 min |
| 5 全栈 E2E | ✅ | ✅ | ~35 min |

---

## 典型回归场景 → 对应层

| 变更类型 | 最低必跑层 |
|---------|---------|
| 只改文档 / 注释 | 1-A |
| 改后端 Java 代码 | 1-B + 2-A |
| 改 Flutter 代码 | 1-C + 1-D + 2-A |
| 改 Helm chart / values | 1-A + 2-A + 2-B + 2-C |
| 改 admin-web React 代码 | 2-A + 3 |
| 全量 release（PR merge 后） | 1-A → 1-B → 1-C → 2-A → 2-B → 2-C → 3 |
| 发布前 full sign-off | 全部 1-5 层 |
