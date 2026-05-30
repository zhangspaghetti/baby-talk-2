# BabyTalk Mobile CI/CD Pipeline Specification

**Date**: 2026-05-28
**Target**: Flutter mobile app (Android + iOS)
**Package ID**: `com.babytalk.mobile`
**Current Version**: 1.2.0.4

---

## 1. Branch Strategy

```
main (protected, deploy-ready)
  |
  +-- develop (integration branch)
  |     |
  |     +-- feature/* (feature branches, PR -> develop)
  |     +-- bugfix/*  (bug fixes, PR -> develop)
  |
  +-- release/* (release prep, PR -> main)
  +-- hotfix/*  (emergency fixes, PR -> main + develop)
```

**Rules**:
- `main` is always deployable. All merges to `main` require passing CI + code review.
- `develop` is the integration branch. Feature branches merge here first.
- `release/*` branches are cut from `develop` when preparing a release. Only bugfixes allowed.
- `hotfix/*` branches are cut from `main` for critical production fixes.

---

## 2. Workflow Architecture

Three workflows, separated by trigger and purpose:

```
.github/workflows/
  mobile-pr.yml          # PR validation (fast feedback)
  mobile-build.yml       # Main branch build (artifacts)
  mobile-release.yml     # Tag-triggered release (stores)
```

### 2.1 PR Validation — `mobile-pr.yml`

**Triggers**: `pull_request` to `main` or `develop`

**Purpose**: Fast feedback loop. Must complete under 10 minutes.

```yaml
name: Mobile PR Validation

on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'mobile/**'
      - '.github/workflows/mobile-pr.yml'
      - 'ci/mobile-*'

concurrency:
  group: mobile-pr-${{ github.head_ref }}
  cancel-in-progress: true

jobs:
  # ── Job 1: Static Analysis (2-3 min) ──
  analyze:
    name: Lint & Format
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Check formatting
        run: dart format --set-exit-if-changed mobile/

      - name: Run analyzer
        working-directory: mobile
        run: |
          flutter pub get
          flutter analyze --fatal-infos

  # ── Job 2: Unit & Widget Tests (3-4 min) ──
  test:
    name: Unit & Widget Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: analyze
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Run tests with coverage
        working-directory: mobile
        run: |
          flutter pub get
          flutter test --coverage --reporter expanded

      - name: Check coverage threshold
        run: |
          COVERAGE=$(lcov --summary coverage/lcov.info 2>&1 | grep "lines" | grep -oP '[\d.]+(?=%)')
          THRESHOLD=60
          echo "Line coverage: ${COVERAGE}% (threshold: ${THRESHOLD}%)"
          if [ "$(echo "$COVERAGE < $THRESHOLD" | bc -l)" -eq 1 ]; then
            echo "::error::Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
            exit 1
          fi

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report
          path: mobile/coverage/lcov.info
          retention-days: 7

  # ── Job 3: Smoke Tests (2 min) ──
  smoke:
    name: Smoke Tests
    runs-on: ubuntu-latest
    timeout-minutes: 10
    needs: analyze
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Run smoke tests
        working-directory: mobile
        run: |
          flutter pub get
          flutter test test/smoke/ --reporter expanded

  # ── Job 4: Android Build Check (3-4 min) ──
  android-check:
    name: Android Build Check
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: analyze
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: gradle

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Build debug APK (compile check)
        working-directory: mobile
        run: |
          flutter pub get
          flutter build apk --debug

      - name: Check APK size
        run: |
          APK_SIZE=$(stat -c%s mobile/build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null || stat -f%z mobile/build/app/outputs/flutter-apk/app-debug.apk)
          MAX_SIZE=$((100 * 1024 * 1024))  # 100 MB for debug
          echo "Debug APK size: $(( APK_SIZE / 1024 / 1024 )) MB (limit: $(( MAX_SIZE / 1024 / 1024 )) MB)"
          if [ "$APK_SIZE" -gt "$MAX_SIZE" ]; then
            echo "::warning::Debug APK exceeds ${MAX_SIZE} bytes"
          fi
```

