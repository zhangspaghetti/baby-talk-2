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
                "Expected Spring AI 2.0.0" if name == "spring-ai.version" else f"Expected {name}={value}", errors)
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
