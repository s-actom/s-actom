#!/bin/bash
# UserPromptSubmit hook (owner request 2026-09-25): keep the coordinator on the
# binding Livro + Flora finish roadmap. Only active inside the livro-proibido-site
# repository; prints one line with the current roadmap step (first ESTADO row
# that is not FEITO) and the core rules. Read-only; never fails the prompt.
REPO=$HOME/repos/livro-proibido-site
ROADMAP="$REPO/docs/superpowers/plans/2026-09-25-livro-flora-finish-roadmap.md"
dir="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$dir" in
  "$REPO"|"$REPO"/*) ;;
  *) exit 0 ;;
esac
[ -r "$ROADMAP" ] || exit 0
step=$(awk -F'|' '
  /^## ESTADO/ { f = 1; next }
  f && /^## / { exit }
  f && /^\|/ {
    p = $2; s = $3
    gsub(/^[ \t]+|[ \t]+$/, "", p); gsub(/^[ \t]+|[ \t]+$/, "", s)
    if (p == "" || p == "Passo" || p ~ /^-+$/) next
    if (s != "FEITO") { print p " (" s ")"; exit }
  }' "$ROADMAP")
echo "ROADMAP VINCULATIVO Livro+Flora (docs/superpowers/plans/2026-09-25-livro-flora-finish-roadmap.md): passo atual = ${step:-desconhecido}. Ordem A→GC→C→B→G; fechar passos só com prova na tabela ESTADO; âmbito congelado; 1 ronda de correção por passo; parar só nos [GO], no B1 ou na 2.ª falha; começar cada mensagem ao owner com 'Roadmap: passo X'."
exit 0