**Quality Gates**:
| Gate | Threshold | Blocking |
|------|-----------|----------|
| `dart format` | Zero diffs | Yes |
| `flutter analyze --fatal-infos` | Zero issues | Yes |
| Unit/widget test pass rate | 100% | Yes |
| Line coverage | >= 60% | Yes |
| Smoke tests | 100% pass | Yes |
| Debug APK build | Compile success | Yes |
| Debug APK size | < 100 MB | Warning only |

### 2.2 Main Branch Build — `mobile-build.yml`

**Triggers**: Push to `main` or `develop`

**Purpose**: Build release artifacts and run full test suite.

```yaml
name: Mobile Build

on:
  push:
    branches: [main, develop]
    paths:
      - 'mobile/**'
      - '.github/workflows/mobile-build.yml'

concurrency:
  group: mobile-build-${{ github.ref_name }}
  cancel-in-progress: false

jobs:
  # ── Job 1: Full Test Suite ──
  test-full:
    name: Full Test Suite
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Run all tests with coverage
        working-directory: mobile
        run: |
          flutter pub get
          flutter test --coverage --reporter expanded

      - name: Run R4 release gates
        run: bash ci/mobile-r4-release-gates.sh

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: coverage-report-${{ github.ref_name }}
          path: mobile/coverage/lcov.info
          retention-days: 30

  # ── Job 2: Android Release Build ──
  android-release:
    name: Android Release
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: test-full
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: gradle

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          echo "$KEYSTORE_BASE64" | base64 -d > mobile/android/secrets/baby-talk-upload.jks
          mkdir -p mobile/android/secrets

      - name: Write key.properties
        env:
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          cat > mobile/android/key.properties << EOF
          storeFile=../secrets/baby-talk-upload.jks
          storePassword=${KEYSTORE_PASSWORD}
          keyAlias=${KEY_ALIAS}
          keyPassword=${KEY_PASSWORD}
          EOF

      - name: Build release APK
        working-directory: mobile
        run: flutter build apk --release

      - name: Build release AAB
        working-directory: mobile
        run: flutter build appbundle --release

      - name: Check release artifact sizes
        run: |
          APK_SIZE=$(stat -c%s mobile/build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || stat -f%z mobile/build/app/outputs/flutter-apk/app-release.apk)
          AAB_SIZE=$(stat -c%s mobile/build/app/outputs/bundle/release/app-release.aab 2>/dev/null || stat -f%z mobile/build/app/outputs/bundle/release/app-release.aab)
          echo "Release APK: $(( APK_SIZE / 1024 / 1024 )) MB"
          echo "Release AAB: $(( AAB_SIZE / 1024 / 1024 )) MB"

      - uses: actions/upload-artifact@v4
        with:
          name: android-release-${{ github.sha }}
          path: |
            mobile/build/app/outputs/flutter-apk/app-release.apk
            mobile/build/app/outputs/bundle/release/app-release.aab
          retention-days: 30

  # ── Job 3: Android Debug Build (for internal testing) ──
  android-debug:
    name: Android Debug
    runs-on: ubuntu-latest
    timeout-minutes: 15
    needs: test-full
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: gradle

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Build debug APK
        working-directory: mobile
        run: |
          flutter pub get
          flutter build apk --debug

      - uses: actions/upload-artifact@v4
        with:
          name: android-debug-${{ github.sha }}
          path: mobile/build/app/outputs/flutter-apk/app-debug.apk
          retention-days: 14

  # ── Job 4: iOS Build Check (compile-only, no signing) ──
  ios-check:
    name: iOS Compile Check
    runs-on: macos-latest
    timeout-minutes: 20
    needs: test-full
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Build iOS (no codesign)
        working-directory: mobile
        run: |
          flutter pub get
          flutter build ios --no-codesign --debug

      - name: Check build output
        run: |
          if [ -d "mobile/build/ios/iphoneos/Runner.app" ]; then
            echo "iOS build succeeded"
          else
            echo "::error::iOS build output not found"
            exit 1
          fi
```

