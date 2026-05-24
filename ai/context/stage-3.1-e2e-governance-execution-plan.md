# Stage 3.1 Execution Plan (Admin Web E2E Governance)

## Status
- Approved to execute
- Source approval: human sign-off in stage-3.0-e2e-governance-checklist.md

## Scope
- Governance execution only
- No feature expansion outside approved frozen-domain policy

## Execution Batches

### Batch 1: Environment Recoverability
Owner: Admin Web engineering + QA
1. Add Playwright browser executable preflight check before suite run.
2. Fail fast with actionable error if browser binary is missing.
3. Persist preflight result in run artifacts.

Acceptance:
- No run starts without passing preflight.

Progress:
- Status: IMPLEMENTED
- Evidence: `scripts/run-full-e2e.cmd` preflight step + `playwright-preflight.log` artifact path.

### Batch 2: Evidence Contract Enforcement
Owner: QA
1. Enforce required artifact set for each failed case:
   - trace
   - screenshot or video
   - stdout/stderr
   - run metadata with commit SHA
2. Store artifacts under:
   - artifacts/e2e/{date}/{commit}/{suite}/

Acceptance:
- Runs missing required evidence are marked non-decisionable.

Progress:
- Status: IMPLEMENTED_VALIDATED
- Evidence: persistent artifact directory + stdout/stderr + run metadata in `scripts/run-full-e2e.cmd`.

### Batch 3: High-Risk Domain Regression Gate
Owner: QA + Tech Lead
1. Execute mapped high-risk specs.
2. Compute pass rate and unresolved P0/P1 counts.
3. Fill D11 machine checklist from docs/runbooks/e2e-d11-gate.md.

Acceptance:
- Meets D11 thresholds or auto NO-GO.

Progress:
- Status: EXECUTED_FAILED
- Evidence:
   - Rerun batch: `20260524-152257`
   - Artifact root: `artifacts/e2e/2026-05-24/b994318/fullstack-20260524-152257/`
   - Playwright executed on system Chrome (no install download) and completed with failures.
   - Flutter full-flow completed with `All tests passed!`.
   - Second validation rerun batch: `20260524-154929`
   - Second validation artifact root: `artifacts/e2e/2026-05-24/b994318/fullstack-20260524-154929/`
   - Second validation reproduced same governance outcome: Playwright FAIL, Flutter PASS, exit code `1`.
- Result:
   - High-risk regression does not meet D11 thresholds.
   - According to D11 rule, current state is auto NO-GO.

### Batch 4: D11 Decision Package
Owner: Engineering Lead
1. Produce decision packet with links to artifacts and checklist output.
2. Record sign-offs from engineering lead, tech lead, QA.
3. Prepare go/no-go recommendation.

Acceptance:
- Decision can be audited from report to artifact and commit.

Progress:
- Status: COMPLETED_NO_GO_PACKET
- Notes:
   - Decision package generated as NO-GO with failure class=`functional/use-case` after environment fix.
   - Packet file: `ai/context/stage-3.1-d11-decision-packet-batch4.md`.

## Hard Stops
- Any P0 in high-risk domain remains open.
- Missing artifact traceability.
- Scope drift into frozen-domain functional changes without explicit approval.

## Verification Commands (to run in Stage 3.1)
- cmd /c scripts\run-full-e2e.cmd
- pnpm --filter admin-web test:e2e

## Exit Criteria
- D11 machine checklist fully satisfied OR explicit NO-GO with classified root causes and remediation plan.

## Verification Artifacts
- `ai/context/verification-task-e2e-gov-batch1-2.md`
- `ai/context/task-self-review-task-e2e-gov-batch1-2.md`
- `ai/context/verification-task-e2e-gov-batch3.md`
- `ai/context/task-self-review-task-e2e-gov-batch3.md`
- `ai/context/stage-3.1-d11-decision-packet-batch4.md`
