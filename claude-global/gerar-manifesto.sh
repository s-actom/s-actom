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
ORIGINAL_DE=""
sha() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --destino) [ $# -ge 2 ] || { echo "falta --destino" >&2; exit 2; }; DESTINO="$2"; shift 2 ;;
    --saida)   [ $# -ge 2 ] || { echo "falta --saida" >&2; exit 2; }; SAIDA="$2"; shift 2 ;;
    # Reutiliza o hash_original de um manifesto anterior: depois de aplicar, o destino já
    # tem a versão corrigida e relê-lo perderia o "antes" verdadeiro.
    --original-de) [ $# -ge 2 ] || { echo "falta --original-de" >&2; exit 2; }; ORIGINAL_DE="$2"; shift 2 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done
[ -d "$DESTINO" ] || { echo "destino inexistente: $DESTINO" >&2; exit 2; }
[ -z "$ORIGINAL_DE" ] || [ -f "$ORIGINAL_DE" ] || { echo "sem ficheiro --original-de: $ORIGINAL_DE" >&2; exit 2; }

# Lista fechada: 13 correções + guarda-equipa.sh e o seu teste (vaga final)
# + os testes que as correções alteram/criam (aplicados para poderem correr no destino).
FICHEIROS="
equipas/hooks/portao.mjs
equipas/hooks/atualizar.py
equipas/hooks/guarda-equipa.sh
equipas/hooks/tests/test-guarda-equipa.sh
equipas/gerador/tests/test_atualizar.py
equipas/reverter/reverter-fase-1.sh
equipas/reverter/testes/test-reverter-integridade.sh
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
testes-agentes.sh
equipas/modelos/autorizacao.json
equipas/modelos/descobrir.py
equipas/modelos/README.md
equipas/hooks/lib/modelos.mjs
equipas/hooks/modelo-executado.mjs
equipas/hooks/registo-equipa.mjs
equipas/hooks/tests/modelos.test.mjs
equipas/gerador/tests/test_descobrir.py
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
    # hash_original: preferir o registo anterior (pré-aplicação); senão, o destino atual.
    orig=""
    if [ -n "$ORIGINAL_DE" ]; then
      orig=$(awk -F'\t' -v r="$rel" '$1 == r {print $2; exit}' "$ORIGINAL_DE")
    fi
    if [ -z "$orig" ]; then
      if [ -f "$DESTINO/$rel" ]; then orig=$(sha "$DESTINO/$rel"); else orig="-"; fi
    fi
    # hash_esperado_antes: exatamente o que o aplicador vai encontrar AGORA no destino
    # (ou "-" se não existir). Usar o valor histórico aqui marcaria como conflito uma
    # segunda passagem sobre ficheiros que já aplicámos.
    if [ -f "$DESTINO/$rel" ]; then esp=$(sha "$DESTINO/$rel"); else esp="-"; fi
    printf '%s\t%s\t%s\t%s\n' "$rel" "$orig" "$esp" "$corr"
  done
} >"$TMP" || { rm -f -- "$TMP"; echo "falhou a escrita" >&2; exit 2; }
mv -f -- "$TMP" "$SAIDA" || { rm -f -- "$TMP"; exit 2; }
chmod 644 "$SAIDA" 2>/dev/null || true

n=$(grep -vc '^#' "$SAIDA")
echo "manifesto: $SAIDA ($n ficheiros)"
awk -F'\t' '!/^#/ {printf "  %-58s %s\n", $1, substr($4,1,12)}' "$SAIDA"
