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


def production_java_sources(root: pathlib.Path) -> list[pathlib.Path]:
    return sorted((root / "backend").glob("*/src/main/**/*.java"))


def backend_poms(root: pathlib.Path) -> list[pathlib.Path]:
    return sorted((root / "backend").rglob("pom.xml"))


def verify_explicit_spring_ai_dependency_versions(
    root: pathlib.Path,
    errors: list[str],
) -> None:
    allowed_versions = {REQUIRED["spring-ai.version"], "${spring-ai.version}"}
    for path in backend_poms(root):
        pom = path.read_text(encoding="utf-8")
        for dependency in re.finditer(
            r"<dependency\b[^>]*>(.*?)</dependency>",
            pom,
            re.DOTALL,
        ):
            body = dependency.group(1)
            group_id = re.search(r"<groupId>\s*([^<]+?)\s*</groupId>", body)
            if group_id is None or group_id.group(1) != "org.springframework.ai":
                continue
            version = re.search(r"<version>\s*([^<]+?)\s*</version>", body)
            if version is None or version.group(1) in allowed_versions:
                continue
            artifact = re.search(r"<artifactId>\s*([^<]+?)\s*</artifactId>", body)
            artifact_id = artifact.group(1) if artifact is not None else "unknown-artifact"
            errors.append(
                "Explicit Spring AI dependency version must be 2.0.0 or "
                f"${{spring-ai.version}}: {path.relative_to(root).as_posix()} "
                f"{artifact_id}={version.group(1)}"
            )


def verify_resolved_spring_ai_dependencies(
    dependency_tree: pathlib.Path,
    errors: list[str],
) -> None:
    tree = dependency_tree.read_text(encoding="utf-8")
    resolved: list[tuple[str, str]] = []
    scopes = {"compile", "provided", "runtime", "test", "system", "import"}
    for match in re.finditer(r"org\.springframework\.ai:[^\s]+", tree):
        coordinate = match.group(0).rstrip(",;)]}")
        parts = coordinate.split(":")
        if len(parts) < 5:
            continue
        version = parts[-2] if parts[-1] in scopes else parts[-1]
        resolved.append((parts[1], version))
    if not resolved:
        errors.append("No resolved Spring AI dependencies found in dependency tree")
        return
    for artifact_id, version in sorted(set(resolved)):
        if version != REQUIRED["spring-ai.version"]:
            errors.append(
                "Resolved Spring AI dependency must be 2.0.0: "
                f"{artifact_id}={version}"
            )


