# Baby Talk 2

Baby Talk 2 是一个面向中国父母的亲子英语启蒙项目：`mobile` 提供 Flutter 客户端，`backend` 提供 split-stack Spring Boot runtime，`admin-web` + `admin-api` 提供管理后台，MemPalace 负责知识导入、检索、矛盾检测与管理面审查。

如果你今天第一次进入仓库，**先只记住两条 repo-root 命令**。

## Install once

首次进入仓库前，请先安装这些本地依赖：

- `kind` ≥ 0.23：<https://kind.sigs.k8s.io/>
- `helm` ≥ 3.14：<https://helm.sh/>
- `kubectl` ≥ 1.28：<https://kubernetes.io/docs/tasks/tools/>
- `dart` / `flutter` ≥ 3.11.4：<https://flutter.dev/docs/get-started/install>

> **Helm 本地 secret 配置**：首次运行前，先复制 secret 模板并填入本地值：
> ```bash
> cp deploy/helm/babytalk-app/values-kind-secrets.example.yaml \
>    deploy/helm/babytalk-app/values-kind-secrets.yaml
> # 编辑 values-kind-secrets.yaml，填入 BABY_TALK_ADMIN_JWT_SECRET 等必填项
> ```
> `values-kind-secrets.yaml` 已加入 `.gitignore`，不会被提交。

## QA 环境部署（本地 kind 集群）

QA 环境与 dev 环境**隔离**运行，互不影响：

| 项目 | Dev 环境 | QA 环境 |
|------|----------|---------|
| Kubernetes namespace | `babytalk` | `babytalk-qa` |
| Infra release | `babytalk-infra` | `babytalk-qa-infra` |
| App release | `babytalk-app` | `babytalk-qa-app` |
| Gateway 本地端口 | 8090 | **8091** |
| Admin-web 本地端口 | 3000 | **3001** |
| Infra 持久化存储 | emptyDir（重启丢失） | **PVC（hostpath，持久化）** |

### 首次准备

```bash
# 复制 QA secrets 模板并填入本地值
cp deploy/helm/babytalk-app/values-kind-qa-secrets.example.yaml \
   deploy/helm/babytalk-app/values-kind-qa-secrets.yaml
# 编辑 values-kind-qa-secrets.yaml，设置 JWT secret 和 admin 密码
```

### 一键拉起 QA 环境 + 打包 APK

```bash
./scripts/qa-up-helm.sh
```

这个脚本会依次：

1. **Preflight** — 检查 `helm`, `kubectl`, `flutter` 是否已安装，以及 QA secrets 文件是否存在
2. **Infra** — 部署 `babytalk-qa-infra`（Postgres + Redis + MinIO，全部启用 PVC 持久化）到 `babytalk-qa` namespace
3. **App** — 部署 `babytalk-qa-app`（gateway + app-api + admin-api + admin-web + db-migration）到 `babytalk-qa` namespace
4. **Rollout 验证** — 等待所有 Deployment 就绪
5. **Port-forward（后台）** — gateway → `127.0.0.1:8091`，admin-web → `127.0.0.1:3001`
6. **Gateway smoke** — curl 健康检查
7. **APK 构建** — `flutter build apk --debug`
8. **APK 安装** — 检测 `adb devices`；有模拟器/真机则自动 `adb install`，否则输出 APK 路径

成功后输出：

```
qa_status=ok
namespace=babytalk-qa
gateway_url=http://127.0.0.1:8091/
admin_web_url=http://127.0.0.1:3001
apk_path=mobile/build/app/outputs/flutter-apk/app-debug.apk
```

### 手动分步部署

如果你只想重新部署其中一层：

```bash
# 仅更新 QA infra（含持久化存储）
helm upgrade --install babytalk-qa-infra deploy/helm/babytalk-infra \
  -n babytalk-qa --create-namespace \
  -f deploy/helm/babytalk-infra/values-kind-qa.yaml \
  --wait --timeout 120s

# 仅更新 QA app
helm upgrade --install babytalk-qa-app deploy/helm/babytalk-app \
  -n babytalk-qa \
  -f deploy/helm/babytalk-app/values-kind-qa.yaml \
  -f deploy/helm/babytalk-app/values-kind-qa-secrets.yaml \
  --wait --timeout 180s
```

### 启动 Android 模拟器并安装 APK

