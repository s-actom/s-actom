#!/usr/bin/env bash
# rede-vibesec.sh — hook Stop (Fase 1 da Direção Geral), no padrão do coderabbit-stop-gate.sh.
# Lembra UMA vez se o turno atual (thread principal ou subagentes) editou código com Edit/Write/MultiEdit/NotebookEdit
# e não houve verificação VibeSec (ferramentas mcp__vibesec__* ou a skill VibeSec-Skill) depois da última edição.
# Funciona sem equipa chamada e fora de repositórios git. Ignora docs e pastas temporárias.
# Nunca corre o VibeSec; não repete (stop_hook_active + marca por sessão e conjunto de ficheiros); falha sempre aberto.
set -o pipefail
unset TYPESAFE_API_KEY   # este hook não precisa dela
command -v jq >/dev/null 2>&1 || exit 0
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P) || exit 0
[ -f "$BASE/FASE-1-ATIVA" ] || exit 0

IN=$(cat)
[ "$(printf '%s' "$IN" | jq -r '.stop_hook_active // false' 2>/dev/null)" = true ] && exit 0
TRANSCRIPT=$(printf '%s' "$IN" | jq -r '.transcript_path // empty' 2>/dev/null)
SID=$(printf '%s' "$IN" | jq -r '.session_id // empty' 2>/dev/null)
[[ "$SID" =~ ^[A-Za-z0-9_-]{1,128}$ ]] && [ -f "$TRANSCRIPT" ] || exit 0

TRANSCRIPTS=("$TRANSCRIPT")
for f in "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do [ -f "$f" ] && TRANSCRIPTS+=("$f"); done

# E = edição de ficheiro, V = verificação VibeSec
EVENTS=$(jq -r '
  select(.type == "assistant") | (.timestamp | tostring | gsub("[\t\r\n]"; " ")) as $t | .message.content[]? | select(.type == "tool_use")
  | if (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$")) then
      (.input.file_path // .input.notebook_path // "" | tostring | gsub("[\t\r\n]"; " ")) as $p | if $p != "" then "E\t\($t)\t\($p)" else empty end
    elif (.name | test("^mcp__vibesec__")) or (.name == "Skill" and ((.input.skill // "") | test("^VibeSec"; "i"))) then "V\t\($t)\t-"
    else empty end' "${TRANSCRIPTS[@]}" 2>/dev/null)

DOCS_RE='\.(md|mdx|txt|rst|adoc|json|jsonl|csv|tsv|log|tmp|png|jpe?g|gif|webp|svg|ico|pdf|mp4|mov|mp3|wav|lock)$|/(LICENSE|CHANGELOG)[^/]*$'
TMP_RE='^(/tmp/|/private/tmp/|/var/folders/|/private/var/folders/)'
CODE=$(printf '%s\n' "$EVENTS" | awk -F'\t' '$1 == "E" { print $2 "\t" $3 }' | grep -vE "$DOCS_RE" | awk -F'\t' -v re="$TMP_RE" '$2 !~ re')
[ -n "$CODE" ] || exit 0
LAST_EDIT=$(printf '%s\n' "$CODE" | cut -f1 | sort | tail -1)
LAST_V=$(printf '%s\n' "$EVENTS" | awk -F'\t' '$1 == "V" { print $2 }' | sort | tail -1)
# Início do turno = último prompt real do utilizador (exclui tool_result e mensagens meta).
LAST_PROMPT=$(jq -r 'select(.type == "user" and .isMeta != true and .isSidechain != true)
  | select(.message.content | if type == "string" then true else ((map(.type) | index("tool_result")) == null) end)
  | .timestamp // empty' "$TRANSCRIPT" 2>/dev/null | sort | tail -1)
[ -n "$LAST_PROMPT" ] && ! [[ "$LAST_EDIT" > "$LAST_PROMPT" ]] && exit 0   # turno atual sem edições de código
[ -n "$LAST_V" ] && [[ "$LAST_V" > "$LAST_EDIT" ]] && exit 0                # VibeSec já correu depois da última edição

# Conjunto de ficheiros de código editados desde a última verificação (ou desde o início)
FILES=$(printf '%s\n' "$CODE" | awk -F'\t' -v v="${LAST_V:-}" '$1 > v { print $2 }' | sort -u)
N=$(printf '%s\n' "$FILES" | grep -c .)
FP=$(printf '%s\n' "$FILES" | shasum -a 256 | cut -c1-16)
ESTADO="$BASE/estado"; MARK="$ESTADO/vibesec-avisos"
mkdir -p -m 700 "$ESTADO" 2>/dev/null || exit 0
[ -L "$MARK" ] && exit 0
grep -qx "$SID $FP" "$MARK" 2>/dev/null && exit 0
{ tail -n 199 "$MARK" 2>/dev/null; echo "$SID $FP"; } >"$MARK.tmp.$$" && mv "$MARK.tmp.$$" "$MARK"

jq -n --arg n "$N" --arg r "[VibeSec] Este turno alterou código ($N ficheiros) e não houve verificação VibeSec depois da última alteração (regra de segurança: ~/.claude/equipas/seguranca.md). Se a tarefa está terminada: corre o VibeSec (mcp__vibesec__check_file em cada ficheiro alterado) e faz a triagem VALID, FALSE_POSITIVE, OPTIONAL ou UNVERIFIED; o VibeSec não bloqueia sozinho. Se o trabalho está incompleto, à espera do dono, ou é só configuração ou texto: não corras e termina com 1 linha a dizer porquê. Lembrete único para estes ficheiros." \
  '{decision: "block", reason: $r}'
exit 0
