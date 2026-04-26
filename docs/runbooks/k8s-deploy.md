# BabyTalk Kubernetes 双 release 部署 Runbook

本文描述 M007 之后的 **dual-release topology**。如果你还在找旧的单 chart 命令（例如 `deploy/helm/babytalk` 或 `helm upgrade --install babytalk ...`），请停止：那已经不是当前仓库真相。

当前部署被拆成两个独立 Helm release：
- `babytalk-infra`：Postgres、Redis、MinIO，属于 stateful 基础设施。
- `babytalk-app`：`db-migration` Job、`gateway` stub、`app-api`、`admin-api`、`admin-web`，属于应用层。

本 runbook 关注四件事：
1. 当前部署真相是什么。
2. 安装和升级顺序是什么。
3. 回滚边界在哪里。
4. 出问题时先用什么词和什么命令定位。

---

## 1. 当前部署真相

### 1.1 双 release 对照表

| Release | Chart 路径 | 资源性质 | 主要内容 | 生命周期特点 |
| --- | --- | --- | --- | --- |
| `babytalk-infra` | `deploy/helm/babytalk-infra` | stateful | Postgres、Redis、MinIO | 低频升级；回滚必须保守处理数据面 |
| `babytalk-app` | `deploy/helm/babytalk-app` | stateless + hook Job | `db-migration`、`gateway` stub、`app-api`、`admin-api`、`admin-web` | 高频升级；升级前先跑 migration hook |

### 1.2 `babytalk-infra` 的职责

`babytalk-infra` 提供应用依赖的基础 endpoint：
- Postgres：`babytalk-infra-postgres:5432`
- Redis：`babytalk-infra-redis-master:6379`
- MinIO：`babytalk-infra-minio:9000`

这三个组件都带状态，因此 infra release 的升级和回滚不能按“普通应用重启”来理解。特别是 Postgres 与 MinIO，一旦涉及版本或持久化布局变化，必须优先考虑数据兼容性。

### 1.3 `babytalk-app` 的职责

`babytalk-app` 当前包含以下组件：

| 组件 | 类型 | 暴露面 | 说明 |
| --- | --- | --- | --- |
| `db-migration` | Helm hook Job | 不对外 | schema owner；install / upgrade 前执行 |
| `gateway` | Deployment + Service | 集群内 / smoke 面 | 目前是 stub，S03 才会替换为正式 gateway |
| `app-api` | Deployment + Service + Ingress | 对外 | 面向应用客户端 |
| `admin-api` | Deployment + Service | 仅集群内 | 给 `admin-web` 代理调用，不应暴露公网 Ingress |
| `admin-web` | Deployment + Service + Ingress | 对外 | 管理台前端 |

### 1.4 当前必须记住的边界

1. 现在是 **两个 release**，不是一个。
2. `db-migration` 属于 `babytalk-app`，不属于 `babytalk-infra`。
3. `db-migration` 必须先于 app workloads 执行。
4. `admin-api` 是 internal-only service；如果它有公网入口，那就是 drift。
5. `gateway` 当前是 stub，可作为 smoke / 边界验证对象，但不能把它当最终拓扑。

### 1.5 这次拆分解决什么问题

拆分的核心不是“多了一个 chart”，而是把生命周期切开：
- infra 的风险来自 stateful dependency。
- app 的风险来自镜像、配置和 schema 迁移。
- app 升级不应自动绑定 infra 变更。
- infra 升级也不应自动把 app 重新定义成同一条发布链。

---

## 2. 安装顺序

### 2.1 原则

安装顺序固定为：
1. 先 `babytalk-infra`
2. 后 `babytalk-app`

不要反过来。`babytalk-app` 依赖的 Postgres、Redis、MinIO endpoint 来自 infra release，本质上它没有“先 app 再 infra”的合理路径。

### 2.2 kind / 本地集群安装命令

先安装 infra：

```bash
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra \
  -f deploy/helm/babytalk-infra/values-kind.yaml \
  -n babytalk \
  --create-namespace
```

再安装 app：

```bash
helm upgrade --install babytalk-app deploy/helm/babytalk-app \
  -f deploy/helm/babytalk-app/values-kind.yaml \
  -n babytalk
```

### 2.3 为什么推荐把 namespace 创建放在 infra 命令里

`--create-namespace` 建议放在 infra install 上，原因是：
- infra 通常是一个环境的第一步。
- app 应该默认依赖环境已经初始化。
- 故障时更容易区分“环境未初始化”和“应用发布失败”。

### 2.4 安装后最小检查

```bash
helm list -n babytalk
kubectl get pods,svc,ingress,jobs -n babytalk
```

