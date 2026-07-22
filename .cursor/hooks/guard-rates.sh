#!/usr/bin/env bash
# Block rate-card edits when no characterization test exists.
# Wired to preToolUse (all tools), beforeShellExecution, beforeMCPExecution.
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
  INPUT="$input" SCRIPT_DIR="$SCRIPT_DIR" node <<'JS'
const fs = require("fs");
const path = require("path");

const data = JSON.parse(process.env.INPUT);
const event = data.hook_event_name || "";
const scriptDir = process.env.SCRIPT_DIR || ".";
const repoRoot = path.resolve(scriptDir, "..", "..");

const DENY = {
  permission: "deny",
  user_message:
    "Rate-card change blocked: no characterization tests exist. Run the test-writer subagent first, then retry.",
  agent_message:
    "[guard-rates] BLOCKED — characterization tests are required before any rate-card edit, delete, shell touch, or MCP file write. Run test-writer first.",
};

const RATES_PATH =
  /(^|[\\/])legacy[\\/][^\\/]*rates[^\\/]*(\.(js|ts))?$|(^|[\\/])legacy[\\/]rates(\.(js|ts))?$|(^|[\\/])dist[\\/]legacy[\\/]rates(\.(js|ts))?$|(^|[\\/])rates\.(js|ts)$/i;

const RATE_CONTENT =
  /(?:\bfunction\s+(?:rateFor|baseRate|isPeak)\b|\b(?:const|let|var)\s+(?:rateFor|baseRate|isPeak)\s*=|\bBASE_RATES\b|\bSURGE_MULTIPLIER\b|\bVOLUME_DISCOUNT\b|\bmodule\.exports\s*=\s*\{[^}]*\brateFor\b|\bexport\s*\{[^}]*\brateFor\b)/i;

const EDIT_TOOLS = new Set([
  "write",
  "strreplace",
  "delete",
  "applypatch",
  "editnotebook",
  "notebookedit",
]);

const RATE_SHELL_PATTERNS = [
  /legacy[\\/][^\s"'`|;&]*rates/i,
  /dist[\\/]legacy[\\/]rates/i,
  /(^|[\s"'`\/])rates\.(js|ts)([\s"'`]|$)/i,
  /['"]rates['"]/i,
  /legacy[\\/]['"]?\s*\+/i,
  /\brequire\s*\([^)]*rates/i,
  /\bimport\s+[^;\n]*rates/i,
  /\bfrom\s+['"][^'"]*rates/i,
  />\s*\S*legacy[\\/][^\s"'`|;&]*rates/i,
  /\btee\s+\S*legacy[\\/][^\s"'`|;&]*rates/i,
  /\b(rateFor|baseRate|isPeak)\s*\(/i,
  /\b(cp|mv|install|rsync|ln)\s+[^\n|;&]*rates/i,
  /\b(git\s+(checkout|restore|show|apply|cherry-pick|revert|switch))\b[^\n|;&]*rates/i,
  /\b(rm|unlink|sed\s+-i)\s+[^\n|;&]*rates/i,
  /\b(patch|diff)\b[^\n|;&]*rates/i,
  /curl[^\n|;&]*\/bookings[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)/i,
  /curl[^\n|;&]*(-d\b|--data\b|--json\b|-X\s+POST|--request\s+POST)[^\n|;&]*\/bookings/i,
  /\bfetch\s*\([^\)]*\/bookings/i,
  /\bratePaid\b/i,
  /\bnode\s+-[ep]\b[^\n|;&]*rates/i,
  /\bnpm\s+run\s+build[^\n|;&]*&&[^\n|;&]*rates/i,
];

const MCP_WRITE_TOOL = /(push_files|create_or_update_file|delete_file|create_branch)/i;
const CONCAT = /['"]([^'"]*)['"]\s*\+\s*['"]([^'"]*)['"]/g;

function walk(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, acc);
    else acc.push(full);
  }
  return acc;
}

function isValidRateTest(filePath) {
  try {
    const text = fs.readFileSync(filePath, "utf8");
    return text.trim() && /\b(rateFor|baseRate|isPeak)\b/.test(text);
  } catch {
    return false;
  }
}

function hasRateTests() {
  const roots = [
    path.join(repoRoot, "src", "legacy"),
    path.join(repoRoot, "src"),
    path.join(repoRoot, "test"),
  ];
  for (const root of roots) {
    for (const file of walk(root)) {
      if (/rates.*\.test\./i.test(file) || /[/\\]test[/\\][^/\\]*rates/i.test(file)) {
        if (isValidRateTest(file)) return true;
      }
    }
  }
  return false;
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

function targetsRatesContent(text) {
  if (!text) return false;
  return RATE_CONTENT.test(text);
}

function extractEditText(toolInput) {
  const keys = ["contents", "content", "new_string", "old_string", "patch", "cell_content"];
  return keys
    .map((key) => toolInput[key])
    .filter((value) => typeof value === "string")
    .join("\n");
}

function targetsRatesShell(command) {
  if (!command) return false;
  const haystack = command + "\n" + normalizeObfuscation(command);
  return RATE_SHELL_PATTERNS.some((pattern) => pattern.test(haystack));
}

function targetsRatesMcp(payload) {
  const toolName = String(payload.tool_name || payload.mcp_tool || payload.tool || "");
  if (!MCP_WRITE_TOOL.test(toolName)) return false;
  const blob = JSON.stringify(
    payload.tool_input || payload.arguments || payload.params || payload
  );
  return targetsRatesPath(blob) || targetsRatesContent(blob);
}

function isGuardInfraPath(filePath) {
  const normalized = filePath.replace(/\\/g, "/");
  return (
    normalized.includes("/.cursor/hooks/") ||
    normalized.startsWith(".cursor/hooks/") ||
    normalized.endsWith("/hooks.json") ||
    normalized === ".cursor/hooks.json"
  );
}

function shouldBlockPathOrContent(filePath, content) {
  if (targetsRatesPath(filePath)) return true;
  if (targetsRatesContent(content)) return true;
  return false;
}

function shouldBlockEdit(toolName, toolInput) {
  const name = (toolName || "").toLowerCase();
  if (!EDIT_TOOLS.has(name) && name !== "shell") return false;

  const filePath = String(
    toolInput.path || toolInput.file_path || toolInput.target_file || toolInput.target_notebook || ""
  );
  if (isGuardInfraPath(filePath)) return false;

  const content = extractEditText(toolInput);

  if (name === "delete") return targetsRatesPath(filePath);
  if (name === "shell") return targetsRatesShell(String(toolInput.command || ""));

  if (shouldBlockPathOrContent(filePath, content)) return true;
  if (typeof toolInput.patch === "string" && targetsRatesPath(toolInput.patch)) return true;
  return false;
}

function deny() {
  console.log(JSON.stringify(DENY));
  process.exit(2);
}

function allow() {
  console.log('{"permission":"allow"}');
  process.exit(0);
}

if (hasRateTests()) allow();

if (event === "beforeShellExecution") {
  if (targetsRatesShell(data.command || "")) deny();
  allow();
}

if (event === "beforeMCPExecution") {
  if (targetsRatesMcp(data)) deny();
  allow();
}

if (event === "preToolUse") {
  const tool = data.tool_name || "";
  const toolInput = data.tool_input || {};
  if (shouldBlockEdit(tool, toolInput)) deny();
  allow();
}

allow();
JS
  exit $?
fi

echo '{"permission":"deny","user_message":"guard-rates.sh requires python3 or node.","agent_message":"[guard] Install python3 or node so the rate-card guard can run."}' >&2
exit 2
