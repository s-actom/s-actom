#!/usr/bin/env bash
# Teste C da secção 14 do desenho: os módulos do jev-router correm no Claude Code?
# Corre uma CÓPIA do router (sem state, logs nem dados privados) numa pasta temporária, com:
#   env -i, HOME e CODEX_HOME temporários, CODEX_JEV_TEST_MODE=1 e sandbox-exec que NEGA rede, o executável
#   /usr/bin/security (o router cai para o keychain "typesafe-api-key" se não houver TYPESAFE_API_KEY) e escrita em ~/.codex, ~/.claude e ~/.claude.json.
# Não chama a API do JEV. Não altera nem interrompe ~/.codex/jev-router (só leitura para copiar).
# Uso: teste-c-jev.sh
set -u
set -o pipefail
ROUTER="$HOME/.codex/jev-router"
[ -d "$ROUTER/src" ] || { echo "jev-router não encontrado" >&2; exit 2; }
NODE=$(command -v node) || { echo "falta node" >&2; exit 2; }
TO=$(command -v timeout || command -v gtimeout) || { echo "falta timeout" >&2; exit 2; }
T=$(mktemp -d "${TMPDIR:-/tmp}/teste-c.XXXXXX") || exit 2
T=$(cd "$T" && pwd -P) || exit 2  # caminho real: o sandbox compara com o caminho resolvido (/var é ligação para /private/var)
SRV=""
trap '[ -z "$SRV" ] || kill "$SRV" 2>/dev/null; rm -rf -- "$T"' EXIT
COPIA="$T/codexhome/jev-router"  # o router deriva state, logs e config de $CODEX_HOME/jev-router
mkdir -p "$T/home" "$COPIA" "$T/proj" "$T/negado" "$T/www"
touch "$T/marcador"
rsync -a --exclude state --exclude logs --exclude generated --exclude '.private-team-evaluation' --exclude bench --exclude evals \
  --exclude '.*-backup-path' "$ROUTER/" "$COPIA/" || { echo "falha ao copiar o router" >&2; exit 2; }
PERFIL="(version 1)(allow default)(deny network*)(deny process-exec (literal \"/usr/bin/security\"))(deny file-write* (subpath \"$HOME/.codex\"))(deny file-write* (subpath \"$HOME/.claude\"))(deny file-write* (literal \"$HOME/.claude.json\"))(deny file-write* (subpath \"$T/negado\"))(deny file-read* (subpath \"$HOME/Library/Keychains\"))"
isolado() { "$TO" "$1" env -i PATH="/usr/bin:/bin:$(dirname "$NODE")" HOME="$T/home" CODEX_HOME="$T/codexhome" CODEX_JEV_TEST_MODE=1 TMPDIR="$T" \
  /usr/bin/sandbox-exec -p "$PERFIL" "${@:2}"; }
ms() { perl -MTime::HiRes=time -e 'printf "%d", time*1000'; }

echo "== Sanidade do isolamento (cada bloqueio tem um controlo positivo: o mesmo pedido resulta fora do sandbox ou numa zona permitida)"
[ "$(isolado 10 /bin/echo ok 2>/dev/null)" = ok ] && echo "controlo: o sandbox executa comandos normais" || { echo "o sandbox não executa comandos (a parar)"; exit 3; }
# escrita: permitida em $T, negada na zona de teste (regra da mesma forma que as de ~/.codex, ~/.claude e ~/.claude.json)
isolado 10 /usr/bin/touch "$T/permitido" >/dev/null 2>&1; [ -e "$T/permitido" ] || { echo "controlo falhou: a escrita permitida deu erro (a parar)"; exit 3; }
isolado 10 /usr/bin/touch "$T/negado/x" >/dev/null 2>&1; [ ! -e "$T/negado/x" ] && echo "escrita: negada onde a regra manda" || { echo "escrita: a regra deny não funcionou (a parar)"; exit 3; }
# rede: um servidor local (fora do sandbox) tem de responder cá fora e ser recusado lá dentro. Sem DNS, sem Internet.
echo ok >"$T/www/index.html"
python3 -I -u -m http.server 0 --bind 127.0.0.1 --directory "$T/www" >"$T/www.log" 2>&1 &
SRV=$!
PORTA=""
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  PORTA=$(sed -n 's/.*port \([0-9][0-9]*\).*/\1/p' "$T/www.log" | head -1)
  [ -n "$PORTA" ] && break
  sleep 0.2
