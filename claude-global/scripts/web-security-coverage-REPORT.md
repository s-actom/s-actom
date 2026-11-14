# RELATÓRIO — Diagnóstico de Cobertura Web Security no Agente Site

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **COBERTURA FRACA → CRIAR SKILL**

---

## 1. Objetivo

Determinar se a cobertura de segurança web já chega ao agente `site` de forma acionável,
antes de decidir criar uma skill `web-security` nova.

**Critério de decisão:**
- Rule chega + é acionável + agente usa-a → não criar skill (lacuna aparente)
- Rule não chega, ou é só consciência, ou agente não aplica → criar skill (buraco real)

**Constraints:** read-only total. Zero edits, zero skills criadas, zero symlinks.

---

## 2. PHASE 0 — Conteúdo da rule

**Ficheiro:** `~/.claude/rules/ecc/web/security.md` · 57 linhas

### Classificação: ACIONÁVEL

Contém padrões concretos aplicáveis numa revisão real:

| Secção | Conteúdo |
|--------|----------|
| CSP | Template nonce-based completo (`script-src 'self' 'nonce-{RANDOM}'`) |
| XSS Prevention | Regras explícitas: `innerHTML`, `dangerouslySetInnerHTML`, escape de templates |
| HTTPS Headers | Valores exatos: HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, Permissions-Policy |
| Forms | CSRF, rate limiting, validação dupla client+server |
| Third-Party Scripts | SRI em CDN, async loading, auto-auditoria trimestral |

**MARCADOR ÚNICO extraído:** `"Do not cargo-cult this block unchanged"` — frase
distintiva que só existe neste ficheiro. Usada para detetar injeção no contexto do subagente.

---

## 3. PHASE 1 — A rule chega ao agente site?

### 3.1 Método

Invocação do subagente `site` com tarefa de login form que **não nomeia segurança nem a rule**:

> "Sem editar ficheiros, revê a estrutura de um formulário de login em React que envia
> credenciais a uma API REST. [...] Aponta riscos de produção."

Tarefa de login = território natural de XSS/CSP/secrets. Se a rule estivesse ativa, o
agente devia mencionar CSP e XSS patterns.

### 3.2 Resultado do marcador

**Transcript do subagente:** `~/.claude/projects/-Users-goncaloferro/f3892009.../subagents/agent-aad9cc7933a20dad5.jsonl`

```
grep "cargo-cult" agent-aad9cc7933a20dad5.jsonl
→ 0 ocorrências
```

**Nota crítica:** O JSONL de subagentes tem 2 linhas apenas (user + assistant).
System prompts NÃO são gravados em JSONL. A ausência do marcador no JSONL é
**inconclusiva** sobre injeção — não é prova de ausência.

### 3.3 Mecanismo de injeção das rules

| Mecanismo | Estado |
|-----------|--------|
| `settings.json` customInstructions | Ausente |
| `settings.json` chave `rules` | Ausente |
| `@import` em `~/.claude/CLAUDE.md` | Ausente (só `@RTK.md`) |
| `@import` em `~/CLAUDE.md` | Ausente |
| Auto-load nativo de `~/.claude/rules/` | **Provável** (presente no contexto da sessão principal) |

As rules chegam ao contexto da sessão principal via mecanismo nativo do Claude Code
(auto-load de `~/.claude/rules/`). Se esse mecanismo se estende a subagentes é
**não provado** por transcript.

### 3.4 Achado inesperado: site.md tem checklist próprio

O ficheiro `~/.claude/agents/site.md` **já tem** `## Segurança Web Embutida` (linhas 91–99):

```markdown
- [ ] CSP configurado em produção — sem `unsafe-inline` desnecessário
- [ ] Inputs sanitizados antes de `innerHTML` ou `dangerouslySetInnerHTML`
- [ ] Secrets nunca no bundle do browser
- [ ] SRI em scripts externos via CDN
- [ ] Headers: HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- [ ] Formulários: CSRF, rate limiting, validação server + client
```

Este checklist é **bullets sem exemplos** — menos rico que a rule (que tem templates concretos).

### 3.5 O agente aplicou cobertura de segurança web?

**O agente mencionou:**

| Item | Fonte |
|------|-------|
| HSTS + `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload` | Na rule E no site.md |
| CSRF em formulários com cookie de sessão | Na rule E no site.md |
| Rate limiting no servidor | Na rule E no site.md |
| Content-Type: application/json ausente | Conhecimento geral (não na rule) |
| `response.ok` não verificado | Conhecimento geral |
| Password no React state sem limpeza | Conhecimento geral |
| Double-submit / botão não desativado | Conhecimento geral |
| `autocomplete` em inputs | Conhecimento geral |

**O agente NÃO mencionou** (sendo que o site.md DIZ para verificar):

| Item ausente | Relevância para login form |
|--------------|---------------------------|
| **CSP** — item #1 do checklist do site.md | Alta — toda app React de produção precisa |
| `dangerouslySetInnerHTML` safety | Baixa — sem rendering de HTML user nesta task |
| SRI em scripts externos | Baixa — sem CDN no form |
| Nonce-based CSP (conteúdo distintivo da rule) | Alta — missing em 100% da resposta |