def balanced_parentheses_end(source: str, opening_parenthesis: int) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(opening_parenthesis, len(source)):
        character = source[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character in ('"', "'"):
            quote = character
        elif character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def model_options_expression(source: str, builder_end: int) -> str | None:
    """Return the explicit .options(...) argument for one model builder chain."""
    position = builder_end
    while True:
        method = re.match(r"\s*\.\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*\(", source[position:])
        if method is None:
            return None
        opening_parenthesis = position + method.end() - 1
        closing_parenthesis = balanced_parentheses_end(source, opening_parenthesis)
        if closing_parenthesis is None:
            return None
        method_name = method.group(1)
        if method_name == "options":
            return source[opening_parenthesis + 1:closing_parenthesis]
        if method_name == "build":
            return None
        position = closing_parenthesis + 1


def supplied_options_source(source: str, expression: str, options: str) -> str | None:
    if re.search(rf"\b{re.escape(options)}\s*\.\s*builder\s*\(", expression):
        return expression

    supplied_factory = re.fullmatch(
        r"\s*(?:this\s*\.\s*)?([A-Za-z_$][A-Za-z0-9_$]*)\s*\(.*\)\s*",
        expression,
        re.DOTALL,
    )
    if supplied_factory is None:
        return None
    factory_name = supplied_factory.group(1)
    declaration = re.search(
        rf"\b{re.escape(options)}\s+{re.escape(factory_name)}\s*\([^)]*\)\s*(?:throws[^{{]+)?\{{",
        source,
    )
    if declaration is None:
        return None
    opening_brace = declaration.end() - 1
    closing_brace = balanced_brace_end(source, opening_brace)
    if closing_brace is None:
        return None
    factory_body = source[opening_brace + 1:closing_brace]
    if re.search(rf"\b{re.escape(options)}\s*\.\s*builder\s*\(", factory_body) is None:
        return None
    return factory_body


def balanced_brace_end(source: str, opening_brace: int) -> int | None:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(opening_brace, len(source)):
        character = source[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character in ('"', "'"):
            quote = character
        elif character == "{":
            depth += 1
        elif character == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def verify_manual_model_configuration(root: pathlib.Path, errors: list[str]) -> None:
    required_options = {
        "OpenAiChatModel": "OpenAiChatOptions",
        "OpenAiEmbeddingModel": "OpenAiEmbeddingOptions",
    }
    required_provider_fields = ("baseUrl", "apiKey", "model", "timeout")
    for path in production_java_sources(root):
        source = path.read_text(encoding="utf-8")
        relative_path = path.relative_to(root)
        if re.search(
            r"^\s*import\s+com\.fasterxml\.jackson\.(?:core|databind)\.",
            source,
            re.MULTILINE,
        ):
            errors.append(f"Production Jackson 2 core/databind import remains: {relative_path}")
        if re.search(r"\bOpenAiApi\b", source):
            errors.append(f"Production OpenAiApi reference remains: {relative_path}")
        if re.search(r"\bnew\s+OpenAiApi\s*\(", source):
            errors.append(f"Production OpenAiApi construction remains: {relative_path}")
        for model, options in required_options.items():
            for builder in re.finditer(
                rf"\b{re.escape(model)}\s*\.\s*builder\s*\(\s*\)", source
            ):
                expression = model_options_expression(source, builder.end())
                if expression is None:
                    errors.append(
                        f"Manual {model} construction lacks supplied {options} provider configuration: {relative_path}"
                    )
                    continue
                option_source = supplied_options_source(source, expression, options)
                if option_source is None:
                    errors.append(
                        f"Manual {model} construction lacks {options} provider configuration: {relative_path}"
                    )
                    continue
                for field in required_provider_fields:
                    if not re.search(rf"\.{field}\s*\(", option_source):
                        errors.append(
                            f"Manual {model} construction lacks explicit {field}: {relative_path}"
                        )


def verify(
    root: pathlib.Path,
    dependency_tree: pathlib.Path | None = None,
) -> list[str]:
    errors: list[str] = []
    parent = (root / "backend" / "pom.xml").read_text(encoding="utf-8")
    require(parent, r"<version>4\.0\.7</version>", "Expected Spring Boot 4.0.7", errors)
    for name, value in list(REQUIRED.items())[1:]:
        require(parent, rf"<{re.escape(name)}>{re.escape(value)}</{re.escape(name)}>",
                "Expected Spring AI 2.0.0" if name == "spring-ai.version" else f"Expected {name}={value}", errors)
    require(parent, r"<java\.version>17</java\.version>", "Expected Java bytecode target 17", errors)

    all_poms = "\n".join(
        path.read_text(encoding="utf-8") for path in backend_poms(root)
    )
    for version in sorted(set(re.findall(
        r"<spring-ai\.version>\s*([^<\s]+)\s*</spring-ai\.version>", all_poms,
    ))):
        if version != REQUIRED["spring-ai.version"]:
            errors.append(f"Non-stable Spring AI version: {version}")
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
    old_gateway_prefix = re.search(
        r"^ {4}gateway:\s*\n(?:^ {6}(?!server:).*(?:\n|$))*^ {6}routes:",
        gateway_yml,
        re.MULTILINE,
    )
    if old_gateway_prefix:
        errors.append("Old spring.cloud.gateway prefix remains")
    if not all((
            re.search(r"^ {6}server:\s*$", gateway_yml, re.MULTILINE),
            re.search(r"^ {8}webflux:\s*$", gateway_yml, re.MULTILINE),
            re.search(r"^ {10}routes:", gateway_yml, re.MULTILINE),
    )):
        errors.append("Expected spring.cloud.gateway.server.webflux.routes")
    platform_sources = [
        *production_java_sources(root),
        *(path for path in (root / "backend").glob("*/src/main/resources/**/*") if path.is_file()),
    ]
    for path in sorted(platform_sources):
        if re.search(
                r"\bspring\.cloud\.gateway\.routes\b",
                path.read_text(encoding="utf-8"),
        ):
            errors.append(
                f"Old spring.cloud.gateway.routes property remains: {path.relative_to(root)}"
            )
    verify_manual_model_configuration(root, errors)
    verify_explicit_spring_ai_dependency_versions(root, errors)
    if dependency_tree is not None:
        verify_resolved_spring_ai_dependencies(dependency_tree, errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--dependency-tree",
        type=pathlib.Path,
        help="Maven dependency:tree output containing resolved org.springframework.ai artifacts",
    )
    args = parser.parse_args()
    errors = verify(args.root.resolve(), args.dependency_tree)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Spring AI 2 backend platform contract verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
