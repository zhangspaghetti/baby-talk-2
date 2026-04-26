# Baby Talk 2

Baby Talk 2 是一个面向中国父母的亲子英语启蒙项目：`mobile` 提供 Flutter 客户端，`backend` 提供 split-stack Spring Boot runtime，`admin-web` + `admin-api` 提供管理后台，MemPalace 负责知识导入、检索、矛盾检测与管理面审查。

如果你今天第一次进入仓库，**先只记住两条 repo-root 命令**。

## 2 分钟内拉起 admin demo

### POSIX

```bash
./scripts/dev-up-admin-demo.sh
```

### Windows (cmd / PowerShell)

```bat
scripts\dev-up-admin-demo.cmd
```

这个 golden path 会负责：

- 以同一套 stage label 启动 `postgres → minio → db-migration → app-api → admin-api → admin-web`
- 等待 split stack 到达真实健康状态，而不是只看单个容器启动
- 输出 `tthw_seconds` / `first_failure_stage` / `likely_cause` / `next_action`
- 打印 `admin-web` 登录入口和 demo 账号名（**不会打印 bootstrap password**）
- 把 redaction-safe recent history 追加到 `tmp/m006-s13-front-door-metrics.jsonl`

成功后你会得到：

- `admin_web_url=http://127.0.0.1:3000/login`
- `demo_account=super_admin`
- `next_action=./scripts/dev-verify-admin-demo.sh`（Windows 会显示 `.cmd`）
- `telemetry_path=tmp/m006-s13-front-door-metrics.jsonl`

## Fast smoke（复用 live stack）

### POSIX

```bash
./scripts/dev-verify-admin-demo.sh
```

### Windows (cmd / PowerShell)

```bat
scripts\dev-verify-admin-demo.cmd
```

这个 fast smoke：

- **不会**重新走 full release closure path
- 复用已经启动的 live stack
- 跑完后保留 live stack，方便继续手动操作 admin demo
- 复用 S12 的最小 admin proof surface（auth + Overview freshness control plane）
- 继续输出 `tthw_seconds` / `first_failure_stage` / `likely_cause` / `next_action`
- 继续写入同一份 `tmp/m006-s13-front-door-metrics.jsonl` history，并回显 `smoke_recent_pass_rate` / `first_failure_hotspot`
- 失败时给出下一条可执行的排查命令

## Front-door telemetry handoff

`dev-up-admin-demo` 和 `dev-verify-admin-demo` 共用 `tmp/m006-s13-front-door-metrics.jsonl` 这份 bounded local history。每次 run 都会追加 redaction-safe recent entry（`mode` / `shell` / `success` / `tthw_seconds` / `first_failure_stage` / `likely_cause` / `next_action`），并在 stdout 回显 `telemetry_path` / `smoke_recent_pass_rate` / `first_failure_hotspot`。这样 fresh reader 不用重放 full release closure，也能先判断最近一次 demo + smoke 是否同时成立。

## Final release closure（CI 同款）

```bash
dart run tool/verify_m006_s14_release_closure.dart
```

仓库根唯一 final release command 仍是这条 `dart run tool/verify_m006_s14_release_closure.dart`。

这条顶层 gate 会顺序组合：

- `S07` mentor/distribution closure proof
- `S08` Helm split-stack deploy truth
- `S12` Overview freshness / fallback proof
- `S13` repo-root front-door truth

如果只想 debug 某个局部面，再下钻对应 child verifier；不要在 repo root 重新发明第二条 release command chain。

## Split-stack 地图

| Surface | 角色 | 默认本地入口 | 说明 |
| --- | --- | --- | --- |
| `app-api` | 面向 mobile / consumer 的 HTTP API | `http://127.0.0.1:8080` | public app surface |
| `admin-web` | 管理后台浏览器入口 | `http://127.0.0.1:3000` | 对管理员暴露的唯一前门 |
| `admin-api` | 管理后台后端 API | `http://127.0.0.1:8081` | internal-only；给 `admin-web` 代理和本地开发用；不要把它当 README front door |
| `db-migration` | schema owner / preflight job | `docker compose` one-shot | 先于 app/admin runtime 执行 |
| `mobile` | Flutter 客户端 | `mobile/` | 只连 `app-api`，不连 `admin-api` |

## Role-based quickstarts

### Full stack（推荐）

```bash
./scripts/dev-up-admin-demo.sh
./scripts/dev-verify-admin-demo.sh
```

需要更重的 proof 时再下钻：

```bash
dart run tool/verify_m006_s12_control_plane_freshness.dart
dart run tool/verify_m006_s14_release_closure.dart
```

如果只是 scoped debug，再按面下钻：

```bash
dart run tool/verify_m006_s08_release.dart --runtime
dart run tool/verify_m006_s08_release.dart --helm
```

### Backend only（split-stack 本地开发）

先起依赖与 migration：

```bash
docker compose up -d postgres minio db-migration
```

再分别本地运行两个后端模块：

```bash
./backend/mvnw -f backend/pom.xml -pl app-api -am spring-boot:run
./backend/mvnw -f backend/pom.xml -pl admin-api -am spring-boot:run -Dspring-boot.run.arguments=--server.port=8081
```

快速检查：

```bash
curl -sf http://127.0.0.1:8080/actuator/health
curl -sf http://127.0.0.1:8081/actuator/health
```

### admin-web only

`admin-web` 开发服务器默认把 `/api` 和 `/actuator` 代理到本地 `admin-api`：

```bash
npm --prefix admin-web install
npm --prefix admin-web run dev
```

如果 `admin-api` 不在 `127.0.0.1:8081`，先覆盖代理目标：

```bash
VITE_ADMIN_API_PROXY_TARGET=http://127.0.0.1:8081 npm --prefix admin-web run dev
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
| `docker compose up -d --build` 然后自己猜入口 | 直接跑 `dev-up-admin-demo` wrapper |
| `scripts/verify-e2e.sh` 作为 repo-root smoke | 改用 `dev-verify-admin-demo` wrapper |
| `scripts/run-mobile-e2e.*` 代表仓库前门 | 保留为 mobile 集成历史参考，不再放在 README 顶部 |
| `cd backend && mvn spring-boot:run` | 用 `backend/mvnw` 跑 split modules，或直接走 compose wrapper |
| 仓库“没有 Maven wrapper” | 仓库根真实入口是 `backend/mvnw` / `backend/mvnw.cmd` |
| root README 直接复述部署细节 | 发布 / Helm 真相统一下钻到 runbook |

## 继续往下读什么

- [CONTRIBUTING](CONTRIBUTING.md) — 日常开发路径、verification ladder、目录职责
- [M006 / S14 release-closure runbook](docs/runbooks/m006-s14-release-closure.md) — milestone promise → child verifier → CI artifact 的总入口
- [M006 / S13 demo-path runbook](docs/runbooks/m006-s13-demo-path.md) — wrapper stage、失败语义、Windows/POSIX parity
- [M006 / S12 Overview Control-Plane Freshness Runbook](docs/runbooks/m006-s12-control-plane-freshness.md) — fast smoke 复用的 freshness/auth proof pack
- [Kubernetes split-stack deploy runbook](docs/runbooks/k8s-deploy.md) — 发布、Helm、回滚与 NOTES truth

## Historical references

这些脚本仍然保留，但不再是 repo-root front door：

- `scripts/run-mobile-e2e.sh`
- `scripts/run-mobile-e2e.cmd`
- `scripts/verify-e2e.sh`
- `scripts/verify-s02.sh`
