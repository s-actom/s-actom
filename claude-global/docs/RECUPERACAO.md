# Recuperação

## Princípios

1. Esta pasta é um **snapshot somente leitura**. A recuperação é sempre uma
   operação explícita do dono, comando a comando — nunca automática.
2. O sistema local `~/.claude` é a fonte da verdade ativa; o git local dele
   (branch `main`, sem remotes) **não foi alterado** por esta exportação.
3. Nenhuma recuperação sobrescreve sem backup: copiar primeiro para
   `~/.claude/backups/<data>/`.

## Verificar integridade das equipas

O sistema Direção Geral traz o seu próprio manifesto de integridade:

```bash
cd ~/.claude/equipas && shasum -a 256 -c reverter/MANIFESTO.sha256
```

(As sessões de fase podem ter evoluído ficheiros desde o manifesto; tratar
`FAILED` como sinal para inspeção, não para ação cega.)

## Restaurar por componente (exemplos)

Sempre: `mkdir -p ~/.claude/backups/$(date +%Y%m%d)` e copiar o original antes.

```bash
# a partir da raiz do repo (pasta claude-global/)
B=~/.claude/backups/$(date +%Y%m%d)

# 1) settings.json
cp ~/.claude/settings.json "$B/" && cp claude-global/settings.json ~/.claude/settings.json

# 2) um agente específico
cp claude-global/agents/construcao.md ~/.claude/agents/construcao.md

# 3) as 16 skills da Direção Geral
for d in direcao-geral equipa-*; do
  cp -R "claude-global/skills/$d" ~/.claude/skills/
done

# 4) hooks de segurança
cp claude-global/hooks/skill-policy-hook.mjs ~/.claude/hooks/
cp claude-global/hooks/claude-security-stop-hook.mjs ~/.claude/hooks/

# 5) sistema de equipas (config + código)
rsync -a --exclude='__pycache__' claude-global/equipas/ ~/.claude/equipas/
```

## Reverter a Direção Geral (no sistema local)

O sistema tem scripts de reversão testados (ensaio sem `--aplicar`):

```bash
bash ~/.claude/equipas/reverter/reverter-fase-1.sh           # ensaio
bash ~/.claude/equipas/reverter/reverter-fase-1.sh --aplicar # desfaz a Fase 1
bash ~/.claude/equipas/reverter/reverter-fase-0.sh --aplicar # desfaz até à Fase 0
```

Ver `equipas/LEIA-ME.md` (secção de ativação/reversão) e `equipas/reverter/`.

## Reverter esta exportação (no repositório)

O PR que introduz esta pasta não deve ser feito merge sem revisão. Para
desfazer depois de merge: `git revert` do merge/commits, ou apagar a pasta
`claude-global/` num PR de reversão — a pasta é aditiva e não toca em mais
nada do repo.

## O que NÃO recuperar a partir daqui

- Terceiros (ECC, superpowers/GSD, caveman, skills de marketplace): reinstalar
  pelos marketplaces declarados em `settings.json`.
- Segredos: vivem no Keychain/ambiente; nunca estiveram no repo.
- Runtime (`projects/`, `sessions/`, `tasks/`, `equipas/estado/`, …): não faz
  sentido restaurar de um snapshot de configuração.
