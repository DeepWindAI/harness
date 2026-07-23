#!/usr/bin/env python3
"""Validate the release-contained DeepWind Codex custom-agent role pack."""

from __future__ import annotations

import argparse
import sys
import tomllib
from pathlib import Path


EXPECTED_ROLES = {
    "frontend-developer.toml",
    "harness-coordinator.toml",
    "harness-planner.toml",
    "security-auditor.toml",
}
REQUIRED_KEYS = {"name", "description", "developer_instructions", "sandbox_mode", "mcp_servers"}
ALLOWED_KEYS = REQUIRED_KEYS


def validate_role(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, tomllib.TOMLDecodeError) as exc:
        return [f"{path}: invalid TOML: {exc}"]

    missing = REQUIRED_KEYS - data.keys()
    unexpected = data.keys() - ALLOWED_KEYS
    if missing:
        errors.append(f"{path}: missing keys: {', '.join(sorted(missing))}")
    if unexpected:
        errors.append(f"{path}: unexpected keys: {', '.join(sorted(unexpected))}")

    expected_name = path.stem
    if data.get("name") != expected_name:
        errors.append(f"{path}: name must be {expected_name!r}")
    description = data.get("description")
    if not isinstance(description, str) or len(description.strip()) < 20:
        errors.append(f"{path}: description must be a non-empty explanatory string")
    instructions = data.get("developer_instructions")
    if not isinstance(instructions, str) or len(instructions.strip()) < 100:
        errors.append(f"{path}: developer_instructions must define the bounded role")
    if data.get("sandbox_mode") not in {"read-only", "workspace-write"}:
        errors.append(f"{path}: sandbox_mode must be read-only or workspace-write")
    if data.get("mcp_servers") != {}:
        errors.append(f"{path}: mcp_servers must be an explicit empty table")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("role_dir", type=Path)
    args = parser.parse_args()

    actual = {path.name for path in args.role_dir.glob("*.toml")}
    errors: list[str] = []
    if actual != EXPECTED_ROLES:
        errors.append(
            f"{args.role_dir}: expected roles {sorted(EXPECTED_ROLES)}, got {sorted(actual)}"
        )
    for path in sorted(args.role_dir.glob("*.toml")):
        errors.extend(validate_role(path))

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: validated {len(actual)} Codex custom-agent TOML roles")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
