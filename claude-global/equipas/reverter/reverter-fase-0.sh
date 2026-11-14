#!/usr/bin/env bash
# reverter-fase-0.sh — desfaz a Fase 0: remove os ficheiros do MANIFESTO.sha256, mas só os que ainda têm o sha256 do manifesto.
# Atua SEMPRE na pasta onde o script está (a pasta acima de reverter/). Não aceita outro caminho.
# Uso: reverter-fase-0.sh              dry-run: mostra o que removeria (por omissão)
#      reverter-fase-0.sh --manifesto  (re)gera reverter/MANIFESTO.sha256 com todos os ficheiros desta pasta
#      reverter-fase-0.sh --aplicar    remove os ficheiros do manifesto cujo sha256 não mudou; no fim apaga também *.pyc e pastas vazias
# Saída: 0 ok · 1 manifesto em falta ou inválido · 2 uso ou caminho inseguro
set -u
set -o pipefail

BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P) || { echo "pasta base ilegível" >&2; exit 2; }
SCRIPT_REL="reverter/reverter-fase-0.sh"
MANIF_REL="reverter/MANIFESTO.sha256"
MANIF="$BASE/$MANIF_REL"
[ -f "$BASE/$SCRIPT_REL" ] || { echo "este script tem de estar em <base>/reverter/" >&2; exit 2; }
case "$BASE" in / | "$HOME") echo "base insegura: $BASE" >&2; exit 2 ;; esac

MODO=dry
case "${1:-}" in
  "") ;;
  --manifesto) MODO=manifesto ;;
  --aplicar) MODO=aplicar ;;
  -h | --help) sed -n '2,7p' "$0"; exit 0 ;;
  *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
esac
[ $# -le 1 ] || { echo "demasiados argumentos" >&2; exit 2; }
if [ "$MODO" = aplicar ] && [ -e "$BASE/FASE-1-ATIVA" ]; then
  echo "A Fase 1 está ativa e as skills dela citam seguranca.md e equipas.yaml. Corre primeiro: bash $BASE/reverter/reverter-fase-1.sh --aplicar" >&2
  exit 2
fi

sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }

seguro() { # só caminhos relativos, sem '..'
  case "$1" in "" | /* | .. | ../* | */.. | */../*) return 1 ;; esac
  return 0
}

if [ "$MODO" = manifesto ]; then
  tmp="$MANIF.tmp"
  mkdir -p -- "$BASE/reverter"
  rm -f -- "$tmp"  # nunca escrever através de uma ligação pré-colocada
  ( set -C; : >"$tmp" ) || { echo "não consegui criar $tmp" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    printf '%s  %s\n' "$(sha "$f")" "${f#"$BASE"/}" >>"$tmp"
  done < <(find "$BASE" -type f ! -path "$MANIF" ! -path "$tmp" ! -path '*/__pycache__/*' ! -name '.DS_Store' \
    ! -path "$BASE/backups/*" ! -path "$BASE/estado/*" ! -path "$BASE/registo.jsonl" -print0 | sort -z)  # dados e backups da Fase 1 nunca entram
  mv -f -- "$tmp" "$MANIF"
  echo "manifesto: $(wc -l <"$MANIF" | tr -d ' ') ficheiros em $MANIF_REL"
  exit 0
fi

[ -f "$MANIF" ] || { echo "sem manifesto: corre --manifesto primeiro" >&2; exit 1; }
# 1.ª passagem: valida o manifesto inteiro; se alguma linha for inválida ou insegura, não se remove nada.
while IFS= read -r linha || [ -n "$linha" ]; do
  [ -n "$linha" ] || continue
  h="${linha%%  *}"
  rel="${linha#*  }"
  [[ "$h" =~ ^[0-9a-f]{64}$ ]] || { echo "manifesto inválido: $linha" >&2; exit 1; }
  seguro "$rel" || { echo "caminho inseguro no manifesto: $rel" >&2; exit 2; }
done <"$MANIF"

n_rem=0 n_fica=0 n_falta=0
while IFS= read -r linha || [ -n "$linha" ]; do
  [ -n "$linha" ] || continue
  h="${linha%%  *}"
  rel="${linha#*  }"
  [ "$rel" = "$SCRIPT_REL" ] && continue
  alvo="$BASE/$rel"
  if [ -L "$alvo" ]; then echo "FICA (ligação simbólica): $rel"; n_fica=$((n_fica + 1)); continue; fi
  if [ ! -f "$alvo" ]; then n_falta=$((n_falta + 1)); continue; fi
  # uma pasta intermédia que seja ligação simbólica levaria o rm para fora da base: só se mexe no que está mesmo dentro dela
  pai=$(cd -- "$(dirname -- "$alvo")" 2>/dev/null && pwd -P) || { n_falta=$((n_falta + 1)); continue; }
  case "$pai/" in "$BASE"/*) ;; *) echo "FICA (fora da base): $rel"; n_fica=$((n_fica + 1)); continue ;; esac
  if [ "$(sha "$alvo")" != "$h" ]; then echo "FICA (alterado depois): $rel"; n_fica=$((n_fica + 1)); continue; fi
  if [ "$MODO" = aplicar ]; then rm -f -- "$alvo"; echo "removido: $rel"; else echo "REMOVERIA: $rel"; fi
  n_rem=$((n_rem + 1))
done <"$MANIF"
echo "resumo: $([ "$MODO" = aplicar ] && echo removidos || echo 'removeria') $n_rem · ficam $n_fica · já não existiam $n_falta"
[ "$MODO" = aplicar ] || exit 0

find "$BASE" -type f -name '*.pyc' -path '*/__pycache__/*' -delete 2>/dev/null
find "$BASE" -depth -type d -empty -delete 2>/dev/null
restantes=$(find "$BASE" ! -type d ! -path "$BASE/$SCRIPT_REL" ! -path "$MANIF" 2>/dev/null | wc -l | tr -d ' ')
if [ "$restantes" = 0 ]; then
  rm -f -- "$MANIF" "$BASE/$SCRIPT_REL"
  find "$BASE" -depth -type d -empty -delete 2>/dev/null
  echo "Fase 0 revertida: pasta removida."
else
  echo "ficam $restantes ficheiro(s) fora do manifesto ou alterados; script e manifesto mantidos."
fi
exit 0
