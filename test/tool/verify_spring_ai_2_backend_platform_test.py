import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
VERIFY = ROOT / "tool" / "verify_spring_ai_2_backend_platform.py"


def run_verifier(
    repo: pathlib.Path,
    dependency_tree: pathlib.Path | None = None,
) -> subprocess.CompletedProcess[str]:
    command = ["python3", str(VERIFY), "--root", str(repo)]
    if dependency_tree is not None:
        command.extend(["--dependency-tree", str(dependency_tree)])
    return subprocess.run(
        command,
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

    def test_ci_verifies_resolved_spring_ai_dependency_tree(self) -> None:
        workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")

        self.assertIn("dependency:tree", workflow)
        self.assertIn("-Dincludes=org.springframework.ai:*", workflow)
        self.assertIn("--dependency-tree", workflow)

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

    def test_rejects_non_stable_spring_ai_version_alongside_stable_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            pom = repo / "backend" / "pom.xml"
            pom.write_text(
                pom.read_text(encoding="utf-8")
                + "<spring-ai.version>2.0.1</spring-ai.version>",
                encoding="utf-8",
            )

            result = run_verifier(repo)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Non-stable Spring AI version: 2.0.1", result.stderr)

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

    def test_rejects_production_open_ai_api_import_and_builder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "LegacyConfiguration.java").write_text(
                "import org.springframework.ai.openai.api.OpenAiApi;\n"
                "class LegacyConfiguration {\n"
                "    OpenAiApi api() { return OpenAiApi.builder().build(); }\n"
                "}\n",
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Production OpenAiApi reference", result.stderr)

    def test_rejects_explicit_spring_ai_1x_version_in_child_pom(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            child_pom = repo / "backend" / "app-api" / "pom.xml"
            child_pom.parent.mkdir(parents=True)
            child_pom.write_text(
                "<project><dependencies><dependency>"
                "<groupId>org.springframework.ai</groupId>"
                "<artifactId>spring-ai-openai</artifactId>"
                "<version>1.1.4</version>"
                "</dependency></dependencies></project>",
                encoding="utf-8",
            )

            result = run_verifier(repo)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "Explicit Spring AI dependency version must be 2.0.0 or ${spring-ai.version}",
                result.stderr,
            )
            self.assertIn("backend/app-api/pom.xml", result.stderr)

    def test_accepts_allowed_explicit_spring_ai_dependency_versions(self) -> None:
        for allowed_version in ("2.0.0", "${spring-ai.version}"):
            with self.subTest(version=allowed_version), tempfile.TemporaryDirectory() as tmp:
                repo = pathlib.Path(tmp)
                write_valid_platform(repo)
                child_pom = repo / "backend" / "app-api" / "pom.xml"
                child_pom.parent.mkdir(parents=True)
                child_pom.write_text(
                    "<project><dependencies><dependency>"
                    "<groupId>org.springframework.ai</groupId>"
                    "<artifactId>spring-ai-openai</artifactId>"
                    f"<version>{allowed_version}</version>"
                    "</dependency></dependencies></project>",
                    encoding="utf-8",
                )

                result = run_verifier(repo)

                self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_resolved_spring_ai_1x_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            dependency_tree = repo / "spring-ai-dependency-tree.txt"
            dependency_tree.write_text(
                "[INFO] +- org.springframework.ai:spring-ai-core:jar:1.1.4:compile\n",
                encoding="utf-8",
            )

            result = run_verifier(repo, dependency_tree)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "Resolved Spring AI dependency must be 2.0.0: spring-ai-core=1.1.4",
                result.stderr,
            )

    def test_accepts_resolved_spring_ai_2_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            dependency_tree = repo / "spring-ai-dependency-tree.txt"
            dependency_tree.write_text(
                "[INFO] +- org.springframework.ai:spring-ai-core:jar:2.0.0:compile\n",
                encoding="utf-8",
            )

            result = run_verifier(repo, dependency_tree)

            self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_empty_resolved_spring_ai_dependency_tree(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            dependency_tree = repo / "spring-ai-dependency-tree.txt"
            dependency_tree.write_text("[INFO] BUILD SUCCESS\n", encoding="utf-8")

            result = run_verifier(repo, dependency_tree)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("No resolved Spring AI dependencies found", result.stderr)

    def test_rejects_production_jackson2_core_and_databind_imports(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "LegacyJacksonConfiguration.java").write_text(
                "import com.fasterxml.jackson.core.JsonProcessingException;\n"
                "import com.fasterxml.jackson.databind.ObjectMapper;\n"
                "class LegacyJacksonConfiguration {}\n",
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Production Jackson 2 core/databind import remains", result.stderr)

    def test_allows_production_jackson_annotation_import(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "JacksonAnnotationConfiguration.java").write_text(
                "import com.fasterxml.jackson.annotation.JsonProperty;\n"
                "class JacksonAnnotationConfiguration {}\n",
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_direct_spring_cloud_gateway_routes_property(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = pathlib.Path(tmp)
            write_valid_platform(repo)
            resources = repo / "backend" / "app-api" / "src" / "main" / "resources"
            resources.mkdir(parents=True)
            (resources / "application.yml").write_text(
                "spring.cloud.gateway.routes: []\n",
                encoding="utf-8",
            )

            result = run_verifier(repo)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Old spring.cloud.gateway.routes property remains", result.stderr)

    def test_rejects_direct_spring_cloud_gateway_routes_property_in_java(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            (source / "LegacyGatewayConfiguration.java").write_text(
                "class LegacyGatewayConfiguration {\n"
                "    String property = \"spring.cloud.gateway.routes\";\n"
                "}\n",
                encoding="utf-8",
            )

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Old spring.cloud.gateway.routes property remains", result.stderr)

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

    def test_accepts_exact_practice_ai_options_factory_delegation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            self.write_practice_ai_delegation(source, ".maxRetries(0)")

            result = run_verifier(source.parents[5])

            self.assertEqual(result.returncode, 0, result.stderr)

    def test_rejects_practice_ai_options_factory_without_max_retries_zero(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            self.write_practice_ai_delegation(source, "")

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("PracticeAiOpenAiOptionsFactory must hard-code maxRetries(0)", result.stderr)

    def test_rejects_practice_ai_options_factory_with_positive_retries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = write_valid_platform(pathlib.Path(tmp))
            source.mkdir(parents=True)
            self.write_practice_ai_delegation(source, ".maxRetries(1)")

            result = run_verifier(source.parents[5])

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("PracticeAiOpenAiOptionsFactory must hard-code maxRetries(0)", result.stderr)

    def write_practice_ai_delegation(self, source: pathlib.Path, max_retries: str) -> None:
        (source / "PracticeAiChatClientFactory.java").write_text(
            """
            class PracticeAiChatClientFactory {
                private final PracticeAiOpenAiOptionsFactory optionsFactory;

                Object create(ProviderDefinition provider, String apiKey) {
                    OpenAiChatOptions options = optionsFactory.build(provider, apiKey);
                    return OpenAiChatModel.builder().options(options).build();
                }
            }
            """,
            encoding="utf-8",
        )
        (source / "PracticeAiOpenAiOptionsFactory.java").write_text(
            f"""
            class PracticeAiOpenAiOptionsFactory {{
                OpenAiChatOptions build(ProviderDefinition provider, String apiKey) {{
                    var builder = OpenAiChatOptions.builder()
                            .baseUrl(provider.baseUrl().toString())
                            .apiKey(apiKey)
                            .model(provider.model())
                            .timeout(provider.timeout())
                            .n(1)
                            {max_retries};
                    if (provider.temperature() != null) {{
                        builder.temperature(provider.temperature());
                    }}
                    if (provider.maxTokens() != null) {{
                        builder.maxTokens(provider.maxTokens());
                    }}
                    if (provider.maxCompletionTokens() != null) {{
                        builder.maxCompletionTokens(provider.maxCompletionTokens());
                    }}
                    return builder.build();
                }}
            }}
            """,
            encoding="utf-8",
        )

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
