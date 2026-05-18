# R2 Success Metrics

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: active

## Baseline From R1

| Metric | R1 Baseline | Target |
|---|---:|---:|
| Overall R1 quality score | 4.8 / 10 | 8.5+ before production readiness |
| Architecture score | 4 / 10 | 8+ after Phase 2 |
| Security/privacy score | 4 / 10 | 9+ before R4 exit |
| Design system score | 6 / 10 | 9+ after Phase 3 |
| Test maturity score | 6.5 / 10 | 8+ after Phase 4 |
| Coverage | about 64% | 70% after Phase 2, 80% by R4 |
| `AsyncValue` references | 0 | All migrated async seams use a unified async model |
| Cross-feature import candidates | 245 | No new violations; legacy count trends down each phase |
| UI literal number candidates | 627 | No new hardcoded literals; existing literals tokenized by priority |

## Phase Gates

| Gate | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---|---|---|---|
| Analyze | Baseline recorded | Green for changed files | Green with new UI gates | Green full run |
| Tests | Baseline recorded | Core seam tests added | Widget/a11y tests added | Full suite green |
| Coverage | Measured | 70% target | No regression | 80% target |
| Import boundaries | Report-only | Fail new violations | Reduce legacy violations | Hard gate for migrated areas |
| Generated code | Canary plan | Strict migration verified | No new co-located generated output | Hard gate |
| Auth/consent | Tests planned | Fail-closed tests pass | No regression | Security verification pass |
| Performance | Baseline planned | No known regression | UI interactions checked | Benchmark report pass |

## Non-Negotiable Success Rules

- Existing behavior remains unchanged unless a new decision artifact approves a change.
- CI remains green after every implementation step.
- Every completed task has verification evidence in its task artifact.
- All unresolved red decisions block implementation.