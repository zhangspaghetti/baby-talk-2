# BabyTalk Schema Compatibility Matrix

本文定义 M007 dual-release topology 下的 schema / workload 兼容边界。

适用对象：
- `db-migration` Helm hook Job
- `app-api`
- `admin-api`
- 需要判断 `helm rollback babytalk-app` 是否安全的值班人员

---

## 1. Policy

### 1.1 N / N-1 compatibility window

BabyTalk 当前对数据库 schema 的发布承诺是 **两版本兼容窗口**：
- schema 版本 **N** 发布后，`app-api` 与 `admin-api` 的 **N** 版本必须可运行。
- schema 版本 **N** 发布后，`app-api` 与 `admin-api` 的 **N-1** 版本也必须可运行。
- 这意味着 app release 可以前滚到新 schema，而前一个 workload 版本仍能在当前 schema 上继续工作。

这份文档中的 “compatible” 指：
- 旧 workload 读取现有表/列不会失败。
- 旧 workload 写入路径不会依赖已经被删除、重命名或语义破坏的 schema 对象。
- migration 默认应优先采用 **additive** 方式扩展 schema，而不是破坏性修改。

### 1.2 Release boundary contract

- `db-migration` 是 schema 的唯一 owner。
- `app-api` 与 `admin-api` 不负责在启动时自行执行 Flyway。
- `babytalk-app` 升级时，先跑 migration，再启动 workloads。
- 因此 schema contract 必须独立于单次 workload rollout 被记录和审查。

---

## 2. Current Schema Version

当前 schema 版本是 **V26**。

当前 Flyway 版本化迁移文件总数是 **25** 个，版本范围为 **V3–V26**，其中包含小版本迁移 **V22.1**。

这意味着在 M007 当前仓库真相下：
- 最新 schema = `V26`
- schema 兼容判断必须至少覆盖发布 `V26` 前的上一版 workload
- 发布前需要显式确认 `V26` 没有破坏 `app-api` / `admin-api` 的 N-1 运行假设

---

## 3. Migration Matrix

| Schema Version | Migration File | Summary | First Workload Version That Requires It |
| --- | --- | --- | --- |
| V3 | `V3__create_accounts_and_sync_tables.sql` | accounts and sync tables | `app-api 1.0.0` |
| V4 | `V4__create_mentor_tables.sql` | mentor tables | `app-api 1.0.0` |
| V5 | `V5__create_release_distribution_tables.sql` | release distribution tables | `app-api 1.0.0` |
| V6 | `V6__create_share_landing_tables.sql` | share landing tables | `app-api 1.0.0` |
| V7 | `V7__create_caregiver_invite_tables.sql` | caregiver invite tables | `app-api 1.1.0` |
| V8 | `V8__align_caregiver_invite_public_audit.sql` | caregiver audit alignment | `app-api 1.1.0` |
| V9 | `V9__extend_household_shared_context_for_caregiver_attribution.sql` | household shared context | `app-api 1.1.0` |
| V10 | `V10__create_pgvector_and_minio_infra.sql` | pgvector + minio infra | `app-api 1.2.0` |
| V11 | `V11__create_ingestion_tables.sql` | ingestion tables | `app-api 1.2.0` |
| V12 | `V12__add_keyword_search_to_vector_store.sql` | keyword search vector store | `app-api 1.2.0` |
| V13 | `V13__create_chat_memory_table.sql` | chat memory table | `app-api 1.2.0` |
| V14 | `V14__create_knowledge_graph_tables.sql` | knowledge graph tables | `app-api 1.2.0` |
| V15 | `V15__create_admin_auth_tables.sql` | admin auth tables | `admin-api 1.0.0` |
| V16 | `V16__create_account_jwt_tables.sql` | account JWT tables | `app-api 1.2.0` |
| V17 | `V17__create_admin_rbac_permissions.sql` | admin RBAC permissions | `admin-api 1.0.0` |
| V18 | `V18__create_palace_projection_tables.sql` | Palace projection and trace tables | `unreleased app-api` |
| V19 | `V19__add_palace_rooms_unique_constraint.sql` | Palace room uniqueness | `unreleased app-api` |
| V20 | `V20__create_garden_growth_persistence_tables.sql` | garden and growth persistence | `unreleased app-api` |
| V21 | `V21__harden_garden_fertilizer_constraints.sql` | garden fertilizer constraints | `unreleased app-api` |
| V22 | `V22__create_practice_catalog_tables.sql` | practice catalog tables | `unreleased app-api` |
| V22.1 | `V22_1__seed_practice_catalog.sql` | practice catalog seed data | `unreleased app-api` |
| V23 | `V23__reaction_contract_clean_cutover.sql` | reaction contract clean cutover | `unreleased app-api` |
| V24 | `V24__create_baby_profiles.sql` | baby profile tables | `unreleased app-api` |
| V25 | `V25__create_practice_generated_content.sql` | generated practice content registry | `unreleased app-api` |
| V26 | `V26__upgrade_chat_memory_for_spring_ai_2.sql` | Spring AI 2 chat-memory sequence contract | `unreleased app-api` |

