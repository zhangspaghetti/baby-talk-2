---
phase: 39
slug: vnext-family-english-micro-ritual
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-15
updated: 2026-06-15
---

# Phase 39 - Validation Strategy

Per-phase validation contract for feedback sampling during execution.

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter test / Dart verifier tests from existing repo pattern |
| **Config file** | `mobile/dart_test.yaml`, `mobile/analysis_options.yaml`, root `pubspec.yaml` delegation |
| **Quick run command** | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` |
| **Full suite command** | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/mobile_v2_surface_contract_test.dart mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` |
| **Estimated runtime** | ~60 seconds after Flutter tool warmup |

## Sampling Rate

- **After every task commit:** Run `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` once the verifier test exists.
- **After every semantic-firewall task:** Also run `dart run tool/verify_mobile_v2_semantic_firewall.dart`.
- **After every plan wave:** Run `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/mobile_v2_surface_contract_test.dart mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart`.
- **Before `$gsd-verify-work`:** Semantic firewall verifier, import guard, banned-term scan, targeted tests, and docs supersession proof must be green.
- **Max feedback latency:** 120 seconds for the focused Phase 39 suite.

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 39-W1-01 | 39-01 | 1 | R058/R059/R060 | T-39-01 / T-39-02 | Docs proof rejects old phrase/activity/completion/streak/Garden semantics as vNext product truth | docs proof | Source assertions in `39-SUPERSESSION-PROOF.md` | Yes | passed |
| 39-W1-02 | 39-02 | 1 | R058/R059/R060 | T-39-04 / T-39-05 / T-39-06 | Old product terms and old mobile imports cannot enter `mobile_v2/lib` runtime truth | verifier unit | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` | Yes | passed |
| 39-W1-03 | 39-02 | 1 | R058/R059/R060 | T-39-04 / T-39-05 | Onboarding, Home, Practice, and Garden reject starter phrase, next incomplete task, phrase completion, child-response-required, streak, and Garden growth semantics | surface contract | `./flutter.cmd test test/features/vnext/mobile_v2_surface_contract_test.dart` | Yes | passed |
| 39-W2-01 | 39-03 | 2 | R058/R059/R060 | T-39-07 / T-39-08 | `mobile_v2/` exists as an independent package and `mobile_v2/lib` contains only vNext boundary anchors | static verifier | `dart run tool/verify_mobile_v2_semantic_firewall.dart` | Yes | passed |
| 39-W2-02 | 39-03 | 2 | R058/R059/R060 | T-39-09 | Phase validation records executable docs proof, semantic firewall, import guard, banned-term scan, and targeted surface tests | validation gate | Full suite command below | Yes | passed |

## Wave 0 Requirements

- [x] `tool/verify_mobile_v2_semantic_firewall.dart` - scanner for imports, banned terms, and allowlisted quarantine paths.
- [x] `test/tool/verify_mobile_v2_semantic_firewall_test.dart` - pure tests for scanner behavior.
- [x] `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` - wrapper-forwarder matching existing verifier wrapper patterns.
- [x] `test/features/vnext/mobile_v2_surface_contract_test.dart` - targeted surface contract tests.
- [x] `mobile_v2/lib/vnext_semantic_boundary.dart` - minimal vNext package runtime boundary anchor.

## Phase 39 Final Gate

Run these commands from the repo root:

```bash
dart run tool/verify_mobile_v2_semantic_firewall.dart
./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/mobile_v2_surface_contract_test.dart mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart
```

Required source proof assertions:

- `39-SUPERSESSION-PROOF.md` states Family English Micro-ritual as the canonical vNext product unit.
- `39-SUPERSESSION-PROOF.md` rejects Phrase, Activity, phrase completion, streak, and GardenGrowth as vNext product truth.
- `39-SUPERSESSION-PROOF.md` states old `mobile/` is readable reference only and cannot be imported into `mobile_v2/lib`.
- `39-SUPERSESSION-PROOF.md` keeps Activation Governor and Garden Memory mechanics deferred to Phase 40.
- `39-SUPERSESSION-PROOF.md` keeps Primitive, Graph, Pack, Runtime Agent, and transfer metrics deferred to Phase 41.

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Docs supersession proof explains every reused asset without carrying old product semantics | R058/R059/R060 | The proof is a reasoning artifact, but it must still be inspected for coverage and contradiction | Read the produced supersession proof and confirm it maps old docs/code/assets to Deprecated, Reference only, Re-derived, Keep behind product-semantic firewall, Deferred to Phase 40, or Deferred to Phase 41, with no old product truth feeding `mobile_v2/lib`. |
| Phase 40/41 deferral boundaries remain intact | R058/R060 | Later-phase scope requires human/product judgment | Confirm Activation Governor mechanics, Garden Memory transitions, Strategy Pack/Graph/Runtime schemas, and metrics instrumentation are named as deferred, not implemented by Phase 39. |

## Validation Sign-Off

- [x] All tasks have automated verify commands or completed verifier/test dependencies.
- [x] Sampling continuity: no 3 consecutive implementation tasks without automated verification.
- [x] Wave 0 covers all missing verifier/test references.
- [x] No watch-mode flags appear in verification commands.
- [x] Feedback latency is below 120 seconds for the focused Phase 39 suite.
- [x] `nyquist_compliant: true` is set in frontmatter after verifier/test infrastructure exists and has passed.

**Approval:** approved