### 2.3 Release Workflow — `mobile-release.yml`

**Triggers**: Push of tag matching `v*`

**Purpose**: Build signed release, upload to Firebase App Distribution and/or store.

```yaml
name: Mobile Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  # ── Job 1: Validate Tag ──
  validate:
    name: Validate Release Tag
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.parse.outputs.version }}
      channel: ${{ steps.parse.outputs.channel }}
    steps:
      - uses: actions/checkout@v4

      - name: Parse version from tag
        id: parse
        run: |
          TAG="${GITHUB_REF#refs/tags/v}"
          echo "version=${TAG}" >> "$GITHUB_OUTPUT"
          if [[ "$TAG" == *"-rc"* ]]; then
            echo "channel=rc" >> "$GITHUB_OUTPUT"
          elif [[ "$TAG" == *"-beta"* ]]; then
            echo "channel=beta" >> "$GITHUB_OUTPUT"
          else
            echo "channel=stable" >> "$GITHUB_OUTPUT"
          fi
          echo "Release version: ${TAG}"

      - name: Verify VERSION file matches tag
        run: |
          TAG_VERSION="${GITHUB_REF#refs/tags/v}"
          FILE_VERSION=$(cat VERSION | tr -d '[:space:]')
          MAJOR_MINOR_PATCH=$(echo "$TAG_VERSION" | sed 's/+.*//' | sed 's/-.*//')
          if [[ "$FILE_VERSION" != "$MAJOR_MINOR_PATCH" ]]; then
            echo "::error::Tag version ${TAG_VERSION} does not match VERSION file (${FILE_VERSION})"
            exit 1
          fi

  # ── Job 2: Full Test Suite ──
  test:
    name: Release Tests
    runs-on: ubuntu-latest
    needs: validate
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Run full test suite
        working-directory: mobile
        run: |
          flutter pub get
          flutter test --coverage --reporter expanded

      - name: Run R4 release gates
        run: bash ci/mobile-r4-release-gates.sh

  # ── Job 3: Android Release Build ──
  android-release:
    name: Android Release Build
    runs-on: ubuntu-latest
    needs: [validate, test]
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: gradle

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Decode keystore
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
        run: |
          mkdir -p mobile/android/secrets
          echo "$KEYSTORE_BASE64" | base64 -d > mobile/android/secrets/baby-talk-upload.jks

      - name: Write key.properties
        env:
          KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          cat > mobile/android/key.properties << EOF
          storeFile=../secrets/baby-talk-upload.jks
          storePassword=${KEYSTORE_PASSWORD}
          keyAlias=${KEY_ALIAS}
          keyPassword=${KEY_PASSWORD}
          EOF

      - name: Build release APK
        working-directory: mobile
        run: flutter build apk --release

      - name: Build release AAB
        working-directory: mobile
        run: flutter build appbundle --release

      - uses: actions/upload-artifact@v4
        with:
          name: android-release-${{ needs.validate.outputs.version }}
          path: |
            mobile/build/app/outputs/flutter-apk/app-release.apk
            mobile/build/app/outputs/bundle/release/app-release.aab
          retention-days: 90

  # ── Job 4: iOS Release Build ──
  ios-release:
    name: iOS Release Build
    runs-on: macos-latest
    needs: [validate, test]
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Decode iOS certificates
        env:
          IOS_CERTIFICATE_BASE64: ${{ secrets.IOS_CERTIFICATE_BASE64 }}
          IOS_CERTIFICATE_PASSWORD: ${{ secrets.IOS_CERTIFICATE_PASSWORD }}
          IOS_PROVISION_PROFILE_BASE64: ${{ secrets.IOS_PROVISION_PROFILE_BASE64 }}
        run: |
          KEYCHAIN_PATH=$RUNNER_TEMP/app-signing.keychain-db
          KEYCHAIN_PASSWORD=$(openssl rand -base64 32)

          # Create temporary keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Import certificate
          CERTIFICATE_PATH=$RUNNER_TEMP/certificate.p12
          echo "$IOS_CERTIFICATE_BASE64" | base64 --decode > "$CERTIFICATE_PATH"
          security import "$CERTIFICATE_PATH" -P "$IOS_CERTIFICATE_PASSWORD" \
            -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
          security set-key-partition-list -S apple-tool:,apple: \
            -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security list-keychain -d user -s "$KEYCHAIN_PATH"

          # Install provisioning profile
          PROFILE_PATH=$RUNNER_TEMP/profile.mobileprovision
          echo "$IOS_PROVISION_PROFILE_BASE64" | base64 --decode > "$PROFILE_PATH"
          mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
          UUID=$(/usr/libexec/PlistBuddy -c "Print UUID" /dev/stdin <<< \
            $(security cms -D -i "$PROFILE_PATH"))
          cp "$PROFILE_PATH" ~/Library/MobileDevice/Provisioning\ Profiles/"${UUID}.mobileprovision"

      - name: Build release IPA
        working-directory: mobile
        run: |
          flutter pub get
          flutter build ipa --release \
            --export-options-plist=ios/ExportOptions.plist

      - uses: actions/upload-artifact@v4
        with:
          name: ios-release-${{ needs.validate.outputs.version }}
          path: mobile/build/ios/ipa/*.ipa
          retention-days: 90

      - name: Cleanup keychain
        if: always()
        run: security delete-keychain $RUNNER_TEMP/app-signing.keychain-db 2>/dev/null || true

  # ── Job 5: Upload to Firebase App Distribution ──
  firebase-distribute:
    name: Firebase App Distribution
    runs-on: ubuntu-latest
    needs: [validate, android-release]
    if: needs.validate.outputs.channel != 'stable'
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: android-release-${{ needs.validate.outputs.version }}

      - uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_ANDROID_APP_ID }}
          serviceCredentialsFileContent: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          groups: internal-testers
          file: app-release.apk
          releaseNotes: |
            Release ${{ needs.validate.outputs.version }}
            Channel: ${{ needs.validate.outputs.channel }}

  # ── Job 6: Upload to Google Play (internal track) ──
  google-play-internal:
    name: Google Play Internal
    runs-on: ubuntu-latest
    needs: [validate, android-release]
    if: needs.validate.outputs.channel == 'stable'
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: android-release-${{ needs.validate.outputs.version }}

      - name: Upload to internal track
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.babytalk.mobile
          releaseFiles: app-release.aab
          track: internal
          status: completed

  # ── Job 7: GitHub Release ──
  github-release:
    name: Create GitHub Release
    runs-on: ubuntu-latest
    needs: [validate, android-release, ios-release]
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Generate changelog
        id: changelog
        run: |
          PREV_TAG=$(git tag --sort=-v:refname | head -2 | tail -1)
          echo "## Changes" > CHANGELOG_BODY.md
          git log "${PREV_TAG}..HEAD" --pretty=format:"- %s (%h)" >> CHANGELOG_BODY.md || true

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ github.ref_name }}
          name: "BabyTalk ${{ needs.validate.outputs.version }}"
          body_path: CHANGELOG_BODY.md
          draft: false
          prerelease: ${{ needs.validate.outputs.channel != 'stable' }}
          files: |
            artifacts/android-release-*/app-release.apk
            artifacts/android-release-*/app-release.aab
            artifacts/ios-release-*/*.ipa
```

---

## 3. Quality Gates Summary

| Gate | PR | Main Build | Release | Blocking |
|------|-----|-----------|---------|----------|
| `dart format --set-exit-if-changed` | Yes | Yes | Yes | Yes |
| `flutter analyze --fatal-infos` | Yes | Yes | Yes | Yes |
| Unit/widget tests (100% pass) | Yes | Yes | Yes | Yes |
| Line coverage >= 60% | Yes | Yes | Yes | Yes |
| Smoke tests pass | Yes | Yes | Yes | Yes |
| R4 release gates | No | Yes | Yes | Yes |
| Debug APK compile | Yes | Yes | No | Yes |
| Release APK/AAB compile | No | Yes | Yes | Yes |
| Release APK size < 50 MB | No | Warning | Yes | Warning |
| iOS compile (no codesign) | No | Yes | No | Yes |
| iOS signed build | No | No | Yes | Yes |
| VERSION matches tag | No | No | Yes | Yes |

---

## 4. Secrets Configuration

### GitHub Repository Secrets

| Secret | Purpose | Used By |
|--------|---------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded release keystore (.jks) | Android release build |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | Android release build |
| `ANDROID_KEY_ALIAS` | Key alias in keystore | Android release build |
| `ANDROID_KEY_PASSWORD` | Key password | Android release build |
| `FIREBASE_ANDROID_APP_ID` | Firebase app ID for Android | Firebase distribution |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service account JSON | Firebase distribution |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Google Play developer API service account | Play Store upload |
| `IOS_CERTIFICATE_BASE64` | Base64-encoded .p12 distribution certificate | iOS release build |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password | iOS release build |
| `IOS_PROVISION_PROFILE_BASE64` | Base64-encoded provisioning profile | iOS release build |

