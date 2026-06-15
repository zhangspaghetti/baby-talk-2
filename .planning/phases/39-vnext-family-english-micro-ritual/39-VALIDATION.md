---
phase: 39
slug: vnext-family-english-micro-ritual
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-15
---

# Phase 39 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test / Dart verifier tests from existing repo pattern |
| **Config file** | `mobile/dart_test.yaml`, `mobile/analysis_options.yaml`, root `pubspec.yaml` delegation |
| **Quick run command** | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` |
| **Full suite command** | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/` |
| **Estimated runtime** | ~60 seconds after Wave 0 verifier exists |

---

## Sampling Rate

- **After every task commit:** Run `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` once the Wave 0 verifier test exists.
- **After every semantic-firewall task:** Also run `dart run tool/verify_mobile_v2_semantic_firewall.dart`.
- **After every plan wave:** Run `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/`.
- **Before `$gsd-verify-work`:** Semantic firewall verifier, import guard, banned-term scan, targeted tests, and docs supersession proof must be green.
- **Max feedback latency:** 120 seconds for the focused Phase 39 suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-W0-01 | TBD | 0 | R058/R059/R060 | T-39-01 / T-39-02 | Old phrase/activity/completion/streak semantics cannot enter `mobile_v2/lib` runtime truth | verifier unit | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` | No - Wave 0 creates it | pending |
| 39-W0-02 | TBD | 0 | R059 | T-39-01 | `mobile_v2/` runtime code cannot import old `mobile/` domain/data/presentation models | static verifier | `dart run tool/verify_mobile_v2_semantic_firewall.dart` | No - Wave 0 creates it | pending |
| 39-W1-01 | TBD | 1 | R058 | T-39-03 | vNext thesis rejects course, translator, check-in, infinite generation, completion, and growth goals | docs/verifier | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` | No - Wave 0 creates it | pending |
| 39-W1-02 | TBD | 1 | R060 | T-39-02 | Context Seed is evidence and Joinability is a low-confidence hypothesis, not child diagnosis or auto-activation | docs/static verifier | `./flutter.cmd test test/features/vnext/context_joinability_boundary_test.dart` | No - only if Phase 39 creates target package/tests | pending |

---

## Wave 0 Requirements

- [ ] `tool/verify_mobile_v2_semantic_firewall.dart` - scanner for imports, banned terms, and allowlisted quarantine paths.
- [ ] `test/tool/verify_mobile_v2_semantic_firewall_test.dart` - pure tests for scanner behavior.
- [ ] `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` - optional wrapper-forwarder only if root/mobile test delegation needs it, matching existing verifier wrapper patterns.
- [ ] `test/features/vnext/` or future `mobile_v2/test/` targeted tests - only if Phase 39 creates a minimal package/skeleton.
- [ ] Environment preflight records whether `dart --version`, `flutter --version`, and `./flutter.cmd --version` complete without timeout on the execution machine.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Docs supersession proof explains every reused asset without carrying old product semantics | R058/R059/R060 | The proof is a reasoning artifact, but it must still be inspected for coverage and contradiction | Read the produced supersession proof and confirm it maps old docs/code/assets to `superseded`, `reference-only`, `reusable infrastructure`, `quarantine`, or `deferred`, with no old product truth feeding `mobile_v2/lib`. |
| Phase 40/41 deferral boundaries remain intact | R058/R060 | Later-phase scope requires human/product judgment | Confirm Activation Governor mechanics, Garden Memory transitions, Strategy Pack/Graph/Runtime schemas, and metrics instrumentation are named as deferred, not implemented by Phase 39. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify commands or Wave 0 dependencies.
- [ ] Sampling continuity: no 3 consecutive implementation tasks without automated verification.
- [ ] Wave 0 covers all missing verifier/test references.
- [ ] No watch-mode flags appear in verification commands.
- [ ] Feedback latency is below 120 seconds for the focused Phase 39 suite.
- [ ] `nyquist_compliant: true` is set in frontmatter after Wave 0 verifier/test infrastructure exists and has passed.

**Approval:** pending