```bash
# 列出已创建的 AVD
emulator -list-avds

# 启动模拟器（替换 <avd_name> 为你的 AVD 名称）
emulator -avd <avd_name> &

# 等待模拟器启动后安装 APK
adb wait-for-device
adb install -r mobile/build/app/outputs/flutter-apk/app-debug.apk
```

### 查看 QA 环境状态

```bash
kubectl -n babytalk-qa get pods
kubectl -n babytalk-qa get pvc       # 查看持久化存储状态
```

### 清理 QA 环境

```bash
# 卸载 Helm release（PVC 默认保留，数据不丢）
helm uninstall babytalk-qa-app babytalk-qa-infra -n babytalk-qa

# 如需彻底清除包括 PVC
kubectl delete namespace babytalk-qa
```

## 2 分钟内拉起 admin demo

### POSIX

```bash
./scripts/dev-up-helm-demo.sh
```

### Windows (cmd / PowerShell)

```bat
scripts\dev-up-helm-demo.cmd
```

这个 Helm-first golden path 会负责：

- 创建或复用本地 kind 集群 `babytalk-local`
- 安装/升级 `babytalk-infra` 与 `babytalk-app`
- 验证 gateway 健康检查 `http://127.0.0.1:8090/`
- 输出 `demo_status` / `tthw_seconds` / `gateway_url` / `next_action`
- 把 redaction-safe recent history 追加到 `tmp/m007-s01-helm-metrics.jsonl`

成功后你会得到类似输出：

- `demo_status=passed`
- `tthw_seconds=<seconds>`
- `gateway_url=http://127.0.0.1:8090/`
- `next_action=./scripts/dev-verify-helm-demo.sh`（Windows 会显示 `.cmd`）
- `telemetry_path=tmp/m007-s01-helm-metrics.jsonl`

失败时还会额外给出：

- `first_failure_stage=preflight|cluster|infra|app|gateway|smoke`
- `likely_cause=<machine-readable-cause>`
- `next_action=<next command or inspection step>`

## Fast smoke（复用 live Helm baseline）

### POSIX

```bash
./scripts/dev-verify-helm-demo.sh
```

### Windows (cmd / PowerShell)

```bat
scripts\dev-verify-helm-demo.cmd
```

这个 fast smoke：

- 复用已经存在的 kind 集群与 Helm release
- 只重跑 `preflight -> gateway -> smoke` 这条轻量路径
- 跑完后保留 live stack，方便继续手动调试
- 继续输出 `demo_status` / `tthw_seconds` / `gateway_url` / `next_action`
- 继续写入同一份 `tmp/m007-s01-helm-metrics.jsonl` history

## Helm telemetry handoff

`dev-up-helm-demo` 和 `dev-verify-helm-demo` 共用 `tmp/m007-s01-helm-metrics.jsonl` 这份 bounded local history。每次 run 都会追加 redaction-safe recent entry：

- `mode`
- `shell`
- `success`
- `tthw_seconds`
- `first_failure_stage`
- `likely_cause`
- `next_action`
- `timestamp`

先读 wrapper stdout；如果还想看最近几次 run 的走势，再直接打开这份 telemetry 文件。

## Final release closure (CI smoke gate)

```bash
bash ci/k8s-smoke.sh
```

CI-equivalent gate 是 `bash ci/k8s-smoke.sh`。如果你想在本机直接跑同一套 Helm-first front-door verifier，可执行：

```bash
dart run tool/verify_m007_s01_helm_baseline.dart demo
```

后续里程碑会把更完整的 M007 closure 继续向这条 Helm-first 路径收敛；在 S01 这里，不再把旧的 M006 release-closure verifier 当作仓库前门。

## Split-stack 地图

| Surface | 角色 | 默认本地入口 | 说明 |
| --- | --- | --- | --- |
| `gateway` | repo-root gateway / 健康检查前门 | `http://127.0.0.1:8090/` | Spring Cloud Gateway (babytalk/gateway:1.0.0)；admin 和 consumer 流量的唯一外部后端入口 |
| `app-api` | 面向 mobile / consumer 的 HTTP API | cluster-internal service | cluster-internal service；consumer 流量经 gateway 代理 |
| `admin-web` | 管理后台浏览器入口 | `http://127.0.0.1:3000` | UI 开发时仍可直接打开 |
| `admin-api` | 管理后台后端 API | 仅 cluster-internal；无公网 Ingress | internal-only；admin-web 经 gateway 代理到 admin-api |
| `db-migration` | schema owner / preflight job | Helm hook job | 先于 app/admin runtime 执行 |
| `mobile` | Flutter 客户端 | `mobile/` | 只连 `app-api`，不连 `admin-api` |

