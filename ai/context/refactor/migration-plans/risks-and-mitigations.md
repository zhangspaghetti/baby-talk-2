# R2 Risks And Mitigations

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: active

## Risk Register

| ID | Risk | Probability | Impact | Mitigation | Owner Phase |
|---|---|---:|---:|---|---|
| R2-RISK-001 | Generated-code strict migration breaks `part` generation or imports | Medium | High | Isolated canary first; mirror output paths; run build/analyze/test before deleting old generated files | Phase 1/2 |
| R2-RISK-002 | Provider/Riverpod bridge changes lifecycle behavior | High | High | Boot/provider characterization tests before migration; old Provider only as compatibility | Phase 2 |
| R2-RISK-003 | Router canonicalization changes paths, redirects, or reentry | Medium | High | Route contract inventory and tests before touching router ownership | Phase 2 |
| R2-RISK-004 | Auth unification breaks protected API calls | Medium | Critical | Bearer JWT interceptor tests for every protected service path | Phase 2 |
| R2-RISK-005 | Mentor consent gate changes demo behavior | Medium | Critical | Fail-closed tests; local-only unauthenticated behavior remains explicit | Phase 2 |
| R2-RISK-006 | Local sensitive data lifecycle breaks restore or offline flows | Medium | High | Data classification and migration tests before storage changes | Phase 2/3 |
| R2-RISK-007 | Repository slicing changes Isar/API payload behavior | Medium | High | Temp DB tests and payload snapshots before slicing | Phase 2 |
| R2-RISK-008 | UI token/i18n cleanup changes product experience | Medium | Medium | Preserve visual values and rendered copy; separate approval for design/copy changes | Phase 3 |
| R2-RISK-009 | Hard CI gates turn legacy debt into permanent red builds | High | Medium | Start report-only; fail new violations first; raise gates gradually | Phase 1/4 |
| R2-RISK-010 | Performance regressions remain invisible | High | Medium | Capture cold start and interaction baselines before optimization | Phase 1/4 |

## Global Mitigation Rules

- Every source-code refactor starts with tests.
- Generated migration is never bundled with business behavior changes.
- Large files are split only after characterization tests exist.
- No deletion without a rollback path and verification evidence.
- Yellow design/lint decisions are resolved before hard gates or UI normalization.