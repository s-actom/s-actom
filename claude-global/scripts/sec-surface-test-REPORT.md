# RELATÓRIO — Teste de segurança na superfície CERTA (config/projeto)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **NÃO HÁ BURACO**

Teste decisivo que fecha a investigação do "buraco de segurança web" do agente `site`. Os 3 testes anteriores mediram CSP num **componente isolado** — mas CSP/headers/secrets-de-config não existem num componente, vivem em `next.config`/`middleware`. Este teste dá o artefacto certo e mede se os agentes o revêem. Resultado: **site e auditoria levantam 5/5 itens.** Nunca houve buraco — só superfície de medição errada 3×.

Prova: Read/Glob/Write + `rtk proxy grep` raw (nunca Bash filtrado por RTK). Objeto do teste: invocações dos subagentes `site` e `auditoria`. READ-ONLY total — zero edits a agentes/skills.

---

## 1. Pergunta a fechar

Dado um `next.config` / `middleware` real, o agente levanta **CSP, security headers e secrets-no-bundle**?
- SIM → nunca houve buraco, só superfície errada (componente).
- NÃO → buraco real e fundo.

Testar **dois** agentes para identificar o sítio certo desta revisão:
- `site` — constrói frontend, devia pensar em config de segurança frontend.
- `auditoria` — revê projeto inteiro, tem `owasp-security` declarada, candidato do plano B.

---

## 2. PHASE 0 — Artefacto de config (defeitos naturais, zero dicas)

Mini-projeto Next em `/tmp/sec-surface-test/` com defeitos de config plantados, sem nomear nada.

`next.config.js`:
```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  productionBrowserSourceMaps: true,
  env: {
    API_KEY: process.env.STRIPE_SECRET_KEY,
    NEXT_PUBLIC_API_URL: 'https://api.exemplo.com',
  },
};
module.exports = nextConfig;
```

`middleware.ts`:
```ts
import { NextResponse } from 'next/server';
export function middleware() {
  return NextResponse.next();
}
export const config = { matcher: '/:path*' };
```

**Defeitos plantados (todos de config, sem comentários-dica):**
1. `productionBrowserSourceMaps: true` — source maps em produção.
2. `env.API_KEY = STRIPE_SECRET_KEY` — secret real inlined no bundle do cliente via `env`.
3. `NEXT_PUBLIC_API_URL` hardcoded.
4. `middleware` no-op a correr em todos os paths, **sem** definir headers.
5. Ausência total de CSP / security headers.

**Scan anti-contaminação** (`seguran|csp|content-security|xss|owasp|sanitiz|vulner|header.*secur`):
```
CLEAN — zero palavras de segurança nos ficheiros/comentários
```

---

## 3. PHASE 1+2 — Invocação paralela (site + auditoria), tarefa NEUTRA

String idêntica aos dois (sem palavras de segurança):
> "Sem editar ficheiros, revê a configuração deste projeto Next em /tmp/sec-surface-test/ (next.config.js e middleware.ts) e aponta o que melhorarias antes de ir para produção."

Tarefa não menciona segurança. Mas o artefacto **tem** onde CSP/headers/secrets se manifestam.

---

## 4. PHASE 3 — Veredicto por agente (grep raw nos outputs)

```
========== site ==========
  CSP                : LEVANTADO
  security headers   : LEVANTADO (hsts,nosniff,permissions-policy,referrer-policy,strict-transport,x-content-type,x-frame)
  secret no bundle   : LEVANTADO
  source maps prod   : LEVANTADO
  NEXT_PUBLIC mal uso: LEVANTADO
========== auditoria ==========
  CSP                : LEVANTADO
  security headers   : LEVANTADO (hsts,nosniff,permissions-policy,referrer-policy,strict-transport,x-content-type,x-frame)
  secret no bundle   : LEVANTADO
  source maps prod   : LEVANTADO
  NEXT_PUBLIC mal uso: LEVANTADO
```

| Item | site | auditoria |
|---|---|---|
| **CSP** (decisivo — falhou 3× em componente) | ✅ LEVANTADO | ✅ LEVANTADO |
| security headers (HSTS, nosniff, X-Frame, X-Content-Type, Referrer, Permissions) | ✅ 7/7 | ✅ 7/7 |
| secret no bundle (`env.API_KEY` = STRIPE) | ✅ CRITICAL | ✅ CRITICAL |
| source maps produção | ✅ HIGH | ✅ CRITICAL |
| NEXT_PUBLIC mal usado | ✅ LOW | ✅ LOW |

