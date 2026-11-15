#!/usr/bin/env bash
# coderabbit-stop-gate.sh — hook Stop: lembra a review CodeRabbit, uma vez por diff.
# Dispara só se o turno atual (thread principal ou subagentes) editou código num repo git com
# Edit/Write/MultiEdit/NotebookEdit e não correu coderabbit-review.sh nesse turno.
# Nunca corre a review; não repete (stop_hook_active + marca por sessão/diff); falha sempre aberto.
set -o pipefail
command -v jq >/dev/null 2>&1 || exit 0

IN=$(cat)
[ "$(printf '%s' "$IN" | jq -r '.stop_hook_active // false' 2>/dev/null)" = true ] && exit 0
CWD=$(printf '%s' "$IN" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$IN" | jq -r '.transcript_path // empty' 2>/dev/null)
SID=$(printf '%s' "$IN" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$CWD" ] && [ -f "$TRANSCRIPT" ] || exit 0
cd "$CWD" 2>/dev/null || exit 0
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
git rev-parse --verify -q HEAD >/dev/null || exit 0
PREFIX=$(git rev-parse --show-prefix 2>/dev/null)
LROOT=${PWD%/"${PREFIX%/}"}   # raiz com o caminho lógico (symlinks) usado pelas tools

TRANSCRIPTS=("$TRANSCRIPT")
for f in "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do [ -f "$f" ] && TRANSCRIPTS+=("$f"); done

EVENTS=$(jq -r --arg r1 "$ROOT/" --arg r2 "$LROOT/" '
  select(.type == "assistant") | .timestamp as $t | .message.content[]? | select(.type == "tool_use")
  | if (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$")) then
      (.input.file_path // .input.notebook_path // "") as $p
      | if ($p | startswith($r1) or startswith($r2)) then "E\t\($t)\t\($p)" else empty end
    elif .name == "Bash" and ((.input.command // "") | test("coderabbit-review\\.sh")) then "R\t\($t)\t-"
    else empty end' "${TRANSCRIPTS[@]}" 2>/dev/null)

DOCS_RE='\.(md|mdx|txt|rst|adoc|png|jpe?g|gif|webp|svg|ico|pdf|mp4|mov|mp3|wav|lock)$|/(LICENSE|CHANGELOG)[^/]*$'
LAST_EDIT=$(printf '%s\n' "$EVENTS" | awk -F'\t' '$1 == "E" { print $2 "\t" $3 }' | grep -vE "$DOCS_RE" | cut -f1 | sort | tail -1)
[ -n "$LAST_EDIT" ] || exit 0
LAST_REVIEW=$(printf '%s\n' "$EVENTS" | awk -F'\t' '$1 == "R" { print $2 }' | sort | tail -1)
# Início do turno = último prompt real do utilizador (exclui tool_result e mensagens meta de hooks).
LAST_PROMPT=$(jq -r 'select(.type == "user" and .isMeta != true and .isSidechain != true)
  | select(.message.content | if type == "string" then true else ((map(.type) | index("tool_result")) == null) end)
  | .timestamp // empty' "$TRANSCRIPT" 2>/dev/null | sort | tail -1)
[ -n "$LAST_PROMPT" ] && ! [[ "$LAST_EDIT" > "$LAST_PROMPT" ]] && exit 0       # turno atual sem edições
[ -n "$LAST_REVIEW" ] && [[ "$LAST_REVIEW" > "${LAST_PROMPT:-0}" ]] && exit 0   # review já corrida neste turno

CHECK=$(bash "$HOME/.claude/scripts/coderabbit-review.sh" --check 2>/dev/null)
[ $? -eq 10 ] || exit 0   # sem diff, já revisto, ou CodeRabbit indisponível
FP=$(printf '%s\n' "$CHECK" | sed -n 's/.*fp=\([0-9a-f]*\).*/\1/p' | head -1)
STATE="$(git rev-parse --absolute-git-dir)/coderabbit"
MARK="$STATE/nudged"
grep -qx "$SID $FP" "$MARK" 2>/dev/null && exit 0
{ tail -n 99 "$MARK" 2>/dev/null; echo "$SID $FP"; } > "$MARK.tmp" && mv "$MARK.tmp" "$MARK"

jq -n --arg r "[CodeRabbit] Esta sessão alterou código neste repo e ainda não houve review depois da última alteração. Se a tarefa está terminada e os testes relevantes estão verdes: corre \`bash ~/.claude/scripts/coderabbit-review.sh\` e faz a triagem (~/.claude/rules/coderabbit-review.md). Se o trabalho está incompleto, à espera do utilizador, ou é trivial/só docs: não corras e termina com 1 linha a dizer porquê. Lembrete único para este diff." \
  '{decision: "block", reason: $r}'
exit 0
