#!/usr/bin/env bash
# Teste de INSTALAÇÃO e RECUPERAÇÃO completas numa instalação isolada (Fase 3).
# Instala a partir desta pasta num HOME temporário, verifica, altera, reverte e compara hashes.
# Nunca toca em ~/.claude real. Exit 0 = tudo OK.
set -u
RAIZ="$(cd "$(dirname "$0")" && pwd -P)"
T=$(mktemp -d) || exit 2
trap 'rm -R -- "$T"' EXIT
H="$T/home"; D="$H/.claude"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }
sha() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }

mkdir -p "$H"

# --- 1. ensaio não escreve nada --------------------------------------------------
bash "$RAIZ/instalar.sh" --destino "$D" --ensaio >/dev/null 2>&1
[ -d "$D" ] && ko "1) o ensaio criou ficheiros" || ok "1) ensaio não escreve nada"

# --- 2. instalação ---------------------------------------------------------------
if bash "$RAIZ/instalar.sh" --destino "$D" >"$T/i1.log" 2>&1; then ok "2) instalação termina com 0"
else ko "2) instalação terminou com erro:"; tail -6 "$T/i1.log"; fi

SK_SRC=$(find "$RAIZ/skills" -maxdepth 1 -type d \( -name direcao-geral -o -name 'equipa-*' \) 2>/dev/null | wc -l | tr -d ' ')
SK=$(find "$D/skills" -maxdepth 1 -type d \( -name direcao-geral -o -name 'equipa-*' \) 2>/dev/null | wc -l | tr -d ' ')
if [ "$SK_SRC" -eq 0 ]; then ok "3) sem skills neste pacote"
elif [ "$SK" -eq "$SK_SRC" ]; then ok "3) skills da Direção Geral: $SK (igual à origem)"
else ko "3) skills: $SK instaladas, $SK_SRC na origem"; fi

# O pacote pode ser parcial (a série de PRs divide os agentes): comparar com a origem.
AG_SRC=$(find "$RAIZ/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
AG=$(find "$D/agents" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$AG_SRC" -eq 0 ]; then ok "4) sem agentes neste pacote (nada a comparar)"
elif [ "$AG" -eq "$AG_SRC" ]; then ok "4) agentes instalados: $AG (igual à origem)"
else ko "4) agentes: $AG instalados, $AG_SRC na origem"; fi

# --- 5. portabilidade: nenhum path da máquina de origem ---------------------------
ANTIGOS=$(grep -rl '/Users/goncaloferro/\.claude' "$D" 2>/dev/null | wc -l | tr -d ' ')
[ "$ANTIGOS" = 0 ] && ok "5) nenhum caminho absoluto da máquina de origem" || ko "5) $ANTIGOS ficheiro(s) ainda com o prefixo antigo"
# O node do destino tem de existir; noutra máquina o sed substitui pelo node local.
NODES=$(jq -r '[.. | objects | select(has("command")) | .command] | .[]' "$D/settings.json" 2>/dev/null \
  | grep -oE '"[^"]*/node"' | tr -d '"' | sort -u)
NODE_OK=1
for n in $NODES; do [ -x "$n" ] || { NODE_OK=0; echo "  node inexistente: $n"; }; done
[ "$NODE_OK" = 1 ] && ok "5) todos os intérpretes node referenciados existem" || ko "5) node referenciado não existe"

# --- 6. hooks descobríveis -------------------------------------------------------
jq -e . "$D/settings.json" >/dev/null 2>&1 && ok "6) settings.json válido" || ko "6) settings.json inválido"
MORTOS=$(jq -r '[.. | objects | select(has("command")) | .command] | .[]' "$D/settings.json" 2>/dev/null \
  | grep -oE "$D/[^\" ]+" | sort -u | while IFS= read -r p; do [ -e "$p" ] || echo x; done | grep -c x)
[ "$MORTOS" = 0 ] && ok "6) todos os comandos de hook apontam para ficheiros existentes" || ko "6) $MORTOS comando(s) de hook quebrados"
FICAM=$(jq -r '[.hooks[]|.[]|.hooks[]]|length' "$D/settings.json" 2>/dev/null)
[ "${FICAM:-0}" -ge 15 ] && ok "6) $FICAM comandos de hook preservados" || ko "6) só $FICAM hooks preservados"

# --- 7. manifesto + permissões ---------------------------------------------------
[ -f "$D/.claude-global-manifest.sha256" ] && ok "7) manifesto criado" || ko "7) sem manifesto"
if [ -f "$D/settings.json" ]; then
  M=$(stat -f %Lp "$D/settings.json" 2>/dev/null || stat -c %a "$D/settings.json")
  [ "$M" = 600 ] && ok "7) settings.json com 0600" || ko "7) settings.json com modo $M"
fi

# --- 8. idempotência: reinstalar não altera o que está igual ---------------------
H1=$(sha "$D/settings.json")
bash "$RAIZ/instalar.sh" --destino "$D" --forcar >/dev/null 2>&1
H2=$(sha "$D/settings.json")
[ "$H1" = "$H2" ] && ok "8) re-instalação é idempotente (settings.json igual)" || ko "8) re-instalação alterou settings.json"

# --- 9. alteração controlada + rollback ------------------------------------------
ANTES_SET=$(sha "$D/settings.json")
printf '\n# alterado pelo teste\n' >> "$D/CLAUDE.md"
mkdir -p "$D/skills/equipa-do-dono"; printf -- '---\nname: equipa-do-dono\n---\n' > "$D/skills/equipa-do-dono/SKILL.md"

bash "$RAIZ/desinstalar.sh" --destino "$D" --ensaio >/dev/null 2>&1
[ -f "$D/.claude-global-manifest.sha256" ] && ok "9) ensaio da desinstalação não remove nada" || ko "9) ensaio removeu o manifesto"

bash "$RAIZ/desinstalar.sh" --destino "$D" >"$T/d1.log" 2>&1; RC=$?
[ "$RC" -eq 1 ] && ok "9) reversão reporta parcial (CLAUDE.md foi alterado)" || ko "9) código $RC, esperado 1"
[ -f "$D/CLAUDE.md" ] && grep -q "alterado pelo teste" "$D/CLAUDE.md" && ok "9) alteração do dono preservada" || ko "9) perdeu a alteração do dono"
[ -f "$D/skills/equipa-do-dono/SKILL.md" ] && ok "9) skill criada pelo dono preservada" || ko "9) apagou skill do dono"
[ ! -d "$D/skills/equipa-ia" ] && ok "9) skills instaladas removidas" || ko "9) skills instaladas ficaram"

# --- 10. hash final: a instalação restaurada volta ao estado anterior ------------
[ -f "$D/settings.json" ] && [ "$(sha "$D/settings.json")" = "$ANTES_SET" ] \
  && ok "10) settings.json restaurado do backup (hash igual)" || ko "10) settings.json não voltou ao estado anterior"

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi
