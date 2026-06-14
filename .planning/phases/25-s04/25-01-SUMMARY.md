---
phase: "25"
plan: "01"
---

# T01: Added app-api-consumer (/api/v1/**) and app-api-public (/download/**,/upgrade/**,/share/**,/invite/**) routes to gateway application.yml

**Added app-api-consumer (/api/v1/**) and app-api-public (/download/**,/upgrade/**,/share/**,/invite/**) routes to gateway application.yml**

## What Happened

Modified backend/gateway/src/main/resources/application.yml to add two new Spring Cloud Gateway routes alongside the existing admin-api route: (1) app-api-consumer targeting ${BABY_TALK_APP_API_URI:http://localhost:8080} with Path=/api/v1/**; (2) app-api-public targeting the same URI with Path predicates for distribution/share/invite public paths (/download/**, /upgrade/**, /share/**, /invite/**). No gateway-level filter was added for consumer routes — app-api enforces its own JWT security internally. Gateway Maven build and 9-test AdminJwtFilterTest suite pass unchanged.

## Verification

mvn -pl backend/gateway -am clean verify -q exits 0; WARN logs confirm 5 error codes; Tests run: 9, Failures: 0, Errors: 0, Skipped: 0

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `mvn -pl backend/gateway -am clean verify -q` | 0 | ✅ pass | 112500ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `backend/gateway/src/main/resources/application.yml`
