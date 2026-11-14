#!/usr/bin/env bash
# Testes de guarda-sessao.sh numa BASE temporária, com o ambiente mínimo da app (env -i, /bin/bash 3.2, /usr/bin/jq).
# Usa o guarda-equipa.sh verdadeiro (cópia), salvo onde se troca por um eco para ver o que lhe chega.
# Correr: bash ~/.claude/equipas/hooks/tests/test-guarda-sessao.sh
set -u
AQUI=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
T=$(mktemp -d) && [ -d "$T" ] || exit 2
trap 'rm -R -- "$T"' EXIT
H="$T/h"; G="$H/.claude/equipas"   # HOME e BASE como na máquina real
GS="$G/hooks/guarda-sessao.sh"; GE="$G/hooks/guarda-equipa.sh"; REG="$G/registo.jsonl"
mkdir -p "$G/hooks" "$G/estado" && touch "$G/FASE-1-ATIVA" "$G/estado/guardas-revistas"
cp "$AQUI/guarda-equipa.sh" "$GE" && cp "$GE" "$T/guarda-equipa.orig"
cp "$AQUI/guarda-sessao.sh" "$GS"
APP='/usr/bin:/bin:/usr/sbin:/sbin'; J=/usr/bin/jq
F=0; N=0
ok() { echo "ok - $1"; }
falha() { echo "FALHOU - $1"; F=$((F+1)); }
# corre <entrada> [PATH] [bash]: corre o guarda como o hook de settings.json; saída em O, código de saída em C.
corre() { O=$(printf '%s' "$1" | env -i PATH="${2:-$APP}" HOME="$H" "${3:-/bin/bash}" "$GS"); C=$?; }
# Veredito: vazio (cala), ask (um só objeto JSON PreToolUse com ask), SAIU-<código> ou INVALIDA. Tem de sair sempre 0.
veredito() { [ "$C" = 0 ] || { echo "SAIU-$C"; return; }; [ -z "$O" ] && return
  printf '%s' "$O" | $J -sr 'if length == 1 and .[0].hookSpecificOutput.hookEventName == "PreToolUse"
    then .[0].hookSpecificOutput.permissionDecision else "INVALIDA" end' 2>/dev/null || echo INVALIDA; }
pede() { local v; N=$((N+1)); corre "$2"; v=$(veredito); [ "$v" = ask ] && ok "pede: $1" || falha "devia pedir: $1 (veredito '$v')"; }
cala() { local v; N=$((N+1)); corre "$2"; v=$(veredito); [ -z "$v" ] && ok "cala: $1" || falha "devia calar: $1 (veredito '$v')"; }
# tempo <rótulo> <entrada> <ask ou vazio>: o veredito esperado em menos de 2 s.
tempo() { local s v; N=$((N+1)); { TIMEFORMAT=%R; time corre "$2"; } 2>"$T/tempo"; s=$(tail -n 1 "$T/tempo" | tr , .); v=$(veredito)
  if [ "$v" = "$3" ] && awk -v t="$s" 'BEGIN { exit !(t + 0 < 2) }'; then ok "$1 (${s} s)"
  else falha "$1: esperava '$3' em menos de 2 s (veredito '$v', ${s} s)"; fi; }
# ent <session_id> <tool_name> <tool_input em JSON> [agent_id]: entrada PreToolUse como a da app (agent_id só em subagentes).
ent() { $J -cn --arg s "$1" --arg t "$2" --argjson i "$3" --arg a "${4-}" '{session_id: $s,
  transcript_path: "/tmp/t.jsonl", cwd: "/tmp", permission_mode: "default", hook_event_name: "PreToolUse",
  tool_name: $t, tool_input: $i, tool_use_id: "toolu_01"} + (if $a == "" then {} else {agent_id: $a, agent_type: "general-purpose"} end)'; }
bash_() { ent "$1" Bash "$($J -cn --arg c "$2" '{command: $c}')" "${3-}"; }
mon() { ent "$1" Monitor "$($J -cn --arg c "$2" '{command: $c, description: "d", timeout_ms: 60000}')"; }
mcp() { ent "$1" "$2" '{}'; }
# linha <sessao> <equipa> [JSON a juntar]: linha de registo.jsonl como as de registo-equipa.mjs.
linha() { local x=${3-}; [ -n "$x" ] || x='{}'
  $J -cn --arg s "$1" --arg e "$2" --argjson x "$x" '{v: 1, tipo: "equipa", equipa: $e, ts: "2026-11-08T10:00:00.000Z",
    sessao: $s, via: "ferramenta", razao_etiquetas: ["infra"], ok: true} + $x'; }
reg() { local l; rm -f -- "$REG"; : >"$REG"; for l in "$@"; do printf '%s\n' "$l" >>"$REG"; done; }
# eco: põe no lugar de guarda-equipa.sh um eco que pede sempre e conta o que recebeu (equipa, bash, chave, entrada).
eco() { cat >"$GE" <<'ECO'
s=$(/usr/bin/cksum | /usr/bin/awk '{print $1 "-" $2}')
/usr/bin/jq -cn --arg r "equipa=$1 bash=$BASH chave=${TYPESAFE_API_KEY-ausente} entrada=$s" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
ECO
}
S1=4b0d3c7e-9a51-4f0e-8c2a-1d6e5f7a8b90; S2=9f8e7d6c-5b4a-4321-8fed-cba987654321; PUSH='git push origin main'

# 1-2. O mesmo pedido num subagente (com agent_id) e na thread principal (sem agent_id: o caso da retoma)
reg "$(linha "$S1" infraestrutura)"
pede "subagente + infraestrutura + $PUSH" "$(bash_ "$S1" "$PUSH" a1b2c3d4e5f6)"
pede "thread principal (retoma) + infraestrutura + $PUSH" "$(bash_ "$S1" "$PUSH")"
cala "infraestrutura + ls -la" "$(bash_ "$S1" 'ls -la')"
# 3. Inerte sem estado/guardas-revistas ou sem FASE-1-ATIVA; também com o eco, que pede sempre (o guarda da sessão é
#    inerte por si, não só porque guarda-equipa.sh o é). Controlo: com as duas marcas, o eco pede.
for g in verdadeiro eco; do
  [ "$g" = eco ] && { eco; pede "com as marcas e o eco no lugar de guarda-equipa.sh (controlo)" "$(bash_ "$S1" 'ls -la')"; }
  rm "$G/estado/guardas-revistas"; cala "sem estado/guardas-revistas (guarda-equipa.sh $g)" "$(bash_ "$S1" "$PUSH")"; touch "$G/estado/guardas-revistas"
  rm "$G/FASE-1-ATIVA"; cala "sem FASE-1-ATIVA (guarda-equipa.sh $g)" "$(bash_ "$S1" "$PUSH")"; touch "$G/FASE-1-ATIVA"
done
cp "$T/guarda-equipa.orig" "$GE"
# 4. Sem equipas com guarda: registo vazio, só outros tipos, só equipas sem guarda, nome parecido, equipa noutro tipo
reg; cala "registo vazio" "$(bash_ "$S1" "$PUSH")"
reg "$($J -cn --arg s "$S1" '{v: 1, tipo: "pedido", ts: "x", sessao: $s, turno: 1, ordem: 1, portao: "x"}')" \
  "$($J -cn --arg s "$S1" '{v: 1, tipo: "direcao", ts: "x", sessao: $s, via: "ferramenta", ok: true}')"
cala "sessão sem equipas (só pedido e direcao)" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" sistema)" "$(linha "$S1" qualidade)"; cala "sessão só com equipas sem guarda (sistema, qualidade)" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestruturas)" "$(linha "$S1" infra)"; cala "equipa de nome parecido (infraestruturas, infra)" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestrutura '{"tipo":"pedido"}')"; cala "equipa numa linha de outro tipo" "$(bash_ "$S1" "$PUSH")"
# 5. A equipa chamada noutra sessão não conta, nem numa sessão cujo id contém o desta
reg "$(linha "$S2" infraestrutura)" "$(linha "${S1}x" infraestrutura)" "$(linha "x${S1}" infraestrutura)"
cala "infraestrutura só noutras sessões" "$(bash_ "$S1" "$PUSH")"
# 6. ok:false não conta; /equipa-x escrito à mão (via comando), entradas de subagente e ok ausente contam
reg "$(linha "$S1" infraestrutura '{"ok":false}')"; cala "ok:false" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestrutura '{"ok":false}')" "$(linha "$S1" infraestrutura)"; pede "ok:false e depois ok:true" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestrutura '{"via":"comando","razao_etiquetas":null}')"; pede "via comando" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestrutura '{"subagente":true}')"; pede "entrada de subagente (subagente:true)" "$(bash_ "$S1" "$PUSH")"
reg "$(linha "$S1" infraestrutura | $J -c 'del(.ok)')"; pede "ok ausente" "$(bash_ "$S1" "$PUSH")"
# 7. Linhas estragadas antes da válida (todas com o id da sessão, para passarem o pré-filtro): não se perde a seguinte
{ printf '{"v":1,"tipo":"equipa","equipa":"infraestrutura","sessao":"%s"\n\n\n' "$S1"; printf 'lixo %s\n[1,"%s"]\n"%s"\nnull\n' "$S1" "$S1" "$S1"
  printf '{"tipo":"equipa","sessao":"%s","equipa":7}\n' "$S1"; printf '{"tipo":"equipa","sessao":"%s"} {"x":1}\n' "$S1"; linha "$S1" infraestrutura; } >"$REG"
