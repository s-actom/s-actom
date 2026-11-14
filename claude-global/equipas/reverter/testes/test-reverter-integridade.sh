#!/usr/bin/env bash
# Regressão dos achados CodeRabbit no PR #1 sobre reverter-fase-1.sh:
#   (a) cópia corrompida no backup nunca deve substituir o ficheiro atual;
#   (b) falha ao remover uma skill não pode apagar instalado.sha256 (perde a lista da reversão).
# Corre num HOME totalmente temporário. Sem rede. Exit 0 = tudo OK.
set -u
T=$(mktemp -d) || exit 2
trap 'chmod -R u+rwX -- "$T" 2>/dev/null; rm -R -- "$T"' EXIT
H="$T/home"; C="$H/.claude"; BASE="$C/equipas"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }
sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }

REPO="$(cd "$(dirname "$0")/../../.." && pwd -P)"   # raiz de claude-global/
[ -d "$REPO/equipas/reverter" ] || { echo "sem $REPO/equipas/reverter" >&2; exit 2; }

montar() {
  rm -Rf -- "$H"; mkdir -p "$C" "$BASE"
  cp -R "$REPO/equipas/reverter" "$BASE/reverter"
  rm -Rf -- "$BASE/reverter/testes"
  # ficheiros que a Fase 1 toca
  printf '{"hooks":{}}\n' >"$C/settings.json"
  printf '# CLAUDE\n' >"$C/CLAUDE.md"
  mkdir -p "$C/skills/agency-commander"; printf 'a\n' >"$C/skills/agency-commander/SKILL.md"
  echo '{}' >"$C/settings.local.json"
  mkdir -p "$C/hooks" "$C/rules"; echo x >"$C/hooks/h.js"; echo r >"$C/rules/r.md"

  # backup sintético: estado ANTES (o que deve ser reposto)
  B="$BASE/backups/fase-1-20261108-142034"
  mkdir -p "$B/ficheiros" "$B/pares"
  cp "$C/settings.json" "$B/ficheiros/settings.json"
  cp "$C/CLAUDE.md" "$B/ficheiros/CLAUDE.md"
  cp "$C/skills/agency-commander/SKILL.md" "$B/ficheiros/skills_agency-commander"
  ( cd "$C" && shasum -a 256 settings.json CLAUDE.md skills/agency-commander/SKILL.md ) \
    | sed 's|  |  ./|' >"$B/ANTES.sha256"
  printf 'backup=backups/fase-1-20261108-142034\nestado=ativa\nativada=2026-11-08T14:20:35+0100\n' >"$BASE/FASE-1-ATIVA"

  # a "ativação" mudou settings.json e CLAUDE.md (estado DEPOIS)
  printf '{"hooks":{"X":1}}\n' >"$C/settings.json"
  printf '# CLAUDE fase1\n' >"$C/CLAUDE.md"
  ( cd "$C" && shasum -a 256 settings.json CLAUDE.md ) | sed 's|  |  ./|' >"$B/DEPOIS.sha256"
  mkdir -p "$BASE/estado"
  ORIG_SET="$(sha "$C/settings.json")"
}

reverter() { HOME="$H" bash "$BASE/reverter/reverter-fase-1.sh" "$@"; }

# --- (a) cópia do backup corrompida: não pode publicar lixo ---
montar
printf 'CORROMPIDO\n' >"$B/ficheiros/settings.json"
reverter --aplicar >"$T/out-a.txt" 2>&1; RC=$?
if [ "$(sha "$C/settings.json")" = "$ORIG_SET" ]; then
  ok "a) backup corrompido: settings.json intacto (não substituído por lixo)"
else
  ko "a) backup corrompido substituiu settings.json (bug de integridade)"
fi
[ "$RC" -eq 1 ] && ok "a) sai 1 (pendente), não 0" || ko "a) código de saída $RC, esperado 1"
grep -qi "FALHOU a reposição" "$T/out-a.txt" && ok "a) reporta a falha" || ko "a) não reporta a falha"
[ ! -e "$C/settings.json.fase1.tmp" ] && ok "a) sem temporário residual" || ko "a) temporário ficou para trás"

