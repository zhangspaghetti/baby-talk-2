# BabyTalk Kubernetes split-stack 部署 Runbook

本文面向 **值班/发布工程师**。读完后，你应该能够在不依赖旧 README quickstart 的前提下，独立完成 BabyTalk M006 admin runtime 的 **split-stack 发布、验证、失败定位和回滚判断**。

## 1. 当前部署真相（不要再按旧单体模型操作）

M006 的 Helm chart 已经不是单个 `babytalk/backend` workload。当前生产部署模型是 4 个明确组件：

| 组件 | 角色 | 暴露面 | 说明 |
| --- | --- | --- | --- |
| `app-api` | 移动端/消费端 HTTP API | **public** | 通过 `appApi.ingress` 暴露给 mobile/client 使用。 |
| `admin-web` | 管理台浏览器入口（Nginx + 静态前端） | **public** | 通过 `adminWeb.ingress` 暴露给管理员浏览器。 |
| `admin-api` | 管理台后端 API | **internal-only** | 只通过集群内 `Service` 提供给 `admin-web` 反向代理，不应创建外网 Ingress。 |
| `db-migration` | schema 迁移 owner | **hook job** | 以 `pre-install,pre-upgrade` hook 先于 app/admin workloads 执行。 |

必须记住的边界：

- **mobile/public client 只走 `app-api`**。
- **admin browser 只走 `admin-web`**。
- **`admin-api` 只给 `admin-web` 代理，不对外暴露**；如果渲染结果里出现 `admin-api` 的 Ingress，就是 drift。
- **`db-migration` 是唯一 schema owner**；不要在 `app-api`/`admin-api` rollout 成功后才补做迁移。

## 2. 发布前输入与前置条件

发布前准备以下输入：

- Kubernetes 集群（建议 `kubectl >= 1.28`）。
- Helm（建议 `helm >= 3.12`）。
- 已推送的四个镜像 tag：`app-api`、`admin-api`、`admin-web`、`db-migration`。
- 一份生产覆盖值：`deploy/helm/babytalk/values-production.yaml`。
- 可注入的敏感配置来源（CI secret、External Secret、Vault 等）。

生产 chart 假设：

- `app-api` 的公网入口是 `https://api.babytalk.example.com`。
- `admin-web` 的公网入口是 `https://admin.babytalk.example.com`。
- `admin-api` 只保留为集群内 `svc/babytalk-admin-api:8081`。
- `admin-web` 本身只挂载代理配置，**不直接消费 DB/JWT/AI/MinIO secrets**。

## 3. 必填 Secret / Config 面

生产部署至少要覆盖以下敏感值；不要把真实值提交进仓库：

| 配置组 | 关键键 | 被谁消费 |
| --- | --- | --- |
| 数据库 | `BABY_TALK_DB_URL` / `BABY_TALK_DB_USERNAME` / `BABY_TALK_DB_PASSWORD` | `app-api`、`admin-api`、`db-migration` |
| 消费端认证 | `BABY_TALK_CONSUMER_JWT_SECRET` | `app-api` |
| 管理端认证 | `BABY_TALK_ADMIN_JWT_SECRET` / `BABY_TALK_ADMIN_BOOTSTRAP_PASSWORD` | `admin-api` |
| AI / Embedding | `BABY_TALK_AI_API_KEY` / `BABY_TALK_EMBEDDING_API_KEY` | `app-api`、`admin-api` |
| 对象存储 | `BABY_TALK_MINIO_ENDPOINT` / `BABY_TALK_MINIO_ACCESS_KEY` / `BABY_TALK_MINIO_SECRET_KEY` / `BABY_TALK_MINIO_BUCKET` | `app-api`、`admin-api` |

还需要确认以下非敏感配置与目标环境一致：

- `BABY_TALK_MENTOR_PROVIDER_MODE` / `BABY_TALK_MENTOR_PROVIDER_TIMEOUT`
- `BABY_TALK_MENTOR_SEARCH_MODE`
- `BABY_TALK_KG_REVIEW_ENABLED` / `BABY_TALK_KG_REVIEW_INTERVAL` / `BABY_TALK_KG_REVIEW_BATCH_SIZE`
- `BABY_TALK_ADMIN_*` 的 bootstrap / audit / distribution 默认值
- 面向用户的 `BABY_TALK_UPGRADE_URL`、下载地址、分享/邀请公网 URL

推荐做法：

1. 把 `values-production.yaml` 里的镜像仓库、host、资源配额当作非敏感基线。
2. 通过 CI secret、`--set secret.*`、或外部 Secret Controller 注入真实 secret。
3. 不要为了“省事”给 `admin-api` 额外配 Ingress；它的可达性应该来自 `admin-web` 代理而不是公网直连。

