#!/usr/bin/env bash
# Guarda contra a regressão dos patches a agentes de terceiros (docs/PATCHES-TERCEIROS.md).
# Falha se um padrão perigoso voltar a um agente ATIVO. Exit 0 = tudo OK.
set -u
RAIZ="$(cd "$(dirname "$0")" && pwd -P)"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }

# Sem os agentes-alvo (PRs que só trazem a guarda), não há nada para verificar.
# Cada agente presente é validado; o skip só acontece se NENHUM dos quatro existir.
if [ ! -f "$RAIZ/agents/security/blockchain-security-auditor.md" ] && \
   [ ! -f "$RAIZ/agents/security/penetration-tester.md" ] && \
   [ ! -f "$RAIZ/agents/engineering/incident-response-commander.md" ] && \
   [ ! -f "$RAIZ/agents/engineering/multi-agent-systems-architect.md" ]; then
  echo "skip: agentes-alvo não estão neste conjunto de ficheiros"
  exit 0
fi

# 1) decimals(): dividir por decimals() em vez de 10 ** decimals()
# Apanha também a forma com cast: `/ uint256(priceFeed.decimals())`.
if grep -rn "priceFeed\.decimals()" "$RAIZ/agents" 2>/dev/null \
   | grep -qE '/ *priceFeed\.decimals\(\)|/ *uint256\( *priceFeed\.decimals'; then
  ko "1) divisão por priceFeed.decimals() (fator de escala errado)"
else
  ok "1) normalização de decimais usa 10 ** decimals()"
fi
BC="$RAIZ/agents/security/blockchain-security-auditor.md"
if [ -f "$BC" ]; then
  # qualquer divisão pelo número de casas (com ou sem cast) é o fator errado
  if grep -qE '/ *uint256\( *priceFeed\.decimals\(\) *\)|/ *priceFeed\.decimals\(\)' "$BC"; then
    ko "1) divisão pelo número de casas (com ou sem cast)"
  else ok "1) sem divisão por decimals()"; fi
  grep -q "10 \*\* uint256(priceFeed.decimals())" "$BC" \
    && ok "1) o fator correto está presente" || ko "1) falta o fator 10 ** decimals()"
  # a presença do fator não chega: a DIVISÃO tem de o usar (em `return ... / scale` ou
  # numa variável intermédia, como em `uint256 valor = (amount * price) / scale;`)
  grep -qE '/ *scale' "$BC" \
    && ok "1) a divisão usa scale" || ko "1) a divisão não usa scale"
  grep -qi 'moeda de cota\|unidades' "$BC" && ok "1) unidades documentadas" || ko "1) unidades não documentadas"
else
  ok "1) blockchain-security-auditor ausente neste conjunto (nada a verificar)"
fi

# 2) penetration-tester: sondagem só dentro do âmbito
PT="$RAIZ/agents/security/penetration-tester.md"
if [ -f "$PT" ]; then
  grep -q 'SCOPE_FILE=' "$PT" && ok "2) âmbito obrigatório presente" || ko "2) sem SCOPE_FILE"
  grep -qE 'grep +-Fxf +"\$SCOPE_FILE"' "$PT" && ok "2) in-scope produzido pelo filtro de escopo" \
    || ko "2) in-scope.txt não é produzido pelo filtro (uma cópia sem filtro passaria)"
  grep -q 'no-follow-redirects' "$PT" && ok "2) redirects não são seguidos" \
    || ko "2) -follow-redirects pode sair do âmbito"
  # nenhum scanner pode apontar ao conjunto sem filtro
  if grep -nE '(dnsx|httpx|naabu|whatweb).*-l? *"\$OUT/subdomains\.txt"|-list "\$OUT/subdomains\.txt"' "$PT" | grep -q .; then
    ko "2) scanner aponta a subdomains.txt (sem filtro de âmbito)"
  else
    ok "2) scanners usam in-scope.txt"
  fi
else ok "2) penetration-tester ausente neste conjunto (nada a verificar)"; fi

# 3) incident-response-commander: namespace/contexto confirmados
IR="$RAIZ/agents/engineering/incident-response-commander.md"
if [ -f "$IR" ]; then
  # apanha também as formas com opções globais antes do subcomando
  if grep -qE 'kubectl .*(-n|--namespace) +production' "$IR"; then
    ko "3) kubectl com namespace fixo (production)"
  else ok "3) kubectl sem namespace presumido"; fi
  grep -q 'CTX=' "$IR" && ok "3) contexto explícito" || ko "3) sem CTX confirmado"
else ok "3) incident-response-commander ausente neste conjunto (nada a verificar)"; fi

# 4) multi-agent: registo com redação
MA="$RAIZ/agents/engineering/multi-agent-systems-architect.md"
if [ -f "$MA" ]; then
  # "unredacted" também casa com "redacted": exigir a instrução positiva
  # exigir a instrução de redação E a ordem "antes de gravar"; rejeitar "unredacted"
  if grep -qi 'redact' "$MA" && grep -qi 'before' "$MA" && ! grep -qi 'unredacted' "$MA"; then
    ok "4) registo exige redação (e não pede unredacted)"
  else ko "4) log sem exigência clara de redação"; fi
else ok "4) multi-agent-systems-architect ausente neste conjunto (nada a verificar)"; fi

# 5) nenhum agente ATIVO recomenda comandos destrutivos sem aviso explícito
DESTR=$(grep -rlnE 'git reset --hard|git clean -[a-z]*f|rm -rf /( |$)|--no-preserve-root' "$RAIZ/agents" 2>/dev/null || true)
if [ -n "$DESTR" ]; then
  # permitido apenas se o ficheiro avisar explicitamente
  for f in $DESTR; do
    # O aviso tem de estar no mesmo bloco de código que o comando (até 6 linhas antes).
    while IFS=: read -r ln _; do
      inicio=$(( ln > 6 ? ln - 6 : 1 ))
      if ! sed -n "${inicio},${ln}p" "$f" | grep -qiE 'n[aã]o (usar|executar)|never run|do not run|perigoso|destrutiv'; then
        ko "5) comando destrutivo sem aviso no bloco: ${f#$RAIZ/}:$ln"
      fi
    done < <(grep -nE 'git reset --hard|git clean -[a-z]*f|rm -rf /( |$)|--no-preserve-root' "$f")
  done
  [ "$FALHAS" -eq 0 ] && ok "5) comandos destrutivos (se existem) têm aviso"
else
  ok "5) sem comandos destrutivos nos agentes ativos"
fi

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi
