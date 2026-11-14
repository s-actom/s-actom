#!/usr/bin/env bash
# test-ligar-guarda-sessao.sh — testa reverter/ligar-guarda-sessao.sh num HOME temporário (settings copiado do vivo
# sem o bloco env). Nunca toca no vivo. Correr: bash ~/.claude/equipas/reverter/testes/test-ligar-guarda-sessao.sh
set -u
AQUI="$(cd "$(dirname "$0")" && pwd -P)"; L="$AQUI/../ligar-guarda-sessao.sh"
R=$(mktemp -d) && [ -d "$R" ] || exit 2
trap 'chmod -R u+rwx "$R" 2>/dev/null; rm -R -- "$R"' EXIT
T="$R/casa"; ATALHO="$R/atalho"; ln -s casa "$ATALHO"   # o HOME e o mesmo HOME atrás de uma ligação simbólica
F=0; ok() { echo "ok - $1"; }; ko() { echo "FALHOU - $1"; F=$((F+1)); }
E="$T/.claude/equipas"; S="$T/.claude/settings.json"; sha() { shasum -a 256 < "$S" | cut -d' ' -f1; }
M='Bash|Monitor|mcp__.*'
# BASE_JQ: o settings do vivo sem o bloco env e sem os hooks que citam guarda-sessao.sh (o vivo pode já ter o grupo
# ligado); grupos e chaves que esses hooks deixem vazios saem, como no --desligar.
BASE_JQ='def cita: (.command // "") | tostring | contains("guarda-sessao.sh");
  del(.env) | if (.hooks.PreToolUse | type) == "array" then .hooks.PreToolUse |= map(if any(.hooks[]?; cita)
    then (.hooks |= map(select(cita | not))) | select(.hooks | length > 0) else . end)
    | if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end else . end
  | if .hooks == {} then del(.hooks) else . end'
# montar: HOME de ensaio; CMD é o comando exato, com o caminho resolvido (como ativar-fase-1.sh e reverter-fase-1.sh).
montar() { rm -R -- "$T" 2>/dev/null; mkdir -p "$E/hooks" "$E/backups" && mkdir -m 700 "$E/estado"
  touch "$E/hooks/guarda-sessao.sh"; jq "$BASE_JQ" "$HOME/.claude/settings.json" > "$S"; chmod 600 "$S"; O=$(sha)
  CMD="bash \"$(cd "$E/hooks" && pwd -P)/guarda-sessao.sh\" || true"; }
# poe <expr jq>: muda o settings de ensaio ($c = comando exato, $m = matcher) e passa a ser o "original".
poe() { jq --arg c "$CMD" --arg m "$M" "$1" "$S" > "$S.t" && mv "$S.t" "$S" && chmod 600 "$S"; O=$(sha); }
corre() { HOME="${CASA:-$T}" bash "$L" "$@" </dev/null >/dev/null 2>&1; }
n() { jq '[.hooks.PreToolUse[]?.hooks[]? | select((.command // "") | tostring | contains("guarda-sessao.sh"))] | length' "$S"; }
# exato: um só comando cita guarda-sessao.sh e é o do grupo exato (matcher, type, comando com caminho resolvido, 30 s).
exato() { [ "$(n)" = 1 ] && jq -e --arg c "$CMD" --arg m "$M" '[.hooks.PreToolUse[] | select(.matcher == $m) | .hooks[]
  | select(.type == "command" and .command == $c and .timeout == 30)] | length == 1' "$S" >/dev/null; }
sem_tmp() { [ -z "$(find "$T/.claude" "$E/estado" "$E/backups" -maxdepth 1 -name '.settings*' -print -quit 2>/dev/null)" ]; }
nbk() { find "$E/backups" -maxdepth 1 -type d -name 'settings-m1-*' | wc -l | tr -d ' '; }