**Conclusão:** A resposta do agente é **inteiramente explicável** por site.md + conhecimento
geral. Nenhum conteúdo DISTINTIVO da rule apareceu. O agente focou em issues de
**componente React** (fetch headers, state, UX) — não em **browser security** (CSP, headers).

---

## 4. PHASE 2 — Cruzamento e Veredicto

| Sinal | Resultado |
|-------|-----------|
| Rule é acionável (Phase 0) | ✓ SIM — 57 linhas com exemplos concretos |
| Rule chega ao contexto do site | ⚠️ INCONCLUSIVO — provável via auto-load, não provado por transcript |
| Site.md tem checklist próprio | ✓ SIM — linhas 91–99, bullets sem exemplos |
| Agente mencionou CSP na tarefa de login | ✗ NÃO — item #1 do seu próprio checklist |
| Cobertura efetiva = comportamento provado | ✗ NÃO — agent não aplicou checklist |

### VEREDICTO: COBERTURA FRACA → CRIAR SKILL

A cobertura **existe** (site.md tem checklist, rule provavelmente injetada), mas é
**passiva** — está no contexto como conhecimento mas **não é aplicada** em revisões
de código sem invocação explícita.

**Prova:** O agente reviu formulário de login React de produção e não levantou CSP —
o item #1 do seu próprio checklist interno. Falha real, não aparente.

**Por que skill em vez de confiar na rule/site.md:**

| Mecanismo | Comportamento |
|-----------|---------------|
| Rule | Conhecimento passivo no contexto |
| site.md checklist | Conhecimento passivo no agent definition |
| **Skill (invocada via `Skill(web-security)`)** | **Checklist ativo forçado na task** |

Padrão já provado em sessões anteriores: skills injetam conteúdo acionável no momento
certo; rules/site.md não garantem aplicação.

---

## 5. O que a skill web-security tem de cobrir

### Coberto pela rule (manter/incorporar)

- CSP nonce-based template completo
- XSS: `innerHTML`, `dangerouslySetInnerHTML`, escape
- HTTPS headers com valores exatos
- Forms: CSRF, rate limiting, validação dupla
- SRI em CDN scripts

### Gaps que a rule NÃO cobre (adicionar na skill)

1. **React-specific XSS:**
   - `href` injection com `javascript:` pseudo-protocol
   - Template literals sem escape em `dangerouslySetInnerHTML`
   - `eval()` / `new Function()` com input externo

2. **Bundle secret exposure:**
   - `process.env` exposto em bundle client-side
   - `NEXT_PUBLIC_*` variáveis — o que pode/não pode ir público
   - Source maps em produção (expõem lógica)

3. **Auth storage:**
   - httpOnly cookie vs localStorage vs sessionStorage
   - JWT attack surface por storage type
   - XSS → localStorage token theft

4. **Crash reporters / session replay:**
   - Sentry, Hotjar, FullStory — masking obrigatório de passwords e PII
   - React state capturado por tools de debug (Redux DevTools, React DevTools)

5. **CSP em Next.js especificamente:**
   - Implementação via middleware (`next.config.js` headers vs middleware.ts)
   - Nonce em App Router vs Pages Router
   - `unsafe-eval` e webpack — como evitar

6. **CORS no cliente:**
   - `credentials: 'include'` — implicações de segurança
   - Origem wildcard em APIs próprias

7. **Third-party scripts:**
   - Supply chain risk: o que corre no browser sem controlo
   - Tag managers, analytics, pixels — superfície de ataque

8. **Checklist de code review ativo:**
   - Processo passo-a-passo para revisar componentes com input/output
   - Flags automáticas: `dangerouslySetInnerHTML`, `eval`, `innerHTML`, `document.write`

---

## 6. Próximos passos

1. **Criar** `~/.claude/skills/ecc/web-security/` (ou diretamente em root via symlink)
2. Incorporar rule existente + 8 gaps listados acima
3. Adicionar à frontmatter do site.md: invocar `web-security` em revisões de segurança
4. Testar: repetir tarefa login form com `Skill(web-security)` invocado — CSP deve aparecer

---

## 7. Artefactos

- Rule analisada: `~/.claude/rules/ecc/web/security.md`
- Agente testado: `~/.claude/agents/site.md`
- Transcript subagente: `~/.claude/projects/-Users-goncaloferro/f3892009-3bb7-46e3-a605-9a0377a235a0/subagents/agent-aad9cc7933a20dad5.jsonl`
- Este relatório: `~/.claude/scripts/web-security-coverage-REPORT.md`

---

**Critérios do veredicto COBERTURA FRACA:**
rule acionável (provado) · rule no subagente inconclusiva (transcript não grava system prompt) ·
site.md tem checklist passivo · agente perdeu CSP em login form review (prova comportamental) ·
skill = mecanismo ativo vs knowledge passivo
