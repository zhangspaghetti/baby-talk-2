# Verification Record - task-e2e-gov-batch3

## Timestamp
- 2026-05-24

## Scope
- Stage 3.1 Batch 3: High-Risk Domain Regression Gate
- Command: `scripts\\run-full-e2e.cmd`
- Rerun batch: `20260524-152257`
- Second-validation rerun batch: `20260524-154929`

## Execution Evidence
1. Command entered script main flow and completed all 5 steps.
2. Step 1 backend connectivity passed:
   - `http://127.0.0.1:8080/actuator/health` -> 200
   - `http://127.0.0.1:8081/actuator/health` -> 200
   - `http://127.0.0.1:3000` -> 200
3. Step 2 ADB reverse passed:
   - emulator: `emulator-5554`
   - reverse: `tcp:8080`, `tcp:8081`
4. Step 3 Playwright executed using system Chrome (no browser download) and completed with failures.
5. Step 4/5 Flutter flow completed and log contains `All tests passed!`.
6. Artifact directory:
   - `artifacts/e2e/2026-05-24/b994318/fullstack-20260524-152257/`
7. Metadata persisted:
   - `run-metadata.txt` has `run_batch_id=20260524-152257`, `commit=b994318`.
8. Second-validation rerun completed with consistent outcome:
   - `docs/e2e-full-test-report-2026-05-24.md` updated to `run_batch_id=20260524-154929`.
   - Playwright still fails; Flutter still passes.
   - Script exit code observed as `1`.

## D11 Checklist Outcome for This Batch
1. Unique run batch id generated: PASS
2. High-risk regression executed with >=95% pass: FAIL
3. P0/P1 unresolved = 0 snapshot: FAIL (not provided in this packet)
4. Per-failure trace + screenshot/video: PASS (trace=60, video=60, png=61)
5. stdout/stderr persisted and mapped to commit: PASS
6. Traceability from conclusion to artifact path: PASS
7. Sign-offs completed: FAIL

## Overall
- Status: NO_GO_TRIGGERED
- Classification: functional-or-usecase-failure-after-environment-fix
- Next: Batch 4 decision packet uses second-validation batch (`20260524-154929`) as authoritative D11 input.
