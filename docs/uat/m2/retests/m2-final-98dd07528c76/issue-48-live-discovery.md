# GitHub #48 rev47 live discovery

Candidate: `98dd07528c768e4b88e0d259a5915e33a5e89715`, image tag `m2-98dd0752`, Helm app revision 47, infra revision 42, debug APK SHA-256 `479f1c74af500244cbec1d593dc23de289e31cfeb6806b1eef538fa8a211d188`.

Verdict: **FAIL — OPEN**.

Backend generation and same-identity reconciliation succeeded, but Android could not enter the prepared generated Care Turn.

- Android first showed the same-identity reconciliation control after response loss.
- Reconciliation found the terminal ACTIVE content without creating another request.
- Automatic handoff failed.
- `打开已准备内容` retry failed repeatedly with the recoverable route-failure surface.
- Counts remained `7/9/15/15` during reconciliation and all open retries.

Root cause: production `BabyTalkApp._resolveRouter` attaches `GoRouter` to instance `_navigatorKey`; `AppCustomSceneCareTurnHandoffSink` resolves unrelated global `appRootNavigatorKey`. The sink therefore cannot obtain the active production navigator context.

GitHub #48 owns the mobile navigation seam. Backend provider behavior and GitHub #47 Repair policy are out of scope.

Candidate configuration fingerprint is `sha256:9cd438e1c5a003a1636a6ddcd711a2ce67f309e47831d55aa379090b2e91fd42`, computed from the sanitized source/profile/prompt-version tuple. Provider model identity is stored only as `model_sha256:bb43a640f04c8e5504a8fbc8c6980455029f3e8fc1dedff10bcd04f94c4f4319`.

No generated text, scene text, content/request/account identifier, owner hash, token, secret, prompt, or provider body is stored.
