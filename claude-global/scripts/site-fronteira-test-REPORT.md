# RELATÓRIO — Correção de fronteira de segurança do agente site (3ª tentativa)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **TEXTO NÃO RESOLVE (3ª falha → plano B)**

Tentativa de fechar o buraco de segurança web do agente `site` reescrevendo a **fronteira de scope** (não conhecimento, não gatilho). Testada na mesma corrida. Resultado: CSP falhou 3ª vez consecutiva → problema é estrutural (superfície de revisão), não de texto.

Prova: Read/Grep/Glob + `rtk proxy` raw (nunca Bash filtrado por RTK). Objeto do teste: invocação do subagente `site`.

---

## 1. Contexto — causa raiz provada antes desta corrida

Buraco do agente `site`: revê frontend e **não levanta CSP**. Causa raiz já provada nos testes anteriores:
- **NÃO** é falta de conhecimento — CSP está em 3 sítios do site.md (Missão linha 26, checklist linha 105, skill owasp-security).
- **NÃO** é falta de gatilho — instrução de processo enterrada no checklist já falhou (relatório `site-trigger-test-REPORT.md`).
- **É misclassificação de scope** — agente classifica segurança frontend como backend e empurra p/ Sistema ("fora deste ficheiro").

Esta tentativa: reescrever a **identidade/fronteira** no topo (junto à Missão), cravar 3 categorias, nomear o erro de delegar. Tentativa DIFERENTE das 2 anteriores.

**Pré-condição declarada:** se falhar também → plano B (fluxo via auditoria), NÃO mais texto.

---

## 2. PHASE 0 — Backup

```
cp ~/.claude/agents/site.md /tmp/site-backup-fronteira.md
diff /tmp/site-backup-fronteira.md site.md → BACKUP_IDENTICAL
```

---

## 3. PHASE 1 — Reescrever a fronteira (no topo, após Missão)

Bloco inserido após `## Missão` (linha 30), antes de `## Quando Usar`. Diff `30a31,50`, `added=20 removed=0` (append puro, topo):

```markdown
## Segurança é Tua na Construção (não delegues ao backend)

Constróis frontend SEGURO desde o primeiro momento — segurança não é um passo no fim nem
trabalho do Sistema. Numa revisão ou construção de componente:

**FRONTEND — TEU, nunca delegar ao Sistema:**
- CSP e security headers (configurados no Next/edge/middleware)
- Secrets fora do bundle do browser; `NEXT_PUBLIC_*` só para o que pode ser público
- XSS no DOM: `dangerouslySetInnerHTML`, `innerHTML`, sanitização client-side (DOMPurify)
- Sanitização de `href` (bloquear `javascript:`), source maps fora de produção
- Storage de token no cliente (httpOnly cookie vs localStorage)

**PARTILHADO — implementas a ponte no frontend MAS a proteção real é no servidor:**
- Validação de inputs: client-side é só UX; a validação que protege é server-side (coordena com Sistema)
- CSRF: token no frontend, verificação no backend

**BACKEND — do Sistema, não teu:**
- SQL injection, auth/sessão no servidor, rate limiting, segurança de payloads

**REGRA:** numa revisão de frontend, NUNCA classifiques CSP, secrets-no-bundle, headers ou
sanitização client-side como "backend" ou "fora deste ficheiro". São teus.
```

---

## 4. PHASE 2 — Teste com tarefa NEUTRA (anti-contaminação)

Mesmo componente do teste anterior (comparação direta). String exata sem palavras de segurança.

**Scan** (`seguran|csp|xss|owasp|secret|sanitiz|vulner|injec`):
```
CLEAN — zero palavras proibidas
```

Componente (RegisterForm React, defeitos naturais, zero comentários-dica): email/password/confirm,
`fetch POST /api/register`, `console.log(data)`, `window.location.href='/dashboard'`, inputs sem type/label.

---

## 5. PHASE 3 — Veredicto (grep raw no output do subagente)

```
=== [DECISIVO] CSP levantado? ===
CSP: ZERO MENÇÕES — NÃO levantado

=== Itens FRONTEND tratados como dele? ===
  [csp]                                  -> AUSENTE
  [secret|bundle|token de sessão|auth]   -> token de sessão, auth
  [header]                               -> AUSENTE
  [sanitiz|innerHTML]                    -> AUSENTE
  [type="password"|texto claro]          -> texto claro, type="password"

=== CRÍTICO: ainda empurra p/ backend? ===
14: do lado do servidor   (aplicado a rate-limiting — backend correto)
```