pede "linhas estragadas e vazias antes da válida" "$(bash_ "$S1" "$PUSH")"
{ printf '{"tipo":"equipa","sessao":"%s","x":"\0"}\n' "$S1"; linha "$S1" infraestrutura; } >"$REG"
pede "linha com byte NUL antes da válida (sem grep -a, o grep diria 'Binary file matches')" "$(bash_ "$S1" "$PUSH")"
# 8. session_id inválido: cala e sai 0 (há linhas no registo com cada um destes valores, para o teste não ser vazio)
L128=$(printf 'a%.0s' $(seq 1 128)); L129="${L128}b"
reg "$(linha '' infraestrutura)" "$(linha null infraestrutura)" "$(linha 123 infraestrutura)" "$(linha a/b infraestrutura)" \
  "$(linha 'a"b' infraestrutura)" "$(linha abc infraestrutura)" "$(linha "$L129" infraestrutura)" "$(linha "$L128" infraestrutura)"
cala "session_id vazio" "$(bash_ '' "$PUSH")"
cala "session_id ausente" "$(bash_ x "$PUSH" | $J -c 'del(.session_id)')"
cala "session_id número" "$(bash_ x "$PUSH" | $J -c '.session_id = 123')"
cala "session_id com /" "$(bash_ a/b "$PUSH")"
cala "session_id com aspas" "$(bash_ 'a"b' "$PUSH")"
cala "session_id com quebra de linha no fim" "$(bash_ $'abc\n' "$PUSH")"
cala "session_id com 129 caracteres" "$(bash_ "$L129" "$PUSH")"
pede "session_id com 128 caracteres (limite)" "$(bash_ "$L128" "$PUSH")"
# 9. Sessão {infraestrutura, blockchain}
reg "$(linha "$S1" infraestrutura)" "$(linha "$S1" blockchain)"
pede "{infraestrutura, blockchain} + solana program deploy x.so" "$(bash_ "$S1" 'solana program deploy x.so')"
cala "{infraestrutura, blockchain} + ls -la" "$(bash_ "$S1" 'ls -la')"
# 10. MCP e Monitor
reg "$(linha "$S1" multimedia)"; pede "multimedia + mcp__nano-banana-mcp__generate_image" "$(mcp "$S1" mcp__nano-banana-mcp__generate_image)"
cala "multimedia + mcp__nano-banana-mcp__get_configuration_status" "$(mcp "$S1" mcp__nano-banana-mcp__get_configuration_status)"
reg "$(linha "$S1" infraestrutura)"; pede "infraestrutura + Monitor com $PUSH" "$(mon "$S1" "$PUSH")"
cala "infraestrutura + Monitor com tail -f" "$(mon "$S1" 'tail -f app.log')"
# 11. registo.jsonl ligação simbólica (para um registo que pediria) ou ausente
linha "$S1" infraestrutura >"$T/outro.jsonl"; rm -f -- "$REG"; ln -s "$T/outro.jsonl" "$REG"
cala "registo.jsonl é ligação simbólica" "$(bash_ "$S1" "$PUSH")"
rm -f -- "$REG"; cala "registo.jsonl ausente" "$(bash_ "$S1" "$PUSH")"
# 12. Duas equipas pedem: sai um só objeto, o da primeira pela ordem fixa (não a do registo), tal como guarda-equipa.sh o deu
reg "$(linha "$S1" marketing)" "$(linha "$S1" infraestrutura)"; E=$(mcp "$S1" mcp__meta-ads__ads_create_campaign); corre "$E"
D=$(printf '%s' "$E" | env -i PATH="$APP" HOME="$H" /bin/bash "$GE" infraestrutura)
N=$((N+1)); if [ "$(veredito)" = ask ] && [ "$O" = "$D" ] && printf '%s' "$O" | $J -se 'length == 1
  and (.[0].hookSpecificOutput | .hookEventName == "PreToolUse" and .permissionDecision == "ask" and (.permissionDecisionReason | startswith("Infraestrutura:")))' >/dev/null
