#!/usr/bin/env bash
# desinstalar.sh — reverte uma instalação feita por instalar.sh.
#
# Uso: desinstalar.sh [--destino DIR] [--ensaio]
#   Remove exatamente os ficheiros do manifesto (.claude-global-manifest.sha256),
#   mas só se o hash ainda corresponder (não apaga o que mudaste depois).
#   Restaura o backup mais recente (.claude-global-backup-<ts>/) por cima.
set -u
DESTINO="$HOME/.claude"
ENSAIO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --destino) [ $# -ge 2 ] || { echo "falta o valor de --destino" >&2; exit 2; }; DESTINO="$2"; shift 2 ;;
    --ensaio) ENSAIO=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
MAN="$DESTINO/.claude-global-manifest.sha256"
erro() { echo "desinstalar: $*" >&2; exit 2; }
ok()   { echo "ok - $*"; }
diz()  { echo "  $*"; }

[ -f "$MAN" ] || erro "sem manifesto em $MAN (não foi este script que instalou?)"
# O instalador regista o backup da SUA instalação; é esse que se restaura.
# Fallback: o mais antigo (estado anterior ao pacote).
if [ -f "$DESTINO/.claude-global-origem" ]; then
  BK=$(head -1 "$DESTINO/.claude-global-origem")
  [ -d "$BK" ] || BK=""
else
  BK=$(ls -d "$DESTINO"/.claude-global-backup-* 2>/dev/null | sort | head -1)
fi

PENDENTE=0; n_rm=0; n_fica=0
while read -r h rel; do
  [ -n "$rel" ] || continue
  alvo="$DESTINO/$rel"
  [ -e "$alvo" ] || continue
  atual=$(shasum -a 256 -- "$alvo" 2>/dev/null | cut -d' ' -f1)
  if [ "$atual" = "$h" ]; then
    if [ "$ENSAIO" = 1 ]; then diz "removeria: $rel"
    elif rm -f -- "$alvo" 2>/dev/null; then n_rm=$((n_rm + 1))
    else diz "FALHOU a remover: $rel"; PENDENTE=1; fi
  else
    diz "fica (mudou depois da instalação): $rel"; n_fica=$((n_fica + 1)); PENDENTE=1
  fi
done <"$MAN"

if [ -n "${BK:-}" ] && [ -d "$BK" ]; then
  if [ "$ENSAIO" = 1 ]; then diz "restauraria de: $BK"; else
    # Sem clobber: um ficheiro que o dono alterou depois da instalação NÃO pode ser
    # sobrescrito pelo backup. Só se restaura o que já não existe (removido acima).
    FALHOU_RESTAURO=0
    while IFS= read -r rel; do
      mkdir -p "$DESTINO/$(dirname "$rel")" 2>/dev/null || { FALHOU_RESTAURO=1; continue; }
      # Sem clobber: um ficheiro que o dono alterou depois da instalação NÃO pode ser
      # sobrescrito pelo backup. Só se restaura o que já não existe (removido acima).
      [ -e "$DESTINO/$rel" ] && continue
      cp -p "$BK/$rel" "$DESTINO/$rel" 2>/dev/null || FALHOU_RESTAURO=1
    done < <( cd "$BK" && find . -type f | sed 's|^\./||' )
    if [ "$FALHOU_RESTAURO" = 0 ]; then ok "backup restaurado de $BK"
    else diz "ATENÇÃO: houve falhas a restaurar de $BK"; PENDENTE=1; fi
  fi
else
  diz "sem backup para restaurar"
fi

if [ "$ENSAIO" = 0 ]; then
  # Diretórios que ficaram vazios por causa das remoções saem também (só se vazios).
  for d in "$DESTINO"/skills/*/ "$DESTINO"/agents/*/; do
    [ -d "$d" ] && rmdir "$d" 2>/dev/null || true
  done
  [ "$PENDENTE" -eq 0 ] && rm -f -- "$MAN"
  ok "$n_rm ficheiros removidos, $n_fica preservados (alterados por ti)"
fi
echo
if [ "$PENDENTE" -eq 0 ]; then echo "REVERSÃO COMPLETA"; exit 0
else echo "REVERSÃO PARCIAL — revê as linhas 'fica': foram alterados depois da instalação."; exit 1; fi
