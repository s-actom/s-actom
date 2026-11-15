#!/usr/bin/env bash
# gerar-manifesto.sh — escreve docs/manifesto-correcoes.tsv com os três hashes por ficheiro.
#
# A lista de ficheiros é a lista fechada das correções já validadas (docs/PLANO-APLICACAO.md
# e docs/PATCHES-TERCEIROS.md). Não é uma cópia do pacote: é a lista do que se aplica.
#
# Uso: gerar-manifesto.sh [--destino DIR] [--saida FICHEIRO]
# Exit: 0 escrito · 2 origem incompleta (nada escrito)
set -u -o pipefail
RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 2
DESTINO="$HOME/.claude"
SAIDA="$RAIZ/docs/manifesto-correcoes.tsv"
sha() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --destino) [ $# -ge 2 ] || { echo "falta --destino" >&2; exit 2; }; DESTINO="$2"; shift 2 ;;
    --saida)   [ $# -ge 2 ] || { echo "falta --saida" >&2; exit 2; }; SAIDA="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
[ -d "$DESTINO" ] || { echo "destino inexistente: $DESTINO" >&2; exit 2; }

# Lista fechada: 13 correções + guarda-equipa.sh e o seu teste (vaga final).
FICHEIROS="
equipas/hooks/portao.mjs
equipas/hooks/atualizar.py
equipas/hooks/guarda-equipa.sh
equipas/hooks/tests/test-guarda-equipa.sh
equipas/reverter/reverter-fase-1.sh
hooks/claude-security-stop-hook.mjs
scripts/coderabbit-review.sh
scripts/coderabbit-review.test.sh
agents/auditoria.md
agents/workspace-automation-auditor.md
agents/conteudo.md
agents/security/blockchain-security-auditor.md
agents/security/penetration-tester.md
agents/engineering/incident-response-commander.md
agents/engineering/multi-agent-systems-architect.md
"

FALTA=0
for rel in $FICHEIROS; do
  [ -f "$RAIZ/$rel" ] || { echo "origem ausente no pacote: $rel" >&2; FALTA=1; }
done
[ "$FALTA" = 0 ] || { echo "nada escrito" >&2; exit 2; }

TMP="$SAIDA.tmp.$$"
{
  echo "# Manifesto de aplicação — gerado por gerar-manifesto.sh em $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "# destino de referência: $DESTINO"
  echo "# rel<TAB>hash_original<TAB>hash_esperado_antes<TAB>hash_corrigido"
  echo "# hash_original = destino aquando da geração ('-' = não existia); hash_esperado_antes = exigido"
  echo "# ao aplicar (divergência = CONFLITO, não substituição); hash_corrigido = versão no pacote."
  for rel in $FICHEIROS; do
    corr=$(sha "$RAIZ/$rel") || exit 2
    [ -n "$corr" ] || { echo "sem hash para $rel" >&2; exit 2; }
    if [ -f "$DESTINO/$rel" ]; then orig=$(sha "$DESTINO/$rel"); else orig="-"; fi
    printf '%s\t%s\t%s\t%s\n' "$rel" "$orig" "$orig" "$corr"
  done
} >"$TMP" || { rm -f -- "$TMP"; echo "falhou a escrita" >&2; exit 2; }
mv -f -- "$TMP" "$SAIDA" || { rm -f -- "$TMP"; exit 2; }
chmod 644 "$SAIDA" 2>/dev/null || true

n=$(grep -vc '^#' "$SAIDA")
echo "manifesto: $SAIDA ($n ficheiros)"
awk -F'\t' '!/^#/ {printf "  %-58s %s\n", $1, substr($4,1,12)}' "$SAIDA"