then ok "duas equipas pedem: um só objeto JSON, o de infraestrutura, igual ao de guarda-equipa.sh"; else falha "um só objeto JSON, o primeiro pela ordem fixa (saída: $O)"; fi
# A mesma entrada inteira, o mesmo bash, sem TYPESAFE_API_KEY e pela ordem fixa: o eco no lugar de guarda-equipa.sh
eco; mkdir "$T/b" && ln -s /bin/bash "$T/b/bash"
reg "$(linha "$S1" seguranca)" "$(linha "$S1" multimedia)" "$(linha "$S1" marketing)" "$(linha "$S1" infraestrutura)" "$(linha "$S1" blockchain)"
E=$(bash_ "$S1" "$(awk 'BEGIN { for (i = 0; i < 4000; i++) print "echo linha de enchimento 0123456789 abcdefghij"; printf "fim" }')")
O=$(printf '%s' "$E" | env -i PATH="$APP" HOME="$H" TYPESAFE_API_KEY=valor-de-ensaio "$T/b/bash" "$GS"); C=$?
ESP="equipa=blockchain bash=$T/b/bash chave=ausente entrada=$(printf '%s' "$E" | cksum | awk '{print $1 "-" $2}')"
N=$((N+1)); [ "$(veredito)" = ask ] && [ "$(printf '%s' "$O" | $J -r '.hookSpecificOutput.permissionDecisionReason')" = "$ESP" ] \
  && ok "guarda-equipa.sh recebe a entrada inteira (${#E} B), o mesmo bash, sem TYPESAFE_API_KEY, blockchain primeiro" \
  || falha "entrada, bash, chave ou ordem: esperava '$ESP', veio '$O'"
