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


def write_valid_platform(repo: pathlib.Path) -> pathlib.Path:
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
        "<artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>",
        encoding="utf-8",
    )
    (gateway / "src" / "main" / "resources" / "application.yml").write_text(
        "spring:\n  cloud:\n    gateway:\n      server:\n        webflux:\n          routes: []\n",
        encoding="utf-8",
    )
    return repo / "backend" / "app-api" / "src" / "main" / "java" / "example"


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

    def test_rejects_each_boot3_starter_and_old_gateway_prefix(self) -> None:
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
                "<artifactId>mybatis-plus-spring-boot3-starter</artifactId>"
                "<artifactId>druid-spring-boot-3-starter</artifactId>"
                "<artifactId>spring-cloud-starter-gateway</artifactId>",
                encoding="utf-8",
            )
            (gateway / "src" / "main" / "resources" / "application.yml").write_text(
                "spring:\n  cloud:\n    gateway:\n      routes: []\n",
                encoding="utf-8",
            )
            result = run_verifier(repo)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "Forbidden completed-migration dependency: mybatis-plus-spring-boot3-starter",
                result.stderr,
            )
            self.assertIn(
                "Forbidden completed-migration dependency: druid-spring-boot-3-starter",
                result.stderr,
            )
            self.assertIn("gateway-server-webflux", result.stderr)

    def test_rejects_old_gateway_prefix(self) -> None:
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
                "<artifactId>spring-cloud-starter-gateway-server-webflux</artifactId>",
                encoding="utf-8",
            )
            (gateway / "src" / "main" / "resources" / "application.yml").write_text(
                "spring:\n  cloud:\n    gateway:\n      routes: []\n",
                encoding="utf-8",
            )
            result = run_verifier(repo)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Old spring.cloud.gateway prefix remains", result.stderr)

    def test_rejects_production_open_ai_api_construction(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "LegacyConfiguration.java").write_text(
                "class LegacyConfiguration { Object api() { return new OpenAiApi(); } }",
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Production OpenAiApi construction", result.stderr)

    def test_rejects_manual_model_without_explicit_provider_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "IncompleteConfiguration.java").write_text(
                """
                class IncompleteConfiguration {
                    Object model() {
                        return OpenAiChatModel.builder()
                                .options(OpenAiChatOptions.builder()
                                        .baseUrl(\"https://example.test\")
                                        .apiKey(\"key\")
                                        .model(\"model\")
                                        .build())
                                .build();
                    }
                }
                """,
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Manual OpenAiChatModel construction lacks explicit timeout", result.stderr)

    def test_rejects_incomplete_model_with_unrelated_valid_options_factory(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "IncompleteConfiguration.java").write_text(
                """
                class IncompleteConfiguration {
                    OpenAiChatOptions unusedOptions() {
                        return OpenAiChatOptions.builder()
                                .baseUrl("https://example.test")
                                .apiKey("key")
                                .model("model")
                                .timeout(Duration.ofSeconds(60))
                                .build();
                    }

                    Object model() {
                        return OpenAiChatModel.builder()
                                .options(OpenAiChatOptions.builder()
                                        .baseUrl("https://example.test")
                                        .apiKey("key")
                                        .model("model")
                                        .build())
                                .build();
                    }
                }
                """,
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Manual OpenAiChatModel construction lacks explicit timeout", result.stderr)

    def test_accepts_routes_after_other_webflux_options(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            (repo / "backend" / "gateway" / "src" / "main" / "resources" / "application.yml").write_text(
                "spring:\n"
                "  cloud:\n"
                "    gateway:\n"
                "      server:\n"
                "        webflux:\n"
                "          httpclient:\n"
                "            codec:\n"
                "              max-in-memory-size: 100MB\n"
                "          routes: []\n",
                encoding="utf-8",
            )

            result = run_verifier(repo)

            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
