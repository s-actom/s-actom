# RELATÓRIO COMPLETO — Camada de exposição de skills ECC para o path do harness

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **PASS**

---

## 1. Objetivo

Expor skills órfãs de `~/.claude/skills/ecc/` ao path que o harness escaneia
(`~/.claude/skills/<nome>/`), de forma idempotente, que **sobreviva a
`ecc repair`/`auto-update`**, sem perder fonte única e **sem sobrepor skills
nativas**. Sem mexer no código do ECC (forkar partiria no próximo update).

## 2. Problema (diagnóstico pré-fechado, re-confirmado)

- Harness só escaneia **filhos diretos** de `~/.claude/skills/`. Subpasta `ecc/` é invisível.
- Instalador ECC escreve skills em `~/.claude/skills/ecc/<nome>/` (hardcoded `CLAUDE_ECC_NAMESPACE='ecc'`).
- `ecc repair`/`auto-update` revertem cópias manuais *para dentro* de `ecc/`.
- ~167 skills órfãs em `ecc/`; ~84 relevantes aos 10 agentes operacionais.

## 3. Decisões (do utilizador, nesta sessão)

- **Âmbito:** Tier 1 (~88 skills núcleo).
- **Colisões:** saltar todas + log (nunca sobrepor).
- **Método:** symlink (após provar que o harness os segue).

---

## 4. PHASE 0 — Investigação read-only

### 4.1 Symlink: harness SEGUE symlinks (PROVADO)
Root já continha dezenas de symlinks nativos `→ ../../.agents/skills/<nome>`
(ex.: `seo`, `copywriting`, `gsap-core`), todos presentes no skill_listing com
descrições lidas via symlink. ECC já usa este padrão (módulo agents-core).
Decisão: **symlink** (fonte única, sem duplicar).

```
seo          -> ../../.agents/skills/seo
copywriting  -> ../../.agents/skills/copywriting
gsap-core    -> ../../.agents/skills/gsap-core
```

### 4.2 Lista de exposição
Derivada fresh de `name`+`description` reais de 189 skills ecc/ (não de memória).
Discrepância vs "~84": o conjunto plausível são ~148; Tier 1 (núcleo, alto valor,
≈ os "84") = **88**, confirmado existir em ecc/ (dry-run `missing=0`).

### 4.3 Colisões detetadas (5)

| Skill | Tipo |
|-------|------|
| `fastapi-patterns` | filesystem — dir real em root (cópia de teste antigo) |
| `seo` | filesystem — symlink nativo → `.agents/skills/seo` |
| `deep-research` | registry — nome já no listing (harness diferente) |
| `security-review` | registry — nome já no listing (≠ conteúdo) |
| `security-scan` | registry — nome já no listing (comando ECC) |

### 4.4 Segurança site — achado que contraria o brief
`ecc/security-review` (name=`security-review`) = appsec **backend**
(auth/input/secrets/API/payments). `ecc/security-scan` = audita config `.claude/`
via AgentShield. **Nenhuma é web-XSS/CSP.** Ambas colidem (registry). Cobertura web
existe só como **rule** (`rules/ecc/web/security.md`), não skill.

---

## 5. PHASE 1 — Script

Criado `~/.claude/scripts/expose-ecc-skills.sh` (bash, idempotente, exec bit set). Lógica:

- Fonte `ecc/<nome>/SKILL.md` tem de existir, senão `[missing]`+salta.
- Ownership por target: symlink `→ ecc/<nome>` = desta camada (idempotente, no-op).
- Symlink alheio (`→ .agents/...`) ou dir/ficheiro real = **colisão → salta+log**, nunca sobrepõe.
- Ausente em root → `ln -s ecc/<nome>`.
- `DRY_RUN=1` valida sem mutar. **Exit 0 sempre** (não bloqueia SessionStart). Nunca apaga. Nunca toca em ecc/.

**Validação (read-only):**
```
[syntax] OK
[chmod] +x set
--- DRY RUN (sem mutação) ---
expose-ecc: exposed=88 already=0 collision=0 missing=0 total=88 dry=1
```
→ os 88 existem em ecc/, zero colisões com root atual.

---

## 6. PHASE 2 — Hook SessionStart

Backup primeiro (fora de ~/.claude): `~/claude-settings-backup-20260617-054450.json`.

**Diff settings.json:**
```diff
32a33,42
>       },
>       {
>         "hooks": [
>           { "type": "command",
>             "command": "bash ~/.claude/scripts/expose-ecc-skills.sh",
>             "timeout": 15, "statusMessage": "Expondo skills ECC..." } ]
>       }
```

**SessionStart = 4 grupos coexistentes** (JSON válido):
```
1. gsd-check-update.js
2. gsd-session-state.sh
3. caveman-activate.js
4. expose-ecc-skills.sh
```
RTK (rtk-rewrite.sh) e GSD intactos. O novo grupo **adiciona**, não substitui.

---

## 7. PHASE 3 — Verificação

**7.1/7.2 Exposição + idempotência:**
```
=== RUN 1 (real) ===  expose-ecc: exposed=88 already=0  collision=0 missing=0 total=88
=== RUN 2 (idemp) ===  expose-ecc: exposed=0  already=88 collision=0 missing=0 total=88
=== total symlinks -> ecc/ em root === 88
```