cp "$T/guarda-equipa.orig" "$GE"
# 13. Sai sempre 0: guarda-equipa.sh estragado ou em falta (falha aberto) e sem jq no PATH (cala, sem aviso)
reg "$(linha "$S1" infraestrutura)"
printf 'if then\n' >"$GE"; cala "guarda-equipa.sh estragado (falha aberto)" "$(bash_ "$S1" "$PUSH")" 2>/dev/null
rm -f -- "$GE"; cala "guarda-equipa.sh em falta (falha aberto)" "$(bash_ "$S1" "$PUSH")" 2>/dev/null; cp "$T/guarda-equipa.orig" "$GE"
N=$((N+1)); corre "$(bash_ "$S1" "$PUSH")" /bin; [ "$C" = 0 ] && [ -z "$O" ] && ok "sem jq no PATH (PATH=/bin): sai 0, sem saída" \
  || falha "sem jq no PATH: saída '$O', código $C"
N=$((N+1)); O=$(printf '%s' "$(bash_ "$S1" "$PUSH")" | env -i PATH="$APP" HOME="$H" /bin/sh -c "bash \"$GS\" || true"); C=$?
[ "$(veredito)" = ask ] && ok "a linha de settings.json (bash … || true) pede" || falha "linha de settings.json (veredito '$(veredito)')"
# O próprio guarda-sessao.sh estragado: a linha de settings.json sai 0 e cala; sem o `|| true` sairia 2, e um PreToolUse
# que sai 2 bloqueia a ferramenta (todas as Bash, Monitor e mcp__ de todas as sessões).
cp "$GS" "$T/guarda-sessao.orig"; printf 'if then\n' >"$GS"
N=$((N+1)); O=$(printf '%s' "$(bash_ "$S1" "$PUSH")" | env -i PATH="$APP" HOME="$H" /bin/sh -c "bash \"$GS\" || true" 2>/dev/null); C=$?
[ "$C" = 0 ] && [ -z "$O" ] && ok "guarda-sessao.sh estragado: a linha de settings.json sai 0 e cala" || falha "guarda-sessao.sh estragado: código $C, saída '$O'"
N=$((N+1)); env -i PATH="$APP" HOME="$H" /bin/sh -c "bash \"$GS\"" </dev/null >/dev/null 2>&1; C=$?
[ "$C" = 2 ] && ok "controlo: sem o || true, o script estragado sai 2" || falha "controlo do || true: código $C"
cp "$T/guarda-sessao.orig" "$GS"
# 14. Deriva: a lista fixa de guarda-sessao.sh tem as equipas do case de guarda-equipa.sh (sem *)
LS=$(sed -n 's/^for e in \(.*\); do.*$/\1/p' "$AQUI/guarda-sessao.sh" 2>/dev/null | tr ' ' '\n' | sed '/^$/d' | sort)
LE=$(awk 'index($0, "case \"${1:-}\" in") == 1 { f = 1; next } f && /^esac/ { exit }
  f && match($0, /^[[:space:]]+[a-z]+\)/) { s = substr($0, RSTART, RLENGTH); gsub(/[[:space:])]/, "", s); print s }' "$AQUI/guarda-equipa.sh" | sort)
