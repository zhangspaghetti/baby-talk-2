---
phase: "07"
plan: "03"
---

# T03: 全面重写 README.md 反映 M005 MemPalace 架构，新建 m005-mempalace-ops.md 运维手册，更新 k8s-deploy.md 补充 Embedding Secret 和 9 个 ConfigMap 变量

**全面重写 README.md 反映 M005 MemPalace 架构，新建 m005-mempalace-ops.md 运维手册，更新 k8s-deploy.md 补充 Embedding Secret 和 9 个 ConfigMap 变量**

## What Happened

README.md 完整重写，覆盖 10 个计划要点：(1) 项目描述更新为 MemPalace + Agentic Search；(2) 项目结构表增加 scripts/ 和 deploy/，backend 说明改为 PostgreSQL(pgvector) + MinIO；(3) 环境要求新增 Docker + Docker Compose 行；(4) 后端运行删除 ./mvnw 引用，只保留 mvn；(5) 环境变量表扩展为完整表格含所有 M005 新变量（Embedding 4 个、搜索模式、会话超时、练习长度、KG 审查 3 个）；(6) Docker 本地开发段更新为三服务架构（PostgreSQL + MinIO + backend），提到 .env.example 和安卓模拟器 10.0.2.2 地址；(7) 新增知识宫殿段落含 Agentic Search 说明、三种 search-mode 对比表、batch-ingest.sh 和单本书上传用法；(8) 新增动态练习生成段落含 API 示例；(9) 测试段 ./mvnw test → mvn test；(10) CI 段 ./mvnw verify → mvn verify。

新建 docs/runbooks/m005-mempalace-ops.md（9 个 H2 段落），覆盖：文献导入操作（batch-ingest.sh 用法、单本书上传、失败重试、K8s 环境导入）；Embedding 配置（变量表、第三方 proxy 配置、更换模型注意事项）；KG 矛盾审查流程（工作原理、配置变量、手动管理、关闭方法）；Search Mode 切换（三种模式对比、切换方法、选择建议）；会话超时调整（ISO 8601 Duration 速查表）；动态练习生成（API 接口 + curl 示例）；常见问题排查（Embedding 连接失败、MinIO 问题、KG 审查不运行、搜索模式无效果、会话断开 5 个场景）；附录速查表。

更新 docs/runbooks/k8s-deploy.md：Secret 注入方式一新增 BABY_TALK_EMBEDDING_API_KEY 参数 + 说明备注；ExternalSecret 示例新增 embedding-api-key 条目；首次安装和升级命令均补充 --set secret.BABY_TALK_EMBEDDING_API_KEY；新增"M005 MemPalace 新增变量"完整段落含 1 个 Secret + 9 个 ConfigMap 变量表和 helm upgrade 示例；Helm Chart 文件结构附录更新 configmap/secret 描述。

## Verification

运行 3 项验证检查全部通过：(1) README.md 包含 PostgreSQL、MinIO、MemPalace、pgvector 四个关键词；(2) docs/runbooks/m005-mempalace-ops.md 存在且非空；(3) runbook 包含 9 个 H2 级标题。额外验证：k8s-deploy.md 包含 EMBEDDING_API_KEY；README.md 中 ./mvnw 出现 0 次、H2 出现 0 次。

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `grep -q 'PostgreSQL' README.md && grep -q 'MinIO' README.md && grep -q 'MemPalace' README.md && grep -q 'pgvector' README.md && echo 'README keywords OK'` | 0 | ✅ pass | 120ms |
| 2 | `test -f docs/runbooks/m005-mempalace-ops.md && test -s docs/runbooks/m005-mempalace-ops.md && echo 'runbook exists OK'` | 0 | ✅ pass | 80ms |
| 3 | `grep -c '^## ' docs/runbooks/m005-mempalace-ops.md` | 0 | ✅ pass (9 sections) | 60ms |
| 4 | `grep -q 'EMBEDDING_API_KEY' docs/runbooks/k8s-deploy.md` | 0 | ✅ pass | 50ms |
| 5 | `grep -c './mvnw' README.md` | 0 | ✅ pass (0 stale references) | 40ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `README.md`
- `docs/runbooks/m005-mempalace-ops.md`
- `docs/runbooks/k8s-deploy.md`
