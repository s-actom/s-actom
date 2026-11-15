#!/usr/bin/env bash
# teste-aplicar.sh — prova as garantias do aplicador limitado ao manifesto (aplicar.sh).
# Corre inteiramente em pastas temporárias: não toca em $HOME/.claude.
# Exit 0 = tudo OK.
set -u
T=$(mktemp -d) || exit 2
trap 'chmod -R u+rwX -- "$T" 2>/dev/null; rm -R -- "$T"' EXIT
RAIZ_PACOTE="$(cd "$(dirname "$0")" && pwd -P)"
[ -f "$RAIZ_PACOTE/aplicar.sh" ] || { echo "sem aplicar.sh em $RAIZ_PACOTE" >&2; exit 2; }
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }
sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }

# Pacote sintético com dois ficheiros + manifesto coerente com o destino.
montar() {
  rm -R -- "$T/pkg" "$T/dest" 2>/dev/null
  mkdir -p "$T/pkg/docs" "$T/pkg/equipas/hooks" "$T/pkg/agents/security" \
           "$T/dest/equipas/hooks" "$T/dest/agents/security"
  cp "$RAIZ_PACOTE/aplicar.sh" "$T/pkg/aplicar.sh"
  printf 'novo-hook\n' >"$T/pkg/equipas/hooks/h.sh"
  printf 'novo-agente\n' >"$T/pkg/agents/security/a.md"
  # destino ANTES da correção
  printf 'velho-hook\n' >"$T/dest/equipas/hooks/h.sh"
  printf 'velho-agente\n' >"$T/dest/agents/security/a.md"
  chmod 640 "$T/dest/equipas/hooks/h.sh"
  {
    echo "# teste"
    for rel in equipas/hooks/h.sh agents/security/a.md; do
      printf '%s\t%s\t%s\t%s\n' "$rel" "$(sha "$T/dest/$rel")" "$(sha "$T/dest/$rel")" "$(sha "$T/pkg/$rel")"
    done
  } >"$T/pkg/docs/manifesto-correcoes.tsv"
}
aplicar() { bash "$T/pkg/aplicar.sh" --destino "$T/dest" --sem-testes "$@"; }

# --- 1. ensaio não escreve nada -------------------------------------------
montar
ANTES_H=$(sha "$T/dest/equipas/hooks/h.sh")
bash "$T/pkg/aplicar.sh" --destino "$T/dest" --sem-testes --ensaio >"$T/out1" 2>&1; RC=$?
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$ANTES_H" ] && ok "1) ensaio não escreve" || ko "1) ensaio alterou o destino"
[ "$RC" -eq 0 ] && ok "1) ensaio sai 0 sem conflitos" || ko "1) ensaio saiu $RC"
[ ! -e "$T/dest/equipas/hooks/.aplicar.tmp" ] && ok "1) ensaio sem temporários" || ko "1) ensaio deixou lixo"

# --- 2. aplicação: substitui, preserva modo, backup verificável -----------
montar
aplicar >"$T/out2" 2>&1; RC=$?
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$(sha "$T/pkg/equipas/hooks/h.sh")" ] \
  && ok "2) ficheiro substituído" || ko "2) ficheiro não substituído"
[ "$(stat -f %Lp "$T/dest/equipas/hooks/h.sh")" = "640" ] \
  && ok "2) modo original preservado (640)" || ko "2) modo alterado: $(stat -f %Lp "$T/dest/equipas/hooks/h.sh")"
[ "$RC" -eq 0 ] && ok "2) sai 0" || ko "2) saiu $RC"
BK=$(sed -n 's/^ok - backup: //p' "$T/out2" | head -1)
[ -n "$BK" ] && [ -d "$BK" ] && ok "2) backup registado" || ko "2) sem backup no output"
# ANTES.sha256 descreve o estado PRÉ-aplicação: verifica-se contra as cópias do backup.
( cd "$BK/ficheiros" && shasum -a 256 -c --quiet ../ANTES.sha256 >/dev/null 2>&1 ) \
  && ok "2) ANTES.sha256 confere contra o backup" || ko "2) cópia do backup não confere com ANTES.sha256"
[ "$(stat -f %Lp "$BK")" = "700" ] && ok "2) backup privado (0700)" || ko "2) backup com modo $(stat -f %Lp "$BK")"

# --- 3. rollback repõe byte a byte ---------------------------------------
bash "$T/pkg/aplicar.sh" --destino "$T/dest" --rollback --backup "$BK" >"$T/out3" 2>&1; RC=$?
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$(printf 'velho-hook\n' | shasum -a 256 | cut -d' ' -f1)" ] \
  && ok "3) rollback repôs o original" || ko "3) rollback não repôs"
[ "$(stat -f %Lp "$T/dest/equipas/hooks/h.sh")" = "640" ] && ok "3) rollback preserva o modo" || ko "3) modo perdido no rollback"
[ "$RC" -eq 0 ] && ok "3) rollback sai 0" || ko "3) rollback saiu $RC"

# --- 4. conflito: destino divergiu -> não substituir, aplicar o resto ------
montar
printf 'editado-pelo-dono\n' >"$T/dest/equipas/hooks/h.sh"
DONO=$(sha "$T/dest/equipas/hooks/h.sh")
aplicar >"$T/out4" 2>&1; RC=$?
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$DONO" ] && ok "4) ficheiro divergente preservado" || ko "4) pisou a alteração do dono"
[ "$(sha "$T/dest/agents/security/a.md")" = "$(sha "$T/pkg/agents/security/a.md")" ] \
  && ok "4) alteração independente aplicada" || ko "4) não aplicou a alteração independente"
