# Claude Code — Configuração Global versionada

Cópia **auditada e limpa** da camada de configuração global do Claude Code
(`~/.claude`) do dono deste repositório. Snapshot de **2026-11-14**.

## Princípios

1. **Somente leitura** — nada nesta pasta altera `~/.claude`. Nenhum script aqui
   escreve no sistema local. A estratégia de sincronização futura está em
   [docs/SINCRONIZACAO.md](docs/SINCRONIZACAO.md).
2. **Sem segredos** — credenciais vivem no Keychain do macOS ou no ambiente,
   nunca em ficheiros. Auditado com gitleaks (ver
   [docs/VALIDACAO.md](docs/VALIDACAO.md)).
3. **Sem ficheiros de terceiros** — conteúdo de plugins (ECC, superpowers/GSD,
   caveman, marketplaces) é reinstalável de forma declarativa via
   `settings.json` (`enabledPlugins` + `extraKnownMarketplaces`) e **não** é
   copiado para aqui. Ver [docs/AUDITORIA.md](docs/AUDITORIA.md).
4. **Reversível** — procedimentos de recuperação em
   [docs/RECUPERACAO.md](docs/RECUPERACAO.md).

## Estrutura

| Caminho | Conteúdo | Origem |
|---|---|---|
| `CLAUDE.md` | Instruções globais; Direção Geral como único decisor | autor |
| `settings.json` | Configuração canónica: hooks, env (sem chaves), permissões, plugins declarados | autor |
| `agents/`, `agents-archive/` | Agentes próprios (catálogo agency + PT) e arquivo histórico | autor |
| `commands/` | 3 comandos próprios (`audit`, `design-md`, `polish`) | autor |
| `hooks/` | Hooks de segurança e política (skill-policy, claude-security-stop, agent-browser, context-handoff) | autor |
| `scripts/` | Wrappers e ferramentas próprias (CodeRabbit, auditorias, relatórios) | autor |
| `rules/` | 3 regras próprias (claude-mem, coderabbit-review, context-handoff) | autor |
| `helpers/` | `with-openrouter-key.sh` — injeta chave do Keychain, fail-closed | autor |
| `skills/direcao-geral/` + `skills/equipa-*/` | As 16 skills da Direção Geral e das 15 equipas | autor |
| `equipas/` | Sistema Direção Geral: `equipas.yaml`, gerador Python, hooks+testes, reverter, entradas congeladas, desenho | autor |
| `session-data/…/desenho-direcao-geral.md` | Desenho aprovado da Direção Geral (2026-11-07) | autor |
| `mcp-configs/` | Template de servidores MCP (só placeholders `YOUR_*_HERE`) | autor |
| `coderabbit/` | Instruções globais de review do CodeRabbit | autor |
| `docs/` | Auditoria, recuperação, validação, sincronização | desta exportação |
| `validar.sh` | Validações desta pasta (usado também no CI) | desta exportação |

## O que NÃO está aqui (por design)

Sessões, históricos (`history.jsonl`, `projects/`, `session-env/` com 15.559
ficheiros, `tasks/`), credenciais e caches (`~/.claude.json`, `policy-limits`,
`remote-settings`), ficheiros de terceiros (ECC: 62 agentes/94 comandos/134
scripts/104 regras; superpowers-GSD; caveman; ~297 skills de marketplace) e
runtime das equipas (`estado/`, `rascunho/`, `relatorio/`, `registo.jsonl`,
`backups/`). A lista completa com contagens está em
[docs/AUDITORIA.md](docs/AUDITORIA.md).

## Validar

```bash
bash claude-global/validar.sh          # a partir da raiz do repo
```

No CI: workflow `.github/workflows/validacao.yml` (validação + suites de
testes + gitleaks) corre em cada PR.

## Série de importação (limite de 150 ficheiros por review do CodeRabbit)

O CodeRabbit salta reviews com mais de 150 ficheiros alterados, pelo que o
snapshot completo entra no repo em **5 PRs disjuntos** (paths sem
interseção; merge em qualquer ordem):

| PR | Branch | Âmbito | Ficheiros |
|---|---|---|---|
| #1 | `claude-global/v1` | core: top-level, `equipas/`, skills da DG, `hooks/`, `rules/`, `commands/`, `helpers/`, `mcp-configs/`, `coderabbit/`, `docs/`, `validar.sh`, CI, `.coderabbit.yaml` | 143 |
| #2 | `claude-global/agentes-raiz-scripts` | `agents/*.md` da raiz (60) + `scripts/` (21) | 81 |
| #3 | `claude-global/agentes-subdirs` | `agents/*/` (design, engineering, marketing, paid-media, product, sales, security, testing) | 97 |
| #4 | `claude-global/arquivo-agentes-1` | `agents-archive/` — A–P | 90 |
| #5 | `claude-global/arquivo-agentes-2` | `agents-archive/` — P–Z | 76 |

Os passos do CI são condicionais (`hashFiles`): em cada PR correm só as
validações/testes relativos aos ficheiros presentes. O gitleaks corre
sempre.

## Contexto

- `~/.claude` tem repositório git local próprio (branch `main`, 1 commit,
  sem remotes) que **permanece intacto** — esta pasta é uma exportação
  auditada, não um remote do git local.
- Futuras implementações (incluindo o router dinâmico de modelos, hoje no
  `~/.codex/jev-router`) estão planeadas em
  [docs/SINCRONIZACAO.md](docs/SINCRONIZACAO.md).
