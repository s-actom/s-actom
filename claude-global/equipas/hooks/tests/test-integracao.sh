#!/usr/bin/env bash
# Teste de integração dos hooks da Fase 1 com o Claude Code real (`claude -p`, modelo sonnet, ~0,10 USD).
# Corre num projeto temporário com uma CÓPIA dos hooks e só com as settings desse projeto: não liga nada global.
# Por omissão tira TYPESAFE_API_KEY do ambiente (o JEV não é chamado). Com --jev, faz 1 chamada real ao JEV
# (só etiquetas; entradas marcadas teste:true). Deixa o rasto normal do Claude Code em ~/.claude/projects/.
# Correr: bash equipas/hooks/tests/test-integracao.sh [--jev]
# Pré-condições: CLI `claude` no PATH (custa ~0,10 USD) e python3. NÃO corre no CI.
set -u
REAL=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)   # ~/.claude/equipas
COM_JEV=0; [ "${1:-}" = --jev ] && COM_JEV=1
T=$(mktemp -d) && [ -d "$T" ] || exit 2
# O projeto fica fora das pastas temporárias: a rede VibeSec ignora edições em /tmp e /var/folders.
P=$(mktemp -d "$HOME/.equipas-teste.XXXXXX") && [ -d "$P" ] || exit 2
trap 'rm -R -- "$T" "$P"' EXIT
B="$T/base"; CAN="CANARIO-zx9-$$"
mkdir -p "$B" "$P/.claude/skills"
for x in hooks gerador equipas.yaml seguranca.md entradas; do cp -R "$REAL/$x" "$B/"; done
rm -R -- "$B/hooks/tests"; touch "$B/FASE-1-ATIVA"
# rascunho/ é estado gerado, nunca versionado. Se faltar, gera-se numa cópia: assim o teste
# corre a partir do repositório e não só da máquina onde o rascunho já existia.
RASC="$REAL/rascunho"
if [ ! -d "$RASC/equipa-pesquisa" ]; then
  command -v python3 >/dev/null 2>&1 || { echo "PRECONDIÇÃO: python3 em falta para gerar rascunho/" >&2; exit 2; }
  GR=$(mktemp -d) || exit 2
  trap 'rm -R -- "$T" "$P" "$GR"' EXIT
  cp -R "$REAL"/equipas.yaml "$REAL"/seguranca.md "$REAL"/entradas "$REAL"/gerador "$GR"/ 2>/dev/null
  # exit 1 = a verificação do desenho falhou, MAS os ficheiros são escritos; exigimos só o skill.
  python3 -I "$GR/gerador/gerar.py" --modo vivo --home "$(mktemp -d)" --saida "$GR" >/dev/null 2>&1 || true
  RASC="$GR/rascunho"
fi
[ -d "$RASC/equipa-pesquisa" ] || { echo "PRECONDIÇÃO: não foi possível obter rascunho/equipa-pesquisa" >&2; exit 2; }
cp -R "$RASC/equipa-pesquisa" "$P/.claude/skills/"
NODE=$(command -v node)
c() { printf '{"type":"command","command":"\\"%s\\" \\"%s\\"","timeout":%s}' "$NODE" "$B/hooks/$1" "$2"; }
cat >"$P/.claude/settings.json" <<EOF
{"hooks": {
  "UserPromptSubmit": [{"hooks": [$(c portao.mjs 5)]}],
  "PostToolUse": [{"matcher": "Skill", "hooks": [$(c registo-equipa.mjs 5)]}],
  "UserPromptExpansion": [{"hooks": [$(c registo-equipa.mjs 5)]}],
  "SessionStart": [{"hooks": [$(c arranque.mjs 5)]}],
  "Stop": [{"hooks": [{"type": "command", "command": "bash \"$B/hooks/rede-vibesec.sh\"", "timeout": 15}]}]
}}
EOF
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }
cp_() { # $1 nome, $2 prompt, $3 ferramentas
  if [ $COM_JEV -eq 1 ]; then E=(env EQUIPAS_TESTE=1); else E=(env -u TYPESAFE_API_KEY EQUIPAS_TESTE=1); fi
  (cd "$P" && "${E[@]}" timeout 240 claude -p "$2" --model sonnet --max-turns 4 --output-format json \
    --setting-sources project --strict-mcp-config --allowedTools "$3" >"$T/$1.json" 2>"$T/$1.err")
}

cp_ a "Invoca a skill equipa-pesquisa com a ferramenta Skill e com args exatamente 'porquê: teste de integração'. Depois responde só OK. Referência interna: $CAN em /Users/dono/projeto-x." "Skill"
cp_ b "/equipa-pesquisa $CAN argumento do dono" "Skill"
cp_ c "Usa a ferramenta Write para criar o ficheiro app.py nesta pasta com a linha print(1). Não faças mais nada e não corras verificações." "Write"
sleep 3   # o refrescamento das listas corre em segundo plano

R="$B/registo.jsonl"
[ -f "$R" ] && [ "$(stat -f %Lp "$R")" = 600 ] && ok "registo criado com modo 600" || ko "registo em falta ou com modo errado"
jq -e 'select(.tipo == "objetivo" and .teste == true and (.envelope | startswith("@public;")) and (.turno | type == "string"))' "$R" >/dev/null 2>&1 && ok "UserPromptSubmit: objetivo novo com envelope e referência do turno" || ko "objetivo em falta"
jq -e 'select(.tipo == "equipa" and .equipa == "pesquisa" and .via == "ferramenta" and (.razao_etiquetas | test("teste")))' "$R" >/dev/null 2>&1 && ok "PostToolUse[Skill]: equipa e razão" || ko "registo pela ferramenta em falta"
jq -e 'select(.tipo == "equipa" and .equipa == "pesquisa" and .via == "comando" and .razao_etiquetas == null)' "$R" >/dev/null 2>&1 && ok "UserPromptExpansion: /equipa-pesquisa registado sem os argumentos" || ko "registo por /equipa-x em falta"
jq -e 'select(.tipo == "pedido" and .portao == "comando")' "$R" >/dev/null 2>&1 && ok "portão: /comando não é objetivo" || ko "portão do comando"
! grep -rq -- "$CAN\|/Users/dono\|projeto-x" "$B/registo.jsonl" "$B/estado" 2>/dev/null && ok "nenhum texto do pedido no registo nem no estado" || ko "texto do pedido apareceu"
if [ -n "${TYPESAFE_API_KEY:-}" ]; then
  ! grep -rqF -f <(printf '%s\n' "$TYPESAFE_API_KEY") "$B" "$T"/*.json "$T"/*.err 2>/dev/null && ok "a chave não aparece em nenhum ficheiro" || ko "a chave apareceu num ficheiro"
fi
[ -s "$B/estado/vibesec-avisos" ] && ok "Stop: a rede VibeSec lembrou depois do Write" || ko "rede VibeSec não disparou"
jq -e '.codigo == 0' "$B/estado/arranque.json" >/dev/null 2>&1 && ok "SessionStart: refrescamento em segundo plano correu (código 0)" || ko "arranque.json: $(cat "$B/estado/arranque.json" 2>/dev/null)"
echo "JEV: $(jq -c 'select(.tipo == "objetivo") | .jev | {estado, motivo, primaria, colaboradoras, ms}' "$R" 2>/dev/null | tr '\n' ' ')"
[ "$FALHAS" -eq 0 ] && echo "TODOS OK" || { echo "$FALHAS FALHAS"; for f in a b c; do echo "--- $f"; head -c 400 "$T/$f.err"; jq -r '.result // empty' "$T/$f.json" 2>/dev/null | head -c 300; done; exit 1; }
