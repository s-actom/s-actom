#!/usr/bin/env bash
# reverter-fase-1.sh — desfaz a Fase 1 da Direção Geral a partir do backup feito na ativação.
# Atua em $HOME/.claude (os testes correm-no com um HOME temporário).
# Uso: reverter-fase-1.sh            mostra o que faria (não muda nada)
#      reverter-fase-1.sh --aplicar  desfaz
# Ficheiro que não mudou desde a ativação: volta byte a byte ao backup.
# Ficheiro que mudaste depois da ativação: só sai o que a Fase 1 pôs (hooks, trocas de texto); o resto fica.
# Skills instaladas: saem só os ficheiros com o sha256 da instalação. O registo e o estado (dados) ficam.
# Saída: 0 tudo reposto · 1 ficou algo para veres à mão (está escrito) · 2 uso ou pré-condição
set -u -o pipefail
umask 077

BASE=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P) || { echo "pasta base ilegível" >&2; exit 2; }
C="$HOME/.claude"
[ "$BASE" = "$(cd "$C/equipas" 2>/dev/null && pwd -P)" ] || { echo "o script tem de estar em \$HOME/.claude/equipas/reverter" >&2; exit 2; }
MARCA="$BASE/FASE-1-ATIVA"
HK="$BASE/hooks"
LOCK="$BASE/estado/atualizar.lock.d"

MODO=dry
case "${1:-}" in "") ;; --aplicar) MODO=aplicar ;; -h | --help) sed -n '2,9p' "$0"; exit 0 ;; *) echo "argumento desconhecido: $1" >&2; exit 2 ;; esac
[ $# -le 1 ] || { echo "demasiados argumentos" >&2; exit 2; }
erro() { echo "reverter-fase-1: $*" >&2; exit 2; }
sha() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }
for b in jq python3 shasum; do command -v "$b" >/dev/null 2>&1 || erro "falta $b"; done

[ -f "$MARCA" ] || { echo "Fase 1 não está ativa (sem $MARCA). Nada a fazer."; exit 0; }
REL=$(sed -n 's/^backup=//p' "$MARCA" | head -1)
[[ "$REL" =~ ^backups/fase-1-[0-9]{8}-[0-9]{6}$ ]] || erro "marca com backup inválido: $REL"
B="$BASE/$REL"
[ -f "$B/ANTES.sha256" ] && [ -d "$B/pares" ] || erro "backup incompleto: $B"
[ -f "$B/DEPOIS.sha256" ] || echo "  (ativação interrompida a meio: sem DEPOIS.sha256; só sai o que a Fase 1 pôs)"

PENDENTE=0
diz() { echo "  $*"; }
antes() { awk -v r="./$1" '$2 == r {print $1}' "$B/ANTES.sha256"; }
depois() { [ -f "$B/DEPOIS.sha256" ] && awk -v r="./$1" '$2 == r {print $1}' "$B/DEPOIS.sha256"; }
repor_copia() { # cópia do backup, verificada ANTES de publicar (nunca substitui por lixo)
  local tmp="$C/$1.fase1.tmp" esperado
  esperado=$(antes "$1")
  [ -n "$esperado" ] || return 1
  cp -p "$B/ficheiros/$1" "$tmp" || return 1
  [ "$(sha "$tmp")" = "$esperado" ] || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$C/$1"
}

# Não deixar o refrescamento em segundo plano escrever enquanto se reverte
if [ "$MODO" = aplicar ]; then
  mkdir -p -m 700 "$BASE/estado"
  TEM_LOCK=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do mkdir "$LOCK" 2>/dev/null && { TEM_LOCK=1; break; }; sleep 1; done
  [ "$TEM_LOCK" = 1 ] || erro "o refrescamento das listas está a correr; tenta daqui a 1 minuto"
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT   # só depois de o lock ser nosso
fi

echo "Fase 1: backup $REL"
# 1. settings.json
f=settings.json; cur=$(sha "$C/$f")
if [ "$cur" = "$(antes "$f")" ]; then diz "$f: já está como antes"
elif [ "$cur" = "$(depois "$f")" ]; then
  if [ "$MODO" = aplicar ]; then repor_copia "$f" && diz "$f: reposto do backup (byte a byte)" || { diz "$f: FALHOU a reposição"; PENDENTE=1; }
  else diz "$f: seria reposto do backup"; fi
