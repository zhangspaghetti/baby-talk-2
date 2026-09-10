#!/usr/bin/env python3
"""Generate a stable HMAC key for Practice discovery owner identifiers."""

from __future__ import annotations

import argparse
import base64
import secrets


ENVIRONMENT_VARIABLE = "BABY_TALK_PRACTICE_DISCOVERY_OWNER_KEY_SECRET"
MINIMUM_BYTES = 32


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a random Practice discovery owner-key secret. "
            "Store the output only in an ignored secret overlay."
        )
    )
    parser.add_argument(
        "--bytes",
        type=int,
        default=MINIMUM_BYTES,
        help=f"random byte length (minimum: {MINIMUM_BYTES}; default: %(default)s)",
    )
    parser.add_argument(
        "--format",
        choices=("hex", "base64"),
        default="hex",
        help="output encoding (default: %(default)s)",
    )
    parser.add_argument(
        "--yaml",
        action="store_true",
        help="print an ignored Helm values snippet instead of the value alone",
    )
    return parser.parse_args()


def generate_secret(byte_length: int, output_format: str) -> str:
    if byte_length < MINIMUM_BYTES:
        raise ValueError(f"--bytes must be at least {MINIMUM_BYTES}")

    value = secrets.token_bytes(byte_length)
    if output_format == "hex":
        return value.hex()
    return base64.b64encode(value).decode("ascii")


def main() -> int:
    arguments = parse_arguments()
    try:
        value = generate_secret(arguments.bytes, arguments.format)
    except ValueError as error:
        raise SystemExit(str(error)) from error

    if arguments.yaml:
        print("secret:")
        print(f"  {ENVIRONMENT_VARIABLE}: {value}")
    else:
        print(value)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
