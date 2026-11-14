#!/usr/bin/env bash
# Testa ativar-fase-1.sh e reverter-fase-1.sh num HOME temporário (cópias; settings sem o bloco env).
# Correr: bash ~/.claude/equipas/reverter/testes/test-fase-1.sh
set -u
REAL="$HOME/.claude"
# Fonte dos ficheiros antes da ativação: com a Fase 1 ativa, vêm do backup que a marca indica.
SRC="$REAL"
if [ -f "$REAL/equipas/FASE-1-ATIVA" ]; then
  REL=$(sed -n 's/^backup=//p' "$REAL/equipas/FASE-1-ATIVA" | head -1)
  [[ "$REL" =~ ^backups/fase-1-[0-9]{8}-[0-9]{6}$ ]] && SRC="$REAL/equipas/$REL/ficheiros" || { echo "marca inválida" >&2; exit 2; }
fi
T=$(mktemp -d) && [ -d "$T" ] || exit 2
trap 'rm -R -- "$T"' EXIT
H="$T/home"; C="$H/.claude"
FALHAS=0
ok() { echo "ok - $1"; }
ko() { echo "FALHOU - $1"; FALHAS=$((FALHAS + 1)); }
sha() { shasum -a 256 -- "$1" | cut -d' ' -f1; }

montar() {
  [ -d "$H" ] && rm -R -- "$H"
  mkdir -p "$C/skills" "$C/hooks" "$C/rules"
  jq 'del(.env)' "$SRC/settings.json" >"$C/settings.json" && chmod 600 "$C/settings.json"
  cp "$SRC/CLAUDE.md" "$C/CLAUDE.md"
  mkdir -p "$C/skills/agency-commander" && cp "$SRC/skills/agency-commander/SKILL.md" "$C/skills/agency-commander/"
  echo '{"permissions":{}}' >"$C/settings.local.json"
  echo 'x' >"$C/hooks/h.js"; echo 'r' >"$C/rules/r.md"
  mkdir -p "$C/equipas"
  for p in equipas.yaml seguranca.md rascunho reverter hooks; do cp -R "$REAL/equipas/$p" "$C/equipas/"; done
  rm -R -- "$C/equipas/reverter/testes"
  ORIG_S=$(sha "$C/settings.json"); ORIG_C=$(sha "$C/CLAUDE.md"); ORIG_K=$(sha "$C/skills/agency-commander/SKILL.md")
}
ativar() { HOME="$H" bash "$C/equipas/reverter/ativar-fase-1.sh" "$@"; }
reverter() { HOME="$H" bash "$C/equipas/reverter/reverter-fase-1.sh" "$@"; }
intactos() { [ "$(sha "$C/settings.json")" = "$ORIG_S" ] && [ "$(sha "$C/CLAUDE.md")" = "$ORIG_C" ] && [ "$(sha "$C/skills/agency-commander/SKILL.md")" = "$ORIG_K" ]; }
n_skills() { find "$C/skills" -maxdepth 1 \( -name 'equipa-*' -o -name direcao-geral \) | wc -l | tr -d ' '; }

