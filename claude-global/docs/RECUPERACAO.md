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
# Um diretório por execução: repetir hoje não pode sobrescrever o backup de hoje.
B=$(mktemp -d "$HOME/.claude/backups/$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
echo "backups desta execução: $B"

# 1) settings.json
cp -np ~/.claude/settings.json "$B/" && cp claude-global/settings.json ~/.claude/settings.json

# 2) um agente específico
cp claude-global/agents/construcao.md ~/.claude/agents/construcao.md

# 3) as 16 skills da Direção Geral (16 = direcao-geral + 15 equipa-*)
#    O glob expande-se no diretório das skills; nunca entre aspas.
for d in claude-global/skills/direcao-geral claude-global/skills/equipa-*; do
  [ -d "$d" ] || { echo "falta: $d" >&2; continue; }
  cp -R "$d" ~/.claude/skills/
done

# 4) hooks de segurança
cp claude-global/hooks/skill-policy-hook.mjs ~/.claude/hooks/
cp claude-global/hooks/claude-security-stop-hook.mjs ~/.claude/hooks/

# 5) sistema de equipas (config + código)
rsync -a --exclude='__pycache__' claude-global/equipas/ ~/.claude/equipas/
```

## Importante: este snapshot já está no estado PÓS-Fase 1

O `CLAUDE.md` versionado já tem a Direção Geral como único decisor (o cabeçalho
`## Agentes — Routing` foi substituído). Por isso **não correr `ativar-fase-1.sh`
sobre uma instalação feita a partir deste snapshot**: o script recusa com código 2
(`as trocas no CLAUDE.md ou no agency-commander não batem`) e, por desenho,
**não altera nada** — falha fechada. Isso foi verificado:

| Verificação | Resultado |
|---|---|
| `ativar-fase-1.sh --aplicar` sobre o snapshot | código 2, "nada mudou" |
| `settings.json` depois | idêntico byte a byte |
| `CLAUDE.md` depois | idêntico byte a byte |
| skill de terceiros `agency-commander` | intacta |

`ativar-fase-1.sh` / `reverter-fase-1.sh` são ferramentas da **máquina original**
(usam o backup local `equipas/backups/fase-1-*`, que não é versionado). Numa
instalação nova, a recuperação é feita por git.

### Pré-condições dos scripts de fase (não satisfeitas numa instalação nova)

- skill `agency-commander` (terceiros, catálogo `agency-agents`) — não versionada;
- `equipas/rascunho/` com as 16 skills — estado **gerado** (`gerador/gerar.py`), não versionado;
- `equipas/backups/fase-1-*` com `ANTES.sha256`/`DEPOIS.sha256`/`ficheiros/`/`pares/` — backup local.

O gerador foi validado a produzir o rascunho (17 entradas) a partir desta pasta.
O comportamento de **rollback** com backup válido está coberto por
`equipas/reverter/testes/test-reverter-integridade.sh` (8 verificações, inclui
backup corrompido e remoção falhada).

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