### Secret Setup Commands

```bash
# Encode keystore for GitHub secret
base64 -w 0 mobile/android/secrets/baby-talk-upload.jks

# Encode iOS certificate
base64 -w 0 Certificates.p12

# Encode provisioning profile
base64 -w 0 profile.mobileprovision
```

---

## 5. Local Development Scripts

These scripts complement CI by running the same checks locally.

### `ci/mobile-analyze.sh` (existing, enhanced)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../mobile"

echo '=== Mobile Analyze ==='
flutter pub get
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage --reporter expanded
echo '=== Mobile Analyze PASSED ==='
```

### `ci/mobile-build-android.sh` (new)

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../mobile"

MODE="${1:-debug}"
echo "=== Mobile Android Build (${MODE}) ==="
flutter pub get
flutter build apk --${MODE}
APK_PATH="build/app/outputs/flutter-apk/app-${MODE}.apk"
APK_SIZE=$(stat -c%s "$APK_PATH" 2>/dev/null || stat -f%z "$APK_PATH")
echo "APK: ${APK_PATH} ($(( APK_SIZE / 1024 / 1024 )) MB)"
echo '=== Mobile Android Build PASSED ==='
```

### `ci/mobile-release-gates.sh` (existing, already runs R4 gates)

---

## 6. Deployment Strategy

### 6.1 Staged Rollout Plan

```
Tag v*.*.*-rc.*  -->  Firebase App Distribution (internal testers)
Tag v*.*.*-beta.* -->  Firebase App Distribution (beta testers)
Tag v*.*.*        -->  Google Play internal -> closed testing -> open testing -> production
                      Apple TestFlight -> App Store review -> production
```

### 6.2 Rollout Percentages (Google Play)

| Stage | Rollout | Duration | Auto-promote |
|-------|---------|----------|--------------|
| Internal | 100% | Immediate | After 24h if no crash spike |
| Closed Testing | 20% -> 50% -> 100% | 3 days each | Manual promotion |
| Open Testing | 100% | 7 days | Manual promotion |
| Production | 10% -> 30% -> 50% -> 100% | 2 days each | Manual promotion |

### 6.3 Rollback Strategy

- **Google Play**: Use "Manage releases" to halt rollout at any percentage. Promote previous version if needed.
- **Firebase App Distribution**: Previous APKs remain available. Testers can install older versions.
- **Apple**: Submit previous build for expedited review if critical issue found.

---

## 7. Caching Strategy

