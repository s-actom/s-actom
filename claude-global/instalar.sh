#!/usr/bin/env bash
# instalar.sh — instala esta configuração numa instalação de Claude Code (por omissão $HOME/.claude).
#
# Uso: instalar.sh [--destino DIR] [--ensaio] [--forcar]
#   --destino DIR  alvo (por omissão: $HOME/.claude)
#   --ensaio       mostra o que faria; não escreve nada
#   --forcar       escreve mesmo que o destino já tenha ficheiros destes (senão recusa)
#
# Princípios:
#   - NUNCA substitui a configuração ativa sem --forcar e sem backup.
#   - Re-escrita de prefixo: os caminhos absolutos do snapshot (/Users/goncaloferro/.claude)
#     passam a apontar para --destino. É isto que torna o repositório portátil.
#   - Idempotente: re-executar com o mesmo destino não duplica nem altera o que já está igual.
#   - Manifesto de hashes em $DESTINO/.claude-global-manifest.sha256 + backup em
#     $DESTINO/.claude-global-backup-<ts>/ — base do desinstalar.sh.
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DESTINO="$HOME/.claude"
ENSAIO=0
FORCAR=0
PREFIXO_ORIGEM='/Users/goncaloferro/.claude'
# O settings.json fixa o node do nvm desta máquina; noutra instalação é inválido.
# Substitui-se pelo node encontrado no PATH (se existir) e registra-se o que ficou.
NODE_BIN=$(command -v node 2>/dev/null || true)
if [ -n "$NODE_BIN" ]; then
  NODE_SED="s|/Users/goncaloferro/.nvm/versions/node/[^\"]*/bin/node|$NODE_BIN|g"
else
  NODE_SED="s|/Users/goncaloferro/.nvm/versions/node/[^\"]*/bin/node|node|g"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --destino) [ $# -ge 2 ] || { echo "falta o valor de --destino" >&2; exit 2; }; DESTINO="$2"; shift 2 ;;
    --ensaio) ENSAIO=1; shift ;;
    --forcar) FORCAR=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

erro() { echo "instalar: $*" >&2; exit 2; }
ok()   { echo "ok - $*"; }
aviso(){ echo "aviso - $*" >&2; }

# --- 1. dependências exigidas em runtime -----------------------------------
FALTA=0
for b in jq python3 shasum git; do
  command -v "$b" >/dev/null 2>&1 || { aviso "falta $b (exigido pelos hooks/scripts)"; FALTA=1; }
done
command -v node >/dev/null 2>&1 || { aviso "falta node (hooks .mjs/.js)"; FALTA=1; }
[ "$FALTA" -eq 0 ] && ok "dependências base presentes (jq python3 shasum git node)"
[ "$FALTA" -eq 0 ] || aviso "instalação continua, mas os hooks que precisam disto vão falhar"

# --- 2. plano -----------------------------------------------------------------
# Ficheiros a instalar: tudo o que é configuração (exclui docs da exportação e testes do repo)
PLANO=$(cd "$RAIZ" && find . -type f \
  ! -path './.git/*' ! -name '*.pyc' ! -path '*/__pycache__/*' \
  ! -path './docs/*' ! -name 'validar.sh' ! -name 'validar.test.sh' \
  ! -name 'testes-agentes.sh' ! -name 'instalar.sh' ! -name 'desinstalar.sh' \
  ! -name '.gitignore' | sed 's|^\./||' | sort)
N=$(printf '%s\n' "$PLANO" | grep -c .)
ok "plano: $N ficheiros para $DESTINO"

if [ "$ENSAIO" = 1 ]; then
  printf '%s\n' "$PLANO" | head -20 | sed 's/^/    /'
  [ "$N" -gt 20 ] && echo "    … (+$((N - 20)))"
  echo "Ensaio: nada foi escrito. Para instalar: $0 --destino $DESTINO"
  exit 0
fi

# --- 3. colisões ---------------------------------------------------------------
if [ -d "$DESTINO" ] && [ "$FORCAR" != 1 ]; then
  COL=0
  for rel in $PLANO; do [ -e "$DESTINO/$rel" ] && COL=$((COL + 1)); done
  if [ "$COL" -gt 0 ]; then
    erro "o destino já tem $COL ficheiro(s) deste pacote. Fecha o Claude Code e usa --forcar (faz backup antes de escrever)."
  fi
