#!/usr/bin/env bash
# validar.sh — validações da pasta claude-global (local e CI). Exit 0 = tudo PASS.
# Compatível com bash 3.2 (macOS) e Ubuntu. Requer python3; gitleaks é opcional.
set -u
RAIZ="$(cd "$(dirname "$0")" && pwd)"
FALHAS=0
ok()   { printf 'ok - %s\n' "$*"; }
erro() { printf 'FALHOU - %s\n' "$*"; FALHAS=$((FALHAS+1)); }

# --- 1. JSON válido -------------------------------------------------------
for j in settings.json launch.json mcp-configs/mcp-servers.json hooks/package.json; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$RAIZ/$j" 2>/dev/null; then
    ok "JSON válido: $j"
  else
    erro "JSON inválido: $j"
  fi
done

# --- 2. estrutura mínima de equipas.yaml ----------------------------------
for chave in 'versao:' 'camadas:' 'direcao_geral:'; do
  if grep -q "^$chave" "$RAIZ/equipas/equipas.yaml" 2>/dev/null; then
    ok "equipas.yaml contém $chave"
  else
    erro "equipas.yaml sem $chave"
  fi
done

# --- 3. frontmatter das skills da Direção Geral ---------------------------
n=0; maus=""
for s in "$RAIZ"/skills/*/SKILL.md; do
  [ -f "$s" ] || continue
  if grep -q '^name:' "$s" && grep -q '^description:' "$s"; then
    n=$((n+1))
  else
    maus="$maus $s"
  fi
done
if [ "$n" -ge 16 ] && [ -z "$maus" ]; then
  ok "16+ skills (direcao-geral + equipa-*) com frontmatter name/description ($n)"
else
  erro "skills com frontmatter incompleto:$maus (contagem $n)"
fi

# --- 4. segredos ----------------------------------------------------------
# O relatório é privado (mktemp) e apagado no fim: nunca fica legível por outros,
# e nunca imprime o valor encontrado — só ficheiro, linha e tipo.
PADRAO='ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|sk-(ant-)?[A-Za-z0-9_-]{32,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY'
REL_SEGREDOS=$(umask 077; mktemp "${TMPDIR:-/tmp}/validar-segredos.XXXXXX") || REL_SEGREDOS=""
if [ -n "$REL_SEGREDOS" ]; then
  trap 'rm -f -- "$REL_SEGREDOS"' EXIT
fi
ENCONTRADOS=$(grep -rEnI "$PADRAO" "$RAIZ" 2>/dev/null | grep -v 'gitleaks:allow' | grep -v '^\./\.git/' || true)
if [ -n "$ENCONTRADOS" ]; then
  [ -n "$REL_SEGREDOS" ] && printf '%s\n' "$ENCONTRADOS" >"$REL_SEGREDOS"
  erro "possível segredo em $(printf '%s\n' "$ENCONTRADOS" | grep -c .) linha(s) — valores omitidos de propósito:"
  # Greedy até ao ÚLTIMO ":<número>:" — um nome como "credenciais:backup.txt:1:token"
  # não pode escapar ao mascaramento e imprimir o valor. Se nada casar, não sai a linha.
  printf '%s\n' "$ENCONTRADOS" | head -5 | sed -E 's#^(.+):([0-9]+):.*#  \1 linha \2  (conteúdo não impresso)#' \
    | sed -E 's#^(-{0,2}[^ ]*credenciais.*)$#  (ocorrência mascarada)#'
else
  ok "sem padrões de segredo (ghp_/gho_/PAT/sk-/AKIA/PEM)"
fi
if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks detect --source "$RAIZ" --no-git --redact >/dev/null 2>&1; then
    ok "gitleaks limpo"
  else
    erro "gitleaks encontrou findings"
  fi
else
  ok "gitleaks não instalado (saltado; CI corre à parte)"
fi

# --- 5. higiene -----------------------------------------------------------
sujo="$(find "$RAIZ" \( -name '*.bak' -o -name '*.bak-*' -o -name '.DS_Store' -o -name '*.log' -o -name '.env' \) 2>/dev/null | head -5)"
if [ -z "$sujo" ]; then
  ok "sem .bak/.DS_Store/.log/.env"
else
  erro "ficheiros de higiene proibidos: $sujo"
fi
# Artefactos de build/test locais (__pycache__, *.pyc): só são erro se o repo os puder
# apanhar. Com .gitignore a cobri-los, ficam fora do que é versionado (o CI corre esta
# validação antes dos testes, por isso nunca os tem).
if [ -f "$RAIZ/.gitignore" ] && grep -q '__pycache__/' "$RAIZ/.gitignore" && grep -q '\*\.pyc' "$RAIZ/.gitignore"; then
  ok "artefactos de build cobertos pelo .gitignore (__pycache__, *.pyc)"
else
  poder="$(find "$RAIZ" \( -name '__pycache__' -o -name '*.pyc' \) 2>/dev/null | head -5)"
  if [ -z "$poder" ]; then ok "sem __pycache__/*.pyc"
  else erro "__pycache__/*.pyc presentes e não ignorados: $poder"; fi
fi

# --- 6. limites de tamanho -------------------------------------------------
gordos="$(find "$RAIZ" -type f -size +1500k 2>/dev/null | head -5)"
if [ -z "$gordos" ]; then
  ok "nenhum ficheiro >1,5 MB"
else
  erro "ficheiros >1,5 MB: $gordos"
fi

# --- resumo ----------------------------------------------------------------
total="$(find "$RAIZ" -type f | wc -l | tr -d ' ')"
if [ "$FALHAS" -eq 0 ]; then
  printf 'PASS — %s ficheiros, %s falha(s)\n' "$total" "$FALHAS"
  exit 0
else
  printf 'FAIL — %s falha(s) em %s ficheiros\n' "$FALHAS" "$total"
  exit 1
fi
