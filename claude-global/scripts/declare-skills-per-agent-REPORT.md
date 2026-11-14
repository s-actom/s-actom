# RELATÓRIO — Pacote completo de skills por agente (opção A) + limpeza

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **PASS**

Fonte autoritativa da atribuição ECC: §8 de `~/.claude/scripts/expose-ecc-REPORT.md` (não memória).
Prova: Read/Grep/Glob + `rtk proxy` raw (nunca Bash filtrado por RTK).
Constraints respeitadas: só acrescentar · zero duplicados · não tocar em `ecc/` · não criar skills · idempotente.

---

## 1. Objetivo

Cada um dos 10 agentes operacionais passa a listar no body o **pacote completo do seu domínio**
(skills nativas que já tinha + skills ECC do seu domínio segundo §8), para que "usa o agente X"
puxe todo o arsenal relevante. Mais duas limpezas de consistência.

**Critério de decisão (opção A):** declarar nomes ECC no body de cada agente, agrupados sob
sub-rótulo `**ECC (expostas):**`, mantendo todas as nativas intactas.

---

## 2. PHASE 0 — Read + backup

1. Bodies dos 10 agentes lidos em estado fresco (`## Skills — Invocar via Skill Tool`).
2. §8 do relatório ECC lido → lista autoritativa de ECC por agente.
3. Backup dos 10 ficheiros → `/tmp/agents-backup-skills/` (`BACKUP_AGENTS_OK`, 10 ficheiros).

---

## 3. PHASE 1 — Limpeza (2 itens, provados)

### 3.1 sistema.md — consolidar fastapi-patterns
- Campo `skills:` removido do frontmatter. Diff: `6,7d5` (apaga `skills:` + `  - fastapi-patterns`).
- fastapi-patterns mantém-se **1×** no body (linha 75). `grep -c fastapi-patterns sistema.md → 1`.
- Resultado: sistema fica body-only, consistente com os outros 9.

### 3.2 fastapi-patterns root — cópia real → symlink
- Estado anterior: dir real (513 linhas / 15513 bytes) em `~/.claude/skills/fastapi-patterns/`.
- `diff -q` vs `ecc/fastapi-patterns/SKILL.md` → **IDENTICAL** (conteúdo igual, remoção segura).
- Backup: `/tmp/fastapi-patterns-backup/` (`FASTAPI_BACKUP_OK`).
- Cópia real removida + symlink criado:
  ```
  fastapi-patterns -> ecc/fastapi-patterns   (resolve a SKILL.md 513 linhas)
  ```
- Alinhado com os outros 87 symlinks. Evita cópia que envelhece quando o ECC atualizar.

---

## 4. PHASE 2 — Declarar pacote ECC por agente

Bloco `**ECC (expostas):**` inserido entre a última skill nativa e o heading seguinte
(abordagem append-only → nativas ficam byte-idênticas, diff puramente aditivo).

### Skills ECC acrescentadas (§8, nomes exatos)

**construcao (+19):** python-patterns, python-testing, golang-patterns, golang-testing,
rust-patterns, rust-testing, java-coding-standards, kotlin-patterns, kotlin-testing,
swift-concurrency-6-2, swiftui-patterns, cpp-coding-standards, cpp-testing,
coding-standards, error-handling, tdd-workflow, verification-loop, e2e-testing,
ai-regression-testing

**sistema (+23):** backend-patterns, api-design, api-connector-builder, database-migrations,
postgres-patterns, mysql-patterns, prisma-patterns, jpa-patterns, docker-patterns,
clickhouse-io, latency-critical-systems, data-throughput-accelerator, dashboard-builder,
github-ops, django-patterns, django-security, springboot-patterns, springboot-security,
nestjs-patterns, laravel-patterns, laravel-security, quarkus-patterns, quarkus-security

**site (+11):** react-patterns, react-performance, react-testing, frontend-patterns,
frontend-design-direction, motion-ui, make-interfaces-feel-better, liquid-glass-design,
angular-developer, dart-flutter-patterns, ui-to-vue

**gestor-de-agentes (+14):** mcp-server-patterns, agent-harness-construction,
agent-architecture-audit, agentic-engineering, ai-first-engineering, eval-harness,
parallel-execution-optimizer, prompt-optimizer, cost-aware-llm-pipeline, hookify-rules,
skill-scout, autonomous-loops, team-builder, token-budget-advisor

**crypto (+4):** defi-amm-security, evm-token-decimals, nodejs-keccak256,
llm-trading-agent-security

**lancamento (+2):** deployment-patterns, production-audit

**conteudo (+4):** article-writing, brand-voice, content-engine, market-research

**midia (+4):** fal-ai-media, remotion-video-creation, video-editing, manim-video

**pesquisa (+4):** exa-search, research-ops, knowledge-ops, search-first

**auditoria (+3):** security-bounty-hunter, automation-audit-ops, workspace-surface-audit

**Soma ECC = 19+23+11+14+4+2+4+4+4+3 = 88** (= total §8).

---

## 5. PHASE 3 — Verificação

### 5.1 Resultado por agente: antes → depois

