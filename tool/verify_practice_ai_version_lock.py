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
PROFILE_PATH = RESOURCE_ROOT / "profiles/custom-scene-generation-v2.yml"
LOCK_PATH = RESOURCE_ROOT / "version-lock.yml"
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


def scanned_resources() -> list[dict]:
    profile = load_yaml(PROFILE_PATH)
    resources = [{
        "version": required_string(profile, "version", "profile"),
        "resource-path": "config/practice-ai/" + PROFILE_PATH.relative_to(RESOURCE_ROOT).as_posix(),
        "content-hash": resource_hash(PROFILE_PATH),
    }]
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
        resources.append({
            "version": version,
            "resource-path": resource_path,
            "content-hash": resource_hash(resolved),
        })
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
    current_by_version = {entry["version"]: entry["content-hash"] for entry in current}
    for entry in base_entries:
        version = entry["version"]
        if version in current_by_version and current_by_version[version] != entry["content-hash"]:
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
