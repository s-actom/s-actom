# RELATÓRIO — Declarar owasp-security em 6 agentes (append-only)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **PASS**

Fonte da skill: `~/.claude/skills/owasp-security/` (instalada, scaneada, LIMPA — ver owasp-security-install-REPORT.md).
Prova: Read/Grep/Glob + `rtk proxy` raw (nunca Bash filtrado por RTK).
Constraints respeitadas: só acrescentar · zero duplicados · não tocar nos 4 agentes excluídos · idempotente.

---

## 1. Objetivo

Declarar `owasp-security` no body `## Skills — Invocar via Skill Tool` de 6 agentes operacionais,
no final do bloco `**ECC (expostas):**` de cada um (append-only, sem remoções).

**Agentes a editar:** auditoria, sistema, gestor-de-agentes, crypto, site, construcao
**Agentes a NÃO tocar:** lancamento, conteudo, midia, pesquisa

**Entry adicionada:**
```
- `owasp-security` — OWASP Top 10/ASVS/LLM/Agentic security
```

---

## 2. PHASE 0 — Backup

6 ficheiros copiados para `/tmp/agents-backup-owasp/`:

```
auditoria.md        6.8K
construcao.md       5.3K
crypto.md           6.0K
gestor-de-agentes.md 5.9K
sistema.md          5.8K
site.md             5.5K
```

Backup confirmado: `ls -la /tmp/agents-backup-owasp/` → 6 ficheiros.

---

## 3. PHASE 1 — Read e localização do ponto de inserção

Lida secção `## Skills` de cada agente. Ponto de inserção: última linha do bloco `**ECC (expostas):**`.

| Agente | Última skill ECC (âncora) | Heading seguinte |
|--------|--------------------------|-----------------|
| auditoria | `workspace-surface-audit` (linha 112) | `## Plugins de Segurança` |
| construcao | `ai-regression-testing` (linha 87) | `## Segurança Embutida` |
| sistema | `quarkus-patterns`, `quarkus-security` (linha 91) | `## Segurança Server-Side Embutida` |
| gestor-de-agentes | `token-budget-advisor` (linha 74) | `## Princípios de Configuração` |
| crypto | `llm-trading-agent-security` (linha 100) | `## MCP Disponíveis` |
| site | `ui-to-vue` (linha 100) | `## Segurança Web Embutida` |

---

## 4. PHASE 2 — Edição (6 Edit tool calls em paralelo)

Entry inserida após última skill ECC e antes do heading seguinte, em todos os 6 agentes.

Approach usado: Edit com `old_string = [última_skill]\n\n## [heading]` →
`new_string = [última_skill]\n- \`owasp-security\` — OWASP Top 10/ASVS/LLM/Agentic security\n\n## [heading]`

Resultado: 6/6 `Edit` → `updated successfully`.

---

## 5. PHASE 3 — Verificação

### 5.1 grep -c owasp-security (6 agentes editados)

```
auditoria.md:1
construcao.md:1
sistema.md:1
gestor-de-agentes.md:1
crypto.md:1
site.md:1
```

`total == 1` em todos → zero duplicados, entry presente e única.

### 5.2 grep -c owasp-security (4 agentes NÃO tocados)

```
lancamento.md:0
conteudo.md:0
midia.md:0
pesquisa.md:0
```

4 agentes excluídos intactos.

### 5.3 Diff vs backup (prova de removed=0)

```
auditoria:        added=1  removed=0
construcao:       added=1  removed=0
sistema:          added=1  removed=0
gestor-de-agentes: added=1 removed=0
crypto:           added=1  removed=0
site:             added=1  removed=0
```

Puramente aditivo em todos os 6. Nenhuma skill nativa ou ECC existente removida.

### 5.4 Contagem antes → depois

| Agente | Skills antes | +owasp | Skills depois |
|--------|------------:|-------:|--------------|
| auditoria | 7 | +1 | 8 |
| construcao | 23 | +1 | 24 |
| sistema | 28 | +1 | 29 |
| gestor-de-agentes | 16 | +1 | 17 |
| crypto | 13 | +1 | 14 |
| site | 40 | +1 | 41 |

---

## 6. Riscos restantes

1. **Buraco web CSP/DOMPurify do site** continua aberto — `owasp-security` cobre princípios OWASP mas
   não o detalhe de implementação CSP/DOMPurify específico do frontend. Rule `rules/ecc/web/security.md`
   existe mas skill dedicada `web-security` ainda não criada.
2. Backups em `/tmp` voláteis (perdem em reboot). Edits persistidos em `~/.claude/agents/`.
3. `owasp-security.reference/` (languages.md, owasp-report.md) é load-on-demand: agentes seguem links
   quando precisam de detalhe por linguagem ou standard específico.

---

## 7. Artefactos / paths

- 6 agentes editados: `~/.claude/agents/{auditoria,construcao,sistema,gestor-de-agentes,crypto,site}.md`
- 4 agentes intactos: `~/.claude/agents/{lancamento,conteudo,midia,pesquisa}.md`
- Backups: `/tmp/agents-backup-owasp/` (6 ficheiros)
- Skill instalada: `~/.claude/skills/owasp-security/`
- Relatório de instalação: `~/.claude/scripts/owasp-security-install-REPORT.md`
- Este relatório: `~/.claude/scripts/declare-owasp-per-agent-REPORT.md`

---

**Critérios PASS (todos provados):** `grep -c =1` × 6 editados · `grep -c =0` × 4 intactos ·
`diff removed=0` × 6 · `added=1` × 6 · 4 agentes excluídos não tocados.