预期：
- `helm list` 里存在 `babytalk-infra` 和 `babytalk-app` 两个 release。
- `kubectl get` 里能看到 infra 的 service 与 app 的 workload。
- 如果你只看到一个 `babytalk` release，说明环境仍停留在旧 runbook 语义。

### 2.5 依赖面快速校验

```bash
kubectl get svc -n babytalk | grep 'babytalk-infra'
kubectl get svc -n babytalk | grep 'babytalk-app'
```

这一步不是 smoke 的替代，而是给值班者一个最短路径，用来证明两个 release 都落到了命名空间里。

---

## 3. 独立升级路径

### 3.1 infra-only upgrade

infra-only upgrade 的意思是：
- 只升级 `babytalk-infra`
- 不改变 `babytalk-app` revision
- 不触发 `db-migration` hook

示例：

```bash
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra \
  -f deploy/helm/babytalk-infra/values-kind.yaml \
  -n babytalk
```

适用场景：
- 调整 infra values
- 调整 Postgres / Redis / MinIO 资源
- 升级 infra chart 或其依赖

要点：这不代表“绝不会影响业务”，只代表 **不会触发 app release 生命周期**。stateful dependency 抖动依然可能传导到 app。

### 3.2 app-only upgrade

app-only upgrade 的意思是：
- 只升级 `babytalk-app`
- 触发 `db-migration` pre-upgrade hook
- hook 成功后再 rollout `gateway`、`app-api`、`admin-api`、`admin-web`

示例：

```bash
helm upgrade --install babytalk-app deploy/helm/babytalk-app \
  -f deploy/helm/babytalk-app/values-kind.yaml \
  -n babytalk
```

适用场景：
- 发布新的 app / admin 镜像
- 发布新的 `db-migration` 镜像
- 修改 app config、secret、ingress

### 3.3 app-only upgrade 的真实顺序

`babytalk-app` 的升级顺序不是“先 rollout，再补 migration”，而是：
1. Helm 开始处理 app release。
2. `db-migration` 以 pre-install / pre-upgrade hook 先执行。
3. hook 成功后才应用新的 workloads。

这是 dual-release 边界里最重要的操作语义之一。

### 3.4 不要把两个升级黏在一起

最常见的排障噪音来自“顺手一起升”：
- 先升 infra
- 紧接着升 app
- 失败后分不清到底是 dependency 抖动，还是 migration / rollout 问题

推荐做法：
- 拆成两个明确步骤
- 每一步结束后做一轮最小验证
- 每一步单独评估是否能回滚

---

## 4. db-migration hook 语义与失败处理

### 4.1 当前必须保留的三个 hook 注解

`babytalk-app` 中的 `db-migration` 不是普通 Job，而是 Helm hook Job。当前必须保留：
- `helm.sh/hook: pre-install,pre-upgrade`
- `helm.sh/hook-weight: -10`
- `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`

含义分别是：
- `pre-install,pre-upgrade`：在 install / upgrade 主体资源前执行。
- `hook-weight: -10`：当有多个 hook 时，把 migration 提前。
- `before-hook-creation,hook-succeeded`：新 hook 前清理旧 hook；成功的 hook 会自动删除。

### 4.2 当前失败重试约束

migration Job 的关键运行约束之一是：
- `backoffLimit: 1`

它表示失败不会长时间自动重试，值班者应尽快看日志定位问题，而不是等待多轮重试掩盖根因。

### 4.3 首选诊断命令

如果 app install / upgrade 失败，先看 Job：

```bash
kubectl get jobs -n babytalk
```

再看日志：

```bash
kubectl logs job/<db-migration-job-name> -n babytalk
```

如果名称符合默认渲染，常见会是：

```bash
kubectl logs job/babytalk-app-db-migration -n babytalk
```

### 4.4 常见失败归类

优先从下面几类里找：
- 数据库连通性错误
- 数据库凭证错误
- migration SQL 失败
- 新旧 workload 对 schema 的兼容性判断错误
- 镜像 tag 或 secret 与预期不一致

### 4.5 成功的 Job 可能看不到

因为使用了 `before-hook-creation,hook-succeeded`，成功的 hook 可能已经被 Helm 自动删除。因此：
- “没看到成功 Job”不等于“没跑过”。
- 真正的判断要结合 Helm 输出、release revision、workload 是否进入新版本，以及失败时留下的日志。

### 4.6 回滚约束：schema forward-only

最重要的约束是：
- schema migration 是 **forward-only** 的。
- `helm rollback babytalk-app` 会恢复 workloads。
- 它 **不会撤销** 已执行的数据库迁移。

也就是说：

```bash
helm rollback babytalk-app <revision> -n babytalk
```

恢复的是 Kubernetes workload revision，不是 schema 历史。

### 4.7 值班时的直接判断问题

在执行 app rollback 前，必须先回答：

