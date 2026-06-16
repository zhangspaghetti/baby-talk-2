---
phase: 40-activation-governor-garden-memory
status: planned
gate: pre-execution
created: 2026-06-16
nyquist_dimension_8: pending
execution_results_claimed: false
---

# Phase 40 Validation Plan

This is the pre-execution validation artifact for Phase 40. It exists before implementation so Nyquist validation can inspect the planned automated coverage. All command results are pending; this file does not claim that any implementation, verifier, test, or final gate command has passed.

## Pre-Execution Gate

| Gate | Status | Evidence |
|------|--------|----------|
| Validation artifact exists before execution | planned | `.planning/phases/40-activation-governor-garden-memory/40-VALIDATION.md` |
| Automated coverage is mapped before execution | planned | R063/R064/R065 rows below |
| Final gate commands are declared before execution | planned | Commands below |
| Execution commands have passed | pending | No execution has run yet |

## Nyquist Coverage Map

| Requirement | Required Proof | Planned Artifact | Planned Automated Gate | Current Status |
|-------------|----------------|------------------|------------------------|----------------|
| R063 | Activation Governor is the only activation pacing authority; Pack/Graph cannot activate, Runtime cannot self-govern, and Garden cannot own activation policy. | `tool/verify_activation_governor_contract.dart`; `test/tool/verify_activation_governor_contract_test.dart` | `./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart` | pending implementation |
| R064 | Garden Memory meaningful states require low-pressure parent confirmation and cannot be created from weak signals, checklist, score, streak, growth, unlock, reward, progress, or punishment semantics. | `test/tool/verify_activation_governor_contract_test.dart`; `test/features/vnext/activation_governor_contract_surface_test.dart` | `./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart` | pending implementation |
| R065 | Explore remains open for examples/routes/explanations, while activation intent across Home, Onboarding, Garden, Runtime, and reminder/push-like copy is governed. | `test/features/vnext/activation_governor_contract_surface_test.dart`; typed verifier cases | `./flutter.cmd test test\features\vnext\activation_governor_contract_surface_test.dart` | pending implementation |
| D-01 through D-33 | Locked decisions are traceable from context to verifier, fixture groups, matrix proof, and final validation. | `40-ACTIVATION-GOVERNOR-CONTRACT-PROOF.md`; plan summaries; verifier tests | `Select-String` proof checks in Plan 40-03 plus focused verifier suite | pending implementation |

## Planned Final Gate Commands

Use the direct Dart SDK command as the reliable local verifier path. `dart run` is not a required Phase 40 gate because research found telemetry/profile write failures on this Windows machine.

```powershell
C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart
```

```powershell
C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_mobile_v2_semantic_firewall.dart
```

Preferred focused Flutter suite after Plans 40-01 and 40-02 create the test files:

```powershell
./flutter.cmd test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart mobile\test\tool\verify_activation_governor_contract_test.dart test\tool\verify_mobile_v2_semantic_firewall_test.dart
```

Windows fallback when `./flutter.cmd` stalls or SDK telemetry/cache writes block:

```powershell
C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe --packages=C:\software\flutter\packages\flutter_tools\.dart_tool\package_config.json C:\software\flutter\bin\cache\flutter_tools.snapshot test test\tool\verify_activation_governor_contract_test.dart test\features\vnext\activation_governor_contract_surface_test.dart mobile\test\tool\verify_activation_governor_contract_test.dart test\tool\verify_mobile_v2_semantic_firewall_test.dart
```

## Command Health Policy

- Direct `dart.exe tool\verify_activation_governor_contract.dart` is the reliable local verifier path for Phase 40.
- `./flutter.cmd test ...` remains the preferred test-wrapper path for wrapper parity.
- The direct `flutter_tools.snapshot test` command is the fallback health-check path when wrapper execution stalls or SDK profile/cache writes fail.
- Do not mark this validation file as passed until the executor runs the final gate commands after the verifier and tests exist.

## Threat Coverage

| Threat | Planned Mitigation | Planned Verification |
|--------|--------------------|----------------------|
| Pack/Graph, Runtime, or Garden activation bypass | Structured authority fixtures fail closed unless Activation Governor is the decision source. | `test/tool/verify_activation_governor_contract_test.dart` |
| Weak signals promoted to family truth | Weak-signal-only cases pass only for prompt/review/suggestion actions. | `test/tool/verify_activation_governor_contract_test.dart` |
| Garden Memory pressure/checklist semantics | Language scans reject score, checklist, streak, growth, unlock, reward, progress, completion, fertilizer, and punishment semantics. | `test/features/vnext/activation_governor_contract_surface_test.dart` |
| Explore over-governance | Positive Explore rows pass without Governor decision when they do not imply action now. | `test/features/vnext/activation_governor_contract_surface_test.dart` |
| Old Phase 39 semantic leakage regression | Existing semantic firewall remains in the final gate. | `tool\verify_mobile_v2_semantic_firewall.dart`; `test\tool\verify_mobile_v2_semantic_firewall_test.dart` |

## Status Log

- 2026-06-16: Created as planned/pending pre-execution Nyquist artifact. No commands have been run or claimed passed in this file.