| Cache | Key | Path | Duration |
|-------|-----|------|----------|
| Flutter SDK | `flutter-${{ runner.os }}-stable` | `~/.pub-cache` | 7 days |
| Gradle | `gradle-${{ runner.os }}-...` | `~/.gradle/caches` | 7 days |
| Maven | `maven-${{ runner.os }}-...` | `~/.m2/repository` | 7 days |
| Dart packages | `dart-${{ runner.os }}-...` | `mobile/.dart_tool` | 7 days |

---

## 8. Monitoring & Notifications

### 8.1 CI Failure Notifications

```yaml
# Add to each workflow's final job
- name: Notify on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": ":x: BabyTalk CI failed on ${{ github.ref_name }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*BabyTalk CI Failed*\nBranch: `${{ github.ref_name }}`\nCommit: `${{ github.sha }}`\nAuthor: ${{ github.actor }}\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Run>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 8.2 Release Notifications

- Firebase App Distribution automatically notifies testers via email.
- Google Play sends email notifications to tester groups.
- Apple TestFlight notifies beta testers automatically.

---

## 9. Performance Budgets

| Metric | Threshold | Action on Breach |
|--------|-----------|-----------------|
| Debug APK size | < 100 MB | Warning in PR |
| Release APK size | < 50 MB | Warning in PR, block in release |
| Release AAB size | < 40 MB | Warning in PR, block in release |
| Flutter test duration | < 5 min | Warning |
| Full build duration | < 20 min | Investigate |
| PR validation total | < 10 min | Investigate |

---

## 10. Migration Plan from Current CI

### Current State
- `.github/workflows/ci.yml` handles backend + Helm smoke + mobile analyze
- `ci/mobile-analyze.sh` runs `flutter analyze` + `flutter test`
- `ci/mobile-r4-release-gates.sh` runs specific gate tests

### Migration Steps

1. **Phase 1 — Add PR workflow** (Day 1)
   - Create `mobile-pr.yml` alongside existing `ci.yml`
   - No changes to existing workflow yet
   - Verify PR checks work correctly

2. **Phase 2 — Add build workflow** (Day 2)
   - Create `mobile-build.yml` for main branch builds
   - Update `ci.yml` to call mobile analyze from new workflow
   - Remove duplicate mobile analysis from `ci.yml`

3. **Phase 3 — Add release workflow** (Day 3)
   - Create `mobile-release.yml`
   - Set up all GitHub secrets (Android keystore, Firebase, etc.)
   - Test with an RC tag before production release

4. **Phase 4 — Remove old mobile jobs** (Day 5)
   - Remove `mobile-analyze` job from `ci.yml`
   - Update `ci.yml` to only handle backend + Helm smoke
   - Verify all workflows pass

### File Changes

| File | Action |
|------|--------|
| `.github/workflows/mobile-pr.yml` | **Create** — PR validation |
| `.github/workflows/mobile-build.yml` | **Create** — Main branch builds |
| `.github/workflows/mobile-release.yml` | **Create** — Tag-triggered releases |
| `.github/workflows/ci.yml` | **Modify** — Remove `mobile-analyze` job |
| `ci/mobile-analyze.sh` | **Modify** — Add format check + coverage |
| `ci/mobile-build-android.sh` | **Create** — Local Android build script |
| `mobile/android/secrets/` | **Create** — Add to `.gitignore` |

---

## 11. Future Enhancements

- [ ] **Integration tests on CI**: Add Android emulator for integration tests once stable
- [ ] **Firebase Test Lab**: Automated UI testing on real devices
- [ ] **Dependabot**: Automated dependency updates for Flutter/Dart packages
- [ ] **Code signing automation**: Fastlane for iOS certificate/profile management
- [ ] **Play Store promotion automation**: Auto-promote through testing tracks
- [ ] **Bundle size tracking**: Track APK/AAB size over time with PR comments
- [ ] **Flavor-based builds**: Separate dev/staging/prod configurations
- [ ] **L10n validation**: Verify all translations are complete before release