## Role-based quickstarts

### Full stack（推荐）

```bash
./scripts/dev-up-helm-demo.sh
./scripts/dev-verify-helm-demo.sh
```

需要更重的 proof 时再下钻：

```bash
bash ci/k8s-smoke.sh
dart run tool/verify_m007_s01_helm_baseline.dart demo
```

### Backend only（split-stack 本地开发）

优先还是直接跑 Helm front door：

```bash
./scripts/dev-up-helm-demo.sh
```

如果你已经有 kind 集群，只想手动重放 release 级别安装：

```bash
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -f deploy/helm/babytalk-infra/values-kind.yaml --namespace babytalk --create-namespace --wait --timeout 120s
helm upgrade --install babytalk-app deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-kind.yaml --namespace babytalk --create-namespace --wait --timeout 180s
```

模块级验证继续使用：

```bash
./backend/mvnw -f backend/pom.xml test -DexcludedGroups=llm-it
bash ci/backend-test.sh
```

### admin-web only

`admin-web` 开发服务器默认把 `/api` 和 `/actuator` 代理到本地 `admin-api`：

```bash
npm --prefix admin-web install
npm --prefix admin-web run dev
```

如果 `gateway` 不在 `127.0.0.1:8090`，先覆盖代理目标：

```bash
VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8090 npm --prefix admin-web run dev
```

### mobile

```bash
cd mobile
flutter pub get
flutter run
```

更多 mobile 约定见 [mobile/README.md](mobile/README.md)。

## Copy-paste auth / API examples

这些示例统一走 `admin-web` 代理，不要求你先暴露 public admin-api URL。

### 1) 登录

```bash
export BABY_TALK_ADMIN_PASSWORD='<your local bootstrap password>'

curl -s http://127.0.0.1:3000/api/admin/auth/login \
  -H 'Content-Type: application/json' \
  -d '{
    "username": "super_admin",
    "password": "'"$BABY_TALK_ADMIN_PASSWORD"'"
  }'
```

### 2) refresh

```bash
curl -s http://127.0.0.1:3000/api/admin/auth/refresh \
  -H 'Content-Type: application/json' \
  -d '{
    "refreshToken": "<refresh-token>"
  }'
```

### 3) 读取 Overview summary

```bash
curl -s http://127.0.0.1:3000/api/admin/overview/summary \
  -H 'Authorization: Bearer <access-token>'
```

## 旧单体 → 新 split-stack

| 旧入口 / 旧假设 | 现在应该怎么做 |
| --- | --- |
| 旧容器栈一把启动然后自己猜入口 | 直接跑 `dev-up-helm-demo` wrapper |
| `scripts/verify-e2e.sh` 作为 repo-root smoke | 改用 `dev-verify-helm-demo` wrapper |
| `scripts/run-mobile-e2e.*` 代表仓库前门 | 保留为 mobile 集成历史参考，不再放在 README 顶部 |
| `cd backend && mvn spring-boot:run` | 用 `backend/mvnw` 跑 split modules，或直接走 Helm wrapper |
| 仓库“没有 Maven wrapper” | 仓库根真实入口是 `backend/mvnw` / `backend/mvnw.cmd` |
| root README 直接复述所有部署细节 | 发布 / Helm 真相统一下钻到 runbook |

## 继续往下读什么

- [CONTRIBUTING](CONTRIBUTING.md) — 日常开发路径、verification ladder、目录职责
- [Kubernetes split-stack deploy runbook](docs/runbooks/k8s-deploy.md) — Helm 安装、发布、回滚与 `bash ci/k8s-smoke.sh` truth
- [Post-deploy checklist](docs/runbooks/post-deploy-checklist.md) — 每次 helm upgrade 后的分层验证清单（离线 smoke → gateway → Playwright → Flutter E2E）
- [mobile/README.md](mobile/README.md) — Flutter 客户端约定

## Historical references

这些脚本仍然保留，但不再是 repo-root front door：

- `scripts/run-mobile-e2e.sh`
- `scripts/run-mobile-e2e.cmd`
- `scripts/verify-e2e.sh`
- `scripts/verify-s02.sh`
