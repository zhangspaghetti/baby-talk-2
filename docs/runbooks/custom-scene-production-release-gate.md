# Custom-scene production release gate

Custom-scene entry is production-default-enabled only when mobile, backend, and
the production Helm overlay agree. The independent gate is:

```bash
dart tool/verify_custom_scene_production_release.dart
```

It fails closed unless all of these remain true:

- mobile `BABY_TALK_CUSTOM_SCENE_ENABLED` defaults to `true`; an explicit
  `false` define remains an intentional rollback/development override;
- `values-production.yaml` selects the agentic provider, pins the routing
  policy, routes Generator/Judge/Repair to `dashscope-qwen`, and uses the
  dedicated externally managed Practice AI Secret with a non-empty rollout
  marker;
- the Helm runtime template maps agentic provider mode to
  `babytalk.practice.discovery.custom-scene.enabled=true`;
- the release workflow builds both APK and AAB without disabling custom-scene
  entry.

The gate runs in `ci/full-ci.sh` and `ci/mobile-r4-release-gates.sh`. Unit and
negative-fixture coverage lives in
`test/tool/verify_custom_scene_production_release_test.dart`.

This verifies repository wiring only. Production release still requires
external authorization, real provider credentials, deployed backend/image
identity, Android UAT, and actual TalkBack evidence. Missing credentials,
provider quota/network, cluster access, or device access remain `BLOCKED`; they
must not be converted to `PASS` by this static gate.
