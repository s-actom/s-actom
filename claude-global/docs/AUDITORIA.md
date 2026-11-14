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
- **`equipas/FASE-1-ATIVA`** — marcador de estado (contém o nome do backup local).
  Versioná-lo faz uma instalação nova acreditar que a Fase 1 está ativa: `ativar-fase-1.sh`
  sai com 0 sem ativar e `reverter-fase-1.sh` procura um backup que não existe. É criado
  em runtime por `ativar-fase-1.sh`.

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

## Correções da revisão CodeRabbit (2.ª ronda, 2026-11-14)

Findings Major resolvidos, cada um com teste de regressão e verificação por mutação
onde há comportamento executável:

| Ficheiro | Correção |
|---|---|
| `equipas/hooks/portao.mjs` | Em modo `escuras` o JEV **não** revela equipa nem recurso (o ramo do recurso precedia o gate do modo). Extraída `textoDoObjetivo` pura. |
| `equipas/reverter/reverter-fase-1.sh` | Valida o sha256 da cópia **antes** do `mv`; falha de `rm` deixa a reversão pendente e preserva `instalado.sha256`. |
| `hooks/claude-security-stop-hook.mjs` | `explicitRefusal` recebe `turn.records`, não o transcript inteiro: recusa de tarefa anterior não encerra o gate atual. |
| `validar.sh` | Relatório de segredos em `mktemp` 0600 com `trap` de remoção; nunca imprime o valor encontrado. |
| `equipas/FASE-1-ATIVA` | Removido do snapshot (marcador de runtime). |
| `docs/RECUPERACAO.md` | Glob das 15 skills expandido em `claude-global/skills/`; antes não restaurava nenhuma. |
| `CODEX_MODEL_POLICY.md` | Comentário movido para fora da continuação de linha do `codex exec`. |
| `agents/auditoria.md` | Descreve o limite real da allowlist `Agent(...)` (só na thread principal) e documenta as dependências externas de skills. |
| `agents/workspace-automation-auditor.md` | Auditoria declarada read-only: proibido alterar ficheiros. |
| `scripts/coderabbit-review.sh` | `core.quotePath=false`; nome com caracteres de controlo falha em vez de rever outro conjunto; `shasum` falhado bloqueia o dedup. |
| `scripts/coderabbit-review.test.sh` | HOME isolado no caso `default`: o teste deixou de depender da configuração da máquina. |
| `scripts/nano-banana-fix-REPORT.md` | Rollback por ficheiro com backup e aviso; `git reset --hard` substituído por `git status` + `git checkout -- <ficheiro>`. |
| `agents/conteudo.md` | Documenta que `marketing-agent`/`seo-specialist` vêm do catálogo `agency-agents`. |
| `docs/DEPENDENCIAS.md` | Novo: skills, agentes e programas externos que a instalação de destino precisa. |

## Correções da revisão CodeRabbit (3.ª ronda, 2026-11-14)

Segunda revisão sobre os commits finais. Cada correção tem teste de regressão; as que
alteram comportamento executável foram verificadas por mutação (o teste falha com o
comportamento antigo).

| Ficheiro | Correção | Prova |
|---|---|---|
| `validar.sh` | Um nome com dois-pontos (`credenciais:backup.txt`) fazia o `sed` falhar e **imprimir a linha com o token**. Agora extrai ficheiro+linha de forma gananciosa e nunca emite a linha original. | `validar.test.sh` caso (a) |
| `hooks/claude-security-stop-hook.mjs` | `file_path` era extraído por regex de texto livre e cortava em espaços: um `Edit` em `/app b/…` desaparecia de `roots` e o gate liberava sem verificar. Campos estruturados usam-se literalmente. | teste de 2 repos |
| `hooks/claude-security-stop-hook.mjs` | Com >5000 ficheiros não rastreados o fingerprint ficava parcial e um recibo antigo podia ser reutilizado. Fingerprint parcial já não casa com recibo. | — |
| `equipas/reverter/reverter-fase-1.sh` | Um symlink em `skills/equipa-X` fazia o `rm` apagar ficheiro de outra pasta. Resolve o pai com `cd -P` e recusa sair de `skills/`. | caso (d) |
| `equipas/reverter/reverter-fase-1.sh` | Uma skill `equipa-*` criada pelo dono depois da ativação deixava a reversão pendente para sempre. A verificação final cobre só o que esta instalação criou. | caso (e) |
| `equipas/hooks/atualizar.py` | Conflicto dono/publicação: reconfere o hash imediatamente antes do `replace`. | `test_atualizar` |
| `equipas/hooks/atualizar.py` | Registo `instalado.sha256` era escrito só no fim; uma falha a meio deixava o registo desatualizado e a skill "presa". Passa a gravar num ponto único após o ciclo. | (estrutural) |
| `scripts/coderabbit-review.sh` | `[a].txt` era tratado como *pathspec* glob e escapava à varredura. `--literal-pathspecs`. | — |
| `docs/RECUPERACAO.md` | Backup em `backups/<data>` era sobrescrito em execuções repetidas no mesmo dia. `mktemp -d` por execução + `cp -np`. | — |
| `PLUGIN_SCHEMA_NOTES.md` | `mcpServers: {}` não é opt-out: o Claude Code carrega `.mcp.json` e funde depois. Corrigido com o procedimento real. | — |
| `docs/DEPENDENCIAS.md` | 7 revisores estavam listados como externos mas têm ficheiro local; `code-reviewer`/`security-reviewer` não existem. Listas corrigidas e instalação de `owasp-security` documentada. | contagem real do disco |

**Limitação conhecida (não corrigível sem cooperação do editor):** em `atualizar.py` resta a
janela entre a reconferência do hash e o `os.replace`. Fechá-la exigiria um lock partilhado
com o editor do dono. A reconferência reduz a janela ao mínimo mensurável.

