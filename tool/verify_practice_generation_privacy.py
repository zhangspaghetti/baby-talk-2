#!/usr/bin/env python3
"""Fail closed when private custom-scene generation gains unsafe persistence or AI hooks."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_FIELDS = (
    "security_text",
    "risk_signals",
    "raw_scene",
    "raw_prompt",
    "prompt_body",
    "raw_response",
    "response_body",
    "raw_error",
    "raw_chunk",
    "chain_of_thought",
)
REQUIRED_RESPONSE_COLUMNS = (
    "space_slug",
    "activity_slug",
    "phrase_slug",
    "tpr_action_zh",
    "delivery_guidance_zh",
    "english_text",
    "chinese_text",
)
SECURITY_TEXT_APPROVED = {
    "PracticeGeneratedContentService.java",
    "SceneTextCanonicalizer.java",
    "SceneTextForms.java",
    "SceneTextRiskSignals.java",
    "SceneTextSecurityPolicy.java",
    "PolicyTextMatcher.java",
    "EvidenceSanitizer.java",
    "SceneGeneratedContentValidator.java",
}
CURRENT_GENERATED_CONTENT_MIGRATION = "V27__upgrade_practice_generated_content_agentic_contract.sql"
GENERATED_AUDIO_JAVA_ROOT = "backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/audio"
GENERATED_AUDIO_PERSISTENCE_MARKERS = (
    "PracticeGeneratedContentCommands",
    "PracticeGeneratedContentCommandMapper",
    "insert(",
    "update(",
    "delete(",
    "java.io.File",
    "java.nio.file",
    "Minio",
    "ObjectStorage",
)


def files_under(root: Path, relative: str, suffixes: tuple[str, ...]) -> list[Path]:
    directory = root / relative
    if not directory.exists():
        return []
    return sorted(path for path in directory.rglob("*") if path.is_file() and path.suffix in suffixes)


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def snake_to_camel(value: str) -> str:
    head, *tail = value.split("_")
    return head + "".join(part.capitalize() for part in tail)


def custom_scene_java_paths(root: Path) -> list[Path]:
    """All production Java that can carry generated-content or discovery DTOs/indexes."""
    app_java_root = "backend/app-api/src/main/java"
    return [
        path
        for path in files_under(root, app_java_root, (".java",))
        if "practice" in path.parts or "PracticeGeneratedContent" in path.name
    ]


def find_forbidden_fields(paths: list[Path]) -> list[str]:
    failures: list[str] = []
    snake_pattern = re.compile(r"\b(" + "|".join(FORBIDDEN_FIELDS) + r")\b", re.IGNORECASE)
    java_camel_variants = [
        variant
        for field in FORBIDDEN_FIELDS
        if field not in {"security_text", "risk_signals"}
        for variant in (snake_to_camel(field),)
    ]
    java_pattern = re.compile(
        r"\b(" + "|".join((*FORBIDDEN_FIELDS, *java_camel_variants)) + r")\b",
        re.IGNORECASE,
    )
    for path in paths:
        pattern = java_pattern if path.suffix == ".java" else snake_pattern
        for line_number, line in enumerate(text(path).splitlines(), start=1):
            match = pattern.search(line)
            if match:
                failures.append(f"{path}:L{line_number}: forbidden persisted/audit field {match.group(1)}")
    return failures


def collect_violations(root: Path) -> list[str]:
    java_root = "backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice"
    mapper_root = "backend/app-api/src/main/resources/mapper/practice"
    migration = root / "backend/db-migration/src/main/resources/db/migration" / CURRENT_GENERATED_CONTENT_MIGRATION
    generated_mapper = root / "backend/app-api/src/main/resources/mapper/practice/generated"
    query_mapper = generated_mapper / "PracticeGeneratedContentQueryMapper.xml"
    command_mapper = generated_mapper / "internal/PracticeGeneratedContentCommandMapper.xml"
    options_factory = root / (java_root + "/agentic/PracticeAiOpenAiOptionsFactory.java")

    failures: list[str] = []
    java_paths = custom_scene_java_paths(root)
    production_paths = java_paths + files_under(root, mapper_root, (".xml",))
    if migration.exists():
        production_paths.append(migration)
    failures.extend(find_forbidden_fields(production_paths))

    generated_audio_paths = files_under(root, GENERATED_AUDIO_JAVA_ROOT, (".java",))
    for path in generated_audio_paths:
        source = text(path)
        for marker in GENERATED_AUDIO_PERSISTENCE_MARKERS:
            if marker in source:
                failures.append(f"{path}: generated audio must not persist through {marker}")

    for path in files_under(root, mapper_root, (".xml",)):
        if path.exists() and re.search(r"\bcoach_tip_zh\b", text(path), re.IGNORECASE):
            failures.append(f"{path}: coach_tip_zh must be composed at response time, never persisted")

    for path in java_paths:
        source = text(path)
        for field in ("securityText", "riskSignals"):
            if re.search(rf"\b{field}\b", source, re.IGNORECASE) and path.name not in SECURITY_TEXT_APPROVED:
                failures.append(f"{path}: {field} use outside approved input-security/fingerprint boundary")

    for path in java_paths:
        source = text(path)
        if ".validateSchema(" in source:
            failures.append(f"{path}: validateSchema creates an unapproved structured-output retry path")
        if "new OpenAiApi" in source:
            failures.append(f"{path}: direct OpenAiApi construction bypasses routed audit")
        for match in re.finditer(r"\.maxRetries\(([^)]*)\)", source):
            if match.group(1).strip() != "0":
                failures.append(f"{path}: custom-scene client retries must be hard-coded to maxRetries(0)")

    if options_factory.exists() and ".maxRetries(0)" not in text(options_factory):
        failures.append(f"{options_factory}: missing hard-coded maxRetries(0)")

    private_runtime_paths = [query_mapper, command_mapper]
    for path in private_runtime_paths:
        if path.exists() and re.search(r"\b(promoted|global_candidate)\b", text(path)):
            failures.append(f"{path}: private-generation scope must not contain promoted/global_candidate state")

    if migration.exists():
        migration_text = text(migration)
        for column in REQUIRED_RESPONSE_COLUMNS:
            if column not in migration_text:
                failures.append(f"{migration}: required generated response column missing: {column}")
        if "drop column coach_tip_zh" not in migration_text:
            failures.append(f"{migration}: current generated-content contract must remove coach_tip_zh")
        if "check (owner_scope in ('installation', 'account', 'profile'))" not in migration_text:
            failures.append(f"{migration}: current generated-content owner scope must exclude global_candidate")
        if "check (status in ('draft', 'generating', 'active', 'rejected', 'expired'))" not in migration_text:
            failures.append(f"{migration}: current generated-content status must exclude promoted")
    else:
        failures.append(f"missing current generated-content migration: {migration}")

    if query_mapper.exists():
        mapper_text = text(query_mapper)
        if "and owner_key_version = #{ownerKeyVersion}" not in mapper_text:
            failures.append(f"{query_mapper}: current-key lookup must bind owner_key_version")
        if "<select id=\"findInstallationCleanupCandidates\"" not in mapper_text or "owner_key_version = #{ownerKeyVersion}" not in mapper_text:
            failures.append(f"{query_mapper}: installation cleanup selection lost current-key boundary")
    else:
        failures.append(f"missing mapper: {query_mapper}")

    if command_mapper.exists():
        cleanup = re.search(r"<delete id=\"deleteExpiredInstallationRows\">([\s\S]*?)</delete>", text(command_mapper))
        if cleanup is None or "owner_key_version" in cleanup.group(1):
            failures.append(f"{command_mapper}: retention cleanup must remain cross-key-version")
    else:
        failures.append(f"missing mapper: {command_mapper}")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    failures = collect_violations(args.root.resolve())
    if failures:
        print("practice generation privacy verification failed:", file=sys.stderr)
        print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
        return 1
    print("practice generation privacy verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
