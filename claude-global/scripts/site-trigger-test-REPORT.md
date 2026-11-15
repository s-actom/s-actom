# RELATÓRIO — Teste de gatilho: instrução de processo no agente site

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **NÃO BASTA** (instrução revertida)

Hipótese testada: o buraco de segurança web do agente `site` é problema de **gatilho** (não aplica o que sabe), não de **conhecimento**. Testar se uma instrução de processo de uma linha ("percorre o checklist em toda revisão") força o agente a aplicar o que já tem.

Prova: Read/Grep/Glob + `rtk proxy` raw (nunca Bash filtrado por RTK). Objeto do teste: a invocação do subagente `site`.

---

## 1. Objetivo e hipótese

`site.md` JÁ tem o conhecimento de segurança web:
- Secção `## Segurança Web Embutida` (checklist de 8 itens, CSP no item 1).
- Skill `owasp-security` declarada no body.
- Secção `## Missão` linha 26: "Segurança web/browser: CSP, XSS, sanitização de inputs, sem secrets no bundle".

Mas num teste anterior reviu um login form React e **não levantou CSP** — não aplicou o que sabe.

**Hipótese:** problema é de GATILHO. Uma instrução de processo ("aplica o checklist sempre") fecharia o buraco com uma linha, sem skill nova.

**Anti-contaminação (erro de antes):** a tarefa de teste NÃO pode mencionar segurança/CSP/XSS/owasp/secrets/sanitização. Tem de ser revisão de frontend neutra. Se o agente levantar CSP, foi a instrução a funcionar — não a tarefa a dar a dica.

---

## 2. PHASE 0 — Baseline + backup

- Backup: `cp site.md /tmp/site-backup-trigger.md` → `BACKUP_OK` (133 linhas, ambos idênticos).
- Baseline confirmado por Read (linhas 100-133):
  - Checklist `## Segurança Web Embutida` presente (linhas 105-112), CSP no item 1 (linha 105).
  - `owasp-security` declarada (linha 101).
  - **Conhecimento JÁ presente — teste não adiciona conhecimento, só gatilho.**

---

## 3. PHASE 1 — Adicionar instrução de processo

Inserida UMA instrução após o checklist (linha 113), antes de `## Regras Visuais`:

```
**OBRIGATÓRIO em qualquer revisão de componente, página ou frontend:** antes de concluir,
percorre TODO o checklist de Segurança Web acima e reporta cada item explicitamente como
OK, RISCO ou N/A. Não concluas uma revisão de frontend sem esta passagem.
```

Diff (só esta adição, append puro):
```
113a114,115
> **OBRIGATÓRIO em qualquer revisão de componente, página ou frontend:** ...
>
```
`added=2 removed=0` (instrução + linha vazia). Zero remoções.

---

## 4. PHASE 2 — Invocar com tarefa NEUTRA

### 4.1 Confound na 1ª tentativa (corrigido)

String inicial dizia "revê este componente" mas nenhum ficheiro anexado. Agente `site` procurou no disco (`~/projects`, `~/dev`), não achou, **recusou rever de memória** (correto por "prova > memória"). Nunca chegou à fase de revisão → instrução não foi testada. **Teste inválido, não negativo limpo.**

### 4.2 Correção — componente inline

Para "este componente" resolver, anexado componente React neutro inline. String da instrução idêntica à spec + bloco de código.

**Scan de palavras proibidas no texto da instrução** (`seguran|csp|xss|owasp|secret|sanitiz|vulner|injec`):
```
CLEAN — zero palavras proibidas de segurança
```
Único "header" = `Content-Type: application/json` (boilerplate obrigatório de JSON POST, não dica de segurança).

Componente enviado (defeitos naturais, zero comentários-dica):
```tsx
import { useState } from 'react';
export function RegisterForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  async function handleSubmit(e) {
    e.preventDefault();
    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, confirm }),
    });
    const data = await res.json();
    console.log('registo', data);
    window.location.href = '/dashboard';
  }
  return (
    <form onSubmit={handleSubmit}>
      <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" />
      <input value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" />
      <input value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="Confirmar password" />
      <button type="submit">Registar</button>
    </form>
  );
}
```

---

## 5. PHASE 3 — Veredicto (prova por grep raw no output)

Output do subagente gravado e analisado por `rtk proxy grep`:

