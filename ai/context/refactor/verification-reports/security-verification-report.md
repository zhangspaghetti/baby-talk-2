# Security Verification Report

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Task: REFACTOR-017, updated through REFACTOR-041
Created: 2026-05-20
Status: completed, security release gate blocked

## Summary

REFACTOR-017 did not change security-sensitive mobile code. It verified current security-related refactor evidence through existing reports and the REFACTOR-013 sensitive lifecycle report-only scanner. REFACTOR-017A then stabilized the Mentor integration path by sharing the account notifier and injecting the authenticated Mentor API service through app composition. REFACTOR-019 closed the narrow installation ID delete-primitive gap, REFACTOR-020 added the core-only governance orchestrator, REFACTOR-038 added a verified real-store lifecycle registry, REFACTOR-039 implemented a backup-exclusion posture for local sensitive data, REFACTOR-040 added R4 hard gates for lifecycle zero gaps, unapproved destructive product-flow wiring, and account upgrade URL allowlisting, and REFACTOR-041 used HDR-R4-003 option 3 approval to wire the existing account deletion entry through second confirmation and real-store local sensitive data clearance. Local sensitive data lifecycle enforcement is still not production-complete until live CI, iOS runtime proof, target/profile performance replay, and final release approval are verified.

Security production readiness cannot be approved yet.

## Current Security Evidence

| Evidence | Result |
|---|---|
| R1 security audit | No obvious production secrets found, but security/privacy score was 4/10 |
| REFACTOR-006 | Protected API paths moved toward a single Bearer JWT authenticated client/interceptor |
| REFACTOR-007 | Mentor/AI network calls fail closed without login and accepted consent |
| REFACTOR-013 | Local sensitive data lifecycle matrix and report-only scanner added |
| R017 lifecycle scanner | Ran successfully in report-only mode; one delete primitive remained missing |
| REFACTOR-017A Mentor path | Online Mentor chat remains login/consent gated and now uses the authenticated API service in the legacy Provider path |
| REFACTOR-019 installation ID primitive | `InstallationIdService.deleteIfExists()` added and scanner now reports all six delete primitives covered |
| REFACTOR-020 clearance orchestrator | Core-only orchestrator enforces Staff+ authorization for destructive targets and reports per-target outcomes |
| REFACTOR-038 real-store registry | App-layer registry maps all six lifecycle targets to real delete/close primitives; temp-store Staff+ clearance test passes |
| REFACTOR-039 backup posture | Android backup/data extraction disabled and iOS application-support backup exclusion channel added; focused tests and Android debug build pass |
| REFACTOR-040 R4 policy gate | Feature product-flow destructive wiring is blocked without HDR approval; account upgrade links are HTTPS-only and host-allowlisted |
| REFACTOR-041 approved destructive entry | HDR-R4-003 option 3 is confirmed; account deletion requires a second confirmation and invokes the approved real-store clearance runner |

## Sensitive Lifecycle Scanner

| Metric | Value |
|---|---:|
| Total sensitive surfaces | 6 |
| Covered delete primitive | 6 |
| Missing delete primitive | 0 |
| Missing source | 0 |
| Missing documentation | 0 |

Missing surface: none at the delete-primitive or registry level. The approved account deletion product-flow entry is wired and tested. Device erasure remains unwired because no concrete product entry has been implemented, and hard lifecycle enforcement still requires live CI, iOS runtime proof, approved target/profile performance evidence, and final release approval.

## Open Security Readiness Gaps

| Gap | Status | Release Risk |
|---|---|---|
| Installation ID deletion/reset primitive | Closed by REFACTOR-019 | Primitive exists; destructive lifecycle wiring remains separate |
| Unified destructive lifecycle service | Partially closed | Core orchestrator and real-store registry are verified; approved account deletion wiring exists; device erasure and other destructive entries remain unwired |
| Backup exclusion or encrypted migration proof | Partially closed | Backup-exclusion posture is implemented, Android build-proven, and backed by iOS XCTest source; macOS/iOS runtime execution remains pending |
| Sensitive model logging policy | Partially planned | Generated/default string output can still leak sensitive values if logged wholesale |
| URL allowlist hard gate | Locally closed for account upgrade links | R40 rejects `http` and unknown hosts through production validation and Flutter release-gate tests; invite/share URL hardening can be broadened later if new external launch surfaces appear |

## Security Exit Decision

No new high-severity issue was introduced by R017, R017A, R019, R020, R038, R039, R040, or R041. The persistent identifier delete-primitive gap is closed, all six known local sensitive targets now have a verified registry path, backup exclusion is implemented locally, unapproved destructive feature wiring is blocked by a release gate, account upgrade external URLs are HTTPS-only/allowlisted, and the approved account deletion path now clears local sensitive data after second confirmation. However, the Phase 4 security gate is still not satisfied because iOS backup runtime proof, live CI/target replay, approved target/profile performance evidence, and final human release confirmation remain incomplete.

Security verification is blocked pending target backup proof, live CI/target replay, approved performance proof, and explicit human release confirmation.