montar
[ "$(jq 'has("env")' "$S")" = false ] || { echo "env no ensaio: parar" >&2; exit 2; }
[ "$(n)" = 0 ] || { echo "a base do ensaio ainda cita guarda-sessao.sh: parar" >&2; exit 2; }
# Timeout 30 s: as 5 equipas correm em série dentro deste hook (era o orçamento dos 5 hooks do frontmatter, 5 × 5 s).
corre && exato && jq -e --arg c "$CMD" --arg m "$M" '.hooks.PreToolUse[-1] == {matcher: $m, hooks: [{type: "command", command: $c, timeout: 30}]}' "$S" >/dev/null \
  && [ "$(stat -f %Lp "$S")" = 600 ] && ok "liga: o grupo exato no fim (matcher, caminho resolvido, timeout 30, || true), modo 600" || ko "liga: grupo exato"
L1=$(sha); corre && [ "$(sha)" = "$L1" ] && ok "ligar 2.ª vez (exato, sem variantes) não mexe" || ko "ligar 2.ª vez"
corre --desligar && [ "$(sha)" = "$O" ] && ok "desliga: igual byte a byte ao original" || ko "desliga"
corre --desligar && [ "$(sha)" = "$O" ] && ok "desligar 2.ª vez não mexe" || ko "desligar 2.ª vez"
[ "$(nbk)" = 2 ] && ok "um backup por mudança (2)" || ko "backups ($(nbk))"
# B-1: HOME atrás de uma ligação simbólica; o comando fica com o caminho resolvido, que é o que o reverter-fase-1.sh tira.
montar; CASA="$ATALHO" corre && exato && ! grep -qF "$ATALHO/" "$S" && ok "HOME por ligação simbólica: o comando tem o caminho resolvido" || ko "HOME por ligação simbólica"
# B-4: variantes que citam guarda-sessao.sh mas não são o grupo exato: o ligar tira-as todas e põe o grupo exato.
G='{matcher: $m, hooks: [{type: "command", command: $c, timeout: 30}]}'
while IFS='@' read -r rotulo expr; do
  montar; poe ".hooks.PreToolUse += $expr"
  corre && exato && [ "$(nbk)" = 1 ] && ok "variante ($rotulo): substituída pelo grupo exato" || ko "variante ($rotulo): $(n) comandos"
done <<EOF
timeout 10@[{matcher: \$m, hooks: [{type: "command", command: \$c, timeout: 10}]}]
outro caminho@[{matcher: \$m, hooks: [{type: "command", command: "bash \"/outro/sitio/guarda-sessao.sh\" || true", timeout: 30}]}]
outro matcher@[{matcher: "Bash", hooks: [{type: "command", command: \$c, timeout: 30}]}]
sem o || true@[{matcher: \$m, hooks: [{type: "command", command: (\$c | sub(" \\\\|\\\\| true\$"; "")), timeout: 30}]}]
exato duas vezes@[$G, $G]
exato e uma variante@[$G, {matcher: "Bash", hooks: [{type: "command", command: "bash /x/guarda-sessao.sh"}]}]
sem type@[{matcher: \$m, hooks: [{command: \$c, timeout: 30}]}]
outro type@[{matcher: \$m, hooks: [{type: "prompt", command: \$c, timeout: 30}]}]
EOF
montar; poe ".hooks.PreToolUse += [{matcher: \"Bash\", hooks: [{type: \"command\", command: \"echo alheio\"}, {type: \"command\", command: \"bash /x/guarda-sessao.sh\"}]}]"
corre && exato && jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command == "echo alheio")] | length == 1' "$S" >/dev/null \
  && ok "variante num grupo com um hook alheio: sai a variante, o alheio fica" || ko "variante com hook alheio"