### 3.1 How to read the matrix

- “First Workload Version That Requires It” 表示该 schema 变更第一次成为对应 workload 的运行前提。
- 它不是“只有这个版本能运行”的意思，而是“从这个版本开始，代码已知依赖该变更”。
- 若某个 migration 仅为 additive change，前一个 workload 版本通常仍可与更新后的 schema 共存。
- 若某个 migration 删除列、重命名表、改变旧查询依赖的约束语义，则必须重新证明 N-1 兼容性，而不能默认安全。

---

## 4. Rollback Constraints

Flyway migrations 是 **forward-only** 的。

这条规则在 dual-release 拓扑里的含义是：
- `helm rollback babytalk-app` 只能把 Kubernetes workloads、ConfigMap/Secret 引用、Service/Ingress 等资源恢复到旧 revision。
- **数据库 schema 不会因为 Helm rollback 自动回退。**
- 一旦 `db-migration` 已经把数据库前滚到更高版本，旧版 workload 必须证明仍兼容当前 schema，才能安全回滚。

因此，不应在下面场景直接执行 `helm rollback babytalk-app`：
- 新 migration 删除了旧 workload 仍依赖的列。
- 新 migration 重命名了旧 workload 仍依赖的表。
- 新 migration 改变了旧 workload 仍依赖的数据语义或约束。
- 你无法从代码、测试或本文档证明旧版 `app-api` / `admin-api` 仍兼容当前 schema。

### 4.1 Safe rollback mental model

默认判断顺序应为：
1. 先确认故障属于 workload/config 还是 schema 本身。
2. 再确认旧 workload 是否只依赖 additive schema。
3. 只有兼容性成立时，才允许把 `helm rollback babytalk-app` 作为恢复动作。

---

## 5. Pre-upgrade Checklist

在 bump `db-migration` image tag 之前，必须至少完成以下检查：

1. 确认 schema 版本 **N** 对 `app-api` / `admin-api` 版本 **N-1** 仍 backward-compatible。
2. 优先采用 additive columns / additive tables / additive indexes，不做破坏性 DDL。
3. 不删除旧版 workload 仍可能读取的列。
4. 不重命名旧版 workload 仍可能访问的表。
5. 不把旧字段语义静默改成与旧代码不兼容的新含义。
6. 明确记录哪个 workload 版本第一次依赖新 migration。
7. 若 migration 包含潜在破坏性修改，先准备独立的数据恢复或补丁方案，而不是假设 Helm rollback 能撤销 schema。
8. 在发布说明或 runbook 中补充本矩阵的变更，并让值班人员可以据此判断 rollback 风险。

---

## 6. Operator Notes

- 本矩阵与 `docs/runbooks/k8s-deploy.md` 一起构成 dual-release 的 release boundary contract。
- runbook 负责安装、升级、回滚、排障动作；本矩阵负责 schema 兼容语义。
- 如果后续新增 `V27+` migration，必须同步更新本文件，否则值班人员无法证明 app rollback 是否安全。
- 如果未来要突破 N / N-1 窗口，必须先更新文档、验证器和发布流程，再允许新 policy 生效。