| Critério decisivo | v3 (fronteira no topo) |
|---|---|
| CSP levantado? (falhou nos 2 anteriores) | **NÃO** — 3ª falha |
| headers (HSTS/X-Frame) | AUSENTE |
| sanitiz/innerHTML | AUSENTE (N/A defensável — componente sem sink XSS) |
| secrets-no-cliente | **OWNED** — não delegou |
| punt indevido ao backend | NÃO — só rate-limit (backend real) foi p/ servidor |

**Excerto — o que melhorou (assumiu como frontend, não delegou):**
> "**2. console.log('registo', data) — fuga de dados sensíveis** … a resposta de registo costuma trazer
> token de sessão … **Nunca logar respostas de auth.**"

**Excerto — CSP ausente; o mais perto foi CSRF/rate-limit, corretamente como gate backend:**
> "**3. Sem CSRF / sem garantias de segurança no submit** — a regra de segurança web do projeto exige
> proteção CSRF … rate limiting **do lado do servidor** … gate obrigatório"

---

## 6. Comparação direta (mesmo componente, mesmo agente)

| | v2 (sem fronteira) | v3 (fronteira no topo) |
|---|---|---|
| CSP levantado | NÃO | **NÃO** |
| Punt de segurança | **tudo** "server-side, fora deste ficheiro" → Sistema | só rate-limit (backend real); leak de token assumido como frontend |
| Ownership frontend | nenhuma | leak de token, password-cleartext assumidos como dele |
| Veredicto | NÃO BASTA | **NÃO RESOLVE** |

Fronteira melhorou a *ownership* dos itens **observáveis** no componente (leak de token = frontend agora,
não delegado). Mas o item decisivo (CSP) falhou na mesma.

---

## 7. PHASE 4 — Reversão (veredicto negativo)

```
cp /tmp/site-backup-fronteira.md ~/.claude/agents/site.md
grep -c "Segurança é Tua na Construção" site.md  → 0
diff /tmp/site-backup-fronteira.md site.md       → IDENTICAL
```
site.md revertido ao original (133 linhas). **Sem mais ajustes de texto** (pré-condição cumprida).

---

## 8. Root cause final — porque o texto NUNCA resolve CSP

CSP/headers **não existem num componente colado** — vivem em `next.config` / `middleware` / edge config.
Revisão de *um componente* não tem o artefacto onde CSP se manifesta → o agente não aponta CSP porque
não há nada CSP-shaped para apontar.

As 3 tentativas de texto falharam todas no **mesmo** ponto:
1. Conhecimento repetido (CSP em 3 sítios) → não levantou.
2. Gatilho enterrado (instrução de processo no checklist) → não levantou.
3. Fronteira no topo (3 categorias + regra anti-delegação) → não levantou.

Não é o prompt do site. É a **superfície da revisão**: componente isolado ≠ projeto com config.
Mais texto no site.md não muda a superfície.

---

## 9. Plano B — FLUXO, não texto

Buraco fecha por **estágio de revisão que vê o frontend inteiro (incl. config)**:

> **site constrói** → **auditoria revê frontend antes de produção**

`auditoria` já tem: skill `owasp-security` declarada + checklist OWASP (CSP, headers, CORS) +
acesso a `next.config`/`middleware`/headers (projeto completo, não componente isolado).
Auditoria a olhar o projeto inteiro **tem o artefacto** onde CSP/SRI/headers vivem → levanta-os.

**Próximo passo (aguarda decisão):** formalizar o fluxo, ex.:
- nos `## Limites` do site: "antes de produção, revisão de segurança frontend via **auditoria**", e/ou
- release gate no `lancamento` que exige passagem de auditoria em frontend.

Sem mais variações de texto no site.md.

---

## 10. Artefactos / paths

- Agente testado: `~/.claude/agents/site.md` (revertido ao original)
- Backup: `/tmp/site-backup-fronteira.md` (IDENTICAL ao atual)
- Output subagente v3: `/tmp/site-review-v3-output.txt`
- String neutra: `/tmp/neutral-task-v3.txt`
- Relatório do teste de gatilho anterior: `~/.claude/scripts/site-trigger-test-REPORT.md`
- Este relatório: `~/.claude/scripts/site-fronteira-test-REPORT.md`

---

**Critérios do veredicto (todos provados):** CSP zero menções (grep) · 3ª falha consecutiva no item
decisivo · melhoria parcial real (ownership de itens observáveis) mas insuficiente · site.md revertido
(diff IDENTICAL) · root cause = superfície de revisão (componente ≠ config), não prompt · plano B = fluxo
site→auditoria. Buraco **ABERTO** — fecha por fluxo, não por texto.
