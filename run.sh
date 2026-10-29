#!/usr/bin/env bash
# Runs protocolprobe-selftest for the ProtocolProbe self-test GitHub Action. Every input arrives as an environment
# variable (see action.yml) and is validated here; nothing is passed through eval or a shell string.
set -uo pipefail

# messages may contain input values: encode % and drop CR/LF so a value cannot start a new workflow command
fail() {
  local m="${1//%/%25}"
  m="${m//$'\r'/}"
  m="${m//$'\n'/ }"
  echo "::error title=ProtocolProbe self-test::$m"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then printf 'exit-code=2\nsarif-file=\n' >> "$GITHUB_OUTPUT"; fi
  exit 2
}
bool() { case "$1" in true|false) ;; *) fail "$2 must be true or false, got '$1'";; esac; }

: "${PP_COMMAND:=}" "${PP_VERSION:=0.5.0}" "${PP_FAIL_ON_FINDING:=true}" "${PP_SARIF:=}" "${PP_SARIF_ANCHOR:=}"
: "${PP_OUT:=}" "${PP_ALLOW_MUTATING:=false}" "${PP_ALLOW_FUZZING:=false}"

# exact version only (no ranges, tags or URLs), so a run always uses the version the workflow names
[[ "$PP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must be an exact x.y.z version, got '$PP_VERSION'"
bool "$PP_FAIL_ON_FINDING" fail-on-finding
bool "$PP_ALLOW_MUTATING" allow-mutating
bool "$PP_ALLOW_FUZZING" allow-fuzzing
[[ "$PP_COMMAND" == *$'\n'* ]] && fail "command must be one line"
read -r -a SERVER <<< "$PP_COMMAND"
[[ ${#SERVER[@]} -gt 0 ]] || fail "command is empty: give the command line that starts your MCP server over stdio"

command -v node >/dev/null || fail "node is not on PATH (add actions/setup-node before this step)"
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$NODE_MAJOR" -ge 18 ]] || fail "Node 18 or later is needed, found $(node --version)"

# --i-own-this-server: using this action on a server your workflow starts from your own repository is that statement.
ARGS=(--i-own-this-server)
[[ "$PP_FAIL_ON_FINDING" == true ]] && ARGS+=(--fail-on-finding)
[[ -n "$PP_SARIF" ]] && ARGS+=(--sarif "$PP_SARIF")
[[ -n "$PP_SARIF_ANCHOR" ]] && ARGS+=(--sarif-anchor "$PP_SARIF_ANCHOR")
[[ -n "$PP_OUT" ]] && ARGS+=(--out "$PP_OUT")
[[ "$PP_ALLOW_MUTATING" == true ]] && ARGS+=(--allow-mutating)
[[ "$PP_ALLOW_FUZZING" == true ]] && ARGS+=(--allow-fuzzing)
ARGS+=(--stdio "${SERVER[@]}")

echo "protocolprobe-selftest@$PP_VERSION ${ARGS[*]}"
npx --yes "protocolprobe-selftest@$PP_VERSION" "${ARGS[@]}"
CODE=$?

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "exit-code=$CODE" >> "$GITHUB_OUTPUT"
  if [[ -n "$PP_SARIF" && -f "$PP_SARIF" ]]; then echo "sarif-file=$PP_SARIF" >> "$GITHUB_OUTPUT"; else echo "sarif-file=" >> "$GITHUB_OUTPUT"; fi
fi
[[ $CODE -eq 5 ]] && echo "::warning title=ProtocolProbe self-test::at least one check needs attention (see the output above or the SARIF file)"
exit $CODE
