#!/usr/bin/env python3
"""Create and verify immutable hashes for custom-scene AI resources."""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parent.parent
RESOURCE_ROOT = ROOT / "backend/app-api/src/main/resources/config/practice-ai"
PROFILE_ROOT = RESOURCE_ROOT / "profiles"
LOCK_PATH = RESOURCE_ROOT / "version-lock.yml"
HEALTH_SAFETY_POLICY_VERSION = "health-safety-v1"
HEALTH_SAFETY_POLICY_PATH = "config/practice-health-safety-v1.yml"
HEALTH_SAFETY_POLICY_FILE = (
    ROOT / "backend/app-api/src/main/resources" / HEALTH_SAFETY_POLICY_PATH
)
HEALTH_SAFETY_CLASSIFIER_PROMPT_VERSION = "custom-scene-safety-classifier-v1"
HEALTH_SAFETY_CLASSIFIER_PROMPT_PATH = (
    "config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt"
)
PROFILE_REFERENCE_KEYS = (
    "generator-prompt",
    "judge-prompt",
    "repair-prompt",
    "rubric",
    "evidence-policy",
    "baseline-evidence",
)


def fail(message: str) -> None:
    raise ValueError(message)


def load_yaml(path: Path) -> dict:
    if not path.is_file():
        fail(f"missing practice AI resource: {path}")
    value = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        fail(f"practice AI YAML must be a mapping: {path}")
    return value


