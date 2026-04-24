# M006 / S13 Admin Demo-Path Front Door Runbook

本文面向 **第一次进入仓库的工程师**。读完后，你应该能够在 repo root：

1. 启动可操作的 admin demo
2. 复用 live stack 跑 fast smoke
3. 从 `first_failure_stage` / `likely_cause` / `next_action` 直接下钻排查

## Boundary

S13 只负责 **repo-root front door truth**：

- `dev-up-admin-demo` 负责 golden path demo
- `dev-verify-admin-demo` 负责 live stack fast smoke
- `README.md` / `CONTRIBUTING.md` / `mobile/README.md` 提供 fresh-reader 可执行入口
- `tool/verify_m006_s13_demo_path.dart` 证明 docs links、wrapper parity 与 front-door contract

S13 **不**替代：

- [M006 / S12 Overview Control-Plane Freshness Runbook](m006-s12-control-plane-freshness.md) 的 auth / Overview proof pack
- [Kubernetes split-stack deploy runbook](k8s-deploy.md) 的发布与回滚手册
- 后续 release-closure aggregator 的最终 gate

## Golden path commands

### POSIX

```bash
./scripts/dev-up-admin-demo.sh
./scripts/dev-verify-admin-demo.sh
```

### Windows

```bat
scripts\dev-up-admin-demo.cmd
scripts\dev-verify-admin-demo.cmd
```

## Stage contract

| Flow | Stage label | 通过信号 | 失败后下一步 |
| --- | --- | --- | --- |
| demo | `preflight` | `dart` / `docker` 可执行，daemon 可达 | 安装缺失工具或启动 Docker Desktop |
| demo | `compose_boot` | `postgres → minio → db-migration → app-api → admin-api → admin-web` 全部被 compose 接管 | `docker compose ps --all` / `docker compose logs ...` |
| demo | `runtime_truth` | `app-api`、`admin-api` 健康，`admin-web` 返回 BabyTalk Admin shell | 先修第一个不健康 / 未退出成功的服务 |
| smoke | `preflight` | `docker`、`npm` 可执行 | 安装缺失工具 |
| smoke | `live_stack_precondition` | live stack 已在运行，`admin-web` 可达 | 先运行 `dev-up-admin-demo` |
| smoke | `fast_smoke` | `dart run tool/verify_m006_s12_control_plane_freshness.dart` 通过 | 直接下钻 S12 proof pack |

每条 wrapper 都会输出：

- `tthw_seconds`
- `first_failure_stage`
- `likely_cause`
- `next_action`

成功时固定输出 `first_failure_stage=none`。

## Failure semantics

### Missing prerequisite

- wrapper 不应该只回一个裸的 shell 错误
- 必须返回 `first_failure_stage=preflight`
- `next_action` 必须是可执行动作，而不是“请自行检查环境”

### Compose boot failure

- 停在 `compose_boot`
- 先修第一个 failed / unhealthy service，而不是盲目 `docker compose down -v`
- 把 `db-migration` 是否 exited 0 与 app/admin runtime 是否 healthy 分开判断

### Smoke failure

- 停在 `fast_smoke`
- 直接复用 `dart run tool/verify_m006_s12_control_plane_freshness.dart` 作为下一跳
- smoke 只消费 live stack，不应该在成功后顺手把它停掉
- 不要把 full release closure 变成默认 smoke

### Malformed / stale docs

以下都算 S13 failure，而不是“文档优化待办”：

- `README.md` 没有把 `dev-up-admin-demo` / `dev-verify-admin-demo` 放在 front door
- `mobile/README.md` 仍然保留 Flutter 模板文本
- root docs 继续宣称仓库没有 Maven wrapper
- README / CONTRIBUTING / runbook 的相对链接失效

## Windows / POSIX parity

Windows / POSIX parity 的要求不是“功能大致差不多”，而是：

- `.sh` / `.cmd` 都暴露 **同名** demo / smoke 入口
- 两边都委托给同一个 `tool/verify_m006_s13_demo_path.dart` mode
- 两边都输出相同的 stage vocabulary：`preflight` / `compose_boot` / `runtime_truth` / `live_stack_precondition` / `fast_smoke`
- Windows 不能悄悄跳过 smoke、health、或 next-action guidance

## Docs contract

repo-root docs 现在应该让 fresh reader 一眼知道：

- `README.md` 是唯一 front door
- `CONTRIBUTING.md` 说明 daily workflow 和 verification ladder
- `mobile/README.md` 只说明 mobile truth，不再冒充全仓库入口
- 旧脚本（`run-mobile-e2e.*`、`verify-e2e.sh`）是 historical references，不再出现在 README 顶部
- copy-paste auth / API examples 统一通过 `admin-web` 代理，而不是逼读者先找到 public admin-api URL

## Canonical verification

```bash
dart run tool/verify_m006_s13_demo_path.dart
rg -n "dev-up-admin-demo|dev-verify-admin-demo|admin-web|admin-api|CONTRIBUTING" README.md
! rg -n "A new Flutter project" mobile/README.md
```

运行时 proof：

```bash
./scripts/dev-up-admin-demo.sh
./scripts/dev-verify-admin-demo.sh
```

Windows 对应 `.cmd` 应得到同一套 stage / failure semantics。

## Sensitive output rules

front door wrapper、README、runbook 都不应该打印：

- JWT / refresh token
- bootstrap password
- raw mentor / share payload
- public admin-api URL

成功信息只需要告诉操作者：**入口在哪、账号是谁、下一步跑什么**。
