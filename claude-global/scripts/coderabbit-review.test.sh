#!/usr/bin/env bash
# Teste do coderabbit-review.sh com uma CLI falsa: valida os argumentos passados à CLI, sem rede nem quota.
# Uso: bash ~/.claude/scripts/coderabbit-review.test.sh   (exit 0 = tudo PASS)
set -u
W="$(cd "$(dirname "$0")" && pwd)/coderabbit-review.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
cat > "$T/bin/coderabbit" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  auth) echo '{"type":"status","authenticated":true}' ;;
  review) printf '%s\n' "$*" > "$STUB_ARGS"; echo '{"type":"complete","status":"review_completed"}' ;;
esac
EOF
chmod +x "$T/bin/coderabbit"
export PATH="$T/bin:$PATH" STUB_ARGS="$T/args"
G="$T/global.md"; echo "global" > "$G"
FAIL=0

new_repo() { # repo com um diff por rever na raiz e em sub/
  local r="$T/$1"
  mkdir -p "$r/sub" && git -C "$r" init -q
  echo a > "$r/f.txt"; echo a > "$r/sub/g.txt"
  git -C "$r" add . && git -C "$r" -c user.name=t -c user.email=t@example.invalid commit -qm base
  echo b > "$r/f.txt"; echo b > "$r/sub/g.txt"
  printf '%s' "$r"
}
RUN_HOME=   # quando definido, o caso corre com um HOME isolado (não toca no HOME real)
run() { # run <repo> <CR_GLOBAL_CONFIG|-unset-> [args do wrapper...]
  local repo=$1 gc=$2; shift 2
  rm -f "$STUB_ARGS"
  # Uma só execução: o `||` anterior repetia a chamada SEM o HOME isolado e
  # mascarava a falha original com um resultado dependente da configuração pessoal.
  local rc=0
  # CR_SKIP_SECRET_SCAN=0 fixo: se o chamador o exportasse a 1, os testes de bloqueio
  # passariam a "sucesso" e falhariam por razões alheias ao código testado.
  if [ -n "$RUN_HOME" ]; then
    if [ "$gc" = -unset- ]; then ( cd "$repo" && env -u CR_GLOBAL_CONFIG HOME="$RUN_HOME" CR_SKIP_SECRET_SCAN=0 bash "$W" "$@" >/dev/null 2>"$T/err" ) || rc=$?
    else ( cd "$repo" && CR_GLOBAL_CONFIG="$gc" HOME="$RUN_HOME" CR_SKIP_SECRET_SCAN=0 bash "$W" "$@" >/dev/null 2>"$T/err" ) || rc=$?; fi
  else
    if [ "$gc" = -unset- ]; then ( cd "$repo" && env -u CR_GLOBAL_CONFIG CR_SKIP_SECRET_SCAN=0 bash "$W" "$@" >/dev/null 2>"$T/err" ) || rc=$?
    else ( cd "$repo" && CR_GLOBAL_CONFIG="$gc" CR_SKIP_SECRET_SCAN=0 bash "$W" "$@" >/dev/null 2>"$T/err" ) || rc=$?; fi
  fi
  return "$rc"
}
ok() { echo "PASS $1"; }
ko() { echo "FAIL $1: args=[$(cat "$STUB_ARGS" 2>/dev/null)] err=[$(tr '\n' ' ' < "$T/err")]"; FAIL=1; }
args_end() { [ -f "$STUB_ARGS" ] && [[ "$(cat "$STUB_ARGS")" == *"$1" ]]; }
no_config() { [ -f "$STUB_ARGS" ] && ! grep -q -- '--config' "$STUB_ARGS"; }

