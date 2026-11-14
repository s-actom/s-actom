#!/usr/bin/env bash
# ativar-fase-1.sh — liga a Fase 1 da Direção Geral (às escuras), com backup por cópia antes de qualquer alteração.
# Atua em $HOME/.claude (os testes correm-no com um HOME temporário).
# Uso: ativar-fase-1.sh            mostra o que faria e ensaia as trocas (não muda nada)
#      ativar-fase-1.sh --aplicar  faz o backup e ativa
# Muda: settings.json (6 hooks novos), CLAUDE.md (um só decisor), skills/agency-commander/SKILL.md (descrição),
#       instala skills/direcao-geral e as 15 skills/equipa-*. Reverter: reverter-fase-1.sh --aplicar
# Saída: 0 ok · 1 falhou (o que já tinha mudado foi reposto) · 2 uso ou pré-condição em falta
set -u -o pipefail
umask 077

BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P) || { echo "pasta base ilegível" >&2; exit 2; }
C="$HOME/.claude"
[ "$BASE" = "$(cd "$C/equipas" 2>/dev/null && pwd -P)" ] || { echo "o script tem de estar em \$HOME/.claude/equipas/reverter" >&2; exit 2; }
MARCA="$BASE/FASE-1-ATIVA"
SET="$C/settings.json"; CMD="$C/CLAUDE.md"; COM="$C/skills/agency-commander/SKILL.md"
HK="$BASE/hooks"

MODO=dry
case "${1:-}" in "") ;; --aplicar) MODO=aplicar ;; -h | --help) sed -n '2,8p' "$0"; exit 0 ;; *) echo "argumento desconhecido: $1" >&2; exit 2 ;; esac
[ $# -le 1 ] || { echo "demasiados argumentos" >&2; exit 2; }

erro() { echo "ativar-fase-1: $*" >&2; exit 2; }
sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }
# Frontmatter só com name e description, como o que hooks/atualizar.py aceita publicar: nada de hooks (o guarda das
# equipas é o hook global do settings.json) nem de chaves novas, nem caracteres de controlo (CR, ESC: escondem texto
# no terminal). LC_ALL=C: [[:cntrl:]] são só os bytes 0-31 e 127, e os acentos em UTF-8 passam.
so_nome_e_descricao() {
  LC_ALL=C awk -v n="$2" '/[[:cntrl:]]/ { mau = 1; exit }
    NR == 1 { if ($0 != "---") { mau = 1; exit } next }
    $0 == "---" { fim = 1; exit }
    { k++; if ((k == 1 && $0 != ("name: " n)) || (k == 2 && $0 !~ /^description: ".*"$/) || k > 2) { mau = 1; exit } }
    END { exit (mau || !fim || k != 2) }' "$1"
}

# Pré-condições (nada muda até aqui)
if [ -e "$MARCA" ]; then
  grep -qx 'estado=a-ativar' "$MARCA" && erro "a última ativação foi interrompida: corre primeiro bash $BASE/reverter/reverter-fase-1.sh --aplicar"
  echo "Fase 1 já ativa ($MARCA). Nada a fazer."; exit 0
fi
for b in jq python3 node shasum; do command -v "$b" >/dev/null 2>&1 || erro "falta $b"; done
NODE=$(command -v node); PY=$(command -v python3)
"$NODE" -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 18 ? 0 : 1)' || erro "node >= 18 necessário"
for f in portao.mjs registo-equipa.mjs arranque.mjs atualizar.py rede-vibesec.sh guarda-equipa.sh guarda-sessao.sh lib/equipas.json; do
  [ -f "$HK/$f" ] && [ ! -L "$HK/$f" ] || erro "falta o hook $HK/$f"
done
for f in "$SET" "$CMD" "$COM"; do [ -f "$f" ] && [ ! -L "$f" ] || erro "não é ficheiro normal: $f"; done
jq -e 'type == "object"' "$SET" >/dev/null 2>&1 || erro "settings.json inválido"
grep -qF "$HK/" "$SET" && erro "settings.json já tem hooks desta pasta (ativação anterior incompleta?)"
NOMES=()
for d in "$BASE"/rascunho/direcao-geral "$BASE"/rascunho/equipa-*; do
  n=$(basename "$d"); [[ "$n" =~ ^(direcao-geral|equipa-[a-z]+)$ ]] || erro "nome inesperado em rascunho: $n"
  [ -f "$d/SKILL.md" ] || erro "falta $d/SKILL.md"
  so_nome_e_descricao "$d/SKILL.md" "$n" || erro "frontmatter inesperado em rascunho/$n/SKILL.md (só name e description, sem hooks): recusado"
  [ -e "$C/skills/$n" ] && erro "já existe $C/skills/$n (colisão de nomes)"
  NOMES+=("$n")
