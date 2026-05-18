# Authorization Records

Project: Baby Talk 2 mobile Flutter rescue  
Created: 2026-05-16
Updated: 2026-05-18

| ID | Level | Authorization | Status | Notes |
|---|---|---|---|---|
| AR-R0-001 | Green | Create R0 governance and report artifacts | active | Documentation-only; no runtime code changes |
| AR-R0-002 | Green | Run read-only analysis and verification commands | active | Commands must not mutate source or external systems |
| AR-R0-003 | Yellow | Plan lint hardening | pending | Do not enable stricter lints until baseline is known |
| AR-R1-001 | Green | Run full read-only R1 audit across `mobile/lib`, `mobile/test`, and `mobile/integration_test` | completed | R1 reports generated on 2026-05-18; no runtime code modified |
| AR-R1-002 | Green | Generate R1 report artifacts and decision summaries | completed | Documentation-only |
| AR-R2-001 | Green | Draft R2 migration plans after red decisions are confirmed | completed | R2 draft plans and initial task artifacts generated; no implementation changes before approved R2 plan and refactor tasks |
| AR-R3-001 | Green | Execute REFACTOR-001 and REFACTOR-002 after R2 approval | completed | Governance sync and read-only baselines completed; no runtime Flutter source modified |
| AR-R3-002 | Green | Execute REFACTOR-002A baseline failure recovery after human approval | completed | Updated stale repo-root handoff test expectation to match current CI checkstyle-inclusive fail aggregation; no production Flutter source modified |
| AR-R3-003 | Green | Execute REFACTOR-004 app boot/router/provider characterization after human approval | completed | Added test-only app composition characterization under mobile/test/app; no production Flutter source modified |
| AR-R3-004 | Green | Execute REFACTOR-005 auth and mentor consent characterization after human approval | completed | Added test-only mentor auth/consent characterization under mobile/test/features/mentor; no production Flutter source modified |
| AR-R3-005 | Green | Execute REFACTOR-006 single Bearer JWT authenticated request header after human approval | completed | Added shared Bearer header helper and protected API header tests; no API payload, refresh, route, or consent UX changes |
| AR-R3-006 | Green | Execute REFACTOR-007 Mentor/AI fail-closed consent gate after human approval | completed | Mentor chat network requests now require accepted consent and JWT session; local suggestions remain available and preflight failures are recorded |
| AR-R3-007 | Green | Execute REFACTOR-008 route contract inventory and GoRouter canonicalization pilot after human approval | completed | Centralized canonical mobile route path constants and wired existing GoRouter, legacy route factory, re-entry, and practice push call sites without changing route paths |
| AR-R3-008 | Green | Execute REFACTOR-009 repository/usecase contract map and account adapter seam after human approval | completed | Added an AccountRepositoryContract seam and narrowed AccountNotifier to the contract while preserving concrete repository factories and behavior |
| AR-R3-009 | Green | Execute REFACTOR-010 practice repository characterization harness after human approval | completed | Added a test-only deterministic practice repository characterization harness covering append-only facts, pending uploads, sync metadata, restore, catalog, and continuity outputs |
| AR-R3-010 | Green | Execute REFACTOR-011 feature boundary matrix and report-only import scan after human approval | completed | Added a report-only mobile feature boundary scan and matrix; current baseline is 99 cross-feature directives, 69 approved legacy bridges, and 30 forbidden candidates |
| AR-R3-011 | Green | Execute REFACTOR-012 AsyncValue low-risk pilot after human approval | completed | Added a low-risk AsyncValue request state to ShareNotifier while preserving legacy share getters and behavior |