> 旧版本 `app-api` / `admin-api` 是否兼容已经前滚到当前版本的 schema？

如果不能从代码、文档或矩阵中证明兼容，就不能把 `helm rollback babytalk-app` 当成无脑止血动作。

---

## 5. Schema 兼容矩阵引用

### 5.1 authoritative 文档位置

schema 兼容边界的唯一文档入口是：
- 仓库路径：`docs/schema-compatibility-matrix.md`
- 相对链接：[schema-compatibility-matrix.md](../schema-compatibility-matrix.md)

### 5.2 什么时候先查矩阵

下面几类问题都应先看矩阵：
- app release 是否可以安全回滚
- 新 migration 是否仍满足 N / N-1 兼容窗口
- 哪个 workload 版本第一次依赖某个 schema 变更
- 旧版 admin / app workload 是否还能与当前 schema 共存

### 5.3 runbook 与 matrix 的分工

- 本 runbook 负责：部署、升级、回滚、排障操作。
- `docs/schema-compatibility-matrix.md` 负责：schema 与 workload 版本兼容规则。

两者一起构成 dual-release 的 release boundary contract。

---

## 6. 回滚指南

### 6.1 先说清楚回滚的是哪一个 release

M007 之后，“回滚 BabyTalk”这句话太模糊。必须先明确：
- 你回滚的是 `babytalk-infra`
- 还是 `babytalk-app`

### 6.2 infra rollback

infra rollback 涉及 Postgres、Redis、MinIO，风险模型是 stateful 数据面。

示例：

```bash
helm history babytalk-infra -n babytalk
helm rollback babytalk-infra <revision> -n babytalk
```

执行前至少确认：
1. 当前数据是否允许对应版本回退。
2. StatefulSet / PVC / 依赖 chart 是否存在不兼容行为。
3. app 当前是否依赖新的 infra capability 或 endpoint 约定。

默认心智模型应当是：
- 这是保守操作。
- 这不是应用级快速回滚。
- 数据安全优先于“尽快回到旧版本”。

### 6.3 app rollback

app rollback 典型命令：

```bash
helm history babytalk-app -n babytalk
helm rollback babytalk-app <revision> -n babytalk
```

它通常比 infra rollback 更快，因为主要回滚的是 workloads、config 绑定与入口映射。但它只在下面条件成立时才安全：
- 目标旧 workload 仍兼容当前 schema
- 旧 workload 不依赖已经删除或重命名的列 / 表
- 回滚不会把入口重新指向错误的服务边界

### 6.4 什么情况下不要直接 app rollback

出现以下任一情况时，不应直接执行 `helm rollback babytalk-app`：
- 本次 migration 删除了旧版 workload 仍依赖的列
- 本次 migration 重命名了旧版 workload 仍依赖的表
- 旧版 `admin-api` 或 `app-api` 无法兼容当前 schema
- 你无法从 `docs/schema-compatibility-matrix.md` 证明兼容性

### 6.5 推荐回滚决策顺序

1. 先判断故障属于 infra 还是 app。
2. 如果是 app，先判断是 migration 问题还是 workload / config 问题。
3. 查 `docs/schema-compatibility-matrix.md` 确认 schema 兼容性。
4. 兼容性成立时，才执行 `helm rollback babytalk-app`。
5. 兼容性不成立时，先设计数据库恢复或补丁策略。

### 6.6 回滚后最小验证

```bash
kubectl rollout status deployment/babytalk-app-app-api -n babytalk
kubectl rollout status deployment/babytalk-app-admin-api -n babytalk
kubectl rollout status deployment/babytalk-app-admin-web -n babytalk
kubectl get ingress,svc -n babytalk
```

如果回滚的是 infra，还要补充：

```bash
kubectl get pods -n babytalk
kubectl get pvc -n babytalk
```

---

## 7. 预检与验证

### 7.1 文档级预检

```bash
grep -q 'babytalk-infra' docs/runbooks/k8s-deploy.md
grep -q 'babytalk-app' docs/runbooks/k8s-deploy.md
grep -q 'schema-compatibility-matrix' docs/runbooks/k8s-deploy.md
[ -f docs/schema-compatibility-matrix.md ]
```

### 7.2 Helm template 边界预检

infra chart 应该 **没有** db-migration Job：

```bash
helm template babytalk-infra deploy/helm/babytalk-infra \
  -f deploy/helm/babytalk-infra/values-kind.yaml \
  | grep -c 'kind: Job'
```

期望输出：`0`

app chart 应该仍保留 migration hook-delete-policy：

```bash
helm template babytalk-app deploy/helm/babytalk-app \
  -f deploy/helm/babytalk-app/values-kind.yaml \
  | grep 'hook-delete-policy'
```