done
[ ${#NOMES[@]} -eq 16 ] || erro "esperava 16 skills em rascunho/, encontrei ${#NOMES[@]}"
[ -z "$(find "$BASE/rascunho" -type l -print -quit)" ] || erro "rascunho/ tem ligações simbólicas: recusado"

ENSAIO=$(mktemp -d) && [ -d "$ENSAIO" ] || erro "mktemp falhou"
trap 'rm -R -- "$ENSAIO" 2>/dev/null' EXIT
"$PY" -I "$BASE/reverter/troca.py" preparar "$CMD" "$COM" "$BASE/reverter/textos" "$ENSAIO/pares" || erro "as trocas no CLAUDE.md ou no agency-commander não batem; nada mudou"

if [ "$MODO" = dry ]; then
  echo "Ensaio OK. Com --aplicar:"
  echo "  backup por cópia em $BASE/backups/fase-1-<data>/ (settings.json, settings.local.json, CLAUDE.md, skills/agency-commander, hooks, rules)"
  echo "  instala ${#NOMES[@]} skills em $C/skills: ${NOMES[*]}"
  echo "  settings.json: UserPromptSubmit, PostToolUse[Skill], UserPromptExpansion, SessionStart, PreToolUse (guarda da sessão) e um Stop junto ao do CodeRabbit"
  echo "  CLAUDE.md: Direção Geral como único decisor (3 trocas exatas); agency-commander: descrição 'substituído por direcao-geral'"
  exit 0
fi

# Backup por cópia
mkdir -p -m 700 "$BASE/backups" || erro "não consegui criar backups/"
[ -f "$BASE/backups/.gitignore" ] || printf '*\n' >"$BASE/backups/.gitignore"
B="$BASE/backups/fase-1-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$B" "$B/ficheiros" || erro "backup já existe ou não foi criado: $B"
cp -p "$SET" "$CMD" "$B/ficheiros/" || erro "cópia falhou"
[ -f "$C/settings.local.json" ] && { cp -p "$C/settings.local.json" "$B/ficheiros/" || erro "cópia falhou"; }
mkdir -p "$B/ficheiros/skills" && cp -Rp "$C/skills/agency-commander" "$B/ficheiros/skills/" || erro "cópia falhou"
for d in hooks rules; do [ -d "$C/$d" ] && { cp -Rp "$C/$d" "$B/ficheiros/" || erro "cópia de $d falhou"; }; done
(cd "$B/ficheiros" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256) >"$B/ANTES.sha256" || erro "ANTES.sha256 falhou"
(cd "$C" && shasum -a 256 -c "$B/ANTES.sha256" >/dev/null 2>&1) || erro "o backup não bate com os originais"
mv "$ENSAIO/pares" "$B/pares" || erro "pares não guardados"

INSTALADOS=()
repor() { # desfaz o que já mudou; só repõe ficheiros que mudaram desde o backup
  echo "ativar-fase-1: a repor o estado anterior" >&2
  for rel in settings.json CLAUDE.md skills/agency-commander/SKILL.md; do
    a=$(awk -v r="./$rel" '$2 == r {print $1}' "$B/ANTES.sha256")
    [ "$(sha "$C/$rel")" = "$a" ] || cp -p "$B/ficheiros/$rel" "$C/$rel"
  done
  for n in "${INSTALADOS[@]}"; do [ -d "$C/skills/$n" ] && rm -R -- "$C/skills/$n"; done
  rm -f -- "$BASE/estado/instalado.sha256"
}
falhar() { trap - INT TERM HUP; echo "ativar-fase-1: $*" >&2; repor; rm -f -- "$MARCA"; exit 1; }
trap 'falhar "interrompido"' INT TERM HUP
# Marca logo a seguir ao backup: se o processo morrer a meio (kill -9), a reversão sabe de onde repor.
printf 'backup=%s\nestado=a-ativar\n' "${B#"$BASE"/}" >"$MARCA" || falhar "marca"

# Skills
mkdir -p -m 700 "$BASE/estado" || falhar "estado/"
: >"$BASE/estado/instalado.sha256.tmp" || falhar "instalado.sha256"
for n in "${NOMES[@]}"; do
  INSTALADOS+=("$n")  # antes da cópia: uma cópia a meio também é desfeita por repor()
  cp -R "$BASE/rascunho/$n" "$C/skills/$n" || falhar "cópia de $n"
  chmod 755 "$C/skills/$n" && chmod 644 "$C/skills/$n"/*
  (cd "$C/skills" && find "$n" -type f -print0 | sort -z | xargs -0 shasum -a 256) >>"$BASE/estado/instalado.sha256.tmp" || falhar "sha de $n"
done
mv "$BASE/estado/instalado.sha256.tmp" "$BASE/estado/instalado.sha256" || falhar "instalado.sha256"

# settings.json: hooks novos (o Stop junta-se ao grupo do coderabbit-stop-gate). O PreToolUse é o único mecanismo do
# guarda das equipas (nenhuma skill leva hooks); 30 s porque as 5 equipas com guarda correm em série dentro dele.
q() { printf '"%s" "%s"' "$1" "$2"; }
MODO_SET=$(stat -f %Lp "$SET")
jq --arg up "$(q "$NODE" "$HK/portao.mjs")" --arg re "$(q "$NODE" "$HK/registo-equipa.mjs")" \
   --arg ss "$(q "$NODE" "$HK/arranque.mjs")" --arg st "bash \"$HK/rede-vibesec.sh\"" \
   --arg gs "bash \"$HK/guarda-sessao.sh\" || true" '
  def h($c; $t): {type: "command", command: $c, timeout: $t};
  def cr: any(.hooks[]?; (.command // "") | test("coderabbit-stop-gate"));
  .hooks //= {}
  | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{hooks: [h($up; 5)]}])
  | .hooks.PostToolUse = ((.hooks.PostToolUse // []) + [{matcher: "Skill", hooks: [h($re; 5)]}])
  | .hooks.UserPromptExpansion = ((.hooks.UserPromptExpansion // []) + [{hooks: [h($re; 5)]}])
  | .hooks.SessionStart = ((.hooks.SessionStart // []) + [{hooks: [h($ss; 5)]}])
  | .hooks.PreToolUse = ((.hooks.PreToolUse // []) + [{matcher: "Bash|Monitor|mcp__.*", hooks: [h($gs; 30)]}])
  | .hooks.Stop = ((.hooks.Stop // []) as $s
      | if any($s[]; cr) then [$s[] | if cr then .hooks += [h($st; 15)] else . end]
        else $s + [{hooks: [h($st; 15)]}] end)
' "$SET" >"$SET.fase1.tmp" && jq -e 'type == "object"' "$SET.fase1.tmp" >/dev/null || { rm -f "$SET.fase1.tmp"; falhar "jq falhou"; }
chmod "$MODO_SET" "$SET.fase1.tmp" && mv "$SET.fase1.tmp" "$SET" || falhar "settings.json não escrito"

# CLAUDE.md e agency-commander
"$PY" -I "$BASE/reverter/troca.py" aplicar "$CMD" "$B/pares" claude || falhar "troca no CLAUDE.md"
"$PY" -I "$BASE/reverter/troca.py" aplicar "$COM" "$B/pares" commander || falhar "troca no agency-commander"

(cd "$C" && shasum -a 256 settings.json CLAUDE.md skills/agency-commander/SKILL.md | sed 's#  #  ./#') >"$B/DEPOIS.sha256" || falhar "DEPOIS.sha256"
printf 'backup=%s\nestado=ativa\nativada=%s\n' "${B#"$BASE"/}" "$(date +%Y-%m-%dT%H:%M:%S%z)" >"$MARCA" || falhar "marca"
trap - INT TERM HUP
echo "Fase 1 ativa. Backup: $B"
echo "Reverter: bash $BASE/reverter/reverter-fase-1.sh --aplicar"