montar
ativar >/dev/null && intactos && [ "$(n_skills)" = 0 ] && ok "ensaio da ativação não muda nada" || ko "ensaio mudou algo"
ativar --aplicar >"$T/a1.txt" 2>&1 && ok "ativação: sai 0" || { ko "ativação falhou"; cat "$T/a1.txt"; }
[ -f "$C/equipas/FASE-1-ATIVA" ] && [ "$(n_skills)" = 16 ] && ok "16 skills instaladas e marca criada" || ko "skills ou marca"
[ "$(grep -o "$C/equipas/hooks/" "$C/settings.json" | wc -l | tr -d ' ')" = 6 ] && jq -e . "$C/settings.json" >/dev/null && ok "settings: 6 comandos de hooks novos, JSON válido" || ko "settings"
jq -e '[.hooks.Stop[] | select(any(.hooks[]; .command | test("coderabbit-stop-gate")))][0].hooks | map(.command) | any(test("rede-vibesec"))' "$C/settings.json" >/dev/null && ok "Stop: rede VibeSec junto ao CodeRabbit" || ko "Stop"
jq -e '[.hooks.PostToolUse[] | select(.matcher == "Skill")] | length == 1' "$C/settings.json" >/dev/null && jq -e '.hooks.UserPromptExpansion | length == 1' "$C/settings.json" >/dev/null && ok "PostToolUse[Skill] e UserPromptExpansion" || ko "registo de equipas"
GSC="bash \"$(cd "$C/equipas/hooks" && pwd -P)/guarda-sessao.sh\" || true"; BK="$C/equipas/$(sed -n 's/^backup=//p' "$C/equipas/FASE-1-ATIVA")/ficheiros/settings.json"
# Timeout 30 s: as 5 equipas com guarda correm em série dentro deste hook (o orçamento dos 5 hooks do frontmatter, 5 × 5 s).
jq -e --arg c "$GSC" --slurpfile o "$BK" '.hooks.PreToolUse[-1] == {matcher: "Bash|Monitor|mcp__.*", hooks: [{type: "command", command: $c, timeout: 30}]}
  and .hooks.PreToolUse[:-1] == ($o[0].hooks.PreToolUse // [])' "$C/settings.json" >/dev/null && ok "PreToolUse: guarda da sessão no fim (Bash|Monitor|mcp__.*, || true, timeout 30), grupos anteriores intactos" || ko "PreToolUse: guarda da sessão"
grep -q '^## Direção Geral — único decisor$' "$C/CLAUDE.md" && ! grep -q '^## Agentes — Routing$' "$C/CLAUDE.md" && ! grep -q 'invocar primeiro a skill `agency-commander`' "$C/CLAUDE.md" && ok "CLAUDE.md: um só decisor" || ko "CLAUDE.md"
grep -q '^description: "Substituído por direcao-geral' "$C/skills/agency-commander/SKILL.md" && ok "agency-commander: substituído" || ko "agency-commander"
[ "$(stat -f %Lp "$C/settings.json")" = 600 ] && ok "settings mantém o modo 600" || ko "modo do settings"
ativar --aplicar | grep -q 'já ativa' && ok "2.ª ativação não faz nada" || ko "2.ª ativação"

reverter >/dev/null && [ -f "$C/equipas/FASE-1-ATIVA" ] && [ "$(n_skills)" = 16 ] && ok "ensaio da reversão não muda nada" || ko "ensaio da reversão"
reverter --aplicar >"$T/r1.txt" 2>&1 && ok "reversão: sai 0" || { ko "reversão falhou"; cat "$T/r1.txt"; }
intactos && ok "settings, CLAUDE.md e agency-commander iguais byte a byte ao original" || ko "não ficou igual ao original"
[ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && ok "skills removidas e marca apagada" || ko "skills ou marca ficaram"

ativar --aplicar >/dev/null 2>&1 && [ "$(n_skills)" = 16 ] && ok "reativação" || ko "reativação"
# O dono muda coisas depois da ativação: a reversão tira só o que é da Fase 1
jq '.permissions.allow += ["Bash(ls:*)"]' "$C/settings.json" >"$C/s.tmp" && mv "$C/s.tmp" "$C/settings.json"
printf '\nLinha nova do dono.\n' >>"$C/CLAUDE.md"
printf '\nNota do dono.\n' >>"$C/skills/agency-commander/SKILL.md"
reverter --aplicar >"$T/r2.txt" 2>&1 && ok "reversão com alterações do dono: sai 0" || { ko "reversão cirúrgica falhou"; cat "$T/r2.txt"; }
! grep -q "$C/equipas/hooks/" "$C/settings.json" && jq -e '.permissions.allow | index("Bash(ls:*)")' "$C/settings.json" >/dev/null && ok "settings: sem hooks da Fase 1 e com a permissão do dono" || ko "settings cirúrgico"
[ "$(sha "$C/CLAUDE.md")" = "$( { cat "$SRC/CLAUDE.md"; printf '\nLinha nova do dono.\n'; } | shasum -a 256 | cut -d' ' -f1)" ] && ok "CLAUDE.md: original + linha do dono" || ko "CLAUDE.md cirúrgico"
grep -q 'Nota do dono' "$C/skills/agency-commander/SKILL.md" && ! grep -q 'Substituído por direcao-geral' "$C/skills/agency-commander/SKILL.md" && ok "agency-commander: descrição reposta, nota do dono fica" || ko "agency-commander cirúrgico"

# Skill instalada mudada à mão: fica e a reversão avisa (sai 1, marca fica)
montar; ativar --aplicar >/dev/null 2>&1
printf '\nmexida\n' >>"$C/skills/equipa-ia/SKILL.md"
reverter --aplicar >"$T/r3.txt" 2>&1; rc=$?
[ $rc -eq 1 ] && grep -q 'fica (mudou depois da instalação): skills/equipa-ia/SKILL.md' "$T/r3.txt" && [ -f "$C/skills/equipa-ia/SKILL.md" ] && [ -f "$C/equipas/FASE-1-ATIVA" ] && ok "skill mexida fica, aviso e saída 1" || { ko "skill mexida (rc=$rc)"; cat "$T/r3.txt"; }
intactos && ok "mesmo assim, settings/CLAUDE.md/commander repostos" || ko "reposição parcial"

# Ativação interrompida a meio (simulada: sem DEPOIS.sha256 e marca em "a-ativar"): a reversão repõe tudo
montar; ativar --aplicar >/dev/null 2>&1
REL=$(sed -n 's/^backup=//p' "$C/equipas/FASE-1-ATIVA"); rm -- "$C/equipas/$REL/DEPOIS.sha256"
printf 'backup=%s\nestado=a-ativar\n' "$REL" >"$C/equipas/FASE-1-ATIVA"
reverter --aplicar >"$T/r4.txt" 2>&1; rc=$?
[ $rc -eq 0 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && ok "ativação interrompida: a reversão repõe tudo byte a byte" || { ko "ativação interrompida (rc=$rc)"; cat "$T/r4.txt"; }

# Lock de outro processo (refrescamento a correr): a reversão não avança nem apaga o lock alheio
montar; ativar --aplicar >/dev/null 2>&1; mkdir -p "$C/equipas/estado/atualizar.lock.d"
reverter --aplicar >"$T/r5.txt" 2>&1; rc=$?
[ $rc -eq 2 ] && [ -d "$C/equipas/estado/atualizar.lock.d" ] && [ "$(n_skills)" = 16 ] && [ -f "$C/equipas/FASE-1-ATIVA" ] && ok "lock alheio: sai 2, nada mexido, lock fica" || { ko "lock alheio (rc=$rc)"; cat "$T/r5.txt"; }

# Pré-condições: nada muda quando falham
montar; sed -i '' 's/^## Agentes — Routing$/## Agentes/' "$C/CLAUDE.md"; ORIG_C=$(sha "$C/CLAUDE.md")
ativar --aplicar >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -d "$C/equipas/backups" ] && ok "CLAUDE.md sem a secção esperada: sai 2, nada muda" || ko "pré-condição CLAUDE.md (rc=$rc)"
montar; mkdir -p "$C/skills/equipa-ia" && echo x >"$C/skills/equipa-ia/SKILL.md"
ativar --aplicar >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && intactos && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && ok "colisão de nome: sai 2, nada muda" || ko "colisão (rc=$rc)"
montar; rm "$C/equipas/hooks/guarda-sessao.sh"
ativar --aplicar >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && intactos && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && ok "falta guarda-sessao.sh: sai 2, nada muda" || ko "pré-condição guarda-sessao.sh (rc=$rc)"
# B-2: um rascunho com mais do que name e description no frontmatter (ex.: hooks) é recusado antes de mudar alguma coisa
montar; F="$C/equipas/rascunho/equipa-infraestrutura/SKILL.md"
awk 'NR == 3 { print; print "hooks:"; print "  PreToolUse: []"; next } { print }' "$F" >"$T/s.md" && cat "$T/s.md" >"$F"
ativar --aplicar >"$T/a2.txt" 2>&1; rc=$?
[ $rc -eq 2 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && [ ! -d "$C/equipas/backups" ] && grep -q 'frontmatter' "$T/a2.txt" \
  && ok "rascunho com hooks no frontmatter: sai 2, nada muda" || { ko "frontmatter do rascunho (rc=$rc)"; cat "$T/a2.txt"; }
montar; F="$C/equipas/rascunho/equipa-marketing/SKILL.md"   # 2 linhas, mas hooks no lugar da description
awk 'NR == 3 { print "hooks: {}"; next } { print }' "$F" >"$T/s.md" && cat "$T/s.md" >"$F"
ativar --aplicar >"$T/a3.txt" 2>&1; rc=$?
[ $rc -eq 2 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && grep -q 'frontmatter' "$T/a3.txt" \
  && ok "rascunho com hooks no lugar da description: sai 2, nada muda" || { ko "frontmatter de 2 linhas (rc=$rc)"; cat "$T/a3.txt"; }
# B-2: cada regra do frontmatter (name igual à pasta, cerca de fecho, 2 linhas, sem caracteres de controlo).
while IFS='@' read -r rotulo prog; do
  montar; F="$C/equipas/rascunho/equipa-marketing/SKILL.md"
  awk "$prog" "$F" >"$T/s.md" && cat "$T/s.md" >"$F"
  ativar --aplicar >"$T/a4.txt" 2>&1; rc=$?
  [ $rc -eq 2 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && grep -q 'frontmatter' "$T/a4.txt" \
    && ok "rascunho com $rotulo: sai 2, nada muda" || { ko "frontmatter ($rotulo, rc=$rc)"; cat "$T/a4.txt"; }
done <<'EOF'
name de outra equipa@NR == 2 { print "name: equipa-design"; next } { print }
frontmatter sem a cerca de fecho@NR <= 3 { print }
uma só linha no frontmatter@NR == 3 { next } { print }
CR no meio da description@NR == 3 { sub(/^description: "/, "description: \"x\r"); print; next } { print }
ESC na description@NR == 3 { sub(/^description: "/, "description: \"\033[8m"); print; next } { print }
EOF

# B-7 e B-1: migração com o HOME atrás de uma ligação simbólica: ativar → ligar --desligar → ligar → reverter; o settings
# volta byte a byte ao original (o ligar escreve o caminho resolvido, que é o que o reverter filtra).
montar; ln -s home "$T/atalho"; HA="$T/atalho"; LG="$HA/.claude/equipas/reverter/ligar-guarda-sessao.sh"
{ HOME="$HA" bash "$HA/.claude/equipas/reverter/ativar-fase-1.sh" --aplicar && HOME="$HA" bash "$LG" --desligar \
  && [ "$(grep -c 'guarda-sessao.sh' "$C/settings.json")" = 0 ] && HOME="$HA" bash "$LG" \
  && HOME="$HA" bash "$HA/.claude/equipas/reverter/reverter-fase-1.sh" --aplicar; } >"$T/m1.txt" 2>&1; rc=$?
[ $rc -eq 0 ] && intactos && [ "$(n_skills)" = 0 ] && [ ! -e "$C/equipas/FASE-1-ATIVA" ] && ! grep -q 'guarda-sessao' "$C/settings.json" \
  && ok "migração (HOME por ligação simbólica): ativar, desligar, ligar e reverter deixam o settings igual ao original" || { ko "migração (rc=$rc)"; cat "$T/m1.txt"; }
rm -f -- "$T/atalho"

[ "$FALHAS" -eq 0 ] && echo "TODOS OK" || { echo "$FALHAS FALHAS"; exit 1; }