# --- (b) remoção de skill falhada: preservar instalado.sha256 ---
montar
reverter --aplicar >/dev/null 2>&1   # aplicar primeiro para ter skills instaladas? não: montamos a lista à mão
montar
mkdir -p "$C/skills/equipa-teste"
printf 'conteudo\n' >"$C/skills/equipa-teste/a.md"
H_SK="$(sha "$C/skills/equipa-teste/a.md")"
printf '%s  equipa-teste/a.md\n' "$H_SK" >"$BASE/estado/instalado.sha256"
# tornar a remoção impossível: retirar escrita ao diretório da skill
chmod 500 "$C/skills/equipa-teste"
reverter --aplicar >"$T/out-b.txt" 2>&1; RC=$?
chmod 700 "$C/skills/equipa-teste" 2>/dev/null
if [ -f "$BASE/estado/instalado.sha256" ]; then
  ok "b) remoção falhada: instalado.sha256 preservado (reversão pode ser repetida)"
else
  ko "b) instalado.sha256 apagado apesar da falha (perde a lista da reversão)"
fi
grep -qi "FALHOU a remover" "$T/out-b.txt" && ok "b) reporta a falha de remoção" || ko "b) falha não reportada"
[ "$RC" -eq 1 ] && ok "b) sai 1 (pendente)" || ko "b) código de saída $RC, esperado 1"

# --- (c) caminho feliz: reposição válida funciona ---
montar
reverter --aplicar >/dev/null 2>&1; RC=$?
ANTES_SET="$(awk '$2=="./settings.json"{print $1}' "$B/ANTES.sha256")"
if [ "$(sha "$C/settings.json")" = "$ANTES_SET" ]; then
  ok "c) caso válido: settings.json reposto byte a byte do backup"
else
  ko "c) caso válido não repôs o settings.json"
fi
[ "$RC" -eq 0 ] || ko "c) saída esperada 0, obtida $RC"

# --- (d) skills/equipa-X é uma ligação para fora: não apagar o ficheiro externo ---
montar
EXT="$T/externo"; mkdir -p "$EXT"
printf 'importante\n' > "$EXT/a.md"
H_EXT="$(sha "$EXT/a.md")"
mkdir -p "$C/skills"; ln -s "$EXT" "$C/skills/equipa-teste"
printf '%s  equipa-teste/a.md\n' "$H_EXT" > "$BASE/estado/instalado.sha256"
reverter --aplicar >"$T/out-d.txt" 2>&1; RC=$?
if [ -f "$EXT/a.md" ]; then ok "d) ligação para fora: ficheiro externo preservado"
else ko "d) o rm atravessou a ligação e apagou um ficheiro de fora"; fi
grep -qiE "fora de skills|ligação simbólica" "$T/out-d.txt" && ok "d) reporta o motivo" || ko "d) não reporta"
[ "$RC" -eq 1 ] && ok "d) sai 1 (pendente)" || ko "d) código $RC, esperado 1"

# --- (e) skill equipa-* criada pelo dono DEPOIS da ativação não bloqueia a reversão ---
# Uma só reversão: a instalação criou equipa-instalada; o dono criou equipa-nova depois.
montar
mkdir -p "$C/skills/equipa-instalada" "$C/skills/equipa-nova"
printf 'instalado\n' > "$C/skills/equipa-instalada/a.md"
printf -- '---\nname: equipa-nova\n---\n' > "$C/skills/equipa-nova/SKILL.md"
printf '%s  equipa-instalada/a.md\n' "$(sha "$C/skills/equipa-instalada/a.md")" > "$BASE/estado/instalado.sha256"
reverter --aplicar >"$T/out-e.txt" 2>&1; RC=$?
[ -f "$C/skills/equipa-nova/SKILL.md" ] && ok "e) a skill nova do dono ficou" || ko "e) apagou a skill do dono"
[ ! -e "$C/skills/equipa-instalada/a.md" ] && ok "e) a skill instalada foi removida" || ko "e) não removeu a skill instalada"
[ "$RC" -eq 0 ] && ok "e) reversão conclui (exit 0)" || { ko "e) exit $RC: skill alheia deixou a reversão pendente"; sed -n '1,6p' "$T/out-e.txt"; }
[ ! -f "$BASE/FASE-1-ATIVA" ] && ok "e) marca removida" || ko "e) marca ficou"

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi
