#!/usr/bin/env bash
# fase-2.sh — liga ou desliga a Fase 2 da Direção Geral (JEV a falar). Só mexe em 2 ficheiros de estado/:
#   estado/jev-modo.json (o portão passa a mostrar a proposta do JEV) e estado/fase-2-iniciada (cala o aviso dos 30).
# Uso: bash ~/.claude/equipas/reverter/fase-2.sh ligar | desligar | estado
# Ligar: só o dono, num terminal, depois de arbitrar os desacordos da Fase 1 (hooks/rever.mjs). Desligar é a reversão.
set -euo pipefail
BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
E="$BASE/estado"; M="$E/jev-modo.json"; I="$E/fase-2-iniciada"
case "${1:-estado}" in
  ligar)
    [ -t 0 ] && [ -t 1 ] || { echo "Ligar só no terminal do dono, com confirmação escrita: nada feito." >&2; exit 1; }
    printf 'Ligar a Fase 2 (o JEV passa a propor ao orquestrador)? Escreve sim: '; read -r resp
    [ "$resp" = sim ] || { echo "Nada feito."; exit 1; }
    [ -f "$BASE/FASE-1-ATIVA" ] || { echo "A Fase 1 não está ativa: nada feito." >&2; exit 1; }
    [ -d "$E" ] && [ ! -L "$E" ] || { echo "Pasta estado/ em falta ou insegura: nada feito." >&2; exit 1; }
    for f in "$M" "$M.tmp" "$I"; do [ ! -L "$f" ] || { echo "Ligação simbólica recusada: $f" >&2; exit 1; }; done
    umask 077; rm -f -- "$M.tmp"; set -C
    printf '{"modo":"falar","desde":"%s"}\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" > "$M.tmp"; set +C
    mv -f -- "$M.tmp" "$M"; [ -e "$I" ] || : > "$I"
    echo "Fase 2 ligada: o JEV passa a propor em cada objetivo novo. Desligar: bash $0 desligar" ;;
  desligar)
    rm -f -- "$M" "$I"
    echo "Fase 2 desligada: o JEV volta às escuras." ;;
  estado)
    if [ -f "$M" ] && /usr/bin/jq -e '.modo == "falar"' "$M" >/dev/null 2>&1; then echo "JEV a falar (Fase 2)"; else echo "JEV às escuras (Fase 1)"; fi ;;
  *) echo "Uso: $0 ligar | desligar | estado" >&2; exit 2 ;;
esac