## 4. 发布前预检（chart truth）

先验证 chart 渲染和命名真相，再真正升级 release。

### 4.1 Helm lint

```bash
helm lint deploy/helm/babytalk
helm lint deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml
```

### 4.2 渲染 split-stack 资源清单

```bash
helm template babytalk deploy/helm/babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  > /tmp/babytalk.rendered.yaml

rg -n "babytalk-(app-api|admin-api|admin-web|db-migration)|helm.sh/hook" /tmp/babytalk.rendered.yaml
kubectl apply --dry-run=client -f /tmp/babytalk.rendered.yaml
```

人工检查点：

- 存在 `Deployment/babytalk-app-api`、`Deployment/babytalk-admin-api`、`Deployment/babytalk-admin-web`。
- 存在 `Job/babytalk-db-migration`，并带 `helm.sh/hook: pre-install,pre-upgrade`。
- 生产渲染里有 `Ingress/babytalk-app-api` 和 `Ingress/babytalk-admin-web`。
- **不应**存在旧的单体 `Deployment/babytalk` / `Service/babytalk`。
- **不应**存在 `Ingress/babytalk-admin-api`。

### 4.3 运行 chart smoke（命名/NOTES/hook truth）

```bash
bash ci/k8s-smoke.sh
```

这个 smoke 脚本不是简单数资源个数；它会按 **资源名** 断言 split-stack 真相，并检查：

- `app-api` / `admin-api` / `admin-web` / `db-migration` 是否都被渲染出来。
- `db-migration` 是否仍然是 `pre-install,pre-upgrade` hook。
- NOTES 是否把 `app-api` / `admin-web` 作为 public surface，把 `admin-api` 标成 internal service。
- 旧的单 workload 资源是否已经被拒绝。

## 5. Repo-root release gate（CI 同款）

在真正发布前，先在仓库根跑一遍完整 gate，确认 compose / Maven / Playwright / Helm 这条链没有回归：

```bash
dart run tool/verify_m006_s08_release.dart
```

这个命令默认执行两部分：

1. **runtime gate**：`docker compose up -d --build` → compose truth → backend test → Playwright canonical admin proof。
2. **helm gate**：调用 `bash ci/k8s-smoke.sh` 校验 chart、test pod 和 NOTES truth。

排障时优先看 verifier 打印的 failing step label，例如：

- `Runtime | compose boot`
- `Runtime | migration-first compose truth`
- `Runtime | canonical admin browser proof pack`
- `Helm | split-stack smoke proof`

这比看旧脚本的模糊报错更快，因为它能直接告诉你失败落在 compose、Playwright 还是 Helm smoke。

## 6. 正式发布 / 升级

使用 `helm upgrade --install`，同时显式覆盖四个镜像 tag 和所有敏感值来源。

```bash
helm upgrade --install babytalk deploy/helm/babytalk \
  --namespace babytalk \
  --create-namespace \
  -f deploy/helm/babytalk/values-production.yaml \
  --set appApi.image.tag=<app-api-tag> \
  --set adminApi.image.tag=<admin-api-tag> \
  --set adminWeb.image.tag=<admin-web-tag> \
  --set dbMigration.image.tag=<db-migration-tag> \
  --set secret.BABY_TALK_DB_URL=<db-url> \
  --set secret.BABY_TALK_DB_USERNAME=<db-user> \
  --set secret.BABY_TALK_DB_PASSWORD=<db-password> \
  --set secret.BABY_TALK_CONSUMER_JWT_SECRET=<consumer-jwt-secret> \
  --set secret.BABY_TALK_ADMIN_JWT_SECRET=<admin-jwt-secret> \
  --set secret.BABY_TALK_ADMIN_BOOTSTRAP_PASSWORD=<bootstrap-password> \
  --set secret.BABY_TALK_AI_API_KEY=<ai-api-key> \
  --set secret.BABY_TALK_EMBEDDING_API_KEY=<embedding-api-key> \
  --set secret.BABY_TALK_MINIO_ENDPOINT=<minio-endpoint> \
  --set secret.BABY_TALK_MINIO_ACCESS_KEY=<minio-access-key> \
  --set secret.BABY_TALK_MINIO_SECRET_KEY=<minio-secret-key> \
  --set secret.BABY_TALK_MINIO_BUCKET=<minio-bucket>
```

发布顺序说明：

1. Helm 先执行 `db-migration` hook job。
2. 只有 hook 成功后，`app-api` / `admin-api` / `admin-web` 才进入 rollout。
3. `admin-web` 的代理 upstream 来自 chart 生成的 ConfigMap，目标是集群内 `admin-api` Service。

## 7. 集群内验收（部署后）

### 7.1 看 release 基本面

