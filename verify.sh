#!/usr/bin/env bash
# Inspect a DeepSeek Harness session artifact and list its tool calls.
#
# Usage:
#   ./verify.sh                    # newest session artifact under $DSH_ARTIFACT_ROOT
#   ./verify.sh <dir|file>         # a session directory, or a session.v4.jsonl.zstd
#   DSH_ARTIFACT_ROOT=... ./verify.sh
#
# Exit codes:
#   0  a recall sequence (docs/memory then id=memory) was found
#   1  artifact found but no recall sequence
#   2  no artifact found or decoding failed

set -euo pipefail

ROOT="${DSH_ARTIFACT_ROOT:-$HOME/.dsh/sessions}"

target="${1:-}"
if [[ -z "$target" ]]; then
  artifact="$(find "$ROOT" -name 'session.v4.jsonl.zstd' -type f 2>/dev/null \
    | xargs -I{} stat -f '%m %N' {} 2>/dev/null \
    | sort -rn | head -1 | cut -d' ' -f2-)"
else
  if [[ -d "$target" ]]; then
    artifact="$(find "$target" -name 'session.v4.jsonl.zstd' -type f 2>/dev/null | head -1)"
  else
    artifact="$target"
  fi
fi

if [[ -z "${artifact:-}" || ! -f "$artifact" ]]; then
  echo "No session artifact found (root: $ROOT)" >&2
  exit 2
fi

echo "Artifact: $artifact"
echo

json="$(mktemp)"
trap 'rm -f "$json"' EXIT

# macOS commonly ships no zstd binary; Node's zlib has zstd support.
if ! node -e '
const fs = require("node:fs");
const zlib = require("node:zlib");
const src = process.argv[1];
const dst = process.argv[2];
const out = zlib.zstdDecompressSync(fs.readFileSync(src));
fs.writeFileSync(dst, out);
' "$artifact" "$json" 2>/dev/null; then
  echo "Failed to decode the artifact. Node 22+ with zlib zstd support is required." >&2
  exit 2
fi

node -e '
const fs = require("node:fs");
const lines = fs.readFileSync(process.argv[1], "utf8").split("\n");
const calls = [];
for (const line of lines) {
  if (!line.trim()) continue;
  let ev;
  try { ev = JSON.parse(line); } catch { continue; }
  if (ev.type === "tool/call") {
    calls.push({ name: ev.data.name, args: ev.data.arguments });
  }
}

if (calls.length === 0) {
  console.log("No tool calls in this session.");
  process.exit(1);
}

console.log(`Tool calls: ${calls.length}`);
calls.forEach((c, i) => {
  let args = c.args;
  try { args = JSON.stringify(JSON.parse(c.args)); } catch {}
  console.log(`  ${String(i + 1).padStart(2)}. ${c.name}`);
  if (args) console.log(`      ${String(args).slice(0, 180)}`);
});

const readDocs = calls.findIndex((c) => c.name === "read_mcp_resource");
const fetchMemory = calls.findIndex(
  (c) => c.name.includes("notion-fetch") && String(c.args).includes("\"memory\"")
);
const ok = readDocs !== -1 && fetchMemory !== -1 && readDocs < fetchMemory;

console.log();
console.log(ok ? "RESULT: recall sequence found" : "RESULT: recall sequence NOT found");
process.exit(ok ? 0 : 1);
' "$json"