期望输出包含：`before-hook-creation,hook-succeeded`

app chart 应该仍保留 pre-hook 语义：

```bash
helm template babytalk-app deploy/helm/babytalk-app \
  -f deploy/helm/babytalk-app/values-kind.yaml \
  | grep 'helm.sh/hook'
```

期望输出包含：`pre-install,pre-upgrade`

### 7.3 仓库 smoke

```bash
bash ci/k8s-smoke.sh
```

这条命令应该继续证明：
- 双 chart 可以离线验证
- app chart 仍包含 `gateway`、`db-migration`、`app-api`、`admin-api`、`admin-web`
- release notes 仍清晰区分 public surface 与 internal service
- dual-release 文档边界没有 drift

### 7.4 Dart verifier

```bash
dart run tool/verify_m007_s02_release_boundaries.dart
```

它负责把 release boundary contract 固化成单入口检查，而不是要求值班者自己拼命令。

### 7.5 真实集群安装后的最小检查

```bash
helm list -n babytalk
kubectl get jobs,deployments,services,ingress -n babytalk
kubectl get svc -n babytalk | grep 'babytalk-infra'
kubectl get svc -n babytalk | grep 'babytalk-app'
```

### 7.6 什么叫“验证通过”

只有下面四类证据同时成立，才算 dual-release 拓扑没有 drift：
1. 文档提到 `babytalk-infra` 与 `babytalk-app`，并引用 `schema-compatibility-matrix`。
2. infra chart 不渲染 migration Job。
3. app chart 保留 migration hook 语义。
4. smoke 与 verifier 都通过。

---

## 8. 故障定位词汇

本节用于统一值班沟通语言。建议先用下面六个词归类，再展开调查。

### 8.1 preflight

`preflight` 指进入集群资源变更前就能发现的问题，例如：
- `helm lint` 失败
- `helm template` 失败
- runbook 或 schema matrix 缺失
- smoke / verifier 在离线阶段失败

处理方式：先修 chart、values 或 docs，不要继续真实 install / upgrade。

### 8.2 cluster

`cluster` 指 Kubernetes 资源层的问题，例如：
- Pod Pending / CrashLoopBackOff
- Job Failed
- rollout 卡住
- Service / Ingress 缺失

常用命令：

```bash
kubectl get pods,svc,ingress,jobs -n babytalk
kubectl describe <resource> -n babytalk
kubectl logs <resource> -n babytalk
```

### 8.3 infra

`infra` 指基础设施 release 及其依赖面的问题，例如：
- Postgres 不可达
- Redis endpoint 异常
- MinIO endpoint 异常
- `babytalk-infra` 升级后 app 无法连接依赖

### 8.4 app

`app` 指 `babytalk-app` 自身生命周期的问题，例如：
- `db-migration` hook 失败
- `app-api` / `admin-api` / `admin-web` rollout 失败
- app rollback 后行为与当前 schema 不兼容

### 8.5 gateway

`gateway` 当前仍是 stub，因此既是组件，也是 release boundary 信号：
- 如果 smoke 中 gateway 检查失败，优先把它当 app 边界回归。
- 不要先把 gateway 问题归类成 infra 故障。

### 8.6 smoke

`smoke` 指仓库里的自动化边界证明，而不是手工点页面。
在本 slice 中，最关键的是：
- `bash ci/k8s-smoke.sh`
- `dart run tool/verify_m007_s02_release_boundaries.dart`

如果 smoke 失败，先按它给出的第一失败阶段下钻，而不是跳过 smoke 凭经验宣称“chart 应该没问题”。

### 8.7 推荐报障句式

- `preflight 失败：app chart 丢了 hook-delete-policy。`
- `cluster 失败：babytalk-app-db-migration Job Failed。`
- `infra 风险：babytalk-infra 回滚可能影响数据兼容。`
- `app 风险：旧版 admin-api 可能不兼容当前 schema。`
- `gateway 回归：smoke 不再能证明 gateway stub 仍在 app release 中。`
- `smoke 失败：先修 release boundary contract，再讨论发布。`

---

## 9. 操作摘要

把整篇 runbook 压缩成一句话：

> 先 `babytalk-infra`，后 `babytalk-app`；`db-migration` 作为 app release 的 pre-hook 先执行；infra 回滚保守，app 回滚必须先过 schema 兼容性判断；发布前以 `bash ci/k8s-smoke.sh` 和 `dart run tool/verify_m007_s02_release_boundaries.dart` 证明 dual-release 边界仍成立。

如果后续文档再次出现 `deploy/helm/babytalk`、单个 `babytalk` release，或把 `helm rollback babytalk-app` 写成“会撤销 schema migration”，应视为文档 drift，必须先修正文档再继续发布。