montar; poe ".hooks.PreToolUse += [{matcher: \$m, hooks: [{type: \"command\", command: \$c, timeout: 10}]}]"
corre --desligar && [ "$(n)" = 0 ] && ok "desligar tira também as variantes" || ko "desligar com variante ($(n))"
# Só saem os grupos que tinham o nosso hook: um grupo alheio vazio fica, ao ligar e ao desligar.
montar; poe '.hooks.PreToolUse += [{matcher: "Write", hooks: []}]'
corre && exato && jq -e '[.hooks.PreToolUse[] | select(.matcher == "Write" and .hooks == [])] | length == 1' "$S" >/dev/null \
  && corre --desligar && [ "$(sha)" = "$O" ] && ok "grupo alheio vazio: fica ao ligar e ao desligar (igual byte a byte)" || ko "grupo alheio vazio"
montar; poe 'del(.hooks)'
corre && exato && corre --desligar && [ "$(sha)" = "$O" ] && ok "original sem hooks: ligar e desligar não deixam \"hooks\": {}" || ko "original sem hooks"
# B-7: sem PreToolUse no original, desligar tira a chave vazia (igual byte a byte a esse original).
montar; poe 'del(.hooks.PreToolUse)'
corre && exato && corre --desligar && [ "$(sha)" = "$O" ] && ok "PreToolUse vazio: desligar tira a chave, igual byte a byte ao original sem ela" || ko "chave PreToolUse vazia"
# B-6: o temporário (tem o bloco env) fica em equipas/backups/ (700, mesmo disco; a única pasta no .gitignore de ~/.claude).
montar; chmod 500 "$E/estado"; corre; rc=$?; chmod 700 "$E/estado"
[ $rc -eq 0 ] && exato && sem_tmp && ok "estado/ sem escrita: liga na mesma (o temporário já não vai para estado/)" || ko "estado/ sem escrita (rc=$rc)"
montar; chmod 500 "$E/backups"; corre; rc=$?; chmod 700 "$E/backups"
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && sem_tmp && ok "backups/ sem escrita: recusa, nada muda (o temporário vai para backups/)" || ko "backups/ sem escrita (rc=$rc)"
montar; rm -R -- "$E/backups"; mkdir "$R/fora"; ln -s "$R/fora" "$E/backups"; corre; rc=$?
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && [ -z "$(ls -A "$R/fora")" ] && ok "backups/ ligação simbólica: recusa, nada escrito no destino" || ko "backups/ ligação simbólica (rc=$rc)"
rm -f -- "$E/backups"; rmdir "$R/fora" 2>/dev/null
montar; rm -R -- "$E/backups"; corre && exato && [ -d "$E/backups" ] && [ ! -L "$E/backups" ] && [ "$(stat -f %Lp "$E/backups")" = 700 ] \
  && ok "backups/ em falta: cria-o com modo 700" || ko "backups/ em falta"
montar; chmod 500 "$T/.claude"; corre; rc=$?; chmod 700 "$T/.claude"
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && sem_tmp && ok "falha depois do temporário (o mv para o settings.json falha): nada muda e o temporário sai" || ko "falha a meio (rc=$rc)"
# B-6: ficam os 5 backups mais recentes deste script (o novo incluído); outros backups e ligações simbólicas não se tocam.
montar; for d in 01 02 03 04 05 06; do mkdir -m 700 "$E/backups/settings-m1-202001$d-000000-abcd" && echo '{}' > "$E/backups/settings-m1-202001$d-000000-abcd/settings.json"; done
mkdir "$E/backups/fase-1-20200101-000000"; mkdir "$R/alvo"; echo x > "$R/alvo/f"; ln -s "$R/alvo" "$E/backups/settings-m1-19990101-000000-ligacao"
corre; rc=$?
[ $rc -eq 0 ] && [ "$(nbk)" = 5 ] && [ "$(find "$E/backups" -maxdepth 1 -type d -name "settings-m1-$(date +%Y%m%d)-*" | wc -l | tr -d ' ')" = 1 ] \
  && [ ! -e "$E/backups/settings-m1-20200101-000000-abcd" ] && [ ! -e "$E/backups/settings-m1-20200102-000000-abcd" ] && [ -d "$E/backups/settings-m1-20200103-000000-abcd" ] \
  && [ -d "$E/backups/fase-1-20200101-000000" ] && [ -L "$E/backups/settings-m1-19990101-000000-ligacao" ] && [ -f "$R/alvo/f" ] \
  && ok "backups: ficam os 5 mais recentes deste script; os outros e as ligações simbólicas não se tocam" || ko "rotação dos backups (rc=$rc, $(nbk))"
