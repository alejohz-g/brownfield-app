#!/usr/bin/env bash
# Block rate-card edits when no characterization test exists.
# Wired to:
#   preToolUse             — Write, StrReplace, Delete, Shell (see hooks.json matcher)
#   beforeShellExecution   — shell commands mentioning the rate card (see hooks.json matcher)
# Exit 2 to deny per Cursor hook protocol.
#
# Two layers on purpose:
#   hooks.json matcher — cheap Cursor-side filter; avoids spawning this script on every event.
#   RATES_TARGET below — authoritative allow/deny logic; must stay aligned with those matchers.
set -euo pipefail

input=$(cat)

parse_and_decide() {
  if command -v python3 >/dev/null 2>&1; then
    INPUT="$input" python3 <<'PY'
import glob
import json
import os
import re
import sys

data = json.loads(os.environ["INPUT"])
event = data.get("hook_event_name", "")

# legacy/rates, legacy/rates.js|ts, dist/legacy/rates, rates.js|ts in commands/paths.
RATES_TARGET = re.compile(
    r"legacy[/\\]rates(?:\.(?:js|ts))?(?:[^a-zA-Z]|$)"
    r"|(?:^|[\s\"'`/])rates\.(?:js|ts)(?:[\s\"'`]|$)"
)

DENY = {
    "permission": "deny",
    "user_message": (
        "Refusing to touch the rate card with no characterization test present. "
        "Run the test-writer subagent first."
    ),
    "agent_message": "[guard] Run the test-writer subagent first, then retry.",
}


def has_rate_tests() -> bool:
    return bool(
        glob.glob("src/legacy/*rates*.test.*") or glob.glob("test/*rates*")
    )


def targets_rates(text: str) -> bool:
    return bool(text and RATES_TARGET.search(text))


def should_block(text: str) -> bool:
    return targets_rates(text) and not has_rate_tests()


def deny() -> None:
    print(json.dumps(DENY))
    sys.exit(2)


def allow() -> None:
    print('{"permission":"allow"}')
    sys.exit(0)


if event == "beforeShellExecution":
    if should_block(data.get("command", "")):
        deny()
    allow()

if event == "preToolUse":
    tool = data.get("tool_name", "")
    tool_input = data.get("tool_input") or {}

    if tool in ("Write", "StrReplace", "Delete"):
        if should_block(tool_input.get("path", "")):
            deny()
    elif tool == "Shell":
        if should_block(tool_input.get("command", "")):
            deny()

    allow()

allow()
PY
    return
  fi

  if command -v node >/dev/null 2>&1; then
    INPUT="$input" node <<'JS'
const data = JSON.parse(process.env.INPUT);
const event = data.hook_event_name || "";
const ratesTarget =
  /legacy[/\\]rates(?:\.(?:js|ts))?(?:[^a-zA-Z]|$)|(?:^|[\s"'`\/])rates\.(?:js|ts)(?:[\s"'`]|$)/;

const DENY = {
  permission: "deny",
  user_message:
    "Refusing to touch the rate card with no characterization test present. Run the test-writer subagent first.",
  agent_message: "[guard] Run the test-writer subagent first, then retry.",
};

function hasRateTests() {
  const fs = require("fs");
  const legacy = fs.existsSync("src/legacy")
    ? fs.readdirSync("src/legacy").some((f) => /rates.*\.test\./.test(f))
    : false;
  const testDir = fs.existsSync("test")
    ? fs.readdirSync("test").some((f) => /rates/.test(f))
    : false;
  return legacy || testDir;
}

function targetsRates(text) {
  return Boolean(text && ratesTarget.test(text));
}

function shouldBlock(text) {
  return targetsRates(text) && !hasRateTests();
}

function deny() {
  console.log(JSON.stringify(DENY));
  process.exit(2);
}

function allow() {
  console.log('{"permission":"allow"}');
  process.exit(0);
}

if (event === "beforeShellExecution") {
  if (shouldBlock(data.command || "")) deny();
  allow();
}

if (event === "preToolUse") {
  const tool = data.tool_name || "";
  const toolInput = data.tool_input || {};

  if (["Write", "StrReplace", "Delete"].includes(tool)) {
    if (shouldBlock(toolInput.path || "")) deny();
  } else if (tool === "Shell") {
    if (shouldBlock(toolInput.command || "")) deny();
  }

  allow();
}

allow();
JS
    return
  fi

  echo '{"permission":"deny","user_message":"guard-rates.sh requires python3 or node.","agent_message":"[guard] Install python3 or node so the rate-card guard can run."}' >&2
  exit 2
}

parse_and_decide