grep -q "CONFLITO: equipas/hooks/h.sh" "$T/out4" && ok "4) conflito registado" || ko "4) conflito não registado"
[ "$RC" -eq 1 ] && ok "4) sai 1 (parcial)" || ko "4) saiu $RC, esperado 1"

# --- 5. rollback não pisa o que mudou depois da aplicação -----------------
montar
aplicar >"$T/out5" 2>&1
BK5=$(sed -n 's/^ok - backup: //p' "$T/out5" | head -1)
printf 'mexido-depois\n' >"$T/dest/agents/security/a.md"
DEPOIS=$(sha "$T/dest/agents/security/a.md")
bash "$T/pkg/aplicar.sh" --destino "$T/dest" --rollback --backup "$BK5" >"$T/out5b" 2>&1; RC=$?
[ "$(sha "$T/dest/agents/security/a.md")" = "$DEPOIS" ] && ok "5) rollback não pisa alteração posterior" || ko "5) rollback pisou alteração posterior"
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$(printf 'velho-hook\n' | shasum -a 256 | cut -d' ' -f1)" ] \
  && ok "5) o outro ficheiro foi revertido" || ko "5) não reverteu o ficheiro intacto"
[ "$RC" -eq 1 ] && ok "5) sai 1 (parcial)" || ko "5) saiu $RC, esperado 1"

# --- 6. origem alterada no pacote: aborta sem escrever nada ---------------
montar
printf 'adulterado\n' >"$T/pkg/agents/security/a.md"
ANTES_A=$(sha "$T/dest/agents/security/a.md")
aplicar >"$T/out6" 2>&1; RC=$?
[ "$(sha "$T/dest/agents/security/a.md")" = "$ANTES_A" ] && ok "6) origem adulterada: nada escrito" || ko "6) escreveu com origem adulterada"
[ "$RC" -eq 2 ] && ok "6) sai 2 (pré-condição)" || ko "6) saiu $RC, esperado 2"
grep -q "origem alterada" "$T/out6" && ok "6) reporta a origem alterada" || ko "6) não reporta"

# --- 7. caminho fora do destino é rejeitado -------------------------------
montar
printf '../fuga\tabc\tabc\tabc\n' >>"$T/pkg/docs/manifesto-correcoes.tsv"
aplicar >"$T/out7" 2>&1; RC=$?
[ "$RC" -eq 2 ] && ok "7) caminho com .. rejeitado" || ko "7) aceitou caminho com .."
[ ! -e "$T/fuga" ] && ok "7) nada escrito fora do destino" || ko "7) escreveu fora do destino"

# --- 8. criação de ficheiro novo e repetição idempotente ------------------
montar
printf 'novo-teste\n' >"$T/pkg/equipas/hooks/novo.sh"
printf 'equipas/hooks/novo.sh\t-\t-\t%s\n' "$(sha "$T/pkg/equipas/hooks/novo.sh")" \
  >>"$T/pkg/docs/manifesto-correcoes.tsv"
aplicar >"$T/out8" 2>&1; RC=$?
[ -f "$T/dest/equipas/hooks/novo.sh" ] && ok "8) ficheiro novo criado" || ko "8) não criou o ficheiro novo"
[ "$RC" -eq 0 ] && ok "8) sai 0" || ko "8) saiu $RC"
# Repetição: o manifesto regenerado passa a esperar o hash corrigido (idempotência).
awk -F'\t' 'BEGIN{OFS="\t"} /^#/{print;next} {$3=$4; print}' "$T/pkg/docs/manifesto-correcoes.tsv" >"$T/m2"
mv "$T/m2" "$T/pkg/docs/manifesto-correcoes.tsv"
aplicar >"$T/out8b" 2>&1; RC=$?
grep -q "já está corrigido: equipas/hooks/novo.sh" "$T/out8b" \
  && ok "8) repetição: ficheiro criado não é conflito" || ko "8) repetição marcou o ficheiro criado como conflito"
[ "$RC" -eq 0 ] && ok "8) repetição sai 0" || ko "8) repetição saiu $RC"

# --- 9. falha da bateria -> rollback automático só desta operação ---------
montar
printf '#!/usr/bin/env bash\nexit 1\n' >"$T/dest/testes-agentes.sh"
chmod +x "$T/dest/testes-agentes.sh"
bash "$T/pkg/aplicar.sh" --destino "$T/dest" >"$T/out9" 2>&1; RC=$?
[ "$(sha "$T/dest/equipas/hooks/h.sh")" = "$(printf 'velho-hook\n' | shasum -a 256 | cut -d' ' -f1)" ] \
  && ok "9) bateria falhada: ficheiro revertido" || ko "9) ficou aplicado apesar da falha"
[ "$(sha "$T/dest/agents/security/a.md")" = "$(printf 'velho-agente\n' | shasum -a 256 | cut -d' ' -f1)" ] \
  && ok "9) bateria falhada: segundo ficheiro revertido" || ko "9) segundo ficheiro ficou aplicado"
grep -q "REVERTIDO" "$T/out9" && ok "9) reporta a reversão" || ko "9) não reporta a reversão"
[ "$RC" -eq 1 ] && ok "9) sai 1" || ko "9) saiu $RC, esperado 1"

echo
if [ "$FALHAS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALHAS falha(s)"; exit 1; fi