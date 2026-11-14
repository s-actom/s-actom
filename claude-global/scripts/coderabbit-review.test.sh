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
run() { # run <repo> <CR_GLOBAL_CONFIG|-unset-> [args do wrapper...]
  local repo=$1 gc=$2; shift 2
  rm -f "$STUB_ARGS"
  if [ "$gc" = -unset- ]; then (cd "$repo" && env -u CR_GLOBAL_CONFIG bash "$W" "$@" >/dev/null 2>"$T/err")
  else (cd "$repo" && CR_GLOBAL_CONFIG="$gc" bash "$W" "$@" >/dev/null 2>"$T/err"); fi
}
ok() { echo "PASS $1"; }
ko() { echo "FAIL $1: args=[$(cat "$STUB_ARGS" 2>/dev/null)] err=[$(tr '\n' ' ' < "$T/err")]"; FAIL=1; }
args_end() { [ -f "$STUB_ARGS" ] && [[ "$(cat "$STUB_ARGS")" == *"$1" ]]; }
no_config() { [ -f "$STUB_ARGS" ] && ! grep -q -- '--config' "$STUB_ARGS"; }

r=$(new_repo r1)
run "$r" "$G";           args_end " --config $G" && ok "sem config no repo: instruções globais" || ko "sem config no repo"
run "$r" "$G";           [ ! -f "$STUB_ARGS" ] && ok "diff já revisto: não chama a CLI" || ko "dedup"
run "$r" "$G" --fresh;   args_end " --fresh --config $G" && ok "--fresh repete e passa --fresh" || ko "--fresh"
r=$(new_repo r2); echo "reviews: {}" > "$r/.coderabbit.yml"
run "$r" "$G";           no_config && grep -q 'config do repo' "$T/err" && ok "repo com .coderabbit.yml: config do repo" || ko ".coderabbit.yml"
r=$(new_repo r3); echo "reviews: {}" > "$r/sub/coderabbit.yaml"
run "$r" "$G" --dir sub; no_config && ok "--dir com coderabbit.yaml na subpasta: config do repo" || ko "--dir subpasta"
r=$(new_repo r4)
run "$r" "";             no_config && ! grep -q aviso "$T/err" && ok "CR_GLOBAL_CONFIG vazio: desligado" || ko "vazio"
r=$(new_repo r5)
run "$r" /nao/existe.md; no_config && grep -q aviso "$T/err" && ok "global em falta: aviso, sem --config" || ko "em falta"
r=$(new_repo r6)
run "$r" -unset-;        args_end " --config $HOME/.claude/coderabbit/review-instructions.md" && ok "default: ~/.claude/coderabbit/review-instructions.md" || ko "default"
exit "$FAIL"
