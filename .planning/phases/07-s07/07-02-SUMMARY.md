---
phase: "07"
plan: "02"
---

# T02: Helm chart values.yaml + values-production.yaml 同步 M005 MemPalace 10 个变量（9 config + 1 secret）

**Helm chart values.yaml + values-production.yaml 同步 M005 MemPalace 10 个变量（9 config + 1 secret）**

## What Happened

在 values.yaml 的 config 段末尾（SIMULATE_UNAVAILABLE_TOKEN 之后）追加 9 个 M005 非敏感变量：MENTOR_SEARCH_MODE、MENTOR_SESSION_TIMEOUT、MENTOR_PRACTICE_RESPONSE_MAX_LENGTH、EMBEDDING_BASE_URL/MODEL/DIMENSIONS、KG_REVIEW_INTERVAL/ENABLED/BATCH_SIZE。在 secret 段末尾追加 1 个敏感变量 EMBEDDING_API_KEY。

values-production.yaml 同步添加相同 10 个变量，关键差异：KG_REVIEW_INTERVAL 生产值 PT30M（开发为 PT5M，降低审查频率）。

修复过程中发现之前编辑在 values-production.yaml 尾部产生的重复残余内容（截断的注释行 + 重复 MINIO 变量），已清理干净。

所有值为引号包裹字符串（如 "1536" 而非 1536），符合 configmap.yaml 模板 `{{ $value | quote }}` 要求。Helm template range 遍历模式自动将新增变量渲染到 ConfigMap/Secret 中，无需修改模板文件。

## Verification

helm lint 通过（0 charts failed），helm template 默认值和生产覆盖值均正确渲染 3 个关键 M005 变量。docker-compose config 和 CI 脚本验证也通过。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `helm lint deploy/helm/babytalk/ 2>&1 | tail -3` | 0 | ✅ pass | 800ms |
| 2 | `helm template babytalk deploy/helm/babytalk/ | grep -c SEARCH_MODE|EMBEDDING_BASE_URL|KG_REVIEW_ENABLED` | 0 | ✅ pass (count=3) | 600ms |
| 3 | `helm template babytalk deploy/helm/babytalk/ -f deploy/helm/babytalk/values-production.yaml | grep KG_REVIEW_INTERVAL` | 0 | ✅ pass (PT30M) | 600ms |
| 4 | `docker-compose config > nul 2>&1` | 0 | ✅ pass | 1200ms |
| 5 | `grep -q 'mvn verify' ci/backend-test.sh` | 0 | ✅ pass | 50ms |
| 6 | `grep -q './mvnw' ci/backend-test.sh (inverted)` | 1 | ✅ pass (not found = correct) | 50ms |

## Deviations

修复了 values-production.yaml 文件末尾由之前编辑留下的重复残余内容（截断注释行 + 重复 MINIO 变量块）。

## Known Issues

None.

## Files Created/Modified

- `deploy/helm/babytalk/values.yaml`
- `deploy/helm/babytalk/values-production.yaml`