fi

# --- 4. backup -------------------------------------------------------------------
TS=$(date +%Y%m%d-%H%M%S)
BK="$DESTINO/.claude-global-backup-$TS"
if [ -d "$DESTINO" ]; then
  mkdir -p "$BK" || erro "sem escrita em $BK"
  # Não fazer backup de ficheiros que JÁ são deste pacote (manifesto anterior):
  # senão uma reinstalação guarda a própria instalação e o rollback volta a pô-la.
  MAN_ANTIGO="$DESTINO/.claude-global-manifest.sha256"
  for rel in $PLANO; do
    [ -e "$DESTINO/$rel" ] || continue
    if [ -f "$MAN_ANTIGO" ] && grep -qF "  $rel" "$MAN_ANTIGO"; then continue; fi
    mkdir -p "$(dirname "$BK/$rel")"
    cp -p "$DESTINO/$rel" "$BK/$rel" || erro "falha no backup de $rel"
  done
  ok "backup em $BK"
fi

# --- 5. escrita (com re-escrita de prefixo) ---------------------------------------
mkdir -p "$DESTINO" || erro "sem escrita em $DESTINO"
NOVOS=0
for rel in $PLANO; do
  src="$RAIZ/$rel"; dst="$DESTINO/$rel"
  mkdir -p "$(dirname "$dst")" || erro "sem escrita em $(dirname "$dst")"
  case "$rel" in
    settings.json|*.md|*.sh|*.mjs|*.js|*.json|*.yaml|*.yml|*.py)
      # reescrever o prefixo absoluto da máquina de origem pelo destino
      sed -e "s|$PREFIXO_ORIGEM|$DESTINO|g" -e "${NODE_SED}" "$src" > "$dst.tmp" && mv -f "$dst.tmp" "$dst" \
        || erro "falha ao escrever $rel"
      ;;
    *) cp -p "$src" "$dst" || erro "falha ao copiar $rel" ;;
  esac
  NOVOS=$((NOVOS + 1))
done
ok "$NOVOS ficheiros escritos"

# --- 6. manifesto e permissões -------------------------------------------------------
( cd "$DESTINO" && printf '%s\n' $PLANO | while IFS= read -r rel; do
    printf '%s  %s\n' "$(shasum -a 256 -- "$rel" | cut -d' ' -f1)" "$rel"
  done ) > "$DESTINO/.claude-global-manifest.sha256" || erro "falha no manifesto"
chmod 600 "$DESTINO/.claude-global-manifest.sha256" 2>/dev/null || true
ok "manifesto: $DESTINO/.claude-global-manifest.sha256"

# --- 6b. hooks referenciados mas ausentes (dependências externas) ----------------------
# O settings.json referencia hooks do plugin superpowers/GSD, que NÃO estão neste pacote.
# Numa instalação nova esses comandos falham a cada evento: retiram-se do settings.json e
# registra-se o que saiu, para poderes reinstalar o plugin e repor.
if [ -f "$DESTINO/settings.json" ]; then
  AUSENTES=$(jq -r '[.. | objects | select(has("command")) | .command] | .[]' "$DESTINO/settings.json" 2>/dev/null \
    | grep -oE "$DESTINO/[^\" ]+" | sort -u | while IFS= read -r p; do [ -e "$p" ] || echo "$p"; done)
  if [ -n "$AUSENTES" ]; then
    LOG="$DESTINO/.claude-global-hooks-removidos.txt"
    printf '%s\n' "$AUSENTES" > "$LOG"; chmod 600 "$LOG" 2>/dev/null || true
    # Remover os grupos de hooks que só invocam ficheiros ausentes (Python: legível e verificável).
    python3 - "$DESTINO/settings.json" <<'PYEOF'
