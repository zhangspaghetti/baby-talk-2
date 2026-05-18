# Stage R1 Risks And Mitigations

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Risk Register  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: active

## Risk Register

| ID | Risk | Probability | Impact | Mitigation | Owner Stage |
|---|---|---|---|---|---|
| RISK-R1-001 | Big-bang source movement breaks imports/routes/tests | High | High | Keep logical legacy isolation; only move one tested module at a time | R2/R3 |
| RISK-R1-002 | Provider/Riverpod dual graph causes lifecycle regressions | High | High | Choose canonical app composition; add boot/provider characterization tests | R2 |
| RISK-R1-003 | Router consolidation changes navigation behavior | Medium | High | Route contract inventory and tests before touching router | R2/R3 |
| RISK-R1-004 | Repository slicing changes persisted data or sync behavior | Medium | High | Add Isar/temp DB characterization tests and API payload snapshots | R3 |
| RISK-R1-005 | Mentor chat sends sensitive data before consent | Medium | Critical | Confirm consent gate and add fail-closed tests | R2 |
| RISK-R1-006 | Auth strategy remains split between JWT and Cookie | Medium | Critical | Confirm Bearer JWT vs Cookie; one authenticated client | R2 |
| RISK-R1-007 | Local child/household data remains unprotected | Medium | High | Data classification, encryption/deletion plan, consent withdrawal tests | R2/R3 |
| RISK-R1-008 | Generated code migration breaks build_runner | Medium | Medium | Decide strict generated output versus documented Dart exception | R2 |
| RISK-R1-009 | Token/i18n cleanup accidentally changes UX/copy | Medium | Medium | Preserve rendered text and visual values; product approval for copy rewrites | R3 |
| RISK-R1-010 | Performance regressions are invisible | High | Medium | Add cold start, reaction, home/growth, and mentor benchmarks | R2/R4 |
| RISK-R1-011 | Lint hardening turns current CI red | High | Medium | Start report-only; fail only new violations after baseline | Phase 1 |
| RISK-R1-012 | Coverage goal blocks refactor due low hotspot tests | Medium | Medium | Add characterization tests around hotspots before implementation | R2/R3 |

## Mitigation Principles

- No production behavior changes during R1/R2 planning.
- Every R3 task must start with regression tests.
- No file move or deletion without a task artifact and rollback path.
- Security and privacy red decisions must be resolved before core-flow refactors.
- Design/i18n cleanup must preserve current rendered output unless separately approved.
- CI should become stricter in stages: report-only baseline, then new-violation fail, then full threshold fail.

## Current Blockers Before R3

1. Canonical app composition decision.
2. Auth strategy decision.
3. Mentor consent gate decision.
4. Local sensitive data and installation ID policy decision.
5. Generated code policy decision.

These blockers are recorded in `ai/context/daily-decision-summary.md`.