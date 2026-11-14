# RELATÓRIO — Instalação da skill owasp-security (scan-first)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Veredicto:** **INSTALADA**

Fonte: `github.com/agamm/claude-code-owasp` (MIT, defensiva, OWASP 2025/26).
Destino: `~/.claude/skills/owasp-security/` (root, path escaneado pelo harness).
Regra cumprida: **scan de segurança ANTES de instalar**. Conteúdo externo tratado como não confiável.
Prova: Read/Grep/Glob + `rtk proxy` raw (nunca Bash filtrado por RTK).

---

## 1. Objetivo

Instalar skill `owasp-security` para reforço de segurança transversal — beneficia sistema, auditoria,
gestor-de-agentes, crypto (LLM/agente prompt-injection) e parcialmente site (princípios XSS + checklist).
**Não** fecha sozinha o detalhe CSP/DOMPurify frontend — isso fica na rule `rules/ecc/web/security.md`.

---

## 2. PHASE 0 — Baixar para staging (NÃO instalar)

- Staging fora do path ativo: `/tmp/owasp-skill-staging/`.
- **Não** usado o `curl|sh` do README. Baixado só o conteúdo da skill:

```
SKILL.md              HTTP=200  BYTES=13747  (321 linhas)
reference/languages.md    HTTP=200  BYTES=9197   (334 linhas)
reference/owasp-report.md HTTP=200  BYTES=26267  (792 linhas)
```

- `reference/` confirmado existir no repo (GitHub contents API: SKILL.md=file, reference=dir).
- Primeiro byte = frontmatter válido `name: owasp-security` (não HTML de erro).

---

## 3. PHASE 1 — Scan de segurança (ANTES de mover)

### 3.1 Prompt injection
grep case-insensitive por: `ignore previous/above/prior`, `disregard`, `you are now`, `override`,
`exfiltrat`, `send to/your`, `rm -rf`, `base64 -d`, `ANTHROPIC_`, `API_KEY`, `.env`, `getenv`,
`process.env`, `curl `, `wget`.

| Ficheiro | Resultado |
|----------|-----------|
| SKILL.md | `NENHUM_PADRAO_CRITICO` |
| languages.md | 1 match: linha 326 `"Main Risks: Injection, privilege escalation, data exfiltration"` — **nome de categoria de risco** (secção Shell), não instrução |
| owasp-report.md | nenhum |

### 3.2 Execução escondida
- Todos os blocos ```python``` são exemplos `# UNSAFE` vs `# SAFE` ilustrativos. Nenhum "corre isto".
- Zero blocos bash/shell de execução. Zero `curl`/`wget`/network.
- Frontmatter `allowed-tools: Read Grep Glob` → **read-only**, sem Bash/Write/Edit.

### 3.3 URLs externas
- SKILL.md: **0 URLs**.
- reference/: só citações legítimas + 1 placeholder + 1 URI de feature:

```
owasp.org/Top10/ · genai.owasp.org/ · github.com/OWASP/ASVS · cwe.mitre.org/top25/
csrc.nist.gov/.../800-61 · pages.nist.gov/800-63-3/ · cheatsheetseries.owasp.org/
aikido.dev/blog · securityboulevard.com · about.gitlab.com/blog
cdn.example.com/lib.js (×2)  — RFC-reservado, exemplo SRI
xml.org/sax/features/external-general-entities — URI de feature XXE
```

Contextos verificados:
- `cdn.example.com` → `<!-- BAD: CDN without integrity -->` vs `<!-- GOOD: Subresource Integrity -->` `integrity="sha384-..."` — ensina defesa supply-chain.
- `xml.org SAX` → `factory.setFeature("...external-general-entities", false)` — desativa XXE (defensivo).

Nenhuma URL é endpoint de exfiltração.

### 3.4 Conteúdo vs descrição
Frontmatter promete segurança defensiva (OWASP Top 10:2025, ASVS 5.0, LLM Top 10 2025, Agentic AI 2026).
Body entrega exatamente isso. Coerente.

### VEREDICTO DO SCAN: **LIMPO**
Sem injeção · sem execução escondida · conteúdo coerente · tools read-only.

---

## 4. PHASE 2 — Instalar (só porque LIMPO)

- Destino **não existia** antes (`ls → No such file or directory`) → criado limpo, nada sobreposto, sem backup necessário.
- `mkdir -p ~/.claude/skills/owasp-security/reference` + cópia dos 3 ficheiros de staging.
- Integridade provada (bytes idênticos staging vs instalado):

```
SKILL_IDENTICAL
LANGUAGES_IDENTICAL
REPORT_IDENTICAL
```

- Árvore instalada:
```
~/.claude/skills/owasp-security/
├── SKILL.md            (13747)
└── reference/
    ├── languages.md    (9197)
    └── owasp-report.md (26267)
```

---

## 5. PHASE 3 — Verificação

| Check | Resultado |
|-------|-----------|
| `ls -la SKILL.md` existe + conteúdo | ✓ 13747 bytes, frontmatter intacto |
| child direto de `~/.claude/skills/` (path escaneado) | ✓ |
| `name:` frontmatter == nome do dir | ✓ `owasp-security` |
| Aparece na skill_listing da sessão | ✓ (refrescou via SessionStart) |
| `Skill('owasp-security')` resolve | ✓ `Launching skill` + conteúdo carregado da base dir |

Nota: 1ª tentativa de `Skill()` deu `Unknown skill` — o registry de skills carrega no SessionStart;
skill adicionada mid-sessão entrou no registry segundos depois (mesma mecânica da camada ECC).
Não foi falha de instalação — ficheiro sempre correto no disco.

---

## 6. Próximo passo (PROPOSTA — aguarda aprovação, NÃO automático)

Declarar `owasp-security` no body de **5 agentes**:

| Agente | Justificação |
|--------|--------------|
| auditoria | OWASP Top 10 + checklist = core de auditoria |
| sistema | A01–A10 backend, ASVS, auth/injection/crypto |
| gestor-de-agentes | Agentic AI 2026 (ASI01–10) — segurança de agentes/MCP |
| crypto | LLM Top 10 + Agentic (bots trading) + supply-chain |
| site | A05/A08 + LLM05 output handling (complementa rule web, **não** substitui CSP/DOMPurify) |

Abordagem proposta: append-only + backup + verificação (igual ao trabalho de skills/agente anterior).

---

## 7. Riscos restantes

1. **Buraco web CSP/DOMPurify do site** continua na rule, não nesta skill (por design — owasp-security
   cobre princípios, não o detalhe frontend específico).
2. Staging em `/tmp` é volátil (perde em reboot) — irrelevante, instalação canónica já no disco.
3. `reference/` é load-on-demand: se um agente seguir o link, lê os ficheiros locais (presentes, scaneados).
4. Skill ainda **não declarada** em nenhum agente — descoberta depende de auto-injeção por keyword ou
   invocação explícita até aprovação do passo 6.

---

## 8. Artefactos / paths

- Skill instalada: `~/.claude/skills/owasp-security/{SKILL.md, reference/languages.md, reference/owasp-report.md}`
- Staging (transitório): `/tmp/owasp-skill-staging/`
- Repo fonte: `github.com/agamm/claude-code-owasp` (MIT)
- Este relatório: `~/.claude/scripts/owasp-security-install-REPORT.md`

---

**Critérios INSTALADA (todos provados):** scan LIMPO (3 ficheiros) · baixado a staging, não curl|sh ·
destino novo sem sobreposição · bytes idênticos · harness vê · `Skill()` resolve end-to-end ·
não declarada em agentes (aguarda aprovação).
