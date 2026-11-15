#!/usr/bin/env bash
# aplicar.sh — aplica APENAS os ficheiros listados em docs/manifesto-correcoes.tsv.
#
# Substitui a instalação abrangente para o caso "corrigir ficheiros existentes": não copia
# o pacote, não toca em settings.json, não instala skills e não mexe em nada fora do manifesto.
#
# Uso:
#   aplicar.sh [--destino DIR] [--ensaio]           aplica (default: $HOME/.claude)
#   aplicar.sh --destino DIR --rollback --backup D  desfaz uma aplicação anterior
#   aplicar.sh --destino DIR --sem-testes           aplica sem correr a bateria final
#
# Manifesto (TSV, uma linha por ficheiro, '#' comenta):
#   rel <TAB> hash_original <TAB> hash_esperado_antes <TAB> hash_corrigido
#   hash_original ....... hash do ficheiro no destino quando o manifesto foi gerado ("-" = não existia)
#   hash_esperado_antes .. hash exigido no destino no momento de aplicar (se divergir: CONFLITO)
#   hash_corrigido ...... hash da versão corrigida no pacote (integridade da origem)
#
# Garantias:
#   - ficheiro do destino que não case com hash_esperado_antes NÃO é substituído (conflito
#     registado, os restantes continuam);
#   - ficheiro aberto por um processo é saltado (não se escreve por baixo de um escritor);
#   - backup privado (0700) por execução, com hashes ANTES verificáveis (shasum -c);
#   - escrita atómica (temp na mesma pasta + mv), modo do ficheiro original preservado;
#   - se a bateria de testes falhar, reverte SÓ os ficheiros desta operação e SÓ se ainda
#     estiverem com o hash que escrevemos (não pisa alterações entretanto).
# Exit: 0 aplicado e testado · 1 parcial (conflitos/falhas) · 2 uso ou pré-condição
set -u -o pipefail

RAIZ=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 2
MAN="$RAIZ/docs/manifesto-correcoes.tsv"
DESTINO="$HOME/.claude"
ENSAIO=0
ROLLBACK=0
TESTES=1
BACKUP=""

erro() { echo "aplicar: $*" >&2; exit 2; }
ok()   { echo "ok - $*"; }
diz()  { echo "  $*"; }
aviso(){ echo "aviso - $*" >&2; }
sha()  { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --destino) [ $# -ge 2 ] || erro "falta o valor de --destino"; DESTINO="$2"; shift 2 ;;
    --ensaio)  ENSAIO=1; shift ;;
    --rollback) ROLLBACK=1; shift ;;
    --sem-testes) TESTES=0; shift ;;
    --backup) [ $# -ge 2 ] || erro "falta o valor de --backup"; BACKUP="$2"; shift 2 ;;
    -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
    *) erro "argumento desconhecido: $1" ;;
  esac
done

for b in shasum python3; do command -v "$b" >/dev/null 2>&1 || erro "falta $b"; done
[ -d "$DESTINO" ] || erro "destino inexistente: $DESTINO"
DESTINO=$(cd "$DESTINO" && pwd -P) || erro "destino inválido: $DESTINO"

# --- rollback de uma aplicação anterior -----------------------------------
if [ "$ROLLBACK" = 1 ]; then
  [ -n "$BACKUP" ] || erro "--rollback exige --backup <pasta da execução>"
  [ -d "$BACKUP" ] || erro "backup inexistente: $BACKUP"
  J="$BACKUP/aplicado.tsv"; A="$BACKUP/ANTES.sha256"
  [ -f "$J" ] || erro "sem $J (não foi este aplicador que escreveu?)"
  PENDENTE=0; n=0
  while IFS=$'\t' read -r rel orig corr _quando; do
    case "$rel" in ''|'#'*) continue ;; esac
    alvo="$DESTINO/$rel"
    atual=$(sha "$alvo")
    if [ "$atual" != "$corr" ]; then
      diz "fica (mudou depois de aplicar): $rel"; PENDENTE=1; continue
    fi
    if [ "$orig" = "-" ]; then
      if [ "$ENSAIO" = 1 ]; then diz "removeria (criado pela aplicação): $rel"
      else rm -f -- "$alvo" && n=$((n + 1)) || { diz "FALHOU a remover: $rel"; PENDENTE=1; }; fi
    else
      fonte="$BACKUP/ficheiros/$rel"
      [ -f "$fonte" ] || { diz "FALHOU: sem cópia de $rel no backup"; PENDENTE=1; continue; }
      [ "$(sha "$fonte")" = "$orig" ] || { diz "FALHOU: cópia do backup não confere em $rel"; PENDENTE=1; continue; }
      if [ "$ENSAIO" = 1 ]; then diz "restauraria: $rel"; continue; fi
      tmp="$(dirname -- "$alvo")/.aplicar-rb.$$.tmp"
      cp -p "$fonte" "$tmp" && chmod "$(stat -f %Lp "$alvo")" "$tmp" 2>/dev/null && mv -f -- "$tmp" "$alvo" \
        && n=$((n + 1)) || { rm -f -- "$tmp"; diz "FALHOU a restaurar: $rel"; PENDENTE=1; }
    fi
  done <"$J"
  if [ "$ENSAIO" = 1 ]; then ok "ensaio de rollback: nada foi alterado"; exit 0; fi
  # Verificar a INTEGRIDADE DO BACKUP (as cópias, não o destino: o destino já foi alterado).
  ( cd "$BK/ficheiros" && shasum -a 256 -c --quiet ../ANTES.sha256 >/dev/null 2>&1 ) \
    && ok "backup ANTES.sha256 confere" || aviso "backup ANTES.sha256 não confere (cópia corrompida?)"
  if [ "$PENDENTE" = 0 ]; then ok "$n ficheiros revertidos"; exit 0; fi
  echo "ROLLBACK PARCIAL: revê os 'fica' acima." >&2; exit 1
