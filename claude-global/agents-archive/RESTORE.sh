#!/usr/bin/env bash
# Repõe em ~/.claude/agents os agentes arquivados a 2026-10-29 (lista em MANIFEST.sha256).
# Uso: bash RESTORE.sh [--dry-run] [nome ...]
#   sem nomes  repõe todos          ex.: bash RESTORE.sh --dry-run
#   com nomes  repõe só esses       ex.: bash RESTORE.sh growth-hacker resume-tailor
# Nunca sobrescreve: um agente que já exista em ~/.claude/agents fica como está.
set -euo pipefail
ARCHIVE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/agents"
DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi

restored=0; skipped=0; absent=0; found=" "
while read -r _ rel; do
  name="$(basename "$rel" .md)"
  if [ "$#" -gt 0 ]; then
    match=0
    for want in "$@"; do
      if [ "$want" = "$name" ] || [ "$want" = "$rel" ]; then match=1; found="$found$want "; fi
    done
    [ "$match" -eq 1 ] || continue
  fi
  src="$ARCHIVE/$rel"; dst="$DEST/$rel"
  if [ ! -f "$src" ]; then echo "  absent  $rel (já reposto?)"; absent=$((absent + 1)); continue; fi
  if [ -e "$dst" ]; then echo "  skip    $rel (já existe em agents/)"; skipped=$((skipped + 1)); continue; fi
  echo "  restore $rel"
  restored=$((restored + 1))
  [ "$DRY" -eq 1 ] && continue
  mkdir -p "$(dirname "$dst")"
  mv -n "$src" "$dst"
done < "$ARCHIVE/MANIFEST.sha256"

echo "repor=$restored saltar=$skipped ausentes=$absent"
unmatched=0
for want in "$@"; do
  case "$found" in *" $want "*) ;; *) echo "Não está no arquivo: $want" >&2; unmatched=1 ;; esac
done
if [ "$DRY" -eq 1 ]; then echo "Dry run: nada foi alterado."; exit "$unmatched"; fi
# O catálogo do agency-commander regista quais agentes estão instalados. Regenera sempre,
# para que voltar a correr o script repare uma regeneração anterior que tenha falhado.
CATALOG="$HOME/.claude/skills/agency-commander/build_catalog.py"
if [ -f "$CATALOG" ]; then
  python3 "$CATALOG" > /dev/null
  echo "Catálogo do agency-commander regenerado."
fi
exit "$unmatched"
