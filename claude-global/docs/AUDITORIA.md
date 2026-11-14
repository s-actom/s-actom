# Auditoria da exportação — 2026-11-14

`~/.claude` contém **116.280 ficheiros** (15 GB). Esta exportação inclui
**480 ficheiros de configuração (6 MB)** + 7 ficheiros de documentação e
validação desta exportação — apenas a camada de configuração da autoria do
dono.

## Distribuição em PRs

O snapshot entra no repo em 5 PRs disjuntos (limite de 150 ficheiros/review
do CodeRabbit): #1 core (143) · #2 `agents/*.md`+`scripts/` (81) ·
#3 `agents/*/` (97) · #4/#5 `agents-archive/` (90+76). Ver README.md.

## Metodologia

A inclusão/exclusão foi decidida com quatro fontes cruzadas:

1. **Baseline git local** — o repositório git existente em `~/.claude`
   (1 commit, branch `main`, 1332 alterações pendentes, sem remotes) define a
   camada de configuração que o dono já considerou versionável.
2. **`.gitignore` local** — segredos/voláteis/pesados/reinstaláveis já
   excluídos lá (`projects/`, `sessions/`, `.credentials*`, `plugins/`,
   `skills/`, `history.jsonl`, `file-history/`, `debug/`, …).
3. **Diff contra o upstream ECC** — árvore completa de
   `github.com/affaan-m/ECC` (6.449 paths) comparada ficheiro a ficheiro com
   `agents/`, `commands/`, `hooks/`, `scripts/`, `rules/` locais.
4. **Caches de plugins** (`plugins/cache/`, `plugins/marketplaces/`,
   `installed_plugins.json`) — proveniência de superpowers/GSD, caveman e
   restantes marketplaces.

## Incluído (482 ficheiros)

| Grupo | Ficheiros | Notas |
|---|---|---|
| Top-level (CLAUDE.md, settings.json, launch.json, 7 docs, RTK.md, global-lessons.md) | 11 | `settings.json` auditado: `env` sem chaves; segredos vão ao Keychain |
| `agents/` | 157 | só do dono; excluídos 62 ECC + 33 gsd- (superpowers) + 1 .bak |
| `agents-archive/` | 166 | arquivo histórico do dono; excluídos 5 ECC + gsd/bak |
| `equipas/` (Direção Geral) | 75 | yaml, gerador+testes, hooks+testes, reverter, entradas congeladas, testes-fase-0, docs de fase (2 `.log` de evidência excluídos) |
| `skills/` | 32 | **só** `direcao-geral` + 15 `equipa-*` (16 skills da Direção Geral) |
| `scripts/` | 21 | só do dono; excluídos 134 ECC + 1 .log |
| `hooks/` | 8 | segurança/política; excluídos 12 gsd-, 5 caveman-, 4 ECC, 1 .bak |
| `rules/` | 3 | claude-mem-consulta, coderabbit-review, context-handoff |
| `commands/` | 3 | audit, design-md, polish (94 eram shims ECC) |
| `session-data/…/desenho-direcao-geral.md` | 1 | desenho aprovado 2026-11-07, referenciado por `equipas.yaml` |
| `mcp-configs/`, `helpers/`, `coderabbit/` | 3 | template MCP sem chaves; helper Keychain fail-closed; instruções de review |
| Manifesto completo | — | [MANIFESTO-incluido.txt](MANIFESTO-incluido.txt) |

## Excluído (com razão)

### Segredos e identidade (nunca saem da máquina)
- `~/.claude.json` (home) — contas OAuth, estado de contas, histórico de projetos
- `~/.claude/.claude.json` — machineID/userID
- `policy-limits.json*` (4 ficheiros, modo 600) — estado assinado de limites
- `remote-settings.json*`, `mcp-needs-auth-cache.json` — runtime de sincronização
- `helpers/` só entra o `with-openrouter-key.sh` (lê do Keychain, fail-closed, sem material secreto)
- `equipas/registo.jsonl` — registo de decisões (modo 600; "nunca o texto do pedido")

### Runtime e histórico (privacidade/volume)
- `projects/` (95), `sessions/`, `session-env/` (15.559), `history.jsonl`,
  `file-history/` (57), `tasks/` (1.034), `todos/`, `shell-snapshots/`,
  `telemetry/`, `debug/`, `backups/`, `cache/`, `chrome/`, `uploads/`,
  `spares/`, `state/`, `paste-cache/`, `security-gate-receipts/`,
  `session-data/` (exceto o desenho), `.caveman-*`, `.pi/`, `.last-*`,
  `.gsd-profile`, `.i-have-adhd-always`, `.ponytail-active`,
  `security_warnings_state_*.json` (9), `stats-cache.json`
- `equipas/` runtime: `backups/` (3,4 MB), `estado/` (472 KB), `rascunho/`,
  `relatorio/`, `registo.jsonl`, `__pycache__`

### Terceiros (reinstaláveis de forma declarativa)
- **ECC** (`affaan-m/ECC`, MIT): 62 agentes, 94 comandos, 134 scripts, 4 hooks
  (incl. `hooks/hooks.json` e `memory-persistence/`), 104 regras, e no
  top-level `AGENTS.md`, `README.md`, `plugin.json`, `marketplace.json`,
  `package.json`, `the-security-guide.md`
- **superpowers/GSD** (`obra/superpowers`): 33 agentes `gsd-*`, 12 hooks
  `gsd-*`, `get-shit-done/`, `gsd-user-files-backup/`, manifestos `gsd-*.json`
- **caveman** (`JuliusBrussee/caveman`): 5 hooks `caveman-*`,
  `ponytail-modes/` (96 dirs hash), `.caveman-sessions/`
- **skills de marketplace**: ~297 das 313 em `skills/` (ECC + clones com
  `.git`: `nano-banana-pro-prompts-recommend`, `ai-image-prompts`,
  `code-review-skill`)
- `plugins/`, `skills-src/`, `skill-library/`, `security/`,
  `security-skill-library/`, `design-md/`, `dev-mods/`, `scheduled-tasks/`,
  `ecc/`, `chrome/`
- Cópias de segurança locais: `*.bak*`, `*.archived-*`, `*.backup-*`

## Alterações mínimas ao snapshot vs `~/.claude`

Para publicar/CI, 10 linhas mudam face aos originais locais (originais intactos):
9 anotações `gitleaks:allow` (fixtures sintéticas de teste e padrões PEM
documentais) e 1 `skip` CI no teste interativo `fase-2.sh` (o pseudo-terminal
do runner não reproduz o terminal do dono; o teste passa localmente).

## Verificações de sensibilidade feitas

| Verificação | Resultado |
|---|---|
| gitleaks 8.30.0 (`--no-git`, 5,2 MB) | **0 findings** (6 falsos positivos = fixtures sintéticas de teste, anotadas `// gitleaks:allow`) |
| Headers PEM em `agents/security/senior-secops-engineer.md` | só **documentação de padrões** a detetar (headers sem corpo de chave); 3 linhas anotadas `<!-- gitleaks:allow -->` |
| `settings.json` → `env`, `permissions`, `statusLine`, `pluginConfigs` | sem chaves/tokens |
| `mcp-configs/mcp-servers.json` | só placeholders `YOUR_*_HERE` |
| `equipas/entradas/auditoria-itens-2026-11-05.json` (472 KB) | inventário de skills (nome/descrição/uso); 0 emails; "token/secret" só em descrições de skills |
| `RTK.md`, `launch.json`, `helpers/*` | sem segredos |
| Grep de padrões reais (ghp_/gho_/sk-/AKIA/PAT/JWT/PEM) | só nas fixtures de teste anotadas |
