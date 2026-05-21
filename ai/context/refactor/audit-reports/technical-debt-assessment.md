# Stage R1 Technical Debt Assessment

Version: Flutter AI Software Factory v1.0.0  
Stage: R1 - Technical Debt Assessment  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: completed

## Debt Inventory

| Debt Area | Severity | Evidence | Recommended Phase |
|---|---|---|---|
| App composition and DI dual graph | Critical | Provider + Riverpod + app-level overrides + local providers | Phase 1 / Phase 2 |
| Repository/usecase abstraction missing | Critical | UI imports data repositories/local stores; no stable domain contracts | Phase 2 |
| Cross-feature imports | Critical | 245 cross-feature import candidates | Phase 2 |
| Async state inconsistency | High | 0 `AsyncValue` refs; many ChangeNotifier states | Phase 2 |
| Router ambiguity | High | old router, GoRouter provider, app-level router composition | Phase 2 |
| Security/privacy consent and auth policy | Critical | Mentor chat, auth header strategy, local sensitive data | Phase 1 / Phase 2 |
| Large files | High | 10+ handwritten files over 500 lines | Phase 2 / Phase 3 |
| UI token gaps | Medium | 627 UI literal number candidates | Phase 3 |
| i18n gaps | Medium | 375 `Text(` candidates requiring classification | Phase 3 |
| Accessibility gaps | Medium | Semantics exists but label language and coverage are inconsistent | Phase 3 |
| Generated code policy | Medium | `*.freezed.dart` and `*.g.dart` co-located under feature dirs | Phase 1 decision |
| Performance benchmarks absent | High | No frame/timeline/startup benchmark gate | Phase 1 / Phase 4 |
| Coverage gap | Medium | Existing lcov around 64%, below 70/80 targets | Phase 1 onward |

## Quantified Baseline

| Metric | Current | Factory / Refactor Target |
|---|---:|---:|
| Handwritten source files | 115 | N/A |
| Files over 500 lines, handwritten | At least 10 | 0 pages over 500; source files target 200 where practical |
| AsyncValue references | 0 | All async feature states use unified async model |
| Cross-feature import candidates | 245 | Only allowed contract imports |
| UI literal number candidates | 627 | Tokenized or justified |
| Existing coverage from lcov | About 64% | Phase 2 70%, R4 80% |

## Debt Paydown Strategy

### Phase 1 - Foundation and gates

- Add report-only architecture scans.
- Establish generated code policy.
- Add coverage threshold measurement without immediate hard fail.
- Document auth, consent, local data, and URL policies.

### Phase 2 - Architecture safety

- Define canonical app composition.
- Define route ownership and route contract tests.
- Add repository/usecase contracts.
- Reduce cross-feature imports through domain contracts.
- Pilot AsyncValue migration on one low-risk notifier.

### Phase 3 - UI/design/i18n/a11y

- Tokenize layout and radius values without visual change.
- Extract shared UI surfaces with widget tests.
- Replace existing hardcoded strings with existing ARB keys.
- Add semantics tests for core interactions.

### Phase 4 - Verification and optimization

- Raise coverage to 80%.
- Run startup/reaction/growth/mentor performance benchmarks.
- Complete final security, compatibility, and engineering verification.

## Staff+ Assessment

This project should not be rescued by rewriting screens. It should be rescued by first making the existing behavior observable, then replacing boundaries one seam at a time. The first implementation work must be tests and report-only gates, not source movement.