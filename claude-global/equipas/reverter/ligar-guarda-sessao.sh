#!/usr/bin/env bash
# ligar-guarda-sessao.sh [--desligar] — liga (ou tira) o guarda das equipas no ~/.claude/settings.json; backup e
# escrita atómica. É o único mecanismo do guarda (nenhuma skill leva hooks no frontmatter).
# Ligado = em .hooks.PreToolUse, o grupo exato {matcher "Bash|Monitor|mcp__.*", hooks [{type "command",
# command `bash "<hooks resolvido>/guarda-sessao.sh" || true`, timeout 30}]} e nenhum outro comando que cite
# guarda-sessao.sh. 30 s porque as 5 equipas com guarda correm em série dentro deste hook. O caminho vai resolvido
# (pwd -P), como em ativar-fase-1.sh e reverter-fase-1.sh, que filtram os comandos da Fase 1 por "<hooks resolvido>/".
# Liga: se já está exato, nada a fazer; senão tira todas as variantes (outro timeout, caminho ou matcher) e põe o exato.
# Desliga: tira só os comandos que citam guarda-sessao.sh; saem só os grupos que eles deixam vazios (um grupo alheio
# vazio fica), e a chave PreToolUse e o .hooks se ficarem vazios; o resto do settings.json fica igual. Nunca imprime o
# ficheiro (nem os erros do jq, que mostram pedaços de valores). Recusa se equipas/hooks for ligação simbólica (o ativar
# e o reverter não resolvem esse nível). O temporário (tem o bloco env) e os backups ficam em equipas/backups/ (700,
# mesmo disco: o mv é atómico; a única pasta no .gitignore de ~/.claude); ficam os 5 backups settings-m1-* mais recentes.
# Saída: 0 feito ou nada a fazer · 1 falhou (nada mudou) · 2 uso.
set -euo pipefail
case "$#:${1:-}" in
  0:) MODO=ligar ;;
  1:--desligar) MODO=desligar ;;
  *) echo "uso: ligar-guarda-sessao.sh [--desligar]" >&2; exit 2 ;;
esac
falha() { echo "$*; nada mudou" >&2; exit 1; }
S="$HOME/.claude/settings.json"; E="$HOME/.claude/equipas"; B="$E/backups"
[ ! -L "$E/hooks" ] || falha "$E/hooks é ligação simbólica"
HK=$(cd "$E/hooks" 2>/dev/null && pwd -P) || falha "falta $E/hooks"
M='Bash|Monitor|mcp__.*'; CMD="bash \"$HK/guarda-sessao.sh\" || true"; TO=30
[ -f "$S" ] && [ ! -L "$S" ] || falha "settings.json em falta ou ligação simbólica"
jq -e 'type == "object" and ((.hooks // {}) as $h | ($h | type) == "object" and (($h.PreToolUse // []) | type == "array"
  and all(.[]; type == "object" and (.hooks | type) == "array" and all(.hooks[]; type == "object"))))' "$S" >/dev/null 2>&1 \
  || falha "settings.json inválido ou com .hooks.PreToolUse fora da forma esperada"
ESTADO=$(jq -r --arg m "$M" --arg c "$CMD" --argjson t "$TO" '
  [.hooks.PreToolUse[]? as $g | $g.hooks[] | select((.command // "") | tostring | contains("guarda-sessao.sh"))
     | ($g.matcher == $m and .type == "command" and .command == $c and .timeout == $t)]
  | if length == 0 then "ausente" elif . == [true] then "exato" else "variantes" end' "$S" 2>/dev/null) || falha "jq falhou a ler o settings.json"
if [ "$MODO" = desligar ]; then [ "$ESTADO" != ausente ] || { echo "não está ligado; nada a fazer"; exit 0; }
else [ "$ESTADO" != exato ] || { echo "já está ligado; nada a fazer"; exit 0; }; [ -f "$HK/guarda-sessao.sh" ] || falha "falta $HK/guarda-sessao.sh"; fi
[ ! -L "$B" ] || falha "$B é ligação simbólica"
mkdir -p -m 700 "$B" && [ -d "$B" ] || falha "não consegui criar $B"
[ "$(stat -f %d "$B")" = "$(stat -f %d "$HOME/.claude")" ] || falha "$B não está no mesmo disco que o settings.json"
m=$(stat -f %Lp "$S")
tmp=$(mktemp "$B/.settings.ligar.XXXXXX") || falha "não consegui criar o temporário em $B"
trap 'rm -f "$tmp"' EXIT   # a cópia tem o bloco env: não pode ficar se algo falhar
FILTRO='def cita: (.command // "") | tostring | contains("guarda-sessao.sh");
  def sem_guarda: if .hooks.PreToolUse == null then . else .hooks.PreToolUse |= map(if any(.hooks[]; cita)
    then (.hooks |= map(select(cita | not))) | select(.hooks | length > 0) else . end) end;'
if [ "$MODO" = desligar ]; then
  jq "$FILTRO"' sem_guarda | if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end
    | if .hooks == {} then del(.hooks) else . end' "$S" > "$tmp" 2>/dev/null
else
  jq --arg m "$M" --arg c "$CMD" --argjson t "$TO" "$FILTRO"' sem_guarda
    | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher: $m, hooks: [{type: "command", command: $c, timeout: $t}]}])' "$S" > "$tmp" 2>/dev/null
fi || falha "jq falhou"
jq -e 'type == "object"' "$tmp" >/dev/null 2>&1 || falha "jq falhou"
BK=$(mktemp -d "$B/settings-m1-$(date +%Y%m%d-%H%M%S)-XXXX") || falha "não consegui criar o backup em $B"
cp -p "$S" "$BK/settings.json" || falha "cópia de backup falhou"
chmod "$m" "$tmp" && mv -f "$tmp" "$S" || falha "não consegui substituir o settings.json"
# Ficam os 5 backups mais recentes deste script (o de agora sempre); só pastas com o nome do mktemp acima.
{ find "$B" -maxdepth 1 -type d -name 'settings-m1-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]-*' ! -path "$BK" \
    | sort -r | tail -n +5 | while IFS= read -r d; do case "$d" in "$B"/settings-m1-*) rm -R -- "$d" ;; esac; done; } \
  || echo "aviso: a rotação dos backups falhou (o settings.json já mudou)" >&2   # o case trava nomes com quebra de linha
echo "feito ($MODO$([ "$ESTADO" = variantes ] && echo ', variantes tiradas')); backup: $BK/settings.json"
