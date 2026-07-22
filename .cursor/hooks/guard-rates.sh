#!/usr/bin/env bash
# Block rate-card edits when no characterization test exists.
# Wired to:
#   preToolUse             — Write, StrReplace, Delete, Shell (see hooks.json)
#   beforeShellExecution   — every shell command (see hooks.json; no matcher)
# Exit 2 to deny per Cursor hook protocol.
#
# Detection logic lives in guard-rates.py (Node fallback mirrors it inline).
set -euo pipefail

input=$(cat)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  INPUT="$input" python3 "$SCRIPT_DIR/guard-rates.py"
  exit $?
fi

if command -v node >/dev/null 2>&1; then
  INPUT="$input" node <<'JS'
const fs = require("fs");

const data = JSON.parse(process.env.INPUT);
const event = data.hook_event_name || "";

const DENY = {
  permission: "deny",
  user_message:
    "Refusing to touch the rate card with no characterization test present. Run the test-writer subagent first.",
  agent_message: "[guard] Run the test-writer subagent first, then retry.",
};

const RATES_PATH =
  /(^|[\\/])legacy[\\/]rates(\.(js|ts))?$|(^|[\\/])rates\.(js|ts)$/i;

const RATE_SHELL_PATTERNS = [
  /legacy[\\/]rates(\.(js|ts))?/i,
  /dist[\\/]legacy[\\/]rates/i,
  /(^|[\s"'`\/])rates\.(js|ts)([\s"'`]|$)/i,
  /['"]rates['"]/i,
  /legacy[\\/]['"]?\s*\+/i,
  /\brequire\s*\([^)]*rates/i,
  /\bimport\s+[^;\n]*rates/i,
  /\bfrom\s+['"][^'"]*rates/i,
  />\s*\S*legacy[\\/]rates/i,
  /\btee\s+\S*legacy[\\/]rates/i,
  /\b(rateFor|baseRate|isPeak)\s*\(/i,
  /curl[^\n|;&]*\/bookings[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)/i,
  /curl[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)[^\n|;&]*\/bookings/i,
  /\bfetch\s*\([^\)]*\/bookings/i,
  /\bratePaid\b/i,
];

const CONCAT = /['"]([^'"]*)['"]\s*\+\s*['"]([^'"]*)['"]/g;

function hasRateTests() {
  const legacy = fs.existsSync("src/legacy")
    ? fs.readdirSync("src/legacy").some((f) => /rates.*\.test\./.test(f))
    : false;
  const testDir = fs.existsSync("test")
    ? fs.readdirSync("test").some((f) => /rates/.test(f))
    : false;
  return legacy || testDir;
}

function normalizeObfuscation(text) {
  let out = text;
  for (let i = 0; i < 16; i++) {
    const next = out.replace(CONCAT, (_, a, b) => a + b);
    if (next === out) break;
    out = next;
  }
  return out;
}

function targetsRatesPath(filePath) {
  if (!filePath) return false;
  return RATES_PATH.test(filePath.replace(/\\/g, "/"));
}

function targetsRatesShell(command) {
  if (!command) return false;
  const haystack = command + "\n" + normalizeObfuscation(command);
  return RATE_SHELL_PATTERNS.some((pattern) => pattern.test(haystack));
}

function shouldBlock(text, shell = false) {
  if (hasRateTests()) return false;
  return shell ? targetsRatesShell(text) : targetsRatesPath(text);
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
  if (shouldBlock(data.command || "", true)) deny();
  allow();
}

if (event === "preToolUse") {
  const tool = data.tool_name || "";
  const toolInput = data.tool_input || {};

  if (["Write", "StrReplace", "Delete"].includes(tool)) {
    if (shouldBlock(toolInput.path || "")) deny();
  } else if (tool === "Shell") {
    if (shouldBlock(toolInput.command || "", true)) deny();
  }

  allow();
}

allow();
JS
  exit $?
fi

echo '{"permission":"deny","user_message":"guard-rates.sh requires python3 or node.","agent_message":"[guard] Install python3 or node so the rate-card guard can run."}' >&2
exit 2