import json, os, re, sys
alvo = sys.argv[1]
d = json.load(open(alvo, encoding="utf-8"))
hooks = d.get("hooks")
if isinstance(hooks, dict):
    def caminhos(cmd):
        return re.findall(r"(/[^\s\"']+)", cmd or "")
    def hook_vivo(h):
        """Um hook individual: sem caminhos (ex.: node -e inline) fica;
        com caminhos, fica só se algum existir no destino."""
        # Um comando como `"<node>" "<hook>"` referencia dois caminhos: o intérprete existe
        # e o script pode não existir. Basta UM ausente para o comando falhar -> hook morto.
        ps = caminhos(h.get("command", "") if isinstance(h, dict) else "")
        return True if not ps else all(os.path.exists(p) for p in ps)

    removidos = 0
    # statusLine é um objeto simples, não um evento de hooks
    sl = d.get("statusLine")
    if isinstance(sl, dict) and not hook_vivo(sl):
        d.pop("statusLine", None)
        removidos += 1
    for evento in list(hooks):
        grupos = hooks[evento]
        if not isinstance(grupos, list):
            continue
        ficam = []
        for grupo in grupos:
            if not isinstance(grupo, dict):
                ficam.append(grupo); continue
            antes_n = len(grupo.get("hooks", []))
            grupo["hooks"] = [h for h in grupo.get("hooks", []) if hook_vivo(h)]
            removidos += antes_n - len(grupo["hooks"])
            if grupo["hooks"]:
                ficam.append(grupo)
        if ficam:
            hooks[evento] = ficam
        else:
            del hooks[evento]
    if removidos:
        tmp = alvo + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
            f.write("\n")
        os.replace(tmp, alvo)
    print(f"hooks removidos: {removidos}")
PYEOF
    aviso "$(printf '%s\n' "$AUSENTES" | grep -c .) hook(s) referenciam ficheiros ausentes (ver $LOG)"
    aviso "reinstala o plugin que os fornece ou remove as entradas de settings.json"
  fi
fi

# O passo 6b pode reescrever o settings.json (os.replace): repor o modo restrito depois.
[ -f "$DESTINO/settings.json" ] && chmod 600 "$DESTINO/settings.json" 2>/dev/null || true
[ -f "$DESTINO/.claude-global-hooks-removidos.txt" ] && chmod 600 "$DESTINO/.claude-global-hooks-removidos.txt" 2>/dev/null || true

# --- 7. verificações pós-instalação ---------------------------------------------------
VERMELHO=0
SK=$(find "$DESTINO/skills" -maxdepth 1 -type d \( -name 'direcao-geral' -o -name 'equipa-*' \) 2>/dev/null | wc -l | tr -d ' ')
[ "$SK" = 16 ] && ok "16 skills da Direção Geral instaladas" || { aviso "esperava 16 skills, encontrei $SK"; VERMELHO=1; }

HOOKS_QUEBRADOS=0
if [ -f "$DESTINO/settings.json" ]; then
  while IFS= read -r p; do
    [ -e "$p" ] || { aviso "hook aponta para caminho inexistente: $p"; HOOKS_QUEBRADOS=$((HOOKS_QUEBRADOS + 1)); }
  done < <(jq -r '[.. | objects | select(has("command")) | .command] | .[]' "$DESTINO/settings.json" 2>/dev/null \
           | grep -oE "$DESTINO/[^\" ]+" | sort -u)
  [ "$HOOKS_QUEBRADOS" -eq 0 ] && ok "todos os comandos de hook apontam para ficheiros existentes" || VERMELHO=1
  jq -e . "$DESTINO/settings.json" >/dev/null 2>&1 && ok "settings.json é JSON válido" || { aviso "settings.json inválido"; VERMELHO=1; }
fi

# dependências externas (não instaláveis a partir do repo)
[ -d "$DESTINO/skills/agency-commander" ] || aviso "falta a skill de terceiros 'agency-commander' (catálogo agency-agents)"
for s in owasp-security agent-architecture-audit verification-loop; do
  [ -d "$DESTINO/skills/$s" ] || aviso "falta a skill externa '$s' (ver docs/DEPENDENCIAS.md)"
done
command -v claude >/dev/null 2>&1 && ok "CLI 'claude' presente" || aviso "CLI 'claude' ausente: validação com --debug não é possível"

echo
if [ "$VERMELHO" -eq 0 ]; then
  echo "INSTALAÇÃO OK — reverter: bash $RAIZ/desinstalar.sh --destino $DESTINO"
  exit 0
else
  echo "INSTALAÇÃO COM AVISOS — revê as linhas 'aviso' acima."
  exit 1
fi
