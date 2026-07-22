#!/usr/bin/env python3
"""Block rate-card edits and execution when no characterization test exists."""

from __future__ import annotations

import glob
import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent

DENY = {
    "permission": "deny",
    "user_message": (
        "Rate-card change blocked: no characterization tests exist. "
        "Run the test-writer subagent first, then retry."
    ),
    "agent_message": (
        "[guard-rates] BLOCKED — characterization tests are required before any "
        "rate-card edit, delete, shell touch, or MCP file write. Run test-writer first."
    ),
}

# Path targets: src/legacy/rates.{js,ts}, dist/legacy/rates, wildcard legacy rates files.
RATES_PATH = re.compile(
    r"(^|[\\/])legacy[\\/][^\\/]*rates[^\\/]*(\.(js|ts))?$"
    r"|(^|[\\/])legacy[\\/]rates(\.(js|ts))?$"
    r"|(^|[\\/])dist[\\/]legacy[\\/]rates(\.(js|ts))?$"
    r"|(^|[\\/])rates\.(js|ts)$",
    re.IGNORECASE,
)

RATE_CONTENT = re.compile(
    r"(?:\bfunction\s+(?:rateFor|baseRate|isPeak)\b"
    r"|\b(?:const|let|var)\s+(?:rateFor|baseRate|isPeak)\s*="
    r"|\bBASE_RATES\b"
    r"|\bSURGE_MULTIPLIER\b"
    r"|\bVOLUME_DISCOUNT\b"
    r"|\bmodule\.exports\s*=\s*\{[^}]*\brateFor\b"
    r"|\bexport\s*\{[^}]*\brateFor\b)",
    re.IGNORECASE,
)

EDIT_TOOLS = frozenset(
    {
        "write",
        "strreplace",
        "delete",
        "applypatch",
        "editnotebook",
        "notebookedit",
    }
)

# Shell targets — applied to raw command plus de-obfuscated form.
RATE_SHELL_PATTERNS = (
    re.compile(r"legacy[\\/][^\\s\"'`|;&]*rates", re.IGNORECASE),
    re.compile(r"dist[\\/]legacy[\\/]rates", re.IGNORECASE),
    re.compile(r"(^|[\s\"'`/])rates\.(js|ts)([\s\"'`]|$)", re.IGNORECASE),
    re.compile(r"['\"]rates['\"]", re.IGNORECASE),
    re.compile(r"legacy[\\/]['\"]?\s*\+", re.IGNORECASE),
    re.compile(r"\brequire\s*\([^)]*rates", re.IGNORECASE),
    re.compile(r"\bimport\s+[^;\n]*rates", re.IGNORECASE),
    re.compile(r"\bfrom\s+['\"][^'\"]*rates", re.IGNORECASE),
    re.compile(r">\s*\S*legacy[\\/][^\\s\"'`|;&]*rates", re.IGNORECASE),
    re.compile(r"\btee\s+\S*legacy[\\/][^\\s\"'`|;&]*rates", re.IGNORECASE),
    re.compile(r"\b(rateFor|baseRate|isPeak)\s*\(", re.IGNORECASE),
    re.compile(
        r"\b(cp|mv|install|rsync|ln)\s+[^\n|;&]*rates",
        re.IGNORECASE,
    ),
    re.compile(
        r"\b(git\s+(checkout|restore|show|apply|cherry-pick|revert|switch))\b[^\n|;&]*rates",
        re.IGNORECASE,
    ),
    re.compile(r"\b(rm|unlink|sed\s+-i)\s+[^\n|;&]*rates", re.IGNORECASE),
    re.compile(r"\b(patch|diff)\b[^\n|;&]*rates", re.IGNORECASE),
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
    re.compile(r"\bnode\s+-[ep]\b[^\n|;&]*rates", re.IGNORECASE),
    re.compile(r"\bnpm\s+run\s+build[^\n|;&]*&&[^\n|;&]*rates", re.IGNORECASE),
)