**7.3 Routing/injeção (ponta-a-ponta):**
- Registry live re-listou os **88** mid-sessão com descrições lidas via symlink `ecc/`.
- `Skill(postgres-patterns)` (ecc-only antes) resolveu base dir
  `~/.claude/skills/postgres-patterns` → seguiu symlink → carregou
  `ecc/postgres-patterns/SKILL.md` completo. Cross-refs (`backend-patterns`,
  `clickhouse-io`) também expostos.
- **Symlink-follow para alvo `ecc/` = provado** (não só `.agents/`).

**7.4 Colisões não sobrepostas:**
```
fastapi-patterns   dir real (nativo)          — intacto
seo                -> ../../.agents/skills/seo — intacto
deep-research      ausente em root            — não exposto
security-review    ausente em root            — não exposto
security-scan      ausente em root            — não exposto
```

**7.5 Buraco site:** ver §9. **7.6** `ecc repair` NÃO testado destrutivamente (SPEC) —
hook re-expõe no próximo SessionStart.

---

## 8. As 88 skills expostas (por agente)

**construcao (19):** python-patterns, python-testing, golang-patterns, golang-testing,
rust-patterns, rust-testing, java-coding-standards, kotlin-patterns, kotlin-testing,
swift-concurrency-6-2, swiftui-patterns, cpp-coding-standards, cpp-testing,
coding-standards, error-handling, tdd-workflow, verification-loop, e2e-testing,
ai-regression-testing

**sistema (23):** backend-patterns, api-design, api-connector-builder, database-migrations,
postgres-patterns, mysql-patterns, prisma-patterns, jpa-patterns, docker-patterns,
clickhouse-io, latency-critical-systems, data-throughput-accelerator, dashboard-builder,
github-ops, django-patterns, django-security, springboot-patterns, springboot-security,
nestjs-patterns, laravel-patterns, laravel-security, quarkus-patterns, quarkus-security

**site (11):** react-patterns, react-performance, react-testing, frontend-patterns,
frontend-design-direction, motion-ui, make-interfaces-feel-better, liquid-glass-design,
angular-developer, dart-flutter-patterns, ui-to-vue

**gestor-de-agentes (14):** mcp-server-patterns, agent-harness-construction,
agent-architecture-audit, agentic-engineering, ai-first-engineering, eval-harness,
parallel-execution-optimizer, prompt-optimizer, cost-aware-llm-pipeline, hookify-rules,
skill-scout, autonomous-loops, team-builder, token-budget-advisor

**crypto (4):** defi-amm-security, evm-token-decimals, nodejs-keccak256,
llm-trading-agent-security

**lancamento (2):** deployment-patterns, production-audit

**conteudo (4):** article-writing, brand-voice, content-engine, market-research

**midia (4):** fal-ai-media, remotion-video-creation, video-editing, manim-video

**pesquisa (4):** exa-search, research-ops, knowledge-ops, search-first

**auditoria (3):** security-bounty-hunter, automation-audit-ops, workspace-surface-audit

---

## 9. Buraco de segurança do site — AINDA ABERTO

Não fechado por skill. (a) Por decisão, `security-review`/`security-scan` saltadas
(colisões). (b) Mesmo se expostas, nenhuma é web-XSS/CSP. Não existe skill web-security
em ecc/ para expor. Expostas sim foram **seguranças backend**: `django-security`,
`laravel-security`, `springboot-security`, `quarkus-security`, `security-bounty-hunter`,
`defi-amm-security`, `llm-trading-agent-security`. Cobertura web XSS/CSP continua só na
rule `rules/ecc/web/security.md`. **Fechar = criar skill `web-security` nova**
(chip `task_34ba073e` criado).

---

## 10. Colisões a rever (caso a caso — não tocadas)

| Skill | Decisão pendente |
|-------|------------------|
| `fastapi-patterns` | cópia real em root duplica ecc/ — apagar cópia + expor symlink, ou manter cópia |
| `seo` | nativo `.agents/seo` vs `ecc/seo` — qual fica ativo |
| `deep-research` | já no registry (harness diferente) — expor exigiria nome distinto |
| `security-review` | já no registry; nome distinto + teste de restart |
| `security-scan` | idem; é config-audit, não web |

---

## 11. Riscos restantes

1. **Site security**: sem skill web dedicada (só rule). Recomendado criar `web-security`.
2. **Sem auto-prune**: remover skill da lista ≠ remove o symlink (script nunca apaga, por segurança). Remoção = `unlink` manual.
3. **Tier 2 (~60 skills)** por expor — estender array `EXPOSE` no script.
4. **`ecc repair`** não testado destrutivamente — mitigado: hook re-expõe a cada SessionStart.
5. 88 skills agora elegíveis a auto-injeção por keyword em todas as sessões/agentes (intencional; benigno, só em match).

---

## 12. Artefactos / paths

- Script: `~/.claude/scripts/expose-ecc-skills.sh`
- Log: `~/.claude/scripts/expose-ecc.log`
- Hook: `~/.claude/settings.json` → `hooks.SessionStart[3]`
- Backup settings: `~/claude-settings-backup-20260617-054450.json`
- 88 symlinks: `~/.claude/skills/<nome>` → `ecc/<nome>`
- Memória: `~/.claude/projects/-Users-goncaloferro/memory/ecc-skills-exposure-layer.md`
- Este relatório: `~/.claude/scripts/expose-ecc-REPORT.md`

---

**Critérios PASS (todos provados):** skills em root (88) · idempotência
(run 2x → `exposed=0 already=88`) · routing (registry + Skill load via symlink) ·
zero colisões sobrepostas.