N=$((N+1)); [ -n "$LS" ] && [ -n "$LE" ] && [ "$LS" = "$LE" ] && ok "deriva: lista fixa igual ao case de guarda-equipa.sh ($(echo $LE))" \
  || falha "deriva: guarda-sessao.sh [$(echo $LS)] e guarda-equipa.sh [$(echo $LE)]"
# 15. Desempenho: 20 000 linhas de outras sessões (metade de tipo equipa) + as desta
awk 'BEGIN { for (i = 0; i < 20000; i++) printf "{\"v\":1,\"tipo\":\"%s\",\"equipa\":\"infraestrutura\",\"ts\":\"2026-11-08T10:00:00.000Z\",\"sessao\":\"%08d-0000-4000-8000-%012d\",\"via\":\"ferramenta\",\"razao_etiquetas\":[\"infra\"],\"ok\":true}\n", (i % 2 ? "equipa" : "pedido"), i, i }' >"$T/outras.jsonl"
{ cat "$T/outras.jsonl"; linha "$S1" infraestrutura; } >"$REG"
tempo "20 000 linhas de outras sessões + 1 desta: pede" "$(bash_ "$S1" "$PUSH")" ask
{ cat "$T/outras.jsonl"; for e in seguranca multimedia marketing infraestrutura blockchain; do linha "$S1" "$e"; done; } >"$REG"
tempo "20 000 linhas + as 5 equipas com guarda nesta sessão + ls -la: cala" "$(bash_ "$S1" 'ls -la')" ''
reg "$(linha "$S1" infraestrutura)"
tempo "~190 KB com $PUSH no fim: a entrada é lida inteira" "$(bash_ "$S1" "$(awk 'BEGIN { for (i = 0; i < 4000; i++) print "echo linha de enchimento 0123456789 abcdefghij" }'; echo "$PUSH")")" ask
# Gerais
N=$((N+1)); [ -f "$GS" ] && /bin/bash -n "$GS" && ok "sintaxe em bash 3.2" || falha "sintaxe (ou guarda-sessao.sh em falta)"
N=$((N+1)); if [ -f "$GS" ] && ! grep -v '^[[:space:]]*#' "$GS" | grep -qE 'pipefail|set[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*-[[:alpha:]]*[eo]'
then ok "N4: o guarda da sessão não tem pipefail, set -e nem set -o"; else falha "N4: pipefail, set -e ou set -o (ou guarda-sessao.sh em falta)"; fi
N=$((N+1)); corre 'lixo'; [ "$C" = 0 ] && [ -z "$O" ] && ok "entrada inválida: cala e sai 0" || falha "entrada inválida (código $C)"
[ "$F" -eq 0 ] && echo "TODOS OK ($N)" || { echo "$F FALHAS de $N"; exit 1; }