def resource_hash(path: Path) -> str:
    if path.suffix == ".txt":
        content = path.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
        if content.endswith("\n"):
            content = content[:-1]
        payload = content.encode("utf-8")
    else:
        payload = json.dumps(
            load_yaml(path), ensure_ascii=False, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def required_string(mapping: dict, key: str, context: str) -> str:
    value = mapping.get(key)
    if not isinstance(value, str) or not value:
        fail(f"{context} requires {key}")
    return value


def required_mapping(mapping: dict, key: str, context: str) -> dict:
    value = mapping.get(key)
    if not isinstance(value, dict):
        fail(f"{context} requires {key}")
    return value


def health_safety_content_hash(health_safety: dict) -> str:
    """Match CustomSceneSafetyProperties.contentHash without self-referential lock field."""
    classifier_prompt = required_mapping(
        health_safety,
        "classifier-prompt",
        "health safety policy",
    )
    classifier_timeout = required_string(
        health_safety,
        "classifier-timeout",
        "health safety policy",
    ).strip()
    if classifier_timeout.endswith("s") and classifier_timeout[:-1]:
        classifier_timeout = f"PT{classifier_timeout[:-1]}S"
    canonical = [
        required_string(health_safety, "policy-version", "health safety policy").strip(),
        classifier_timeout,
        "|".join(
            (
                required_string(
                    classifier_prompt,
                    "version",
                    "health safety policy classifier-prompt",
                ).strip(),
                required_string(
                    classifier_prompt,
                    "resource-path",
                    "health safety policy classifier-prompt",
                ).strip(),
            )
        ),
    ]
    templates = required_mapping(health_safety, "templates", "health safety policy")
    for template_id in sorted(templates):
        template = required_mapping(
            templates,
            template_id,
            "health safety policy template",
        )
        canonical.append(
            "|".join(
                (
                    template_id,
                    required_string(template, "action", template_id).strip(),
                    required_string(template, "locale", template_id).strip(),
                    required_string(template, "title-zh", template_id).strip(),
                    required_string(template, "message-zh", template_id).strip(),
                )
            )
        )
    emergency_signals = required_mapping(
        health_safety,
        "emergency-signals",
        "health safety policy",
    )
    for signal_id in sorted(emergency_signals):
        markers = emergency_signals[signal_id]
        if not isinstance(markers, list) or any(not isinstance(marker, str) for marker in markers):
            fail(f"health safety policy emergency signal {signal_id} requires string markers")
        normalized_markers: list[str] = []
        for marker in markers:
            normalized_marker = marker.strip().lower()
            if normalized_marker not in normalized_markers:
                normalized_markers.append(normalized_marker)
        canonical.append(signal_id + "|" + "\x1f".join(normalized_markers))
    return hashlib.sha256(("\n".join(canonical) + "\n").encode("utf-8")).hexdigest()


def scanned_resources() -> list[dict]:
    resources_by_path: dict[str, dict] = {}

    def add_resource(
        version: str,
        resource_path: str,
        resolved: Path,
        content_hash: str | None = None,
    ) -> None:
        entry = {
            "version": version,
            "resource-path": resource_path,
            "content-hash": content_hash or resource_hash(resolved),
        }
        existing = resources_by_path.get(resource_path)
        if existing is not None and existing != entry:
            fail(f"resource path resolves inconsistently: {resource_path}")
        resources_by_path[resource_path] = entry

    profile_paths = sorted(PROFILE_ROOT.glob("custom-scene-generation-v*.yml"))
    if not profile_paths:
        fail("missing custom-scene generation profiles")
    for profile_path in profile_paths:
        profile = load_yaml(profile_path)
        add_resource(
            required_string(profile, "version", "profile"),
            "config/practice-ai/" + profile_path.relative_to(RESOURCE_ROOT).as_posix(),
            profile_path,
        )
        for key in PROFILE_REFERENCE_KEYS:
            reference = profile.get(key)
            if not isinstance(reference, dict):
                fail(f"profile requires {key}")
            version = required_string(reference, "version", f"profile {key}")
            resource_path = required_string(reference, "resource-path", f"profile {key}")
            resolved = RESOURCE_ROOT / resource_path.removeprefix("config/practice-ai/")
            document = load_yaml(resolved) if resolved.suffix == ".yml" else None
            if document is not None and required_string(document, "version", resource_path) != version:
                fail(f"version mismatch for {key}")
            if resolved.suffix == ".txt" and resolved.stem != version:
                fail(f"version mismatch for {key}")
            add_resource(version, resource_path, resolved)

    health_policy = load_yaml(HEALTH_SAFETY_POLICY_FILE)
    health_practice = required_mapping(
        required_mapping(health_policy, "babytalk", "health safety policy"),
        "practice",
        "health safety policy",
    )
    health_safety = required_mapping(
        health_practice,
        "health-safety",
        "health safety policy",
    )
    policy_version = required_string(
        health_safety,
        "policy-version",
        "health safety policy",
    )
    if policy_version != HEALTH_SAFETY_POLICY_VERSION:
        fail("health safety policy version mismatch")
    add_resource(
        policy_version,
        HEALTH_SAFETY_POLICY_PATH,
        HEALTH_SAFETY_POLICY_FILE,
        health_safety_content_hash(health_safety),
    )

    classifier_prompt = required_mapping(
        health_safety,
        "classifier-prompt",
        "health safety policy",
    )
    classifier_version = required_string(
        classifier_prompt,
        "version",
        "health safety policy classifier-prompt",
    )
    classifier_path = required_string(
        classifier_prompt,
        "resource-path",
        "health safety policy classifier-prompt",
    )
    if (
        classifier_version != HEALTH_SAFETY_CLASSIFIER_PROMPT_VERSION
        or classifier_path != HEALTH_SAFETY_CLASSIFIER_PROMPT_PATH
    ):
        fail("version mismatch for classifier-prompt")
    classifier_resource = RESOURCE_ROOT / classifier_path.removeprefix("config/practice-ai/")
    if classifier_resource.stem != classifier_version:
        fail("version mismatch for classifier-prompt")
    add_resource(classifier_version, classifier_path, classifier_resource)

    resources = list(resources_by_path.values())
    resources.sort(key=lambda item: (item["version"], item["resource-path"]))
    hashes_by_version: dict[str, set[str]] = {}
    for resource in resources:
        hashes_by_version.setdefault(resource["version"], set()).add(resource["content-hash"])
    duplicates = [version for version, hashes in hashes_by_version.items() if len(hashes) > 1]
    if duplicates:
        fail(f"one version points to multiple hashes: {', '.join(sorted(duplicates))}")
    return resources


def load_lock(path: Path) -> list[dict]:
    lock = load_yaml(path)
    if lock.get("schema-version") != "practice-ai-version-lock-schema-v1":
        fail("invalid practice AI version lock schema")
    resources = lock.get("resources")
    if not isinstance(resources, list):
        fail("invalid practice AI version lock resources")
    required_keys = {"version", "resource-path", "content-hash"}
    if any(not isinstance(item, dict) or set(item) != required_keys for item in resources):
        fail("invalid practice AI version lock entry")
    return resources


def compare_base_lock(base_lock: Path, current: list[dict]) -> None:
    base_entries = load_lock(base_lock)
    current_by_version = {entry["version"]: entry for entry in current}
    for entry in base_entries:
        version = entry["version"]
        if version not in current_by_version:
            fail(f"existing version disappeared: {version}")
        current_entry = current_by_version[version]
        if current_entry["resource-path"] != entry["resource-path"]:
            fail(f"existing version path changed: {version}")
        if current_entry["content-hash"] != entry["content-hash"]:
            fail(f"existing version hash changed: {version}")


def main() -> int:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true")
    mode.add_argument("--verify", action="store_true")
    parser.add_argument("--base-lock", type=Path)
    args = parser.parse_args()

    try:
        resources = scanned_resources()
        if args.write:
            LOCK_PATH.write_text(yaml.safe_dump({
                "schema-version": "practice-ai-version-lock-schema-v1",
                "resources": resources,
            }, allow_unicode=True, sort_keys=False), encoding="utf-8")
            print(f"updated practice AI version lock: {len(resources)} resources")
            return 0

        locked = load_lock(LOCK_PATH)
        if locked != resources:
            fail("practice AI version lock differs from versioned resources")
        if args.base_lock:
            compare_base_lock(args.base_lock, resources)
        print(f"practice AI version lock verified: {len(resources)} resources")
        return 0
    except (OSError, ValueError, yaml.YAMLError) as exception:
        print(f"practice AI version lock verification failed: {exception}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