r=$(new_repo r1)
run "$r" "$G";           args_end " --config $G" && ok "sem config no repo: instruções globais" || ko "sem config no repo"
run "$r" "$G" && [ ! -f "$STUB_ARGS" ] && ok "diff já revisto: não chama a CLI" || ko "dedup (status ou STUB_ARGS)"
run "$r" "$G" --fresh;   args_end " --fresh --config $G" && ok "--fresh repete e passa --fresh" || ko "--fresh"
r=$(new_repo r2); echo "reviews: {}" > "$r/.coderabbit.yml"
run "$r" "$G";           no_config && grep -q 'config do repo' "$T/err" && ok "repo com .coderabbit.yml: config do repo" || ko ".coderabbit.yml"
r=$(new_repo r3); echo "reviews: {}" > "$r/sub/coderabbit.yaml"
run "$r" "$G" --dir sub; no_config && ok "--dir com coderabbit.yaml na subpasta: config do repo" || ko "--dir subpasta"
r=$(new_repo r4)
run "$r" "";             no_config && ! grep -q 'instruções globais' "$T/err" && ok "CR_GLOBAL_CONFIG vazio: desligado" || ko "vazio"
r=$(new_repo r5)
run "$r" /nao/existe.md; no_config && grep -q 'instruções globais em falta' "$T/err" && ok "global em falta: aviso, sem --config" || ko "em falta"
# default = $HOME/.claude/coderabbit/review-instructions.md. HOME isolado: o teste não pode
# depender da configuração pessoal de quem o corre (falhava num ambiente limpo e no CI).
r=$(new_repo r6)
RUN_HOME="$T/home-default"; mkdir -p "$RUN_HOME/.claude/coderabbit"
echo "default" > "$RUN_HOME/.claude/coderabbit/review-instructions.md"
run "$r" -unset-;        args_end " --config $RUN_HOME/.claude/coderabbit/review-instructions.md" && ok "default: \$HOME/.claude/coderabbit/review-instructions.md" || ko "default"
RUN_HOME=
# --- Regressão: findings do CodeRabbit na revisão do PR #2 -------------------
# (a) um nome de ficheiro que parece opção ("--help") não pode escapar à varredura de segredos
r=$(new_repo r7)
printf 'k=ghp_%s\n' "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" > "$r/--help"
out=$( run "$r" "$G"; echo "rc=$?" )
if printf '%s' "$out" | grep -q 'rc=3'; then ok "nome '--help' ainda é varrido (bloqueia)"
else ko "nome '--help' escapou à varredura (não bloqueou)"; fi
rm -f "$r/--help"

# (b) credencial presente só nas linhas REMOVIDAS do diff também bloqueia
r=$(new_repo r8)
printf 'k=ghp_%s\n' "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" > "$r/cred.txt"
git -C "$r" add . && git -C "$r" -c user.name=t -c user.email=t@example.invalid commit -qm addcred
rm -f "$r/cred.txt"          # agora o diff só tem a linha removida com a credencial
out=$( run "$r" "$G"; echo "rc=$?" )
if printf '%s' "$out" | grep -q 'rc=3'; then ok "credencial removida do ficheiro continua a bloquear (vai no diff)"
else ko "credencial em linha removida passou (seria enviada à CLI)"; fi

# --- Regressão: 3.ª review do CodeRabbit no PR #2 ----------------------------
# (c) opção sem valor não entra em loop infinito
# `timeout` não existe no macOS; perl existe em ambos. O alarm só evita um pendura se houver bug.
out=$( cd "$T/r1" && perl -e 'alarm shift; exec @ARGV' 10 bash "$W" --scope >/dev/null 2>&1; echo "rc=$?" )
if printf '%s' "$out" | grep -q 'rc=4'; then ok "opção sem valor: NOT_RUN (sem loop)"
else ko "opção sem valor não devolveu NOT_RUN: $out"; fi

# (d) conteúdo que começa por "++" (vira "+++ x" no diff) não é descartado como cabeçalho
r=$(new_repo r9)
printf 'vazio\n' > "$r/notes.txt"          # base sem segredo
git -C "$r" add . && git -C "$r" -c user.name=t -c user.email=t@example.invalid commit -qm n
# A linha ADICIONADA começa por "++", logo aparece no diff como "+++ AKIA..." (conteúdo, não cabeçalho).
printf '++ AKIA%s\n' "IOSFODNN7EXAMPLE" > "$r/notes.txt"
out=$( run "$r" "$G"; echo "rc=$?" )
if printf '%s' "$out" | grep -q 'rc=3'; then ok "linha '+++ ...' dentro do hunk é conteúdo (bloqueia)"
else ko "linha '+++ ...' foi tratada como cabeçalho e escapou"; fi

exit "$FAIL"