```
=== [TESTE DECISIVO] CSP levantado? ===
CSP: ZERO MENÇÕES — não levantado

=== Itens do checklist Segurança Web — quais surgiram? ===
  [csp]                                    -> AUSENTE
  [innerHTML|dangerouslySetInnerHTML|sanitiz] -> AUSENTE
  [SRI]                                    -> AUSENTE
  [HSTS|X-Frame|X-Content-Type|Referrer]   -> AUSENTE
  [CSRF]                                   -> CSRF
  [rate limit]                             -> rate limit
  [bundle]                                 -> bundle
```

| Critério | Resultado |
|----------|-----------|
| Percorreu checklist explícito (OK/RISCO/N/A)? | **NÃO** — usou buckets CRITICAL/HIGH/MEDIUM. Único `ok` no grep = `res.ok`, não label de checklist |
| Levantou CSP? (item decisivo) | **NÃO** — zero menções |
| Browser-security do checklist | csp/sanitiz/SRI/headers **todos AUSENTES** |
| O que surgiu | só CSRF + rate limit + validação, na nota **"server-side, fora deste ficheiro"**, empurrado p/ Sistema |

**Excerto-chave do output (o erro de scope):**
> "## Nota de segurança (**server-side, fora deste ficheiro**) — Pertence ao backend (coordenar com **Sistema**)"

O agente fez revisão genuinamente boa nos eixos funcional/a11y (error handling do fetch, `res.ok`, redirect via router, `console.log` da resposta, labels WCAG, `type=password`, tipagem TSX). Mas classificou CSP/SRI/headers como backend e **excluiu-os de uma revisão de componente frontend** — apesar do próprio prompt listar isso como "Segurança web/browser… Inclui sempre".

---

## 6. Comparação honesta com teste anterior

| | Antes (sem instrução) | Agora (com instrução) |
|---|---|---|
| Tarefa | login form React | register form React |
| Agente | site | site |
| CSP levantado? | **NÃO** | **NÃO** |
| Checklist percorrido? | não | não |
| Delta | — | surgiu 1 nota server-side (CSRF/rate-limit) que antes não havia |

Outcome decisivo **idêntico**: instrução de uma linha não mudou o resultado (CSP) nem produziu a passagem explícita do checklist.

---

## 7. Diagnóstico root cause

Problema **não** é trigger ausente — é **misclassificação de scope**. O agente acha CSP/headers/SRI = território de Sistema/backend, logo exclui-os de revisão frontend. A linha de processo enterrada no checklist não venceu:
1. o padrão natural do agente (review por severidade), e
2. o punt ativo de segurança ao backend ("fora deste ficheiro").

CSP estava no prompt em DOIS sítios (Missão linha 26 + checklist linha 105) + skill owasp-security + instrução de processo adicionada — e mesmo assim ausente. Confirma: aplicação, não conhecimento; e mais fundo que uma linha de gatilho.

---

## 8. PHASE 4 — Reversão (veredicto negativo)

```
cp /tmp/site-backup-trigger.md ~/.claude/agents/site.md
grep -c "OBRIGATÓRIO em qualquer revisão" site.md  → 0
diff /tmp/site-backup-trigger.md site.md           → IDENTICAL
```
`site.md` revertido ao estado original. Instrução removida.

---

## 9. Próximo passo (proposta — aguarda decisão)

Três opções, da mais barata à mais forte:

1. **Reposicionar a instrução** — não enterrada no checklist, mas como **Protocolo de Revisão obrigatório no topo** (perto da Missão) + frase explícita: "CSP, SRI, security headers são **frontend-owned** — não delegar a Sistema numa revisão de componente." (RECOMENDADO testar primeiro)
2. **Reforçar a rule** `rules/ecc/web/security.md` com gate de output: revisão de frontend não conclui sem secção CSP/headers explícita.
3. **Skill dedicada `web-security`** com gating duro (último recurso — conhecimento já existe, problema é aplicação).

Recomendação: testar opção 1 (reposicionar como protocolo no topo), mesma metodologia anti-contaminação, antes de escalar.

---

## 10. Artefactos / paths

- Agente testado: `~/.claude/agents/site.md` (revertido ao original)
- Backup: `/tmp/site-backup-trigger.md` (IDENTICAL ao atual)
- Output do subagente: `/tmp/site-review-v2-output.txt`
- String neutra: `/tmp/neutral-task-v2.txt`
- Este relatório: `~/.claude/scripts/site-trigger-test-REPORT.md`

---

**Critérios do veredicto (todos provados):** CSP zero menções (grep) · checklist não percorrido (sem OK/RISCO/N/A) · browser-security items ausentes · scope punt ao backend (excerto) · outcome idêntico ao teste anterior · site.md revertido (diff IDENTICAL). Buraco continua **ABERTO**.
