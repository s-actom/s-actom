#!/usr/bin/env bash
# guarda-sessao.sh — guarda das equipas (Fase 1, M1), o único mecanismo: um só hook PreToolUse no settings.json
# (matcher Bash|Monitor|mcp__.*, comando `bash "<hooks resolvido>/guarda-sessao.sh" || true`, timeout 30 s), posto por
# reverter/ativar-fase-1.sh ou reverter/ligar-guarda-sessao.sh. Nenhuma skill leva hooks no frontmatter: esse hook não
# corre em subagentes nem depois de `claude -p --resume` (provado na CLI 2.1.319); o de settings corre nos dois casos,
# com o session_id da sessão-mãe.
# Lê em registo.jsonl as equipas que esta sessão chamou (ferramenta, /equipa-x ou subagente) e passa a mesma entrada a
# guarda-equipa.sh <equipa> (as regras), por ordem fixa e em série (daí os 30 s); ao primeiro "ask", devolve-o tal como
# veio. Thread principal e subagentes são vigiados da mesma forma (não depende de agent_id).
# Falha aberto: sai sempre 0 e o settings.json acrescenta `|| true`. Sem jq, session_id inválido ou registo ausente ou
# ligação simbólica, cala (corre em todas as chamadas e encheria o ecrã). hooks/arranque.mjs avisa o dono uma vez por
# sessão se o guarda não pode vigiar: falta jq; guarda-sessao.sh, guarda-equipa.sh ou registo-equipa.mjs falta, é
# ligação simbólica ou não se lê; a lista do `for e in` abaixo não se lê; uma equipa com guarda falta no catálogo
# (hooks/lib/equipas.json); o registo.jsonl não é um ficheiro normal que se leia e grave; faltam no settings.json os
# hooks do registo das equipas (PostToolUse Skill e UserPromptExpansion) ou o grupo exato deste guarda; ou o arranque
# não conseguiu verificar.
# Sem errexit nem pipefail, de propósito: um grep -q que sai cedo dá SIGPIPE a montante e o guarda calava (N4).
# Inerte até existirem FASE-1-ATIVA e estado/guardas-revistas.
unset TYPESAFE_API_KEY
BASE=$(cd "${BASH_SOURCE[0]%/*}/.." 2>/dev/null && pwd -P) || exit 0   # sem dirname: não depende do PATH
[ -f "$BASE/FASE-1-ATIVA" ] && [ -f "$BASE/estado/guardas-revistas" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
IN=$(cat)   # inteira: um corte escondia parte do comando ao guarda
# A regra de sessaoValida (hooks/lib/comum.mjs); \A e \z para uma quebra de linha no fim não passar.
S=$(printf '%s' "$IN" | jq -r '.session_id | strings | select(test("\\A[A-Za-z0-9_-]{1,128}\\z"))' 2>/dev/null)
[ -n "$S" ] || exit 0
REG="$BASE/registo.jsonl"
[ -f "$REG" ] && [ ! -L "$REG" ] || exit 0
# Equipas desta sessão: tipo "equipa", ok != false. Linha a linha, para uma linha estragada não esconder as seguintes;
# grep -a porque um NUL no ficheiro fazia o grep responder "Binary file matches" em vez das linhas.
EQ=$(grep -a -F -e "$S" -- "$REG" | jq -R -r --arg s "$S" \
  'fromjson? | objects | select(.tipo == "equipa" and .sessao == $s and .ok != false) | .equipa | strings' 2>/dev/null)
for e in blockchain infraestrutura marketing multimedia seguranca; do   # as do case de guarda-equipa.sh; o arranque lê esta linha
  case $'\n'"$EQ"$'\n' in *$'\n'"$e"$'\n'*) ;; *) continue ;; esac
  O=$(printf '%s' "$IN" | "$BASH" "$BASE/hooks/guarda-equipa.sh" "$e")
  printf '%s' "$O" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 && { printf '%s\n' "$O"; exit 0; }
done
exit 0
