# Spring AI 2 Backend Platform Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the complete Baby Talk backend from Spring Boot 3.4.4 / Spring AI 1.1.4 to a verified Spring Boot 4.0.7 / Spring AI 2.0.0 baseline before implementing the custom-scene agentic generation plan.

**Architecture:** Treat Spring AI 2.0 as a backend platform migration, not an isolated `pom.xml` edit. Move through the latest Spring Boot 3.5 bridge first, then upgrade Spring Boot, Spring Cloud, Gateway, MyBatis-Plus, Druid, Jackson, and all existing Spring AI integrations as one compatibility boundary. Keep the Java source/bytecode level at 17 while building, testing, and running with JDK 21.

**Tech Stack:** JDK 21 toolchain/runtime with Java 17 source and bytecode, Spring Boot 4.0.7, Spring Framework 7, Spring AI 2.0.0, Spring Cloud 2025.1.2, Spring Cloud Gateway 5.x, MyBatis-Plus 3.5.17 Boot 4 starter, Druid 1.2.28 Boot 4 starter, Jackson 3 with Jackson annotations compatibility, PostgreSQL, Flyway, Maven, JUnit 5, Testcontainers.

## Global Constraints

- Complete this plan before Task 1 of `docs/superpowers/plans/2026-07-14-custom-scene-reliable-private-agentic-generation-implementation-plan-spring-ai-2-patch-reviewed.md`.
- Treat `t8.2-b2.1-custom-scene-hardening.patch` (base `d8960d1c...`, SHA-256 `e7e6c40fee445ba49eb24d82ad3b9b88ba62cf61d79771ec5d8d69ea5205b2e4`) as the required source baseline; do not run against the pre-B2.1 tree.
- Preserve the patch's classpath policy import, generated-content mappers, package moves, and API tests throughout Boot/Jackson/MyBatis migration.
- Use only stable releases: Spring AI `2.0.0`, Spring Boot `4.0.7`, Spring Cloud `2025.1.2`, MyBatis-Plus `3.5.17`, and Druid `1.2.28`. Use Boot 4.0.7 rather than 4.1.0 for this migration to reduce simultaneous framework-minor change while moving from Boot 3.4; Spring AI 2.0 supports both lines.
- Upgrade through Spring Boot `3.5.16` and Spring Cloud `2025.0.3` first; do not jump directly from Boot 3.4.4 to Boot 4. Druid `1.2.28` is required because that release explicitly adds the Spring Boot 4 starter; the current `1.2.23` and the `1.2.24` tag cannot satisfy the Boot 4 coordinate.
- Build and run with JDK 21, but preserve `<java.version>17</java.version>` until a separate language-level decision explicitly raises the source/bytecode target.
- Preserve every existing public HTTP contract, JWT claim contract, database schema, Flyway history, and provider-mode behavior.
- Do not implement custom-scene Generator, Judge, Repair, evidence bundles, or new generated-content state-machine behavior in this platform plan.
- Do not rely permanently on `spring-boot-properties-migrator` or `spring-boot-jackson2`; migration-only compatibility dependencies must be removed before this plan is complete.
- Prefer Jackson 3 packages (`tools.jackson.*`) for application JSON code. Keep Jackson annotations in `com.fasterxml.jackson.annotation.*`, which remains the supported annotation package.
- Spring AI 2.0's OpenAI implementation intentionally retains internal Jackson 2 deserialization code for the official OpenAI SDK. Transitive Jackson 2 jars inside Spring AI/OpenAI SDK are allowed; Baby Talk application source must not import Jackson 2 core/databind packages, and the temporary Boot `spring-boot-jackson2` bridge must still be removed.
- Existing Mentor, KG, Palace, chat memory, PGVector, Tika, tool calling, and embedding behavior must remain covered by tests.
- Spring AI 2.0 uses the official OpenAI Java SDK. Existing manually constructed models must be migrated to `OpenAiChatModel.builder().options(OpenAiChatOptions.builder()...)`; production code must no longer construct `OpenAiApi`.
- Freeze the existing documented Spring AI retry default as an explicit Baby Talk Mentor/KG contract before replacing Spring AI 1.1.4: `app.mentor.ai-max-attempts=10` means ten total outbound attempts. On Spring AI 2, map it to SDK `maxRetries=aiMaxAttempts-1`; do not silently inherit a framework default. The later custom-scene plan independently sets SDK `maxRetries(0)` for its auditable named-provider path.
- Preserve the reviewed B2.1 dirty working tree. Commit only files explicitly listed by each task, and never use `git add -A`.
- Follow TDD and migration checkpoints: each platform step must compile and pass its focused tests before the next dependency generation is introduced.


---

## Reviewed B2.1 Hardening Baseline

This migration runs on the development computer only after the B2.1 hardening
diff is captured as a separate reviewed baseline.

```text
base commit: d8960d1c9a68c2dd666cf697b047c0faa367a789
patch: t8.2-b2.1-custom-scene-hardening.patch
patch SHA-256: e7e6c40fee445ba49eb24d82ad3b9b88ba62cf61d79771ec5d8d69ea5205b2e4
```

The patch changes 79 paths and adds the generated-content registry, practice
catalog/profile package migration, V25, MyBatis mappers, Druid/MyBatis metadata
handling, Spring configuration import, and a large regression suite. Do not run
the platform upgrade while these changes remain an unidentified mixed
working-tree diff.

Before Task 1:

1. Commit/capture the B2.1 hardening baseline separately.
2. Copy the approved specification and both patch-reviewed plans into the repo.
3. Run `git diff --check` and the existing B2.1 focused tests.
4. Record whether V25 has ever run outside disposable/Testcontainers databases.
5. Use repository-root-relative commands; machine-specific paths are forbidden.

