#!/usr/bin/env python3
"""Privacy-safe Android verifier for #55 generated Today projection."""

from __future__ import annotations

import argparse
import json
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SEED_CONTENT = PROJECT_ROOT / "mobile" / "assets" / "content" / "seed_content.json"
GENERATED_STORE = "files/generated_care_moments.json"
UI_DUMP = "/sdcard/babytalk_issue55_ui.xml"


def adb(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", *args],
        check=check,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def _visible_values(xml_text: str) -> set[str]:
    root = ET.fromstring(xml_text)
    values: set[str] = set()
    for node in root.iter("node"):
        for attribute in ("text", "content-desc"):
            value = (node.attrib.get(attribute) or "").strip()
            if value:
                values.add(value)
    return values


def _generated_markers(store: object) -> tuple[list[str], list[str], int]:
    if not isinstance(store, dict):
        return [], [], 0
    records = store.get("records")
    if not isinstance(records, list):
        return [], [], 0
    starters: list[str] = []
    supports: list[str] = []
    for record in records:
        if not isinstance(record, dict):
            continue
        starter = record.get("starter")
        if isinstance(starter, dict):
            starters.extend(_display_values(starter))
        reaction_supports = record.get("reactionSupports")
        if isinstance(reaction_supports, dict):
            for support in reaction_supports.values():
                if isinstance(support, dict):
                    supports.extend(_display_values(support))
    return starters, supports, len(records)


def _display_values(utterance: dict[str, object]) -> list[str]:
    return [
        value.strip()
        for key in ("english", "chinese")
        if isinstance((value := utterance.get(key)), str) and value.strip()
    ]


def _seed_bath_markers() -> list[str]:
    payload = json.loads(SEED_CONTENT.read_text(encoding="utf-8"))
    for space in payload.get("spaces", []):
        for activity in space.get("activities", []):
            if activity.get("id") != "bath_time":
                continue
            values = [activity.get("title")]
            for phrase in activity.get("phrases", []):
                values.extend((phrase.get("english"), phrase.get("chinese")))
            return [value.strip() for value in values if isinstance(value, str) and value.strip()]
    return []


def _today_selected(xml_text: str) -> bool:
    root = ET.fromstring(xml_text)
    for node in root.iter("node"):
        label = " ".join(
            part
            for part in (
                (node.attrib.get("text") or "").strip(),
                (node.attrib.get("content-desc") or "").strip(),
            )
            if part
        )
        if "今天" in label and node.attrib.get("selected") == "true":
            return True
    return False


def _normalized(value: str) -> str:
    return "".join(value.split()).casefold()


def _marker_visible(markers: list[str], visible_values: set[str]) -> bool:
    normalized_visible = [_normalized(value) for value in visible_values]
    return any(
        (candidate := _normalized(marker))
        and any(candidate in value for value in normalized_visible)
        for marker in markers
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--package", default="com.babytalk.mobile")
    parser.add_argument("--activity", default=".MainActivity")
    parser.add_argument("--wait-seconds", type=float, default=15.0)
    parser.add_argument(
        "--skip-restart",
        action="store_true",
        help="Inspect the current foreground state without force-stop/start.",
    )
    args = parser.parse_args()

    adb("wait-for-device")
    if not args.skip_restart:
        adb("shell", "am", "force-stop", args.package)
        adb("shell", "am", "start", "-W", "-n", f"{args.package}/{args.activity}")
    time.sleep(max(0.0, args.wait_seconds))
    adb("shell", "uiautomator", "dump", "--compressed", UI_DUMP)
    ui_xml = adb("exec-out", "cat", UI_DUMP).stdout
    adb("shell", "rm", "-f", UI_DUMP, check=False)

    store_result = adb(
        "shell",
        "run-as",
        args.package,
        "cat",
        GENERATED_STORE,
        check=False,
    )
    try:
        store = json.loads(store_result.stdout) if store_result.returncode == 0 else None
    except json.JSONDecodeError:
        store = None

    visible = _visible_values(ui_xml)
    starters, supports, record_count = _generated_markers(store)
    seed_bath_markers = _seed_bath_markers()
    generated_starter_visible = _marker_visible(starters, visible)
    generated_support_visible = _marker_visible(supports, visible)
    seed_bath_visible = _marker_visible(seed_bath_markers, visible)
    today_selected = _today_selected(ui_xml)
    passed = generated_support_visible and not seed_bath_visible and today_selected

    print(f"device_ready={True}")
    print(f"generated_store_readable={store is not None}")
    print(f"generated_record_count={record_count}")
    print(f"generated_starter_visible={generated_starter_visible}")
    print(f"generated_support_visible={generated_support_visible}")
    print(f"seed_bath_visible={seed_bath_visible}")
    print(f"today_selected={today_selected}")
    print(f"verdict={'PASS' if passed else 'FAIL'}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
