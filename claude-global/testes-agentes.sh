#!/usr/bin/env bash
# Guarda contra a regressão dos patches a agentes de terceiros (docs/PATCHES-TERCEIROS.md).
# Falha se um padrão perigoso voltar a um agente ATIVO. Exit 0 = tudo OK.
set -u
RAIZ="$(cd "$(dirname "$0")" && pwd -P)"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }

# 1) decimals(): dividir por decimals() em vez de 10 ** decimals()
if grep -rn "priceFeed\.decimals()" "$RAIZ/agents" 2>/dev/null | grep -qE '/ *priceFeed\.decimals\(\)'; then
  ko "1) divisão por priceFeed.decimals() (fator de escala errado)"
else
  ok "1) normalização de decimais usa 10 ** decimals()"
fi
grep -q "10 \*\* uint256(priceFeed.decimals())" "$RAIZ/agents/security/blockchain-security-auditor.md" \
  && ok "1) o fator correto está presente" || ko "1) falta o fator 10 ** decimals()"

# 2) penetration-tester: sondagem só dentro do âmbito
PT="$RAIZ/agents/security/penetration-tester.md"
if [ -f "$PT" ]; then
  grep -q 'SCOPE_FILE=' "$PT" && ok "2) âmbito obrigatório presente" || ko "2) sem SCOPE_FILE"
  # nenhum scanner pode apontar ao conjunto sem filtro
  if grep -nE '(dnsx|httpx|naabu|whatweb).*-l? *"\$OUT/subdomains\.txt"|-list "\$OUT/subdomains\.txt"' "$PT" | grep -q .; then
    ko "2) scanner aponta a subdomains.txt (sem filtro de âmbito)"
  else
    ok "2) scanners usam in-scope.txt"
  fi
else ko "2) penetration-tester.md ausente"; fi

# 3) incident-response-commander: namespace/contexto confirmados
IR="$RAIZ/agents/engineering/incident-response-commander.md"
if [ -f "$IR" ]; then
  if grep -qE 'kubectl (rollout|get) [^#]* -n production' "$IR"; then
    ko "3) kubectl com -n production fixo"
  else ok "3) kubectl sem namespace presumido"; fi
  grep -q 'CTX=' "$IR" && ok "3) contexto explícito" || ko "3) sem CTX confirmado"
else ko "3) incident-response-commander.md ausente"; fi

# 4) multi-agent: registo com redação
MA="$RAIZ/agents/engineering/multi-agent-systems-architect.md"
if [ -f "$MA" ]; then
  grep -qi "redacted" "$MA" && ok "4) registo exige redação" || ko "4) log sem redação"
else ko "4) multi-agent-systems-architect.md ausente"; fi

# 5) nenhum agente ATIVO recomenda comandos destrutivos sem aviso explícito
DESTR=$(grep -rlnE 'git reset --hard|git clean -[a-z]*f|rm -rf /( |$)|--no-preserve-root' "$RAIZ/agents" 2>/dev/null || true)
if [ -n "$DESTR" ]; then
  # permitido apenas se o ficheiro avisar explicitamente
  for f in $DESTR; do
    if ! grep -qiE 'n[aã]o (usar|executar)|never run|do not run|perigoso|destrutiv' "$f"; then
      ko "5) comando destrutivo sem aviso: ${f#$RAIZ/}"
    fi
  done
  [ "$FALHAS" -eq 0 ] && ok "5) comandos destrutivos (se existem) têm aviso"
else
  ok "5) sem comandos destrutivos nos agentes ativos"
fi

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi
