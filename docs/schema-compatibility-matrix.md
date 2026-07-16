# BabyTalk Schema Compatibility Matrix

本文记录 M007 dual-release topology 下可审计的 schema/workload 边界。它不是“所有版本天然兼容”的声明。

No release tag or image digest exists; compatibility is audited by exact commits.

- Audited N workload: `40bb9600991f5c7a0cf73eb59658b97ce590383f`
- Exact N-1/pre-V23 workload: `3ee8bb7729f450a3a3e65b279cc76662ebc1b75e`
- V23 introducing workload/migration commit: `a13d45407f2143bfe67fe623674d9696c2b7cb3f`
- 当前 schema：V26；版本化 migration 共 25 个（V3–V26，含 V22.1）。

N/N-1 是发布目标，不是未经证据即可成立的事实。任一 migration 标为 `incompatible` 或 `not verified`，都会阻止 overlapping rollout 或 rollback，直到问题被解决或由 release owner 明确 waiver。

## Status semantics

- `compatible`：有直接证据证明该 migration 后目标旧 workload 路径仍可用。
- `incompatible`：已有证据证明至少一个 N-1 路径不兼容。
- `not verified`：没有足够的目标 workload compatibility 证据；不得据此推断安全。

每个 commit anchor 来自 `git log -1 --format=%H -- <migration>`，固定为 exact 40-character SHA。

## Migration matrix

| Schema Version | Migration File | Commit Anchor | Status | Evidence |
| --- | --- | --- | --- | --- |
| V3 | `V3__create_accounts_and_sync_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V4 | `V4__create_mentor_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V5 | `V5__create_release_distribution_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V6 | `V6__create_share_landing_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V7 | `V7__create_caregiver_invite_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V8 | `V8__align_caregiver_invite_public_audit.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V9 | `V9__extend_household_shared_context_for_caregiver_attribution.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V10 | `V10__create_pgvector_and_minio_infra.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V11 | `V11__create_ingestion_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V12 | `V12__add_keyword_search_to_vector_store.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V13 | `V13__create_chat_memory_table.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V14 | `V14__create_knowledge_graph_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V15 | `V15__create_admin_auth_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V16 | `V16__create_account_jwt_tables.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V17 | `V17__create_admin_rbac_permissions.sql` | `1755f529706d8caf45715be5cb5cccfbcdc65a85` | not verified | 无当前 N-1 workload 定向证据。 |
| V18 | `V18__create_palace_projection_tables.sql` | `efddef2670c81a4483e3e504322c1bdce300076d` | not verified | 无当前 N-1 workload 定向证据。 |
| V19 | `V19__add_palace_rooms_unique_constraint.sql` | `efddef2670c81a4483e3e504322c1bdce300076d` | not verified | 无当前 N-1 workload 定向证据。 |
| V20 | `V20__create_garden_growth_persistence_tables.sql` | `a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98` | not verified | 无当前 N-1 workload 定向证据。 |
| V21 | `V21__harden_garden_fertilizer_constraints.sql` | `a61f66d39f2b98417fe20fe2ed7f7c5a56c29d98` | not verified | 无当前 N-1 workload 定向证据。 |
| V22 | `V22__create_practice_catalog_tables.sql` | `347c623ca58be8e7300b48d844c933a6bd257bdc` | not verified | 无当前 N-1 workload 定向证据。 |
| V22.1 | `V22_1__seed_practice_catalog.sql` | `190d9a1d0b30710d39f88d069a826f9eccbc7f59` | not verified | 无当前 N-1 workload 定向证据。 |
| V23 | `V23__reaction_contract_clean_cutover.sql` | `a13d45407f2143bfe67fe623674d9696c2b7cb3f` | incompatible | Legacy rows/read survive mapping; N-1 writes old values and fails under V23+. |
| V24 | `V24__create_baby_profiles.sql` | `26a5c1f6696aba728ffe34afa233a2dd588c6dd8` | not verified | Additive DDL 本身不足以证明当前 N-1 workload compatibility。 |
| V25 | `V25__create_practice_generated_content.sql` | `ad05936ea58283fced9db67a21f9cde2c63ea1c1` | not verified | Additive DDL 本身不足以证明当前 N-1 workload compatibility。 |
| V26 | `V26__upgrade_chat_memory_for_spring_ai_2.sql` | `132ea115b3b8c693537aac1e690e84f5d0e18ac9` | compatible | Sequence upgrade/preserved-row evidence linked below。 |

## V23 hard boundary

V23 会把 legacy reaction values 映射到新值，已有 rows 与 read path 在迁移后保留；但 N-1/pre-V23 workload 仍写旧值，V23+ constraint 会拒绝这些写入。因此 V23 对 N-1 reaction-event writes 明确为 `incompatible`，不能推广成 universal N/N-1 compatibility。

After V23+, do not roll back to `3ee8bb7729f450a3a3e65b279cc76662ebc1b75e` while reaction-event writes are possible.

证据：[DbMigrationSmokeTest.java](../backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java)，证据 commit `012766e7`，方法 `v23UpgradePreservesLegacyReactionRowsButRejectsNMinusOneWrites`。

## V26 evidence boundary

V26 的 `compatible` 只覆盖已测试的 chat-memory sequence upgrade 与 legacy row preservation，不代表其他 `not verified` migration 自动兼容。现有证据位于同一 [DbMigrationSmokeTest.java](../backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java)：

- `upgradesChatMemorySchemaForSpringAi2SequenceOrdering`
- `flywayUpgradeFromV13PreservesChatMemoryRowsAndAddsSpringAi2Contract`

## Rollback/operator rule

Flyway migration 是 forward-only；`helm rollback babytalk-app` 不回退数据库。操作前必须按 exact workload commit 和对应 migration status 判断。遇到 `incompatible` 或 `not verified` 时，停止 overlapping rollout/rollback，先补证据、修复兼容路径，或取得 release owner 的显式 waiver。

新增 V27+ migration 时，必须同步添加 exact commit anchor、三态 status、证据与 rollback 影响；否则 M007 docs coherence gate 应失败。