# Um nome de backup com quebra de linha não faz apagar nada fora de backups/settings-m1-* (o ligar corre noutra pasta).
montar; for d in 01 02 03 04 05 06; do mkdir -m 700 "$E/backups/settings-m1-202001$d-000000-abcd"; done
mkdir "$R/.vitima" "$E/backups/settings-m1-19990101-000000-x"$'\n'".vitima"
(cd "$R" && HOME="$T" bash "$L" </dev/null >/dev/null 2>&1); rc=$?
[ $rc -eq 0 ] && [ -d "$R/.vitima" ] && ok "rotação: um nome com quebra de linha não apaga nada fora de backups/" || ko "rotação com quebra de linha (rc=$rc)"
rmdir "$R/.vitima" 2>/dev/null
# Nunca imprime o settings.json, nem num erro do jq (o jq mostra um pedaço do valor que falha): forma inesperada recusa antes.
montar; poe '.hooks.PreToolUse = {"CANARIO-lg77 valor do settings": {"hooks": []}}'; SAIDA=$(HOME="$T" bash "$L" 2>&1 </dev/null); rc=$?
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && sem_tmp && ! printf '%s' "$SAIDA" | grep -q CANARIO && ok "PreToolUse que não é lista: recusa, nada muda, nada do settings na saída" || ko "forma inesperada (rc=$rc, saída: ${SAIDA:0:70})"
montar; poe '.hooks.PreToolUse += [{matcher: "Bash"}]'; corre; rc=$?
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && sem_tmp && ok "grupo do PreToolUse sem lista de hooks: recusa, nada muda" || ko "grupo sem hooks (rc=$rc)"
for raiz in null '[]' '"texto"'; do
  montar; echo "$raiz" > "$S"; O=$(sha); corre; rc=$?
  [ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && sem_tmp && ok "settings que não é objeto ($raiz): recusa, nada muda" || ko "raiz $raiz (rc=$rc)"
done
montar; mv "$E/hooks" "$E/hooks.real" && ln -s hooks.real "$E/hooks"; corre; rc=$?
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && ok "hooks/ ligação simbólica: recusa, nada muda (o ativar e o reverter não resolvem esse nível)" || ko "hooks/ ligação simbólica (rc=$rc)"
montar; rm "$E/hooks/guarda-sessao.sh"; corre; rc=$?
[ $rc -ne 0 ] && [ "$(sha)" = "$O" ] && ok "sem guarda-sessao.sh: recusa, nada muda" || ko "sem o script (rc=$rc)"
montar; U=$(HOME="$T" bash "$L" --x 2>&1 >/dev/null); rc=$?
[ $rc -eq 2 ] && [ "$(sha)" = "$O" ] && [ "$U" = "uso: ligar-guarda-sessao.sh [--desligar]" ] && ok "argumento desconhecido: sai 2 com o uso, nada muda" || ko "argumento desconhecido (rc=$rc, '$U')"
montar; corre --desligar a; rc=$?
[ $rc -eq 2 ] && [ "$(sha)" = "$O" ] && ok "argumentos a mais: sai 2, nada muda" || ko "argumentos a mais (rc=$rc)"
montar; mv "$S" "$S.real" && ln -s "$S.real" "$S"; corre; rc=$?
[ $rc -ne 0 ] && [ -L "$S" ] && ok "settings ligação simbólica: recusa" || ko "symlink (rc=$rc)"
[ "$F" -eq 0 ] && echo "TODOS OK" || { echo "$F FALHAS"; exit 1; }