fi

# --- aplicação -------------------------------------------------------------
[ -f "$MAN" ] || erro "sem manifesto: $MAN"
command -v lsof >/dev/null 2>&1 || aviso "lsof ausente: não é possível detetar ficheiros abertos"

# 1. Validar o manifesto e a integridade da origem ANTES de escrever nada.
ORIGEM_MAU=0; N_LINHAS=0
while IFS=$'\t' read -r rel orig esp corr; do
  case "$rel" in ''|'#'*) continue ;; esac
  [[ "$rel" == /* || "$rel" == *..* ]] && { echo "manifesto: caminho inválido: $rel" >&2; ORIGEM_MAU=1; continue; }
  [[ "$esp" =~ ^[0-9a-f]{64}$ && "$corr" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "manifesto: hash inválido em $rel" >&2; ORIGEM_MAU=1; continue; }
  [ "$orig" = "-" ] || [[ "$orig" =~ ^[0-9a-f]{64}$ ]] \
    || { echo "manifesto: hash_original inválido em $rel" >&2; ORIGEM_MAU=1; continue; }
  [ -f "$RAIZ/$rel" ] || { echo "manifesto: origem ausente no pacote: $rel" >&2; ORIGEM_MAU=1; continue; }
  [ "$(sha "$RAIZ/$rel")" = "$corr" ] \
    || { echo "manifesto: origem alterada (hash != corrigido): $rel" >&2; ORIGEM_MAU=1; continue; }
  N_LINHAS=$((N_LINHAS + 1))
done <"$MAN"
[ "$ORIGEM_MAU" = 0 ] || erro "manifesto/origem inválidos: nada foi escrito"
[ "$N_LINHAS" -gt 0 ] || erro "manifesto vazio"

BK="$BACKUP"
if [ -z "$BK" ]; then
  if [ "$ENSAIO" = 1 ]; then BK="(ensaio)"; else
    BK=$(mktemp -d "${TMPDIR:-/tmp}/aplicar-backup.XXXXXX") || erro "sem espaço para o backup"
    chmod 700 "$BK" || erro "sem permissões no backup"
    mkdir -p "$BK/ficheiros"
  fi
fi

# 2. Backup + verificação de conflitos, ficheiro a ficheiro.
CONFLITOS=0; APLICADOS=0; CRIADOS=0; SALTADOS=0
if [ "$ENSAIO" = 0 ]; then
  : >"$BK/aplicado.tsv" || erro "sem escrita no backup"
  : >"$BK/ANTES.sha256" || erro "sem escrita no backup"
fi

while IFS=$'\t' read -r rel orig esp corr; do
  case "$rel" in ''|'#'*) continue ;; esac
  alvo="$DESTINO/$rel"
  atual=$(sha "$alvo")
  if [ -z "$atual" ]; then atual="-"; fi

  if [ "$orig" = "-" ] && [ "$atual" != "-" ]; then
    diz "CONFLITO: $rel já existe no destino (o manifesto esperava criá-lo)"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  if [ "$orig" != "-" ] && [ "$atual" = "-" ]; then
    diz "CONFLITO: $rel desapareceu do destino"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  if [ "$atual" != "$esp" ]; then
    diz "CONFLITO: $rel divergiu (destino=$atual esperado=$esp); não foi tocado"
    CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  if [ "$atual" = "$corr" ]; then
    diz "já está corrigido: $rel"; SALTADOS=$((SALTADOS + 1)); continue
  fi
  if command -v lsof >/dev/null 2>&1 && [ -n "$(lsof -t -- "$alvo" 2>/dev/null)" ]; then
    diz "CONFLITO: $rel está aberto por um processo; não se escreve por baixo"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi

  if [ "$ENSAIO" = 1 ]; then diz "aplicaria: $rel ($atual -> $corr)"; APLICADOS=$((APLICADOS + 1)); continue; fi

  # backup do original (só se existia)
  if [ "$atual" != "-" ]; then
    mkdir -p "$BK/ficheiros/$(dirname -- "$rel")" || { diz "FALHOU: backup de $rel"; CONFLITOS=$((CONFLITOS + 1)); continue; }
    cp -p "$alvo" "$BK/ficheiros/$rel" || { diz "FALHOU: backup de $rel"; CONFLITOS=$((CONFLITOS + 1)); continue; }
    printf '%s  ./%s\n' "$atual" "$rel" >>"$BK/ANTES.sha256"
  fi

  pasta=$(dirname -- "$alvo")
  mkdir -p "$pasta" || { diz "FALHOU: sem pasta para $rel"; CONFLITOS=$((CONFLITOS + 1)); continue; }
  tmp="$pasta/.aplicar.$$.tmp"
  if ! cp -p "$RAIZ/$rel" "$tmp"; then
    rm -f -- "$tmp"; diz "FALHOU: cópia de $rel"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  # modo do original (a posse fica a do utilizador que corre: é o mesmo que já lá estava)
  [ "$atual" != "-" ] && chmod "$(stat -f %Lp "$alvo")" "$tmp" 2>/dev/null
  if [ "$(sha "$tmp")" != "$corr" ]; then
    rm -f -- "$tmp"; diz "FALHOU: cópia corrompida em $rel"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  # reconferir o destino imediatamente antes de publicar (o dono pode ter gravado entretanto)
  if [ "$(sha "$alvo")" != "$esp" ] && [ "$atual" != "-" ]; then
    rm -f -- "$tmp"; diz "CONFLITO: $rel mudou durante a aplicação; não foi tocado"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  if ! mv -f -- "$tmp" "$alvo"; then
    rm -f -- "$tmp"; diz "FALHOU: publicação de $rel"; CONFLITOS=$((CONFLITOS + 1)); continue
  fi
  printf '%s\t%s\t%s\t%s\n' "$rel" "$atual" "$corr" "$(date +%Y%m%d-%H%M%S)" >>"$BK/aplicado.tsv"
  if [ "$atual" = "-" ]; then CRIADOS=$((CRIADOS + 1)); else APLICADOS=$((APLICADOS + 1)); fi
done <"$MAN"

echo
if [ "$ENSAIO" = 1 ]; then
  echo "ENSAIO: $APLICADOS aplicar-se-iam, $CONFLITOS conflito(s), $SALTADOS já corretos. Nada foi escrito."
  [ "$CONFLITOS" -eq 0 ] && exit 0 || exit 1
fi
ok "backup: $BK"
ok "$APLICADOS substituídos, $CRIADOS criados, $SALTADOS já corretos, $CONFLITOS conflito(s)"

# 3. Bateria de regressão sobre o ambiente atualizado.
FALHOU_TESTES=0
if [ "$TESTES" = 1 ] && [ $((APLICADOS + CRIADOS)) -gt 0 ]; then
  echo
  echo "Bateria de regressão em $DESTINO"
  # O backup é a rede de segurança: tem de estar verificável ANTES de confiar nele.
  ( cd "$BK/ficheiros" && shasum -a 256 -c --quiet ../ANTES.sha256 >/dev/null 2>&1 ) \
    && ok "backup verificável (ANTES.sha256)" || { aviso "backup ANTES.sha256 não confere"; FALHOU_TESTES=1; }
  if [ -d "$DESTINO/equipas/gerador" ]; then
    ( cd "$DESTINO/equipas/gerador" && PYTHONPATH=..:. python3 -m unittest discover -s tests >/dev/null 2>&1 ) \
      && ok "python (equipas/gerador)" || { aviso "falharam testes python"; FALHOU_TESTES=1; }
  fi
  if [ -f "$DESTINO/testes-agentes.sh" ]; then
    bash "$DESTINO/testes-agentes.sh" >/dev/null 2>&1 && ok "guarda dos agentes" || { aviso "guarda dos agentes falhou"; FALHOU_TESTES=1; }
  fi
  if [ -f "$DESTINO/equipas/reverter/testes/test-reverter-integridade.sh" ]; then
    bash "$DESTINO/equipas/reverter/testes/test-reverter-integridade.sh" >/dev/null 2>&1 \
      && ok "integridade do rollback" || { aviso "teste de rollback falhou"; FALHOU_TESTES=1; }
  fi
  if command -v node >/dev/null 2>&1 && [ -d "$DESTINO/equipas/hooks/tests" ]; then
    ( cd "$DESTINO/equipas/hooks" && node --test tests/*.test.mjs >/dev/null 2>&1 ) \
      && ok "node (equipas/hooks)" || { aviso "falharam testes node"; FALHOU_TESTES=1; }
  fi
fi

if [ "$FALHOU_TESTES" = 1 ]; then
  echo
  echo "REVERTER (só esta operação): $0 --destino $DESTINO --rollback --backup $BK" >&2
  exit 1
fi
[ "$CONFLITOS" -eq 0 ] || { echo "APLICAÇÃO PARCIAL: $CONFLITOS conflito(s)." >&2; exit 1; }
echo "APLICAÇÃO COMPLETA"
exit 0