```bash
kubectl get jobs,deployments,services,ingress -n babytalk
kubectl rollout status deployment/babytalk-app-api -n babytalk
kubectl rollout status deployment/babytalk-admin-api -n babytalk
kubectl rollout status deployment/babytalk-admin-web -n babytalk
```

期望结果：

- `app-api`、`admin-api`、`admin-web` 三个 deployment 都完成 rollout。
- service 名称与 split-stack 一致。
- ingress 只有 `babytalk-app-api` 和 `babytalk-admin-web`。

### 7.2 检查 migration 是否真的先跑过

```bash
kubectl get job -n babytalk | rg db-migration || true
kubectl describe job babytalk-db-migration -n babytalk || true
kubectl logs job/babytalk-db-migration -n babytalk --tail=200 || true
```

注意：

- chart 配置了 `hook-delete-policy: before-hook-creation,hook-succeeded`。
- **成功的 migration hook 可能已经被 Helm 自动删除**，所以“看不到 job”不一定是失败。
- 如果 install/upgrade 卡住或失败，优先抓失败中的 `db-migration` job logs；不要先去怀疑 `admin-web`。

### 7.3 验证 public 与 internal surface

```bash
kubectl get ingress -n babytalk
kubectl get svc -n babytalk
```

你应该看到：

- `app-api` 对应外网 host（mobile/public surface）。
- `admin-web` 对应外网 host（admin browser surface）。
- `admin-api` 只有 ClusterIP Service，没有 Ingress；它是 **internal-only**。

如需临时诊断，可做 port-forward，但这只是运维通道，不代表要把它公开暴露：

```bash
kubectl port-forward -n babytalk svc/babytalk-app-api 8080:8080
kubectl port-forward -n babytalk svc/babytalk-admin-web 3000:80
kubectl port-forward -n babytalk svc/babytalk-admin-api 8081:8081
```

## 8. 故障定位顺序（按信号，不按猜测）

### A. `helm lint` 或 `helm template` 失败

优先怀疑：

- `values-production.yaml` 缺字段。
- 新 chart 资源名/hook 注解被改坏。
- 试图把旧单 workload 逻辑混回 chart。

先跑：

```bash
bash ci/k8s-smoke.sh
helm template babytalk deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml
```

### B. 发布卡在 hook 阶段

优先看：

```bash
kubectl describe job babytalk-db-migration -n babytalk || true
kubectl logs job/babytalk-db-migration -n babytalk --tail=200 || true
```

常见根因：

- DB URL / 凭证错误。
- `db-migration` 镜像 tag 与服务镜像不匹配。
- 集群网络无法访问 PostgreSQL。

### C. `admin-web` 正常、但后台页面请求失败

优先确认：

- `admin-api` deployment 是否 ready。
- `admin-api` service 是否存在且端口仍为 `8081`。
- `admin-web` 代理 ConfigMap 是否仍指向 `admin-api` service，而不是旧 host。

### D. Repo-root verifier 失败

优先根据 step label 归类：

- `Runtime | migration-first compose truth`：看 compose 服务健康、`db-migration` 是否 exited=0、两个 actuator 是否 `UP`。
- `Runtime | canonical admin browser proof pack`：看 `admin-web/playwright-report`。
- `Helm | split-stack smoke proof`：回到 `bash ci/k8s-smoke.sh` 的具体 FAIL 行。

## 9. 回滚原则

先看历史版本：

```bash
helm history babytalk --namespace babytalk
```

如果只是 `app-api` / `admin-api` / `admin-web` 镜像或配置回归，可以执行：

```bash
helm rollback babytalk <revision> --namespace babytalk
kubectl rollout status deployment/babytalk-app-api -n babytalk
kubectl rollout status deployment/babytalk-admin-api -n babytalk
kubectl rollout status deployment/babytalk-admin-web -n babytalk
```

但要注意两条硬规则：

- Helm rollback **不会自动撤销已经执行过的数据库迁移**。
- 如果本次 `db-migration` 引入了不向后兼容的 schema 变化，只有在旧版本镜像仍兼容该 schema 时才允许快速回滚；否则先处理数据库恢复/补丁策略，再回滚应用层。

## 10. 发布完成前的最小证据

把下面这些命令的结果视为 M006/S08 的 deploy truth 证据，而不是旧 runbook 里的单体检查：

```bash
dart run tool/verify_m006_s08_release.dart
bash ci/k8s-smoke.sh
helm template babytalk deploy/helm/babytalk -f deploy/helm/babytalk/values-production.yaml
kubectl get jobs,deployments,services,ingress -n babytalk
```

只要其中任何一步还在引用旧的单 workload `babytalk/backend` 叙事，就说明发布文档或发布流程已经 drift，必须先修正再继续。