## File Structure

### Parent build and runtime

- `AGENTS.md`
  - Update the documented backend baseline to Spring Boot 4.0.7 and Spring AI 2.0.0 without removing the patch's UTC/PostgreSQL rules.
- `backend/app-api/src/main/resources/application.yml`
  - Preserve `spring.config.import: classpath:config/practice-discovery-policy.yml` while adding Spring AI 2 runtime imports.

- `backend/pom.xml`
  - Own the Boot parent, Spring AI BOM, Spring Cloud BOM, MyBatis-Plus/Druid versions, and Java target.
- `backend/Dockerfile`
  - Use Temurin JDK/JRE 21 images while preserving Java 17 bytecode.
- `.github/workflows/ci.yml`
  - Run backend Maven verification on Temurin 21.
- `tool/verify_spring_ai_2_backend_platform.py`
  - Fail when versions, Boot 3-only starters, Gateway coordinates/properties, or prohibited compatibility dependencies drift.
- `test/tool/verify_spring_ai_2_backend_platform_test.py`
  - Test the platform verifier against temporary fixtures.

### Boot 4 starter and configuration migration

- `backend/app-api/pom.xml`
- `backend/admin-api/pom.xml`
- `backend/common/pom.xml`
- `backend/gateway/pom.xml`
- `backend/db-migration/pom.xml`
- `backend/gateway/src/main/resources/application.yml`
- `backend/app-api/src/main/resources/application.yml`

### Jackson 3 migration

- Every Java file currently importing `com.fasterxml.jackson.core.*` or `com.fasterxml.jackson.databind.*` beneath `backend/`.
- Annotation imports under `com.fasterxml.jackson.annotation.*` remain unchanged.
- JSON web tests in `backend/app-api/src/test/java` and `backend/admin-api/src/test/java` verify that wire contracts do not change.

### Spring AI 2 migration

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ChatMemoryConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgConfiguration.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProvider.java`
- Spring AI consumers under `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace`, `kg`, `ingestion`, and `service`.
- Existing focused tests under the matching `src/test/java` packages.

---

### Task 1: Add a platform compatibility verifier and capture the current baseline

**Files:**
- Create: `tool/verify_spring_ai_2_backend_platform.py`
- Create: `test/tool/verify_spring_ai_2_backend_platform_test.py`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `python3 tool/verify_spring_ai_2_backend_platform.py`.
- The verifier reads repository files only; it performs no network calls and writes no files.
- Later tasks intentionally make the initially failing assertions pass.

- [ ] **Step 1: Write failing verifier fixture tests**

Create `test/tool/verify_spring_ai_2_backend_platform_test.py` with temporary-file cases proving the verifier rejects:

```python
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
VERIFY = ROOT / "tool" / "verify_spring_ai_2_backend_platform.py"


def run_verifier(repo: pathlib.Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["python3", str(VERIFY), "--root", str(repo)],
        text=True,
        capture_output=True,
        check=False,
    )