done
if [ -n "$PORTA" ] && [ "$(curl -sS -m 3 "http://127.0.0.1:$PORTA/" 2>/dev/null)" = ok ]; then
  echo "controlo: fora do sandbox o servidor local responde"
  isolado 10 /usr/bin/curl -sS -m 3 -o /dev/null "http://127.0.0.1:$PORTA/" >/dev/null 2>&1 && { echo "rede: ABERTA (isolamento falhou, a parar)"; exit 3; } || echo "rede: bloqueada dentro do sandbox"
else
  echo "rede: sem controlo positivo (o servidor local não respondeu); a parar"; exit 3
fi
kill "$SRV" 2>/dev/null; SRV=""
if /usr/bin/security list-keychains >/dev/null 2>&1; then echo "controlo: fora do sandbox o /usr/bin/security corre"; else echo "aviso: o /usr/bin/security também falha fora do sandbox (sem controlo positivo)"; fi
isolado 10 /usr/bin/security list-keychains >/dev/null 2>&1 && { echo "keychain: ACESSÍVEL (isolamento falhou, a parar)"; exit 3; } || echo "keychain (/usr/bin/security): bloqueado"

printf '%s' "{\"session_id\":\"s-teste\",\"transcript_path\":\"$T/t.jsonl\",\"cwd\":\"$T/proj\",\"permission_mode\":\"default\",\"hook_event_name\":\"UserPromptSubmit\",\"prompt\":\"vamos começar um projeto de site\"}" >"$T/claude.json"
printf '%s' "{\"session_id\":\"s-teste\",\"turn_id\":\"turn-1\",\"transcript_path\":null,\"cwd\":\"$T/proj\",\"hook_event_name\":\"UserPromptSubmit\",\"model\":\"gpt-5.5\",\"prompt\":\"vamos começar um projeto de site\"}" >"$T/codex.json"

echo; echo "== Hook de prompt (user-prompt-hook.mjs) com payload do Claude Code e com payload do Codex"
for quem in claude codex; do
  ini=$(ms)
  isolado 40 "$NODE" "$COPIA/src/user-prompt-hook.mjs" <"$T/$quem.json" >"$T/$quem.out" 2>"$T/$quem.err"; rc=$?
  fim=$(ms)
  echo "-- payload $quem: exit=$rc, $((fim - ini)) ms, stdout=$(wc -c <"$T/$quem.out" | tr -d ' ') bytes, stderr=$(wc -c <"$T/$quem.err" | tr -d ' ') bytes"
  if jq -e . "$T/$quem.out" >/dev/null 2>&1; then
    echo "   JSON válido; chaves: $(jq -c 'keys' "$T/$quem.out"); hookSpecificOutput: $(jq -c '.hookSpecificOutput | keys? // "ausente"' "$T/$quem.out")"
    echo "   additionalContext (início): $(jq -r '.hookSpecificOutput.additionalContext // "" | .[0:220]' "$T/$quem.out" | tr '\n' ' ')"
  else
    echo "   stdout não é JSON: $(head -c 200 "$T/$quem.out" | tr '\n' ' ')"
  fi
  [ -s "$T/$quem.err" ] && echo "   stderr (início): $(head -c 240 "$T/$quem.err" | tr '\n' ' ')"
done

echo; echo "== Testes de contrato offline do próprio router (cópia, sem rede)"
( cd "$COPIA" && isolado 150 "$NODE" --test tests/private-data.test.mjs tests/action-gate.test.mjs tests/task-state.test.mjs tests/context-gate.test.mjs ) >"$T/node-test.out" 2>&1
echo "exit=$?"
tail -n 9 "$T/node-test.out" | cut -c1-200
grep -E '^(not ok|✖)' "$T/node-test.out" | head -5

echo; echo "== Router real intocado?"
echo "ficheiros do router real mais novos que o início do teste: $(find "$ROUTER" -type f -newer "$T/marcador" ! -path '*/node_modules/*' 2>/dev/null | wc -l | tr -d ' ') (informativo: o Codex pode estar a usá-lo)"
echo "state/logs escritos só na cópia: $(find "$COPIA/state" "$COPIA/logs" -type f 2>/dev/null | wc -l | tr -d ' ') ficheiro(s)"