MCP_WRITE_TOOL = re.compile(
    r"(push_files|create_or_update_file|delete_file|create_branch)",
    re.IGNORECASE,
)

CONCAT = re.compile(r"""['"]([^'"]*)['"]\s*\+\s*['"]([^'"]*)['"]""")


def _glob(pattern: str) -> list[str]:
    return glob.glob(str(REPO_ROOT / pattern), recursive=True)


def _is_valid_rate_test(path: str) -> bool:
    try:
        text = Path(path).read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return False
    if not text.strip():
        return False
    return bool(re.search(r"\b(rateFor|baseRate|isPeak)\b", text))


def has_rate_tests() -> bool:
    patterns = (
        "src/legacy/**/*rates*.test.*",
        "src/legacy/*rates*.test.*",
        "src/**/*rates*.test.*",
        "test/**/*rates*",
        "**/__tests__/**/*rates*",
    )
    for pattern in patterns:
        for path in _glob(pattern):
            if _is_valid_rate_test(path):
                return True
    return False


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


def targets_rates_content(text: str) -> bool:
    if not text:
        return False
    return bool(RATE_CONTENT.search(text))


def extract_edit_text(tool_input: dict) -> str:
    chunks: list[str] = []
    for key in (
        "contents",
        "content",
        "new_string",
        "old_string",
        "patch",
        "cell_content",
        "new_string",
    ):
        value = tool_input.get(key)
        if isinstance(value, str):
            chunks.append(value)
    return "\n".join(chunks)


def targets_rates_shell(command: str) -> bool:
    if not command:
        return False
    haystack = command + "\n" + normalize_obfuscation(command)
    return any(pattern.search(haystack) for pattern in RATE_SHELL_PATTERNS)


def targets_rates_mcp(data: dict) -> bool:
    tool_name = str(
        data.get("tool_name")
        or data.get("mcp_tool")
        or data.get("tool")
        or ""
    )
    if not MCP_WRITE_TOOL.search(tool_name):
        return False

    blob = json.dumps(
        data.get("tool_input")
        or data.get("arguments")
        or data.get("params")
        or data
    )
    if targets_rates_path(blob):
        return True
    return targets_rates_content(blob)


def is_guard_infra_path(path: str) -> bool:
    normalized = path.replace("\\", "/")
    return (
        "/.cursor/hooks/" in normalized
        or normalized.startswith(".cursor/hooks/")
        or normalized.endswith("/hooks.json")
        or normalized == ".cursor/hooks.json"
    )


def should_block_path_or_content(path: str, content: str) -> bool:
    if targets_rates_path(path):
        return True
    if is_guard_infra_path(path):
        return False
    if targets_rates_content(content):
        return True
    return False


def edit_target_path(tool_input: dict) -> str:
    for key in ("path", "file_path", "target_file", "target_notebook"):
        value = tool_input.get(key)
        if isinstance(value, str) and value:
            return value
    return ""


def should_block_edit(tool_name: str, tool_input: dict) -> bool:
    name = (tool_name or "").lower()
    if name not in EDIT_TOOLS and name != "shell":
        return False

    path = edit_target_path(tool_input)
    if is_guard_infra_path(path):
        return False

    content = extract_edit_text(tool_input)

    if name == "delete":
        return targets_rates_path(path)

    if name == "shell":
        return targets_rates_shell(str(tool_input.get("command") or ""))

    if should_block_path_or_content(path, content):
        return True

    # ApplyPatch paths live inside the patch body.
    patch = tool_input.get("patch")
    if isinstance(patch, str) and targets_rates_path(patch):
        return True

    return False


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

    if has_rate_tests():
        allow()

    if event == "beforeShellExecution":
        if should_block(data.get("command", ""), shell=True):
            deny()
        allow()

    if event == "beforeMCPExecution":
        if targets_rates_mcp(data):
            deny()
        allow()

    if event == "preToolUse":
        tool = data.get("tool_name", "")
        tool_input = data.get("tool_input") or {}

        if should_block_edit(tool, tool_input):
            deny()

        allow()

    allow()


if __name__ == "__main__":
    main()
