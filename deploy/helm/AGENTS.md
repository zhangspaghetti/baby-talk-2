# HELM CHARTS

Kubernetes Helm 部署配置。

## STRUCTURE

```
helm/
├── babytalk-infra/     # 基础设施 (PostgreSQL, Redis, MinIO)
└── babytalk-app/       # 应用服务 (gateway, admin-api, app-api, admin-web)
```

## WHERE TO LOOK

| 任务 | 位置 | 说明 |
|------|------|------|
| 基础设施 | `babytalk-infra/` | PostgreSQL, Redis, MinIO 部署 |
| 应用服务 | `babytalk-app/` | 4 个服务部署 |
| 配置 | `values-kind.yaml` | Kind 集群配置 |
| 密钥 | `values-kind-secrets.yaml` | 敏感配置 |

## CONVENTIONS

- **环境分离**：prod (babytalk) / QA (babytalk-qa)
- **配置管理**：values-kind.yaml + values-kind-secrets.yaml
- **部署**：helm upgrade --install

## COMMANDS

```bash
# 生产环境
helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -n babytalk --create-namespace -f deploy/helm/babytalk-infra/values-kind.yaml
helm upgrade --install babytalk-app deploy/helm/babytalk-app -n babytalk -f deploy/helm/babytalk-app/values-kind.yaml -f deploy/helm/babytalk-app/values-kind-secrets.yaml

# QA 环境
helm upgrade --install babytalk-qa-infra deploy/helm/babytalk-infra -n babytalk-qa --create-namespace -f deploy/helm/babytalk-infra/values-kind-qa.yaml
helm upgrade --install babytalk-qa-app deploy/helm/babytalk-app -n babytalk-qa -f deploy/helm/babytalk-app/values-kind-qa.yaml -f deploy/helm/babytalk-app/values-kind-qa-secrets.yaml
```