| Agente             | Antes | +ECC | Depois | Dup     |
|--------------------|------:|-----:|-------:|---------|
| construcao         |     4 |  +19 |     23 | NO_DUP  |
| sistema            |     5 |  +23 |     28 | NO_DUP  |
| site               |    29 |  +11 |     40 | NO_DUP  |
| gestor-de-agentes  |     2 |  +14 |     16 | NO_DUP  |
| crypto             |     9 |   +4 |     13 | NO_DUP  |
| lancamento         |     3 |   +2 |      5 | NO_DUP  |
| conteudo           |    61 |   +4 |     65 | NO_DUP  |
| midia              |    10 |   +4 |     14 | NO_DUP  |
| pesquisa           |     2 |   +4 |      6 | NO_DUP  |
| auditoria          |     4 |   +3 |      7 | NO_DUP  |

Cada total final = nativas + ECC, sem sobreposições (overlaps pré-edit = 0).

### 5.2 Prova — nenhuma nativa removida

`diff /tmp/agents-backup-skills/<f>.md` vs `~/.claude/agents/<f>.md`:

```
construcao         added=15  removed=0
site               added=11  removed=0
sistema            added=16  removed=2   <- 2 = campo frontmatter autorizado
crypto             added=6   removed=0
gestor-de-agentes  added=16  removed=0
lancamento         added=4   removed=0
conteudo           added=6   removed=0
midia              added=6   removed=0
pesquisa           added=6   removed=0
auditoria          added=5   removed=0
```

- 9 agentes: `removed=0` → puramente aditivo.
- sistema: `removed=2` = só as 2 linhas do frontmatter `skills:`; body só additions (`78a77,92`).

### 5.3 Dup check + contagem (rtk proxy raw)

```
construcao  total=23 uniq=23  NO_DUP
site        total=40 uniq=40  NO_DUP
sistema     total=28 uniq=28  NO_DUP
crypto      total=13 uniq=13  NO_DUP
gestor      total=16 uniq=16  NO_DUP
lancamento  total=5  uniq=5   NO_DUP
conteudo    total=65 uniq=65  NO_DUP
midia       total=14 uniq=14  NO_DUP
pesquisa    total=6  uniq=6   NO_DUP
auditoria   total=7  uniq=7   NO_DUP
```

`total==uniq` em todos → zero duplicados no body.

### 5.4 sistema — frontmatter + fastapi-patterns

```
grep -c fastapi-patterns sistema.md → 1
linha 75: - `fastapi-patterns` — padrões FastAPI produção (ECC)
frontmatter: SEM campo skills:
```

### 5.5 Symlink fastapi-patterns

```
lrwxr-xr-x  fastapi-patterns -> ecc/fastapi-patterns
wc -l .../fastapi-patterns/SKILL.md → 513
```

### 5.6 Spot-check — nomes ECC resolvem em root (não inventados)

10/10 (1 por agente) existem como symlink `-> ecc/<nome>` com SKILL.md presente:

```
OK python-patterns        -> ecc/python-patterns
OK backend-patterns       -> ecc/backend-patterns
OK react-patterns         -> ecc/react-patterns
OK mcp-server-patterns    -> ecc/mcp-server-patterns
OK defi-amm-security      -> ecc/defi-amm-security
OK deployment-patterns    -> ecc/deployment-patterns
OK article-writing        -> ecc/article-writing
OK fal-ai-media           -> ecc/fal-ai-media
OK exa-search             -> ecc/exa-search
OK security-bounty-hunter -> ecc/security-bounty-hunter
```

### 5.7 Idempotência

Re-correr Phase 2 não adiciona nada:
- Cada nome ECC já presente 1× (`total==uniq`) → pass add-if-absent salta os 88.
- Anchors de Edit (última-nativa + linha vazia + heading) já não casam (bloco ECC no meio) → no-op.

---

## 6. Riscos restantes

1. **Buraco web-security do site** continua aberto (§9 do relatório ECC). react-patterns/performance/testing
   adicionadas, mas nenhuma cobre XSS/CSP. Fecho = criar skill `web-security` nova (fora deste âmbito).
2. Backups em `/tmp` são voláteis (perde em reboot). Edits já persistidos em `~/.claude/agents/`.
3. Auto-injeção por keyword: 88 skills declaradas elevam probabilidade de match em sessões/agentes —
   intencional e benigno (só em match real).

---

## 7. Artefactos / paths

- 10 agentes editados: `~/.claude/agents/{construcao,site,sistema,crypto,gestor-de-agentes,lancamento,conteudo,midia,pesquisa,auditoria}.md`
- Symlink: `~/.claude/skills/fastapi-patterns -> ecc/fastapi-patterns`
- Backups: `/tmp/agents-backup-skills/` (10 ficheiros) · `/tmp/fastapi-patterns-backup/`
- Fonte autoritativa: `~/.claude/scripts/expose-ecc-REPORT.md` §8
- Este relatório: `~/.claude/scripts/declare-skills-per-agent-REPORT.md`

---

**Critérios PASS (todos provados):** contagens batem (nativas + ECC, soma 88) ·
zero duplicados (`total==uniq`) · nenhuma nativa removida (diff só-adições, exceto
frontmatter sistema autorizado) · sistema body-only · fastapi-patterns symlink → ecc/ ·
symlinks ECC resolvem · idempotente.
