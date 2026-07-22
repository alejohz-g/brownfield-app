#!/usr/bin/env python3
"""Block rate-card edits and execution when no characterization test exists."""

from __future__ import annotations

import glob
import json
import os
import re
import sys

DENY = {
    "permission": "deny",
    "user_message": (
        "Refusing to touch the rate card with no characterization test present. "
        "Run the test-writer subagent first."
    ),
    "agent_message": "[guard] Run the test-writer subagent first, then retry.",
}

# Path targets: src/legacy/rates.{js,ts}, dist/legacy/rates, etc.
RATES_PATH = re.compile(
    r"(^|[\\/])legacy[\\/]rates(\.(js|ts))?$|(^|[\\/])rates\.(js|ts)$",
    re.IGNORECASE,
)

# Shell targets — applied to raw command plus de-obfuscated form.
RATE_SHELL_PATTERNS = (
    re.compile(r"legacy[\\/]rates(\.(js|ts))?", re.IGNORECASE),
    re.compile(r"dist[\\/]legacy[\\/]rates", re.IGNORECASE),
    re.compile(r"(^|[\s\"'`/])rates\.(js|ts)([\s\"'`]|$)", re.IGNORECASE),
    re.compile(r"['\"]rates['\"]", re.IGNORECASE),
    re.compile(r"legacy[\\/]['\"]?\s*\+", re.IGNORECASE),
    re.compile(r"\brequire\s*\([^)]*rates", re.IGNORECASE),
    re.compile(r"\bimport\s+[^;\n]*rates", re.IGNORECASE),
    re.compile(r"\bfrom\s+['\"][^'\"]*rates", re.IGNORECASE),
    re.compile(r">\s*\S*legacy[\\/]rates", re.IGNORECASE),
    re.compile(r"\btee\s+\S*legacy[\\/]rates", re.IGNORECASE),
    re.compile(r"\b(rateFor|baseRate|isPeak)\s*\(", re.IGNORECASE),
    re.compile(
        r"curl[^\n|;&]*\/bookings[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)",
        re.IGNORECASE,
    ),
    re.compile(
        r"curl[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)[^\n|;&]*\/bookings",
        re.IGNORECASE,
    ),
    re.compile(r"\bfetch\s*\([^\)]*\/bookings", re.IGNORECASE),
    re.compile(r"\bratePaid\b", re.IGNORECASE),
)

CONCAT = re.compile(r"""['"]([^'"]*)['"]\s*\+\s*['"]([^'"]*)['"]""")


def has_rate_tests() -> bool:
    patterns = (
        "src/legacy/*rates*.test.*",
        "src/legacy/**/*rates*.test.*",
        "test/*rates*",
    )
    return any(glob.glob(pattern) for pattern in patterns)


def normalize_obfuscation(text: str) -> str:
    out = text
    for _ in range(16):
        collapsed = CONCAT.sub(lambda m: m.group(1) + m.group(2), out)
        if collapsed == out:
            break
        out = collapsed
    return out


def targets_rates_path(path: str) -> bool:
    if not path:
        return False
    normalized = path.replace("\\", "/")
    return bool(RATES_PATH.search(normalized))


def targets_rates_shell(command: str) -> bool:
    if not command:
        return False
    haystack = command + "\n" + normalize_obfuscation(command)
    return any(pattern.search(haystack) for pattern in RATE_SHELL_PATTERNS)


def should_block(text: str, *, shell: bool = False) -> bool:
    if has_rate_tests():
        return False
    if shell:
        return targets_rates_shell(text)
    return targets_rates_path(text)


def deny() -> None:
    print(json.dumps(DENY))
    sys.exit(2)


def allow() -> None:
    print('{"permission":"allow"}')
    sys.exit(0)


def main() -> None:
    data = json.loads(os.environ["INPUT"])
    event = data.get("hook_event_name", "")

    if event == "beforeShellExecution":
        if should_block(data.get("command", ""), shell=True):
            deny()
        allow()

    if event == "preToolUse":
        tool = data.get("tool_name", "")
        tool_input = data.get("tool_input") or {}

        if tool in ("Write", "StrReplace", "Delete"):
            if should_block(tool_input.get("path", "")):
                deny()
        elif tool == "Shell":
            if should_block(tool_input.get("command", ""), shell=True):
                deny()

        allow()

    allow()


if __name__ == "__main__":
    main()