class SpringAi2BackendPlatformVerifierTest(unittest.TestCase):

    def test_rejects_boot3_and_spring_ai1_versions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            (repo / "backend").mkdir()
            (repo / "backend" / "pom.xml").write_text(
                "<version>3.4.4</version>"
                "<spring-ai.version>1.1.4</spring-ai.version>"
                "<spring-cloud.version>2025.1.2</spring-cloud.version>"
                "<mybatis-plus.version>3.5.17</mybatis-plus.version>"
                "<druid.version>1.2.28</druid.version>"
                "<java.version>17</java.version>",
                encoding="utf-8",
            )
            gateway = repo / "backend" / "gateway"
            (gateway / "src" / "main" / "resources").mkdir(parents=True)
            (gateway / "pom.xml").write_text(
                "<artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>",
                encoding="utf-8",
            )
            (gateway / "src" / "main" / "resources" / "application.yml").write_text(
                "spring:\n  cloud:\n    gateway:\n      server:\n        webflux:\n          routes: []\n",
                encoding="utf-8",
            )
            result = run_verifier(repo)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Spring Boot 4.0.7", result.stderr)
            self.assertIn("Spring AI 2.0.0", result.stderr)

    def test_rejects_boot3_starters_and_old_gateway_prefix(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            gateway = repo / "backend" / "gateway"
            (gateway / "src" / "main" / "resources").mkdir(parents=True)
            (repo / "backend" / "pom.xml").write_text(
                "<version>4.0.7</version>"
                "<spring-ai.version>2.0.0</spring-ai.version>"
                "<spring-cloud.version>2025.1.2</spring-cloud.version>"
                "<mybatis-plus.version>3.5.17</mybatis-plus.version>"
                "<druid.version>1.2.28</druid.version>"
                "<java.version>17</java.version>",
                encoding="utf-8",
            )
            (gateway / "pom.xml").write_text(
                "<artifactId>spring-cloud-starter-gateway</artifactId>",
                encoding="utf-8",
            )
            (gateway / "src" / "main" / "resources" / "application.yml").write_text(
                "spring:\n  cloud:\n    gateway:\n      routes: []\n",
                encoding="utf-8",
            )
            result = run_verifier(repo)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("gateway-server-webflux", result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run tests and verify they fail because the verifier is absent**

```bash
cd "$(git rev-parse --show-toplevel)"
python3 test/tool/verify_spring_ai_2_backend_platform_test.py
```

Expected: non-zero with `No such file or directory` for the verifier.

- [ ] **Step 3: Implement the repository-only verifier**

Create `tool/verify_spring_ai_2_backend_platform.py` with these exact checks:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REQUIRED = {
    "spring-boot": "4.0.7",
    "spring-ai.version": "2.0.0",
    "spring-cloud.version": "2025.1.2",
    "mybatis-plus.version": "3.5.17",
    "druid.version": "1.2.28",
}


def require(text: str, pattern: str, message: str, errors: list[str]) -> None:
    if re.search(pattern, text, re.MULTILINE) is None:
        errors.append(message)


def verify(root: pathlib.Path) -> list[str]:
    errors: list[str] = []
    parent = (root / "backend" / "pom.xml").read_text(encoding="utf-8")
    require(parent, r"<version>4\.0\.7</version>", "Expected Spring Boot 4.0.7", errors)
    for name, value in list(REQUIRED.items())[1:]:
        require(parent, rf"<{re.escape(name)}>{re.escape(value)}</{re.escape(name)}>",
                f"Expected {name}={value}", errors)
    require(parent, r"<java\.version>17</java\.version>", "Expected Java bytecode target 17", errors)

    all_poms = "\n".join(path.read_text(encoding="utf-8") for path in (root / "backend").glob("*/pom.xml"))
    for forbidden in (
        "mybatis-plus-spring-boot3-starter",
        "druid-spring-boot-3-starter",
        "spring-cloud-starter-gateway</artifactId>",
        "spring-boot-properties-migrator",
        "spring-boot-jackson2",
    ):
        if forbidden in all_poms or forbidden in parent:
            errors.append(f"Forbidden completed-migration dependency: {forbidden}")

    gateway_pom = (root / "backend" / "gateway" / "pom.xml").read_text(encoding="utf-8")
    require(gateway_pom, r"spring-cloud-starter-gateway-server-webflux", "Expected gateway-server-webflux starter", errors)
    gateway_yml = (root / "backend" / "gateway" / "src" / "main" / "resources" / "application.yml").read_text(encoding="utf-8")
    if re.search(r"^\s{4}gateway:\s*$", gateway_yml, re.MULTILINE):
        errors.append("Old spring.cloud.gateway prefix remains")
    require(gateway_yml, r"server:\s*\n\s+webflux:\s*\n\s+routes:",
            "Expected spring.cloud.gateway.server.webflux.routes", errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    errors = verify(args.root.resolve())
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Spring AI 2 backend platform contract verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Add the verifier test to CI without yet enforcing the repository check**

Add after checkout/setup in `.github/workflows/ci.yml`:

```yaml
      - name: Test Spring AI 2 platform verifier
        run: python3 test/tool/verify_spring_ai_2_backend_platform_test.py
```

Do not add the live repository verifier invocation until Task 8, because the current repository must fail it during migration.

- [ ] **Step 5: Run fixture tests and capture the current Maven baseline**

```bash
cd "$(git rev-parse --show-toplevel)"
python3 test/tool/verify_spring_ai_2_backend_platform_test.py
cd backend
bash mvnw -version
bash mvnw -pl common,app-api,admin-api,gateway,db-migration -am -DskipTests compile
```

Expected: verifier fixture tests pass; current backend compile outcome is recorded in the task review notes before dependency edits.

- [ ] **Step 6: Commit the verifier scaffold**

```bash
git add tool/verify_spring_ai_2_backend_platform.py \
  test/tool/verify_spring_ai_2_backend_platform_test.py .github/workflows/ci.yml
git commit -m "test: add Spring AI 2 platform verifier"
```

---

### Task 2: Move the build and runtime toolchain to JDK 21 while preserving Java 17 bytecode

**Files:**
- Modify: `backend/Dockerfile`
- Modify: `.github/workflows/ci.yml`
- Modify: `backend/pom.xml`

**Interfaces:**
- JDK used by Maven, CI, builder image, and runtime image is 21.
- Java source/target remains 17 through `<java.version>17</java.version>`.

- [ ] **Step 1: Add a CI assertion for toolchain and bytecode target**

Add before Maven tests in `.github/workflows/ci.yml`:

```yaml
      - name: Verify Java toolchain contract
        run: |
          java -version 2>&1 | grep '21\.'
          grep -q '<java.version>17</java.version>' backend/pom.xml
```

- [ ] **Step 2: Run the assertion locally and verify it exposes the current JDK/image mismatch**

```bash
cd "$(git rev-parse --show-toplevel)"
java -version
head -1 backend/Dockerfile
```

Expected before implementation: local/container evidence shows whether JDK 21 is installed; Dockerfile still references Temurin 17.

- [ ] **Step 3: Upgrade Docker and CI runtime images**

Replace `backend/Dockerfile` image declarations with:

```dockerfile
FROM maven:3-eclipse-temurin-21 AS builder
...
FROM eclipse-temurin:21-jre-alpine AS runtime
```

Change `.github/workflows/ci.yml` setup-java input to:

```yaml
          distribution: temurin
          java-version: '21'
```

Keep this in `backend/pom.xml`:

```xml
<java.version>17</java.version>
```

- [ ] **Step 4: Compile and inspect the class-file target**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl common -am clean compile
javap -verbose common/target/classes/com/zhangspaghetti/babytalk/security/JwtTokenService.class | grep 'major version: 61'
```

Expected: Maven runs on Java 21 and `JwtTokenService.class` remains Java 17 bytecode (`major version: 61`).

- [ ] **Step 5: Commit the toolchain migration**

```bash
git add backend/Dockerfile backend/pom.xml .github/workflows/ci.yml
git commit -m "build: run backend on JDK 21"
```

---

### Task 3: Upgrade to the Spring Boot 3.5 bridge and migrate Gateway coordinates/properties

**Files:**
- Modify: `backend/pom.xml`
- Modify: `backend/gateway/pom.xml`
- Modify: `backend/gateway/src/main/resources/application.yml`
- Modify: `backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/GatewayJwtConfigTest.java`
- Modify: `backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/filter/AdminJwtFilterTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProperties.java`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/MentorPropertiesTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/AgenticMentorIntegrationTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/ConversationSessionServiceTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java`

**Interfaces:**
- Bridge baseline: Spring Boot 3.5.16 + Spring Cloud 2025.0.3.
- Gateway uses the explicit WebFlux server starter and new configuration prefix before Boot 4.
- Mentor/KG retry behavior becomes an explicit application property before the framework retry implementation is replaced.

- [ ] **Step 1: Freeze the existing retry default as an explicit application contract**

Add this field to `MentorProperties` immediately after `aiMaxTokens`:

```java
@Min(1) int aiMaxAttempts,
```

Add this default to `backend/app-api/src/main/resources/application.yml`:

```yaml
app:
  mentor:
    ai-max-attempts: ${BABY_TALK_AI_MAX_ATTEMPTS:10}
```

Create `MentorPropertiesTest` with an `ApplicationContextRunner` that binds the production default and rejects `0`:

```java
private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
        .withConfiguration(AutoConfigurations.of(ConfigurationPropertiesAutoConfiguration.class))
        .withUserConfiguration(TestConfiguration.class);

@Test
void bindsExplicitAttemptCount() {
    contextRunner
            .withPropertyValues(baseProperties())
            .withPropertyValues("app.mentor.ai-max-attempts=10")
            .run(context -> {
                assertThat(context).hasNotFailed();
                assertThat(context.getBean(MentorProperties.class).aiMaxAttempts()).isEqualTo(10);
            });
}

@Test
void rejectsZeroAttempts() {
    contextRunner
            .withPropertyValues(baseProperties())
            .withPropertyValues("app.mentor.ai-max-attempts=0")
            .run(context -> assertThat(context).hasFailed());
}

private static String[] baseProperties() {
    return new String[] {
            "app.mentor.provider-mode=dev",
            "app.mentor.provider-timeout=PT4S",
            "app.mentor.rate-limit-max-requests=3",
            "app.mentor.rate-limit-window=PT10M",
            "app.mentor.prompt-max-length=280",
            "app.mentor.response-max-length=280",
            "app.mentor.allowed-surfaces[0]=home",
            "app.mentor.allowed-modes[0]=single_turn",
            "app.mentor.simulate-timeout-token=[timeout]",
            "app.mentor.simulate-malformed-token=[malformed]",
            "app.mentor.simulate-unavailable-token=[unavailable]"
    };
}

@TestConfiguration(proxyBeanMethods = false)
@EnableConfigurationProperties(MentorProperties.class)
static class TestConfiguration {}
```

Update every manual `new MentorProperties(...)` call in the four service tests listed above by inserting `10` immediately after `aiMaxTokens`. This is a mechanical constructor update; no test-specific retry behavior changes in Task 3.

This freezes the pre-upgrade documented Spring AI retry default as a Baby Talk configuration contract. In Task 4, ten total attempts are translated to Spring AI 2/OpenAI SDK `maxRetries(9)` because the SDK option counts retries after the first request.


- [ ] **Step 2: Add a failing Gateway context/property binding test**

Extend `GatewayJwtConfigTest` with:

```java
@Test
void bindsRoutesFromServerWebfluxGatewayPrefix() {
    new ApplicationContextRunner()
            .withPropertyValues(
                    "spring.cloud.gateway.server.webflux.routes[0].id=app-api",
                    "spring.cloud.gateway.server.webflux.routes[0].uri=http://app-api:8080",
                    "spring.cloud.gateway.server.webflux.routes[0].predicates[0]=Path=/api/**")
            .run(context -> assertThat(context).hasNotFailed());
}
```

- [ ] **Step 3: Upgrade the bridge versions**

Change the parent and version properties in `backend/pom.xml`:

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>3.5.16</version>
    <relativePath/>
</parent>
...
<spring-cloud.version>2025.0.3</spring-cloud.version>
<mybatis-plus.version>3.5.17</mybatis-plus.version>
<druid.version>1.2.28</druid.version>
```

Use `${spring-cloud.version}` in the Spring Cloud BOM import.

- [ ] **Step 4: Migrate the Gateway starter and prefix**

Replace in `backend/gateway/pom.xml`:

```xml
<artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>
```

Move every route/globalcors/httpclient property in `backend/gateway/src/main/resources/application.yml` from:

```yaml
spring:
  cloud:
    gateway:
```

to:

```yaml
spring:
  cloud:
    gateway:
      server:
        webflux:
```

Preserve route IDs, URIs, predicates, filters, rate-limit behavior, and JWT filters exactly.

- [ ] **Step 5: Run bridge compilation and Gateway tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl gateway -am clean test -Dtest=GatewayJwtConfigTest,AdminJwtFilterTest
bash mvnw -pl common,app-api,admin-api,db-migration -am -DskipTests compile
```

Expected: all commands pass on Boot 3.5.16; no Boot 4 migration begins until this checkpoint is green.

- [ ] **Step 6: Commit the bridge migration**

```bash
git add backend/pom.xml backend/gateway/pom.xml \
  backend/gateway/src/main/resources/application.yml backend/gateway/src/test/java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProperties.java \
  backend/app-api/src/main/resources/application.yml \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/MentorPropertiesTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/AgenticMentorIntegrationTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/ConversationSessionServiceTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/SpringAiMentorProviderTest.java
git commit -m "build: bridge backend through Spring Boot 3.5"
```

---

### Task 4: Upgrade to Spring Boot 4.0.7 and Spring AI 2.0.0 as one green platform checkpoint

**Files:**
- Modify: `backend/pom.xml`
- Modify: `backend/app-api/pom.xml`
- Modify: `backend/admin-api/pom.xml`
- Modify: `backend/common/pom.xml`
- Modify: `backend/gateway/pom.xml`
- Modify: `backend/db-migration/pom.xml`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `backend/gateway/src/main/resources/application.yml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgConfiguration.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/MentorProviderConfigurationOptionsTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/kg/KgConfigurationOptionsTest.java`

**Interfaces:**
- Produces one compilable baseline: Boot 4.0.7 + Spring AI 2.0.0 + Cloud 2025.1.2.
- MyBatis-Plus and Druid use their Boot 4 starters in every executable module.
- Existing manual OpenAI-compatible clients use the Spring AI 2 builder API; no production code constructs `OpenAiApi`.

- [ ] **Step 1: Add failing dependency and manual-model construction assertions**

Extend the platform verifier fixtures and focused Mentor/KG tests so they reject:

```text
Spring AI version other than 2.0.0
Boot 3 MyBatis-Plus or Druid starters
production `new OpenAiApi(...)`
manual chat models without explicit baseUrl, apiKey, model, and timeout
```

The focused configuration test must inspect a package-private options factory rather than making a network call:

```java
@Test
void buildsSpringAi2OptionsFromMentorProperties() {
    var options = configuration.openAiOptions(properties(
            "https://models.inference.ai.azure.com", "secret", "gpt-4o-mini", 0.2, 600, 10));

    assertThat(options.getBaseUrl()).isEqualTo("https://models.inference.ai.azure.com");
    assertThat(options.getApiKey()).isEqualTo("secret");
    assertThat(options.getModel()).isEqualTo("gpt-4o-mini");
    assertThat(options.getTemperature()).isEqualTo(0.2);
    assertThat(options.getMaxTokens()).isEqualTo(600);
    assertThat(options.getMaxRetries()).isEqualTo(9);
}

private static MentorProperties properties(
        String baseUrl,
        String apiKey,
        String model,
        Double temperature,
        Integer maxTokens,
        int maxAttempts) {
    return new MentorProperties(
            "openai",
            Duration.ofSeconds(4),
            baseUrl,
            apiKey,
            model,
            temperature,
            maxTokens,
            maxAttempts,
            3,
            Duration.ofMinutes(10),
            280,
            280,
            List.of("home"),
            List.of("single_turn"),
            List.of("体罚"),
            "[timeout]",
            "[malformed]",
            "[unavailable]",
            "none",
            Duration.ofMinutes(30),
            2000);
}
```

- [ ] **Step 2: Switch all platform coordinates in one edit**

Change `backend/pom.xml` to the exact stable baseline:

```xml
<parent>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-parent</artifactId>
    <version>4.0.7</version>
    <relativePath/>
</parent>
...
<spring-ai.version>2.0.0</spring-ai.version>
<spring-cloud.version>2025.1.2</spring-cloud.version>
<mybatis-plus.version>3.5.17</mybatis-plus.version>
<druid.version>1.2.28</druid.version>
```

Replace starter coordinates:

```xml
<artifactId>mybatis-plus-spring-boot4-starter</artifactId>
<artifactId>druid-spring-boot-4-starter</artifactId>
```

Temporarily add to each executable module:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-properties-migrator</artifactId>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-jackson2</artifactId>
</dependency>
```

`spring-boot-jackson2` is a migration bridge only. Task 5 removes it after application imports move to Jackson 3. Do not create or commit an interim Boot 4 + Spring AI 1.x state.

- [ ] **Step 3: Migrate manual OpenAI model construction enough to compile on Spring AI 2**

Replace `OpenAiApi` construction in `MentorProviderConfiguration` and `KgConfiguration` with the Spring AI 2 builder:

```java
OpenAiChatOptions openAiOptions(MentorProperties properties) {
    var builder = OpenAiChatOptions.builder()
            .baseUrl(resolveBaseUrl(properties))
            .apiKey(properties.aiApiKey())
            .model(properties.aiModel())
            .timeout(Duration.ofSeconds(60))
            .maxRetries(properties.aiMaxAttempts() - 1);
    if (properties.aiTemperature() != null) {
        builder.temperature(properties.aiTemperature());
    }
    if (properties.aiMaxTokens() != null) {
        builder.maxTokens(properties.aiMaxTokens());
    }
    return builder.build();
}

var chatModel = OpenAiChatModel.builder()
        .options(openAiOptions(properties))
        .build();
var chatClient = ChatClient.builder(chatModel).build();
```

Make `openAiOptions(MentorProperties)` package-private in `MentorProviderConfiguration` so `MentorProviderConfigurationOptionsTest` can inspect the exact options without reflection or a network call. Add the equivalent package-private `openAiOptions(MentorProperties, String)` seam in `KgConfiguration` and cover it with `KgConfigurationOptionsTest`. Apply the same pattern to KG using its existing independent temperature/token settings. Set `.maxRetries(properties.aiMaxAttempts() - 1)` so the default `ai-max-attempts=10` preserves ten total outbound attempts. Assert `aiMaxAttempts >= 1` through configuration validation. Do not rely on Spring AI 2 auto-configuration defaults; the later custom-scene provider factory is the only path that forces `maxRetries(0)`.

- [ ] **Step 4: Reconcile Boot 4 starter modules and Spring AI 2 auto-configuration names**

Validate every class named under `spring.autoconfigure.exclude` in `backend/app-api/src/main/resources/application.yml`. Replace obsolete exclusions with Spring AI 2 equivalents, or use documented model selection properties such as:

```yaml
spring:
  ai:
    model:
      chat: none
```

Add the narrow Boot 4 starter module that owns any missing auto-configuration; do not restore broad Boot 3 transitive behavior with arbitrary direct Spring Framework dependencies.

- [ ] **Step 5: Compile every module and run focused platform tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl common,app-api,admin-api,gateway,db-migration -am -DskipTests compile
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
bash mvnw -pl gateway -Dtest=GatewayJwtConfigTest,AdminJwtFilterTest test
bash mvnw -pl app-api -Dtest='MentorProviderConfigurationTest,MentorProviderConfigurationOptionsTest,KgConfigurationOptionsTest,SpringAiMentorProviderTest,KgContradictionReviewServiceTest' test
```

Expected: all commands pass. Do not commit a baseline where `app-api` is excluded or fails to compile.

- [ ] **Step 6: Commit the green Boot 4 / Spring AI 2 baseline**

```bash
git add backend/pom.xml backend/*/pom.xml \
  backend/app-api/src/main/resources/application.yml \
  backend/gateway/src/main/resources/application.yml \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/MentorProviderConfiguration.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg/KgConfiguration.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/MentorProviderConfigurationOptionsTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service/MentorProviderConfigurationTest.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/kg/KgConfigurationOptionsTest.java
git commit -m "build: upgrade backend to Spring AI 2"
```

---

### Task 5: Migrate application JSON code to Jackson 3 without changing wire contracts

**Files:**
- Modify: all Java files beneath `backend/` importing `com.fasterxml.jackson.core.*` or `com.fasterxml.jackson.databind.*`.
- Preserve: files importing only `com.fasterxml.jackson.annotation.*`.
- Modify: JSON-focused web tests under `backend/app-api/src/test/java` and `backend/admin-api/src/test/java`.
- Modify: `backend/app-api/pom.xml`, `backend/admin-api/pom.xml`, `backend/gateway/pom.xml`, and `backend/db-migration/pom.xml` to remove the temporary `spring-boot-jackson2` bridge.
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/Jackson3ContractTest.java`

**Interfaces:**
- Application JSON runtime uses `tools.jackson.core.*` and `tools.jackson.databind.*`.
- JSON annotations remain `com.fasterxml.jackson.annotation.*`.
- HTTP payload field names and null/unknown-field behavior remain unchanged.

- [ ] **Step 1: Add a failing package-boundary contract test**

Create `Jackson3ContractTest`:

```java
package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class Jackson3ContractTest {

    @Test
    void bootUsesJackson3JsonMapper() {
        var mapper = JsonMapper.builder().build();
        assertThat(mapper.getClass().getPackageName()).startsWith("tools.jackson");
    }
}
```

- [ ] **Step 2: Replace core/databind imports but keep annotations**

Apply these package transformations to production and test code:

```text
com.fasterxml.jackson.core.JsonProcessingException
→ tools.jackson.core.JacksonException

com.fasterxml.jackson.core.type.TypeReference
→ tools.jackson.core.type.TypeReference

com.fasterxml.jackson.databind.ObjectMapper
→ tools.jackson.databind.ObjectMapper

com.fasterxml.jackson.databind.JsonNode
→ tools.jackson.databind.JsonNode
```

Keep imports such as these unchanged:

```java
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
```

Where a catch block currently catches `JsonProcessingException`, catch `JacksonException` and preserve the existing public error mapping.

- [ ] **Step 3: Update mapper construction/customization**

Replace direct Jackson 2 builder/customizer APIs with Jackson 3 equivalents. Prefer injected Boot-managed `JsonMapper`/`ObjectMapper`; where a standalone mapper is required in a test, use:

```java
var objectMapper = tools.jackson.databind.json.JsonMapper.builder().build();
```

Do not add `spring-boot-jackson2` as a permanent dependency.

- [ ] **Step 4: Run JSON contract and web tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='Jackson3ContractTest,PracticeDiscoveryControllerTest,MentorWebTest,ShareLinkApiWebTest,AuthConsentSyncWebTest' test
bash mvnw -pl admin-api -Dtest='AdminAuthWebTest,AdminOverviewWebTest,AdminKnowledgeOpsWebTest' test
bash mvnw -pl gateway -Dtest=GatewayJwtConfigTest,AdminJwtFilterTest test
```

Expected: response/request JSON contracts are unchanged and no application source imports Jackson 2 core/databind packages.

- [ ] **Step 5: Add a static import check**

```bash
cd "$(git rev-parse --show-toplevel)"
if grep -RInE '^import com\.fasterxml\.jackson\.(core|databind)' backend --include='*.java'; then
  echo 'Jackson 2 core/databind imports remain' >&2
  exit 1
fi
```

Expected: exit `0`.

- [ ] **Step 6: Remove the temporary Jackson 2 bridge and commit the Jackson 3 migration**

Delete every executable-module dependency on:

```xml
<artifactId>spring-boot-jackson2</artifactId>
```

Then run the focused tests from Step 4 once more and commit:

```bash
git add backend/*/pom.xml \
  backend/app-api/src/main backend/app-api/src/test \
  backend/admin-api/src/main backend/admin-api/src/test \
  backend/gateway/src/main backend/gateway/src/test
git commit -m "refactor: migrate backend JSON to Jackson 3"
```

---

### Task 6: Complete Spring AI 2 integration migration and regression hardening

**Files:**
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config/ChatMemoryConfiguration.java`
- Modify: Spring AI consumers under `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace`, `kg`, `ingestion`, and `service` as 2.0 contracts require.
- Modify: matching focused tests.
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config/MentorProviderRetryContractTest.java`

**Interfaces:**
- All Spring AI artifacts resolve at exactly `2.0.0`.
- Existing Mentor, KG, Palace, PGVector, Tika, chat-memory, embedding, advisor, and tool-calling behavior remains unchanged at the business boundary.
- This task does not introduce custom-scene zero-retry semantics; that remains isolated to the custom-scene plan.

- [ ] **Step 1: Add focused contract tests for every existing Spring AI integration**

Before changing consumers, ensure the focused suite covers:

```text
Mentor provider construction and response mapping
KG contradiction review and tools
JDBC chat-memory repository behavior
PGVector/embedding configuration
Palace hybrid retrieval and search
Tika document ingestion
metadata enrichment and prompt building
tool callback registration and execution
```

Tests use mocks/Testcontainers only and must not require a real AI key or external endpoint.

- [ ] **Step 2: Resolve Spring AI 2 API changes without compatibility wrappers**

Update changed Spring AI types and accessors in the affected packages. Prefer the 2.0 contracts directly:

```text
OpenAiChatModel.builder().options(...)
ChatClient.builder(chatModel)
current Document/ChatResponse accessors
current JDBC chat-memory repository APIs
current ToolCallback/Advisor APIs
current PGVector and Tika starter contracts
```

Do not add local adapter classes whose only purpose is to preserve removed 1.x signatures. Business-facing Baby Talk ports may stay stable; framework-facing code must use 2.0 natively.

- [ ] **Step 3: Revalidate retry and structured-output behavior of existing paths**

Extend `MentorProviderConfigurationOptionsTest` and `KgConfigurationOptionsTest` to assert that `ai-max-attempts=10` becomes Spring AI 2 `OpenAiChatOptions.getMaxRetries()==9`, while an explicit value of `1` becomes `maxRetries==0`. Do not use `spring.ai.retry.max-attempts` for these manually constructed models. If a product decision changes the Mentor/KG count, change `app.mentor.ai-max-attempts` in a separate reviewed change. Only the later custom-scene path requires exactly one outbound request per named-provider attempt.

Add `MentorProviderRetryContractTest` using a local JDK `HttpServer`: configure `ai-max-attempts=2`, return HTTP 500 for the first request and a valid completion for the second, call the real Spring AI 2 `OpenAiChatModel`, and assert the server request counter is exactly `2`. This verifies the migration preserves total-attempt semantics rather than merely checking an options value. The test must not contact an external endpoint and must use a short SDK timeout.

For any existing structured-output path, assert that malformed output maps to the same public failure as before. Do not introduce `validateSchema()` auto-retry behavior without an explicit product decision and an audit model capable of observing each retry.

- [ ] **Step 4: Run Spring AI focused tests without external network calls**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='MentorPropertiesTest,MentorProviderConfigurationTest,MentorProviderConfigurationOptionsTest,MentorProviderRetryContractTest,KgConfigurationOptionsTest,SpringAiMentorProviderTest,ChatMemoryConfigurationTest,ChatMemoryIntegrationTest,EmbeddingConfigurationTest,KgContradictionReviewServiceTest,KgQueryToolTest,PalaceHybridRetrievalServiceTest,PalaceSearchServiceTest,PalaceToolProviderTest,MemPalaceMetadataEnricherTest,MemPalacePromptBuilderTest' test
```

Expected: all selected tests pass with mocks/Testcontainers and no call to an external AI endpoint.

- [ ] **Step 5: Run dependency convergence and source-boundary checks**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -DskipTests dependency:tree \
  -Dincludes=org.springframework.ai,org.springframework.boot,org.springframework,tools.jackson,com.fasterxml.jackson,com.openai
bash mvnw -pl app-api -DskipTests compile
cd ..
if grep -RIn 'new OpenAiApi' backend --include='*.java'; then
  echo 'Legacy OpenAiApi construction remains' >&2
  exit 1
fi
```

Expected: Spring AI resolves only at `2.0.0`; Boot resolves at `4.0.7`; no Spring Framework 6 artifacts remain; no production source constructs `OpenAiApi`. Transitive Jackson 2 used internally by Spring AI/OpenAI SDK is acceptable, but no Baby Talk application source may import Jackson 2 core/databind packages.

- [ ] **Step 6: Commit Spring AI 2 integration hardening**

```bash
git add backend/app-api/src/main/resources/application.yml \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/config \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/kg \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/ingestion \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/config \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/kg \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/palace \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/service
git commit -m "refactor: complete Spring AI 2 migration"
```

---

## Patch-Specific Platform Regression Gate

Before Task 7, run tests most sensitive to Boot 4, Jackson 3, MyBatis-Plus Boot
4, Druid Boot 4, configuration binding, and Spring context wiring:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='CustomSceneGenerationProviderWiringTest,PracticeDiscoveryCustomScenePropertiesTest,PracticeDiscoveryPolicyPropertiesTest,PracticeGeneratedContentMapperTest,PracticeGeneratedContentConcurrencyTest,PracticeGeneratedContentServiceTest,PracticeDiscoveryControllerTest,PracticeCatalogMapperTest,PracticeCatalogServiceTest,BabyProfileMapperTest,BabyProfileServiceTest,AuthConsentSyncWebTest' test
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Explicitly instantiate and exercise the patch-added
`MyBatisPlusMetaObjectHandler`, all new practice/profile mappers, and the
classpath policy import. A generic green context test is insufficient.

### Task 7: Remove migration shims and run the full backend regression matrix

**Files:**
- Modify: `backend/app-api/pom.xml`
- Modify: `backend/admin-api/pom.xml`
- Modify: `backend/gateway/pom.xml`
- Modify: `backend/db-migration/pom.xml`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `backend/gateway/src/main/resources/application.yml`

**Interfaces:**
- No temporary Boot property migrator remains; Task 5 already removed the Jackson 2 Boot compatibility module.
- Every executable module starts on Boot 4.0.7.

- [ ] **Step 1: Start every executable application with the property migrator enabled and capture warnings**

Run test contexts or local starts with safe test profiles:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=MentorWebTest test
bash mvnw -pl admin-api -Dtest=AdminAuthWebTest test
bash mvnw -pl gateway -Dtest=GatewayJwtConfigTest test
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Expected: inspect logs and migrate every renamed/removed property before removing the migrator.

- [ ] **Step 2: Remove temporary migration dependencies**

Delete every dependency on:

```xml
<artifactId>spring-boot-properties-migrator</artifactId>
```

Assert `spring-boot-jackson2` is already absent. No completed migration may rely on either module.

- [ ] **Step 3: Run the complete backend test suite**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw clean test
```

Expected: all modules compile and all unit/integration tests pass. No production test may require a real AI API key or external network.

- [ ] **Step 4: Build every executable jar and verify Java 21 runtime startup metadata**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api,admin-api,gateway,db-migration -am package -DskipTests
for module in app-api admin-api gateway db-migration; do
  test -n "$(find "$module/target" -maxdepth 1 -name '*.jar' ! -name '*.original' -print -quit)"
done
```

Expected: four executable module jars exist.

- [ ] **Step 5: Commit migration-shim removal**

```bash
git add backend/*/pom.xml backend/*/src/main/resources
git commit -m "chore: remove Boot 4 migration shims"
```

---

### Task 8: Enforce the final platform contract in CI and link the custom-scene plan prerequisite

**Files:**
- Modify: `AGENTS.md`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/superpowers/plans/2026-07-14-custom-scene-reliable-private-agentic-generation-implementation-plan-spring-ai-2-patch-reviewed.md`
- Modify: `tool/verify_spring_ai_2_backend_platform.py`
- Modify: `test/tool/verify_spring_ai_2_backend_platform_test.py`

**Interfaces:**
- CI prevents regression from Spring AI 2 / Boot 4 baseline.
- Custom-scene implementation cannot begin until this plan's final verification passes.

- [ ] **Step 1: Add live repository verification to CI**

Add after the verifier fixture tests:

```yaml
      - name: Verify Spring AI 2 backend platform
        run: python3 tool/verify_spring_ai_2_backend_platform.py
```

- [ ] **Step 2: Extend the verifier for Jackson and Spring AI construction boundaries**

Add checks that fail when production code contains:

```text
import com.fasterxml.jackson.core.
import com.fasterxml.jackson.databind.
new OpenAiApi
spring-ai.version other than 2.0.0
spring.cloud.gateway.routes
```

Allow `com.fasterxml.jackson.annotation.*` and transitive Jackson 2 dependencies inside Spring AI/OpenAI SDK implementation jars.

- [ ] **Step 3: Run final platform verification**

```bash
cd "$(git rev-parse --show-toplevel)"
python3 test/tool/verify_spring_ai_2_backend_platform_test.py
python3 tool/verify_spring_ai_2_backend_platform.py
cd backend
bash mvnw clean test
bash mvnw -pl app-api -DskipTests dependency:tree \
  -Dincludes=org.springframework.ai,org.springframework.boot,org.springframework.cloud,com.baomidou,com.alibaba,tools.jackson
cd ..
git diff --check
```

Expected: every command exits `0` and the dependency tree shows the exact stable baseline declared in this plan.

- [ ] **Step 4: Commit the final platform gate**

```bash
git add AGENTS.md backend/app-api/src/main/resources/application.yml \
  .github/workflows/ci.yml \
  tool/verify_spring_ai_2_backend_platform.py \
  test/tool/verify_spring_ai_2_backend_platform_test.py \
  docs/superpowers/plans/2026-07-14-custom-scene-reliable-private-agentic-generation-implementation-plan-spring-ai-2-patch-reviewed.md
git commit -m "docs: gate custom scene work on Spring AI 2"
```

---

## Final Review Gate

Before completion, compare the post-migration tree with the B2.1 baseline and
prove that no package move, mapper XML, configuration import, V25 constraint,
or hardening test disappeared merely because Boot/Jackson coordinates changed.

Before declaring the platform migration complete:

1. `backend/pom.xml` declares Boot `4.0.7`, Spring AI `2.0.0`, Cloud `2025.1.2`, MyBatis-Plus `3.5.17`, Druid `1.2.28`, and Java target `17`.
2. CI and Docker use JDK/JRE 21.
3. No Boot 3 MyBatis/Druid/Gateway starter remains.
4. No old `spring.cloud.gateway.*` route prefix remains outside migration tests.
5. No application source imports Jackson 2 core/databind packages; annotation imports remain valid.
6. `spring-boot-properties-migrator` and `spring-boot-jackson2` are absent.
7. Existing Mentor, KG, chat memory, Palace, PGVector, Tika, embedding, and tool-calling tests pass without external AI calls; tests prove `ai-max-attempts=10` maps to Spring AI 2 SDK `maxRetries=9`.
8. `python3 tool/verify_spring_ai_2_backend_platform.py`, `bash mvnw clean test`, and `git diff --check` pass.
9. Request code review before starting the custom-scene implementation plan.
