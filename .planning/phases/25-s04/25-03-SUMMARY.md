---
phase: "25"
plan: "03"
---

# T03: Updated smoke script with S04 consumer-cutover assertions; PASS count grows from 58 to 62, 0 failures

**Updated smoke script with S04 consumer-cutover assertions; PASS count grows from 58 to 62, 0 failures**

## What Happened

Updated ci/k8s-smoke.sh with 4 changes: (1) Step 5b — added 2 new assertions: assert_contains BABY_TALK_APP_API_URI in default render, assert_not_contains gateway Ingress in default render (default keeps gateway ingress disabled). (2) Step 6 — changed assert_resource_present Ingress/app-api to assert_resource_absent (app-api is now internal); added assert_resource_present Ingress/gateway (consumer entry point). (3) Step 8 release notes — updated label text from 'app-api public surface' to 'consumer API via gateway'; added assertion for app-api internal service note. (4) Summary count grows from 58 to 62. Final smoke run: PASS: 62  FAIL: 0  SKIP: 0.

## Verification

bash ci/k8s-smoke.sh → PASS: 62  FAIL: 0  SKIP: 0; first_failure_hotspot=none

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `bash ci/k8s-smoke.sh` | 0 | ✅ pass — PASS: 62  FAIL: 0  SKIP: 0 | 5800ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `ci/k8s-smoke.sh`