**5/5 em ambos.**

---

## 5. Excertos reais (palavras dos agentes)

**site** — levantou CSP sozinho, tarefa neutra, sem skill owasp-security invocada (rules em contexto bastaram):
> "**HIGH — Nenhum security header configurado** … `Content-Security-Policy` — ausente. A rule exige CSP
> em produção (idealmente nonce-based, sem `unsafe-inline` em `script-src`) … O `middleware.ts`, que já
> intercepta todos os paths, seria o local natural para injetar estes headers (e o nonce do CSP por request)."

> "**CRITICAL — Segredo do Stripe exposto no bundle do browser** … Tudo dentro do bloco `env` do Next é
> **inlined em build-time** … a `STRIPE_SECRET_KEY` (`sk_live_...`) acaba no bundle … deve ser **rodada**."

**auditoria** — 5/5 + prompt-injection scan + routing:
> "**Ausência total de security headers** … nem **Content-Security-Policy**. As regras web do projeto
> exigem CSP em produção … CSP baseada em nonce. Ver `rules/ecc/web/security.md`."

> "Prompt Injection: **CLEAN**" · "Próximo Passo: encaminhar para **sistema** as correções CRITICAL e HIGH …
> **rotacionar a Stripe key** (assumir comprometida). Não avançar para produção enquanto os dois CRITICAL
> não estiverem resolvidos."

---

## 6. Comparação com os 3 testes anteriores

| Teste | Superfície | Artefacto tem CSP? | CSP levantado? |
|---|---|---|---|
| v1 (gatilho) | componente isolado | não | — (recusou: sem ficheiro) |
| v2 (knowledge) | componente isolado | não | **NÃO** |
| v3 (fronteira topo) | componente isolado | não | **NÃO** |
| **este (config)** | **next.config + middleware** | **sim** | **SIM — site E auditoria** |

Padrão: CSP só aparece quando o artefacto onde CSP vive está na superfície de revisão. Componente nunca o teve.

---

## 7. Conclusão final

**Nunca houve buraco.** Os 3 testes mediram **CSP num componente** — onde CSP/headers/secrets-de-config
**não existem** (vivem em `next.config`/`middleware`/edge). Superfície errada 3×.

Dado o artefacto certo, o agente `site` **no estado original (revertido, intacto)** faz revisão de
segurança de config completa: CSP, 7 headers, secret-no-bundle, source maps, NEXT_PUBLIC — sem dica,
sem skill nova, sem edição de prompt. O `auditoria` faz igual + prompt-injection scan + routing p/ sistema.

Gap = **artefacto de medição**, não defeito do agente.

---

## 8. Próximo passo

Nada a corrigir. Decisões fechadas:
- **NÃO criar** skill `web-security` — conhecimento aplica-se quando a superfície é a certa.
- **NÃO editar** `site.md` — intacto, funciona (133 linhas, original).
- **Plano B (fluxo site→auditoria) é OPCIONAL**, não obrigatório: auditoria fez 5/5 e adiciona
  prompt-injection + routing, útil como gate final; mas o site sozinho cobre config quando recebe a config.
- **Lição operacional:** rever segurança ao nível de **projeto/config**, não componente isolado, quando o
  alvo é headers/CSP/secrets-de-build.

---

## 9. Artefactos / paths

- Agentes testados: `site`, `auditoria` (ambos no estado original, READ-ONLY, zero edits)
- `site.md`: intacto (133 linhas, original — fronteira do teste anterior revertida)
- Outputs: `/tmp/site-config-output.txt` · `/tmp/auditoria-config-output.txt`
- Artefacto de teste: `/tmp/sec-surface-test/` — **removido no fim** (`rm -rf`, confirmado LIMPO)
- Relatórios da investigação: `site-trigger-test-REPORT.md` · `site-fronteira-test-REPORT.md` · este
- Este relatório: `~/.claude/scripts/sec-surface-test-REPORT.md`

---

**Critérios do veredicto (todos provados):** artefacto CLEAN (sem dicas) · tarefa neutra (sem palavras de
segurança) · site 5/5 (grep) · auditoria 5/5 (grep) · CSP levantado por ambos com superfície certa vs 0/3
em componente · site.md intacto · artefacto removido. **NÃO HÁ BURACO — fechado.**