else
  if [ "$MODO" = aplicar ]; then
    m=$(stat -f %Lp "$C/$f")
    jq --arg hk "$HK/" '
      def nosso: (.command // "") | contains($hk);
      .hooks |= (with_entries(.value |= ([.[] | .hooks |= map(select(nosso | not)) | select(.hooks | length > 0)]))
                 | with_entries(select(.value | length > 0)))
    ' "$C/$f" >"$C/$f.fase1.tmp" && jq -e 'type == "object"' "$C/$f.fase1.tmp" >/dev/null && chmod "$m" "$C/$f.fase1.tmp" && mv "$C/$f.fase1.tmp" "$C/$f" \
      && diz "$f: mudaste-o depois da ativação; tirei só os hooks da Fase 1, o resto ficou" \
      || { rm -f "$C/$f.fase1.tmp"; diz "$f: FALHOU a remoção dos hooks"; PENDENTE=1; }
  else diz "$f: mudou depois da ativação; sairiam só os hooks da Fase 1"; fi
fi

# 2. CLAUDE.md e agency-commander
for par in "CLAUDE.md claude" "skills/agency-commander/SKILL.md commander"; do
  set -- $par; f=$1; pre=$2; cur=$(sha "$C/$f")
  if [ "$cur" = "$(antes "$f")" ]; then diz "$f: já está como antes"
  elif [ "$cur" = "$(depois "$f")" ]; then
    if [ "$MODO" = aplicar ]; then repor_copia "$f" && diz "$f: reposto do backup (byte a byte)" || { diz "$f: FALHOU a reposição"; PENDENTE=1; }
    else diz "$f: seria reposto do backup"; fi
  elif [ "$MODO" = aplicar ]; then
    if python3 -I "$BASE/reverter/troca.py" desfazer "$C/$f" "$B/pares" "$pre"; then diz "$f: mudaste-o depois da ativação; desfiz só as trocas da Fase 1"
    else diz "$f: NÃO reposto: as trocas da Fase 1 já não estão lá tal como foram feitas. Compara com $B/ficheiros/$f"; PENDENTE=1; fi
  else diz "$f: mudou depois da ativação; sairiam só as trocas da Fase 1 (se ainda lá estiverem)"; fi
done

# 3. Skills instaladas
INST="$BASE/estado/instalado.sha256"
[ -f "$INST" ] || INST="$INST.tmp"   # ativação morta a meio da cópia das skills: lista parcial
if [ -f "$INST" ]; then
  n_rm=0; n_fica=0
  while read -r h rel; do
    [[ "$rel" =~ ^(direcao-geral|equipa-[a-z]+)/[A-Za-z0-9._-]+$ ]] || { diz "linha ignorada em instalado.sha256: $rel"; PENDENTE=1; continue; }
    alvo="$C/skills/$rel"
    [ -e "$alvo" ] || continue
    if [ -f "$alvo" ] && [ ! -L "$alvo" ] && [ "$(sha "$alvo")" = "$h" ]; then
      if [ "$MODO" = aplicar ]; then
        if rm -- "$alvo" 2>/dev/null; then n_rm=$((n_rm + 1))
        else diz "FALHOU a remover: skills/$rel (reversão pendente)"; n_fica=$((n_fica + 1)); PENDENTE=1; fi
      else n_rm=$((n_rm + 1)); fi
    else diz "fica (mudou depois da instalação): skills/$rel"; n_fica=$((n_fica + 1)); PENDENTE=1; fi
  done <"$INST"
  if [ "$MODO" = aplicar ]; then
    for d in "$C/skills/direcao-geral" "$C"/skills/equipa-*; do [ -d "$d" ] && [ ! -L "$d" ] && rmdir "$d" 2>/dev/null; done
    [ "$n_fica" -eq 0 ] && rm -f -- "$INST"
  fi
  diz "skills: $n_rm ficheiros $([ "$MODO" = aplicar ] && echo removidos || echo a remover), $n_fica ficam"
else diz "skills: sem instalado.sha256 (nada a remover)"; fi

# 4. hooks/ e rules/ não são mudados pela Fase 1: só se verifica
for d in hooks rules; do
  [ -d "$B/ficheiros/$d" ] || continue
  if (cd "$C" && grep "  \./$d/" "$B/ANTES.sha256" | shasum -a 256 -c --quiet >/dev/null 2>&1); then diz "$d/: igual ao backup"
  else diz "$d/: tem alterações desde a ativação (não são da Fase 1; não mexi)"; fi
done

if [ "$MODO" = dry ]; then echo "Ensaio: nada mudou. Para desfazer: $0 --aplicar"; exit 0; fi
grep -qF "$HK/" "$C/settings.json" && { diz "ATENÇÃO: settings.json ainda cita $HK/"; PENDENTE=1; }
for d in "$C/skills/direcao-geral" "$C"/skills/equipa-*; do
  [ -e "$d" ] && { diz "ATENÇÃO: ainda existe $d"; PENDENTE=1; }
done
[ "$PENDENTE" -eq 0 ] && rm -f -- "$MARCA"
echo "Registo e estado ficaram (são dados): $BASE/registo.jsonl, $BASE/estado/"
if [ "$PENDENTE" -eq 0 ]; then echo "Fase 1 desfeita. Abre uma sessão nova para o Claude Code ler a configuração reposta."; exit 0; fi
echo "Fase 1 desfeita em parte: vê as linhas acima. A marca $MARCA ficou."; exit 1
