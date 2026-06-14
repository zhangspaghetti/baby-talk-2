---
phase: "25"
plan: "02"
---

# T02: Injected BABY_TALK_APP_API_URI into gateway Deployment; added gateway Ingress template; moved consumer external entry point from app-api to gateway in production values

**Injected BABY_TALK_APP_API_URI into gateway Deployment; added gateway Ingress template; moved consumer external entry point from app-api to gateway in production values**

## What Happened

Five Helm files updated: (1) deployment.yaml — added BABY_TALK_APP_API_URI env var to gateway container pointing to the cluster-internal app-api service (http://babytalk-app-app-api:8080). (2) ingress.yaml — appended gateway Ingress block gated by gateway.ingress.enabled, following the same pattern as appApi/adminWeb blocks; separator --- block updated to handle all three-way combinations. (3) values.yaml — added gateway.ingress stub (enabled: false, className: nginx, host: gateway.babytalk.local). (4) values-production.yaml — disabled appApi.ingress (enabled: false); added gateway override block with ingress.enabled: true pointing to api.babytalk.example.com with ALB annotations matching the former app-api ingress. (5) NOTES.txt — replaced appApi.ingress.enabled conditional with gateway.ingress.enabled conditional; added app-api to internal services list with note that consumer routes go via gateway. Verified: helm lint passes, BABY_TALK_APP_API_URI env in default render, Ingress/babytalk-app-gateway present in prod render, Ingress/babytalk-app-app-api absent in prod render.

## Verification

helm lint → 1 chart(s) linted, 0 chart(s) failed; helm template | grep BABY_TALK_APP_API_URI → present; helm template -f production | grep 'kind: Ingress' -A10 shows babytalk-app-gateway and babytalk-app-admin-web but no babytalk-app-app-api

## Verification Evidence

| # | Command | Exit Code | Verdict | Duration |
|---|---------|-----------|---------|----------|
| 1 | `helm lint deploy/helm/babytalk-app` | 0 | ✅ pass | 1200ms |
| 2 | `helm template babytalk-app deploy/helm/babytalk-app | grep BABY_TALK_APP_API_URI` | 0 | ✅ pass | 800ms |
| 3 | `helm template babytalk-app deploy/helm/babytalk-app -f values-production.yaml | grep 'kind: Ingress' -A12` | 0 | ✅ pass — gateway ingress present, app-api ingress absent | 900ms |

## Deviations

None.

## Known Issues

None.

## Files Created/Modified

- `deploy/helm/babytalk-app/templates/deployment.yaml`
- `deploy/helm/babytalk-app/templates/ingress.yaml`
- `deploy/helm/babytalk-app/values.yaml`
- `deploy/helm/babytalk-app/values-production.yaml`
- `deploy/helm/babytalk-app/templates/NOTES.txt`
