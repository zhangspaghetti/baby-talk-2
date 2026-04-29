# Baby Talk 2 mobile

`mobile` 是面向父母 / 照护者的 Flutter 客户端。它消费 `app-api` 提供的用户面 contract，**不**直接连接 `admin-api`。

## Getting started

```bash
cd mobile
flutter pub get
flutter run
```

如果你只是想验证 split-stack 能否带起管理员面，先回到 repo root 跑 `dev-up-helm-demo` / `dev-verify-helm-demo`；那两条命令属于 repo-root front door，不属于 mobile front door。对应的 bounded telemetry history 会写到 `../tmp/m007-s01-helm-metrics.jsonl`；如果你是在排查管理员面，不要在 `mobile/` 里再找第二套 smoke。

## Useful commands

### Unit / widget / route tests

```bash
cd mobile
flutter test
```

### Smoke tests

```bash
cd mobile
flutter test test/smoke/
```

### Connect to local app-api

本地开发默认连接 `app-api`。如果你已经从 repo root 拉起了 split stack，`app-api` 默认在 `http://127.0.0.1:8080`。

Android 模拟器访问宿主机时请改用 `10.0.2.2`：

```text
http://10.0.2.2:8080
```

## What lives here

- Flutter UI、路由与状态管理
- 面向家长/照护者的交互流
- 本地缓存 / 离线能力
- 与 `app-api` 的 consumer-facing contract

## Related docs

- [Repo root README](../README.md) — split-stack front door、admin demo、copy-paste auth/API examples
- [CONTRIBUTING](../CONTRIBUTING.md) — everyday workflows 与 verification ladder
- [S13 demo-path runbook](../docs/runbooks/m006-s13-demo-path.md) — wrapper stage、telemetry history、Windows/POSIX parity
