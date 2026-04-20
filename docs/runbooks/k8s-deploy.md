# BabyTalk Kubernetes 部署操作手册

本手册提供从零到运行的完整 K8s 部署操作步骤。

## 目录

1. [前置条件](#前置条件)
2. [环境准备](#环境准备)
3. [Secret 注入](#secret-注入)
4. [部署](#部署)
5. [验证](#验证)
6. [日常运维](#日常运维)
7. [回滚](#回滚)
8. [监控与告警](#监控与告警)
9. [常见问题排查](#常见问题排查)

---

## 前置条件

| 工具 | 版本要求 | 说明 |
|------|----------|------|
| kubectl | ≥ 1.28 | Kubernetes CLI |
| Helm | ≥ 3.12 | Kubernetes 包管理器 |
| Docker | ≥ 24.0 | 构建镜像（可选，CI 中完成） |

### 集群要求

- Kubernetes ≥ 1.28
- Ingress Controller 已安装（nginx 或阿里云 ALB）
- 至少 2 个节点（生产环境，支持 Pod 反亲和性分散）
- 可选：cert-manager（自动 TLS 证书）

### 镜像准备

```bash
# 构建后端镜像
docker build -t babytalk/backend:1.0.0 -f backend/Dockerfile backend/

# 推送到镜像仓库（阿里云 ACR 示例）
docker tag babytalk/backend:1.0.0 registry.cn-hangzhou.aliyuncs.com/babytalk/backend:1.0.0
docker push registry.cn-hangzhou.aliyuncs.com/babytalk/backend:1.0.0
```

---

## 环境准备

### 1. 创建命名空间

```bash
kubectl create namespace babytalk
kubectl label namespace babytalk app=babytalk env=production
```

### 2. 创建镜像拉取凭证（私有仓库）

```bash
# 阿里云 ACR
kubectl create secret docker-registry acr-credential \
  --namespace babytalk \
  --docker-server=registry.cn-hangzhou.aliyuncs.com \
  --docker-username=<your-username> \
  --docker-password=<your-password>

# AWS ECR（替代方案）
# 使用 aws-ecr-credential-helper 或 IRSA
```

---

## Secret 注入

### 方式一：Helm --set（适合初始部署）

```bash
helm install babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --set secret.BABY_TALK_DB_URL="jdbc:postgresql://rds-endpoint:5432/babytalk?sslmode=require" \
  --set secret.BABY_TALK_DB_USERNAME="babytalk_app" \
  --set secret.BABY_TALK_DB_PASSWORD="<your-db-password>" \
  --set secret.BABY_TALK_AI_API_KEY="<your-api-key>" \
  --set secret.BABY_TALK_EMBEDDING_API_KEY="<your-embedding-key>"
```

> **M005 新增：** `BABY_TALK_EMBEDDING_API_KEY` 是 MemPalace 语义搜索所需的 Embedding API 密钥。若使用 `agentic` 或 `rag` 搜索模式，此密钥**必须配置**。

### 方式二：外部 Secret 管理（推荐生产环境）

使用 [External Secrets Operator](https://external-secrets.io/) 从云厂商密钥管理服务同步：

```yaml
# external-secret.yaml 示例（阿里云 KMS）
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: babytalk-secrets
  namespace: babytalk
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aliyun-kms
    kind: ClusterSecretStore
  target:
    name: babytalk  # 必须与 Helm release fullname 一致
  data:
    - secretKey: BABY_TALK_DB_URL
      remoteRef:
        key: babytalk/db-url
    - secretKey: BABY_TALK_DB_USERNAME
      remoteRef:
        key: babytalk/db-username
    - secretKey: BABY_TALK_DB_PASSWORD
      remoteRef:
        key: babytalk/db-password
    - secretKey: BABY_TALK_AI_API_KEY
      remoteRef:
        key: babytalk/ai-api-key
    - secretKey: BABY_TALK_EMBEDDING_API_KEY
      remoteRef:
        key: babytalk/embedding-api-key
```

> **注意：** 使用外部 Secret 管理时，Helm chart 中的 `secret` 值保持为空字符串，Secret 由 ExternalSecret Controller 创建和更新。

### 方式三：HashiCorp Vault

```bash
# 安装 Vault Secrets Operator
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system \
  --create-namespace

# 创建 VaultStaticSecret 资源指向 Vault 路径
```

---

## 部署

### 首次安装

```bash
# 使用生产配置安装
helm install babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  --create-namespace \
  -f deploy/helm/babytalk/values-production.yaml \
  --set secret.BABY_TALK_DB_URL="<db-url>" \
  --set secret.BABY_TALK_DB_USERNAME="<db-user>" \
  --set secret.BABY_TALK_DB_PASSWORD="<db-password>" \
  --set secret.BABY_TALK_AI_API_KEY="<api-key>" \
  --set secret.BABY_TALK_EMBEDDING_API_KEY="<embedding-key>"
```

### 升级/更新

```bash
# 更新镜像版本
helm upgrade babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --set image.tag=1.2.0 \
  --set secret.BABY_TALK_DB_URL="<db-url>" \
  --set secret.BABY_TALK_DB_USERNAME="<db-user>" \
  --set secret.BABY_TALK_DB_PASSWORD="<db-password>" \
  --set secret.BABY_TALK_AI_API_KEY="<api-key>" \
  --set secret.BABY_TALK_EMBEDDING_API_KEY="<embedding-key>"
```

### Dry-Run 预检

```bash
# 模拟安装，不实际部署
helm install babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --dry-run --debug
```

---

## 验证

### 1. 检查 Pod 状态

```bash
kubectl get pods -n babytalk -l app.kubernetes.io/name=babytalk
# 期望：2/2 Running（replicas=2）
```

### 2. 检查 Pod 详情

```bash
kubectl describe pod -n babytalk -l app.kubernetes.io/name=babytalk
# 查看 Events 确认无异常
```

### 3. 检查 Service 和 Ingress

```bash
kubectl get svc,ingress -n babytalk
```

### 4. 健康检查端点

```bash
# Port-forward 测试
kubectl port-forward -n babytalk svc/babytalk 8080:8080 &
curl http://localhost:8080/actuator/health
# 期望返回 {"status":"UP"}
```

### 5. 运行 Helm 测试

```bash
helm test babytalk --namespace babytalk
# 使用 busybox 从集群内部验证 Service 连通性
```

### 6. 查看日志

```bash
kubectl logs -n babytalk -l app.kubernetes.io/name=babytalk --tail=100 -f
```

---

## 日常运维

### 水平扩缩容

```bash
# 手动扩容
kubectl scale deployment babytalk -n babytalk --replicas=4

# 或通过 Helm 更新
helm upgrade babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --set replicaCount=4
```

### 配置热更新

Helm chart 使用 ConfigMap/Secret 的 sha256sum annotation，配置变更会自动触发滚动重启：

```bash
# 更新配置值后 helm upgrade 即可
helm upgrade babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --set config.BABY_TALK_MENTOR_RATE_LIMIT_MAX_REQUESTS=20
```

### 重启 Pod

```bash
kubectl rollout restart deployment/babytalk -n babytalk
kubectl rollout status deployment/babytalk -n babytalk
```

---

## 回滚

### 查看发布历史

```bash
helm history babytalk --namespace babytalk
```

### 回滚到上一版本

```bash
helm rollback babytalk --namespace babytalk
```

### 回滚到指定版本

```bash
# 先查看历史确认版本号
helm history babytalk --namespace babytalk

# 回滚到指定 revision
helm rollback babytalk 3 --namespace babytalk
```

### 验证回滚

```bash
kubectl rollout status deployment/babytalk -n babytalk
kubectl get pods -n babytalk -l app.kubernetes.io/name=babytalk
```

---

## 监控与告警

### Prometheus 指标

Spring Boot Actuator 默认暴露 Prometheus 格式指标：

```bash
# 端点地址
/actuator/prometheus
```

推荐监控项：
- `http_server_requests_seconds_count` — 请求吞吐量
- `http_server_requests_seconds_sum` — 请求延迟
- `jvm_memory_used_bytes` — JVM 内存使用
- `process_cpu_usage` — CPU 使用率
- `hikaricp_connections_active` — 数据库连接池活跃连接

### Kubernetes 原生监控

```bash
# Pod 资源使用
kubectl top pods -n babytalk

# 节点资源使用
kubectl top nodes
```

### 告警建议

| 指标 | 阈值 | 说明 |
|------|------|------|
| Pod restart count | > 3 in 10m | 频繁重启，检查 OOM 或探针配置 |
| CPU 使用率 | > 80% sustained | 考虑扩容或优化 |
| 内存使用率 | > 85% | 检查内存泄漏或调整 limits |
| 5xx 错误率 | > 1% | 检查应用日志和下游依赖 |
| P99 延迟 | > 2s | 检查数据库慢查询或外部 API 超时 |

---

## 常见问题排查

### Pod 一直 Pending

```bash
kubectl describe pod -n babytalk <pod-name>
# 常见原因：
# - 节点资源不足 → kubectl top nodes / 降低 resource requests
# - PVC 绑定失败 → 检查 StorageClass
# - ImagePullBackOff → 检查镜像地址和 imagePullSecrets
```

### Pod CrashLoopBackOff

```bash
# 查看上次崩溃日志
kubectl logs -n babytalk <pod-name> --previous
# 常见原因：
# - 数据库连接失败 → 检查 BABY_TALK_DB_URL 和网络策略
# - 端口冲突 → 检查 containerPort
# - OOMKilled → kubectl describe pod 查看 Last State，增大 memory limits
```

### Readiness Probe 失败

```bash
# 检查健康端点
kubectl exec -n babytalk <pod-name> -- wget -qO- http://localhost:8080/actuator/health
# 常见原因：
# - 应用未完全启动 → 增大 startupProbe.failureThreshold
# - 数据库迁移耗时 → 增大 initialDelaySeconds
```

### Ingress 无法访问

```bash
# 检查 Ingress 状态
kubectl describe ingress -n babytalk babytalk
# 检查 IngressClass
kubectl get ingressclass
# 常见原因：
# - IngressClass 不匹配 → 确认 className 与集群 Ingress Controller 一致
# - TLS 证书未就绪 → kubectl describe certificate -n babytalk
# - DNS 未解析 → nslookup api.babytalk.example.com
```

### Secret 值未注入

```bash
# 检查 Secret 是否创建
kubectl get secret -n babytalk babytalk -o yaml
# 检查环境变量
kubectl exec -n babytalk <pod-name> -- env | grep BABY_TALK
# 常见原因：
# - helm install 时忘记 --set secret.* → 重新 helm upgrade
# - ExternalSecret 同步失败 → kubectl describe externalsecret -n babytalk
```

---

## M005 MemPalace 新增变量

M005 在 Helm chart 中新增了以下 ConfigMap 和 Secret 变量，用于 MemPalace 知识宫殿功能：

### 新增 Secret（1 个）

| 变量 | 说明 |
|------|------|
| `BABY_TALK_EMBEDDING_API_KEY` | Embedding API 密钥，语义搜索必须 |

注入方式同其他 Secret：

```bash
--set secret.BABY_TALK_EMBEDDING_API_KEY="<your-embedding-key>"
```

### 新增 ConfigMap（9 个）

| 变量 | 生产默认值 | 说明 |
|------|-----------|------|
| `BABY_TALK_MENTOR_SEARCH_MODE` | `agentic` | 搜索模式：agentic / rag / none |
| `BABY_TALK_MENTOR_SESSION_TIMEOUT` | `PT30M` | 多轮会话超时 |
| `BABY_TALK_MENTOR_PRACTICE_RESPONSE_MAX_LENGTH` | `2000` | 练习回复最大长度 |
| `BABY_TALK_EMBEDDING_BASE_URL` | Azure 端点 | Embedding API 端点 |
| `BABY_TALK_EMBEDDING_MODEL` | `text-embedding-3-small` | Embedding 模型 |
| `BABY_TALK_EMBEDDING_DIMENSIONS` | `1536` | 向量维度 |
| `BABY_TALK_KG_REVIEW_ENABLED` | `true` | KG 矛盾审查开关 |
| `BABY_TALK_KG_REVIEW_INTERVAL` | `PT30M` | 审查轮询间隔 |
| `BABY_TALK_KG_REVIEW_BATCH_SIZE` | `10` | 每次审查批量数 |

ConfigMap 变量通过 `values-production.yaml` 覆盖，也可在 helm install/upgrade 时通过 `--set config.` 前缀覆盖：

```bash
helm upgrade babytalk deploy/helm/babytalk/ \
  --namespace babytalk \
  -f deploy/helm/babytalk/values-production.yaml \
  --set config.BABY_TALK_MENTOR_SEARCH_MODE="rag" \
  --set config.BABY_TALK_KG_REVIEW_INTERVAL="PT1H"
```

> 📖 详细运维操作参见 [M005 MemPalace 运维手册](m005-mempalace-ops.md)

---

## 清理

### 卸载 Release

```bash
helm uninstall babytalk --namespace babytalk
```

### 删除命名空间（含所有资源）

```bash
kubectl delete namespace babytalk
```

---

## 附录：Helm Chart 文件结构

```
deploy/helm/babytalk/
├── Chart.yaml                    # Chart 元数据
├── values.yaml                   # 默认值（本地开发/CI）
├── values-production.yaml        # 生产覆盖值
├── .helmignore                   # 打包忽略规则
└── templates/
    ├── _helpers.tpl              # 模板 Helper 函数
    ├── NOTES.txt                 # 部署后提示
    ├── deployment.yaml           # Deployment（含 Probes、envFrom）
    ├── service.yaml              # Service（ClusterIP:8080）
    ├── configmap.yaml            # ConfigMap（非敏感变量，含 M005 MemPalace 配置）
    ├── secret.yaml               # Secret（敏感变量，含 Embedding API Key）
    ├── ingress.yaml              # Ingress（条件渲染）
    ├── serviceaccount.yaml       # ServiceAccount（条件创建）
    └── tests/
        └── test-connection.yaml  # Helm test（Service 连通性）
```
