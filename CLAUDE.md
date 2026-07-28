## Deploy Configuration (configured by /setup-deploy)
- Platform: Kubernetes + Helm (Docker Desktop local cluster, namespace: babytalk)
- Production URL: N/A — local cluster only (port-forward: gateway=127.0.0.1:8090, admin-web=127.0.0.1:3000)
- Deploy workflow: manual helm upgrade (no auto-deploy on push)
- Project type: web app + API (Spring Boot backend + React admin-web)
- Merge method: squash

### Custom deploy hooks
- Pre-merge: none
- Deploy trigger: |
    helm upgrade --install babytalk-infra deploy/helm/babytalk-infra -n babytalk --create-namespace -f deploy/helm/babytalk-infra/values-kind.yaml
    helm upgrade --install babytalk-app deploy/helm/babytalk-app -n babytalk -f deploy/helm/babytalk-app/values-kind.yaml -f deploy/helm/babytalk-app/values-kind-secrets.yaml
- Deploy status: |
    kubectl -n babytalk rollout status deployment/babytalk-app-gateway --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-admin-api --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-admin-web --timeout=120s
    kubectl -n babytalk rollout status deployment/babytalk-app-app-api --timeout=120s
- Health check: kubectl -n babytalk get pods

## QA Environment Configuration (configured by /setup-deploy)
- Platform: Kubernetes + Helm (Docker Desktop local cluster, namespace: babytalk-qa)
- Production URL: N/A — local cluster only (port-forward: gateway=127.0.0.1:8091, admin-web=127.0.0.1:3001)
- Deploy workflow: manual helm upgrade (no auto-deploy on push)
- Project type: web app + API (Spring Boot backend + React admin-web)
- Merge method: squash
- Persistence: Enabled (PVC with hostpath StorageClass)
- Storage: PostgreSQL 1Gi, Redis 256Mi, MinIO 5Gi

### QA Custom deploy hooks
- Pre-merge: none
- Deploy trigger: |
    helm upgrade --install babytalk-qa-infra deploy/helm/babytalk-infra -n babytalk-qa --create-namespace -f deploy/helm/babytalk-infra/values-kind-qa.yaml
    helm upgrade --install babytalk-qa-app deploy/helm/babytalk-app -n babytalk-qa -f deploy/helm/babytalk-app/values-kind-qa.yaml -f deploy/helm/babytalk-app/values-kind-qa-secrets.yaml
- Deploy status: |
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-gateway --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-admin-api --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-admin-web --timeout=120s
    kubectl -n babytalk-qa rollout status deployment/babytalk-qa-app-app-api --timeout=120s
- Health check: kubectl -n babytalk-qa get pods

## Agent skills

### Issue tracker

Issues live in this repository's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Uses the five default canonical triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

Multi-context: `CONTEXT-MAP.md` maps each app context; shared decisions live in `docs/adr/`. See `docs/agents/domain.md`.

