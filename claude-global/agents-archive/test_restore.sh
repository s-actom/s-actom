#!/usr/bin/env bash
# Auto-teste do RESTORE.sh com 3 agentes falsos numa pasta temporária; não toca em ~/.claude.
# Uso: bash test_restore.sh [shell]   ex.: bash test_restore.sh /bin/bash
set -uo pipefail
SH_BIN="${1:-bash}"; T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
AR="$T/.claude/agents-archive"; A="$T/.claude/agents"; mkdir -p "$AR/sales" "$A"
cp "$(dirname "$0")/RESTORE.sh" "$AR/"
for f in alpha.md sales/beta.md sales/gamma.md; do echo "$f" > "$AR/$f"; done
(cd "$AR" && shasum -a 256 alpha.md sales/beta.md sales/gamma.md > MANIFEST.sha256)
run() { HOME="$T" "$SH_BIN" "$AR/RESTORE.sh" "$@"; }
fail=0; check() { if [ "$2" = 0 ]; then echo "PASS $1"; else echo "FAIL $1"; fail=1; fi; }
out=$(run --dry-run); [ "$(grep -c '^  restore ' <<<"$out")" = 3 ] && [ -z "$(ls -A "$A")" ]; check "dry-run lista 3 e não altera" $?
run alpha > /dev/null; [ -f "$A/alpha.md" ] && [ ! -e "$AR/alpha.md" ]; check "repõe só o nome pedido" $?
run nada > /dev/null 2>&1; [ $? = 1 ]; check "nome inexistente: exit 1" $?
err=$(run beta gralha 2>&1 > /dev/null); rc=$?
[ "$rc" = 1 ] && [ -f "$A/sales/beta.md" ] && [ "$err" = "Não está no arquivo: gralha" ]; check "misto: repõe o válido e reporta só a gralha" $?
echo LOCAL > "$A/sales/gamma.md"; run gamma > /dev/null
[ "$(cat "$A/sales/gamma.md")" = LOCAL ] && [ -f "$AR/sales/gamma.md" ]; check "não sobrescreve" $?
mkdir -p "$T/.claude/skills/agency-commander"; printf 'import sys\nsys.exit(3)\n' > "$T/.claude/skills/agency-commander/build_catalog.py"
run alpha > /dev/null 2>&1; [ $? != 0 ]; check "erro do catálogo propaga, mesmo sem nada a mover" $?
exit "$fail"
