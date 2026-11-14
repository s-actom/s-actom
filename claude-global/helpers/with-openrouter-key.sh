#!/bin/bash
# with-openrouter-key.sh
#
# Injects OPENROUTER_API_KEY into ONE child process, read from the macOS
# login keychain at runtime. Created 2026-07-28 by the Claude Code
# containment task to replace the global export that used to live in
# ~/.claude/settings.json[env] (where every tool call and every subagent
# inherited it).
#
# Properties:
#   - contains no secret material
#   - never prints the secret
#   - never passes the secret as a process argument (argv is world-readable
#     via `ps`; that is exactly the GEMINI_API_KEY failure mode)
#   - does not export into the caller's shell: this is a separate process,
#     the variable dies with it
#   - FAILS CLOSED: no keychain item => non-zero exit, child never runs
#
# Proven consumer (why this variable is needed at all):
#   ~/repos/trust-harness/src/verifier-live.ts:222   process.env.OPENROUTER_API_KEY
#   ~/repos/trust-harness/src/copy-llm.ts:230        process.env.OPENROUTER_API_KEY
#   plus ~25 gated bench/ and test/ entry points in the same repo.
#
# One-time owner setup (run in YOUR OWN terminal, not inside Claude Code —
# `-w` as the LAST option prompts, so the value never reaches argv):
#
#     security add-generic-password -U \
#       -a "$USER" -s claude-openrouter-api-key \
#       -D "application password" \
#       -j "OpenRouter key for trust-harness live verifier" -w
#
# Usage:
#     ~/.claude/helpers/with-openrouter-key.sh npm run test:live
#     ~/.claude/helpers/with-openrouter-key.sh npx tsx bench/run-gold.ts

set -euo pipefail

KEYCHAIN_SERVICE="claude-openrouter-api-key"
KEYCHAIN_ACCOUNT="${USER:-$(id -un)}"

if [ "$#" -eq 0 ]; then
  echo "usage: $(basename "$0") <command> [args...]" >&2
  exit 64
fi

# Read from keychain. Any failure => fail closed.
if ! _secret="$(/usr/bin/security find-generic-password \
      -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w 2>/dev/null)"; then
  echo "FAIL-CLOSED: no keychain item '$KEYCHAIN_SERVICE' for account '$KEYCHAIN_ACCOUNT'." >&2
  echo "The child process was NOT started." >&2
  echo "Create it with (in your own terminal, -w LAST so it prompts):" >&2
  echo "  security add-generic-password -U -a \"\$USER\" -s $KEYCHAIN_SERVICE -w" >&2
  exit 78
fi

if [ -z "$_secret" ]; then
  echo "FAIL-CLOSED: keychain item '$KEYCHAIN_SERVICE' is empty. Child NOT started." >&2
  unset _secret
  exit 78
fi

# Export into THIS process only; exec replaces it with the child, which
# inherits the variable. The value never appears in argv, stdout or a file.
export OPENROUTER_API_KEY="$_secret"
unset _secret

exec "$@"
