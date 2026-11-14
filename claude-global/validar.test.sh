#!/usr/bin/env bash
# Testes do validar.sh — regressões de segurança (não imprimir credenciais) e higiene.
# Corre sobre cópias numa pasta temporária; não toca no repositório. Exit 0 = tudo OK.
set -u
T=$(mktemp -d) || exit 2
trap 'rm -R -- "$T"' EXIT
RAIZ="$(cd "$(dirname "$0")" && pwd -P)"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }

# Estrutura mínima para o validar.sh não falhar por outros motivos
preparar() {
  rm -Rf -- "$T/c"; mkdir -p "$T/c/skills" "$T/c/equipas" "$T/c/mcp-configs" "$T/c/hooks"
  cp "$RAIZ/validar.sh" "$T/c/"; cp "$RAIZ/.gitignore" "$T/c/" 2>/dev/null || true
  printf '{}\n' > "$T/c/settings.json"; printf '{}\n' > "$T/c/launch.json"
  printf '{"mcpServers":{}}\n' > "$T/c/mcp-configs/mcp-servers.json"
  printf '{"type":"commonjs"}\n' > "$T/c/hooks/package.json"
  printf 'versao: 1\ncamadas: {}\ndirecao_geral: {}\n' > "$T/c/equipas/equipas.yaml"
  for i in $(seq 1 16); do
    n="equipa-s$i"; [ "$i" = 1 ] && n="direcao-geral"
    mkdir -p "$T/c/skills/$n"
    printf -- '---\nname: %s\ndescription: "d"\n---\n' "$n" > "$T/c/skills/$n/SKILL.md"
  done
}

# (a) nome de ficheiro com ":" não pode imprimir o token
preparar
mkdir -p "$T/c/x"
printf 'tok=ghp_%s\n' "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" > "$T/c/x/credenciais:backup.txt"
OUT=$(bash "$T/c/validar.sh" 2>&1 || true)
printf '%s' "$OUT" | grep -q 'ghp_A1b2' && ko "a) token impresso (nome com dois-pontos)" || ok "a) token não impresso com nome de dois-pontos"
printf '%s' "$OUT" | grep -q 'linha 1' && ok "a) reporta ficheiro e linha" || ko "a) não reporta ficheiro/linha"

# (b) nenhum relatório fixo em /tmp
rm -f /tmp/validar-segredos.txt
preparar
mkdir -p "$T/c/y"; printf 'k=ghp_%s\n' "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8" > "$T/c/y/t.txt"
bash "$T/c/validar.sh" >/dev/null 2>&1 || true
[ -e /tmp/validar-segredos.txt ] && ko "b) relatório fixo em /tmp recriado" || ok "b) sem relatório fixo em /tmp"

# (c) pasta limpa passa
preparar
bash "$T/c/validar.sh" >"$T/c.out" 2>&1 && ok "c) pasta limpa: PASS" || { ko "c) pasta limpa falhou"; tail -5 "$T/c.out"; }

# (d) __pycache__ coberto pelo .gitignore não é falha
preparar
mkdir -p "$T/c/equipas/__pycache__"; : > "$T/c/equipas/__pycache__/x.pyc"
bash "$T/c/validar.sh" >"$T/d.out" 2>&1 && ok "d) __pycache__ coberto pelo .gitignore: PASS" || { ko "d) falso alarme de artefactos"; tail -4 "$T/d.out"; }

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi
