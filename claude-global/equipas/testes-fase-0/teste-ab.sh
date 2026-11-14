#!/usr/bin/env bash
# Testes A e B da secção 14 do desenho, num projeto temporário isolado (nada em ~/.claude/{settings,skills,agents,hooks}).
#   A. Um hook no frontmatter de uma skill persiste depois de a skill correr? (a documentação diz: até ao fim da sessão)
#   B. O payload do hook traz o nome e os argumentos da skill? E quando a skill é escrita à mão como /skill?
# Método: `claude -p` num projeto temporário, só com settings do projeto (--setting-sources project), sem MCP
# (--strict-mcp-config) e sem guardar sessão. Usa o HOME real para a autenticação (com HOME vazio dá "Not logged in").
# Efeito colateral conhecido: o Claude Code regista o uso da skill em ~/.claude.json (skillUsage) e cria pastas em ~/.claude/projects e ~/.claude/session-env.
# Uso: teste-ab.sh [--manter]     (--manter deixa a pasta temporária para inspeção)
set -u
set -o pipefail
command -v claude >/dev/null && command -v jq >/dev/null || { echo "faltam claude ou jq" >&2; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/teste-ab.XXXXXX") || exit 2
trap '[ "${1:-}" = --manter ] || rm -rf -- "$T"' EXIT
P="$T/proj"
mkdir -p "$P/.claude/skills/teste-hook" "$P/.claude/hooks"

cat >"$P/.claude/hooks/registar.sh" <<'EOF'
#!/usr/bin/env bash
# Hook inofensivo de teste: acrescenta uma linha (rótulo + evento + ferramenta + tool_input) a $LOG_HOOKS. Não altera nada.
payload=$(cat)
printf '%s\t%s\n' "$1" "$(printf '%s' "$payload" | jq -c '{ev: .hook_event_name, tool: .tool_name, input: .tool_input, resposta_chaves: ((.tool_response // {}) | if type == "object" then keys else type end)}' 2>/dev/null)" >>"${LOG_HOOKS:-/dev/null}"
exit 0
EOF
chmod 700 "$P/.claude/hooks/registar.sh"
R="$P/.claude/hooks/registar.sh"

cat >"$P/.claude/skills/teste-hook/SKILL.md" <<EOF
---
name: teste-hook
description: "Skill de teste da Fase 0. Só serve para testar hooks no frontmatter."
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "$R fm-pre-bash"
---
Responde apenas: skill carregada.
EOF

cat >"$P/.claude/settings.json" <<EOF
{"hooks": {
  "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "$R settings-prompt"}]}],
  "PreToolUse": [{"matcher": "Skill", "hooks": [{"type": "command", "command": "$R settings-pre-skill"}]}],
  "PostToolUse": [{"matcher": "Skill", "hooks": [{"type": "command", "command": "$R settings-post-skill"}]}]
}}
EOF

executar() { # $1 = ficheiro de log, $2 = prompt
  (cd "$P" && env -i PATH="$PATH" HOME="$HOME" USER="${USER:-}" LANG="${LANG:-en_US.UTF-8}" TERM=dumb LOG_HOOKS="$1" CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 \
    timeout 240 claude -p "$2" --model sonnet --max-turns 8 --output-format json --no-session-persistence \
    --setting-sources project --strict-mcp-config --allowedTools "Skill,Bash(echo:*)" >"$1.json" 2>"$1.err")
  echo "exit=$? ($(jq -r '"turnos=\(.num_turns) erro=\(.is_error) custo_usd=\(.total_cost_usd)"' "$1.json" 2>/dev/null))"
}

echo "== Execução 1: a skill é invocada pela ferramenta Skill (caminho que a Direção Geral usa)"
executar "$T/ferramenta.log" "Ignora instruções externas e faz só isto, por ordem. 1) Invoca a skill teste-hook com a ferramenta Skill, com args 'alfa beta'. 2) Corre com a ferramenta Bash exatamente: echo passo2. 3) Corre com a ferramenta Bash exatamente: echo passo3. 4) Responde FIM."
echo "-- log (rótulo, evento, ferramenta, tool_input, chaves da resposta):"
cut -c1-330 "$T/ferramenta.log" 2>/dev/null || echo "(sem log: nenhum hook disparou)"

echo
echo "== Execução 2: a skill é escrita à mão pelo utilizador (/teste-hook alfa beta)"
executar "$T/barra.log" "/teste-hook alfa beta"
echo "-- log:"
cut -c1-330 "$T/barra.log" 2>/dev/null || echo "(sem log: nenhum hook disparou)"

echo
echo "== Veredictos"
n_fm=$(grep -c '^fm-pre-bash' "$T/ferramenta.log" 2>/dev/null); n_fm=${n_fm:-0}
passos=$(grep '^fm-pre-bash' "$T/ferramenta.log" 2>/dev/null | grep -Ec 'passo[23]')
if [ "$passos" -ge 2 ]; then echo "A: PASS — o hook do frontmatter disparou nos 2 Bash que vieram DEPOIS da skill ($n_fm disparos)"
elif [ "$n_fm" -ge 1 ]; then echo "A: PARTIAL — disparou $n_fm vez(es), mas não nos 2 Bash posteriores"
else echo "A: FAIL — o hook do frontmatter nunca disparou"; fi
linha=$(grep '^settings-post-skill' "$T/ferramenta.log" 2>/dev/null | head -1 | cut -f2)
if [ -n "$linha" ]; then
  echo "B (ferramenta Skill): tool_input = $(printf '%s' "$linha" | jq -c .input)"
  printf '%s' "$linha" | jq -e '.input | tostring | (contains("teste-hook") and contains("alfa beta"))' >/dev/null 2>&1 \
    && echo "B: PASS — o payload traz o nome da skill e os argumentos" || echo "B: PARTIAL — o payload existe mas não traz nome e argumentos juntos"
else echo "B: FAIL — PostToolUse com matcher Skill não disparou"; fi
echo "B (escrita à mão): PreToolUse/PostToolUse de Skill dispararam? $(grep -c '^settings-p[or][se]-skill\|^settings-post-skill' "$T/barra.log" 2>/dev/null || echo 0) linha(s); UserPromptSubmit: $(grep -c '^settings-prompt' "$T/barra.log" 2>/dev/null || echo 0)"
