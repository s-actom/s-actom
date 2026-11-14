# RELATÓRIO — Diagnóstico dos `.md` órfãos de `~/.claude/` (read-only)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Modo:** READ-ONLY ABSOLUTO (zero alterações)

Objetivo: saber o que CADA `.md` solto em `~/.claude/` é, antes de decidir apagar/arquivar/manter. Diagnóstico apenas — decisão de apagar é do utilizador, depois. Prova: Read tool (conteúdo) + `rtk proxy wc -l/grep/diff` raw (contagens, refs, sobreposição). **Nada apagado, movido, arquivado ou editado.**

---

## 1. Resumo executivo

- **10 ficheiros · 2855 linhas · ~148K** de `.md` soltos no topo de `~/.claude/`.
- **6 são órfãos TOTAIS** (zero referências em CLAUDE.md / settings / agents / hooks / commands): BUILD_RULES, CAPABILITIES, SKILLS_PROMPT_REFERENCE, SKILLS_MCP_REFERENCE, the-security-guide, PLUGIN_SCHEMA_NOTES.
- **Só `global-lessons.md` tem uso real** — citado por path no CLAUDE.md startup (não `@`-import).
- Candidatos mais fortes a mexer: `README.md` (stub redundante) + `.bak` (obsoleto) → arquivar/apagar.
- `~/.claude/AGENTS.md` **pode** ser auto-lido pelo Claude Code (memory file) — não confirmado em runtime.

---

## 2. Contagens raw (`rtk proxy wc -l`, ground truth)

```
736  CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md
344  CLAUDE_CODE_CAPABILITIES_INVENTORY.md
242  CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md
443  SKILLS_MCP_REFERENCE.md
456  the-security-guide.md
216  PLUGIN_SCHEMA_NOTES.md
170  AGENTS.md
17   README.md
55   global-lessons.md
176  CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md.bak.20260602-162140
2855 total
```
(Tamanhos do `ls -la`: 13.8K · 29.2K · 22K · 25.6K · 28.2K · 6.7K · 8.3K · 1.2K · 3.2K · 15.2K.)

---

## 3. O que cada ficheiro é (com primeiras linhas reais)

### 3.1 `CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md` — 736 L · 13.8K
Regras de construção security-first (PT). Cada feature nova nasce com segurança, permissões, validação, logs, tratamento de erro, tipos e testes mínimos. Não é auditoria de fim — é regra contínua.
> `# CLAUDE CODE — REGRAS DE CONSTRUÇÃO COM SEGURANÇA, TESTES E OBSERVABILIDADE`
**Ref:** órfão total. Mas citado *dentro* de #3 e #10 ("Antes de codificar, lê e aplica CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md").

### 3.2 `CLAUDE_CODE_CAPABILITIES_INVENTORY.md` — 344 L · 29.2K
Snapshot datado de capacidades: roots de skills inspecionados, contagens, regras de discovery, pacotes de segurança #19-24. Fotografia do sistema num instante.
> `## Generated · Date/time: 2026-05-30 11:09:08 CEST · Claude Code version: 2.1.156 · RTK: 0.39.0`
**Ref:** órfão total. **Datado** (CC 2.1.156; atual 2.1.178) → envelhece.

### 3.3 `CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md` — 242 L · 22K
Mapa prático de prompts: que pacote/skill usar, frase exata a colar, quando NÃO usar. Versão viva (perfis ARCANEX_UI/CRO, KAIROS_RUNTIME, VIDEO_RENDER_HYPERFRAMES, packs 1-24).
> `# Claude Code Skills Prompt Reference · ## 1. Como usar este ficheiro`
**Ref:** órfão total.

### 3.4 `SKILLS_MCP_REFERENCE.md` — 443 L · 25.6K
Catálogo completo skills + MCPs + plugins — o que cada um faz (frontend, design, motion, etc.). Para colar como contexto.
> `# Skills, MCPs & Plugins — Referência Completa · Gerado: 2026-05-19`
**Ref:** órfão total. O mais antigo (2026-05-19).

### 3.5 `the-security-guide.md` — 456 L · 28.2K
Artigo/ensaio sobre agentic security: CVEs (CVE-2025-59536, CVE-2026-21852), attack vectors, prompt injection, WhatsApp/email como superfícies. Leitura de fundo, não regra operacional.
> `# The Shorthand Guide to Everything Agentic Security · _everything claude code / research / security_`
**Ref:** órfão total.

### 3.6 `PLUGIN_SCHEMA_NOTES.md` — 216 L · 6.7K
Constraints não-documentadas mas aplicadas pelo validador de `.claude-plugin/plugin.json`. Baseado em falhas reais de instalação. Evita regressões.
> `# Plugin Manifest Schema Notes · captures undocumented but enforced constraints`
**Ref:** órfão total. Valioso quando se edita manifests.

### 3.7 `AGENTS.md` — 170 L · 8.3K
Instruções do plugin ECC (Everything Claude Code): 64 agentes, 261 skills, 84 commands, v2.0.0-rc.1. Lista os sub-agentes ECC (planner, architect, tdd-guide…) — **≠ os 10 agentes operacionais PT** do routing do CLAUDE.md.
> `# Everything Claude Code (ECC) — Agent Instructions · 64 specialized agents, 261 skills`
**Ref:** CLAUDE.md startup (L6) refere "AGENTS.md … do projecto" — isto é o AGENTS.md *de projeto*, não este global. ⚠️ Claude Code **pode** auto-ler `~/.claude/AGENTS.md` como memory file (não confirmado em runtime nesta inspeção).

### 3.8 `README.md` — 17 L · 1.2K
Fragmento incompleto: secção "Plugin Manifest Gotchas" + "Custom Endpoints and Gateways" (`ANTHROPIC_BASE_URL`). Stub acidental, não um README real.
> `### Plugin Manifest Gotchas · If you plan to edit .claude-plugin/plugin.json…`
**Ref:** grep apanhou "README" em ~14 ficheiros (doc-updater, opensource-*, hooks/README, commands/ecc-guide) — mas são menções **genéricas à palavra "README"**, não a *este* ficheiro. Na prática **órfão**.

### 3.9 `global-lessons.md` — 55 L · 3.2K
Lição de disciplina: aprovação de assets visuais só com inspeção explícita (origem ARCANEX). Checklist de extremidades/framing/edges. Distinguir "generated" de "approved".
> `# Global Lessons · Read this at the start of every session.`
**Ref:** **CLAUDE.md** startup item 2 ("Ler `~/.claude/global-lessons.md`") — por path, **não** `@`-import. Único com uso declarado.

### 3.10 `CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md.bak.20260602-162140` — 176 L · 15.2K
Backup antigo de #3 (2026-06-02). Snapshot anterior, menor.
> `# Claude Code Skills Prompt Reference · NÃO é a lista completa das 754 skills cibersegurança`
**Ref:** órfão total. **Obsoleto** (ver §4.1).

---

## 4. Redundância / sobreposição / obsolescência

### 4.1 `.bak` vs #3 (mesmo doc, versões)
`rtk proxy diff` → **175 linhas de diff**. Original (#3) é **mais novo e expandido**:
- `.bak`: "lista completa das **754 skills**", sem perfis.
- #3 atual: "**~186 routable + 651 cyber**", adiciona perfis ARCANEX_UI/ARCANEX_CRO/KAIROS_RUNTIME, VIDEO_RENDER_HYPERFRAMES, catálogo packs 1-24.
→ **`.bak` é subconjunto obsoleto do #3.**

### 4.2 #3 (PROMPT_REF) vs #4 (MCP_REF)
Sobreposição **parcial** — ambos enumeram skills. Ângulos diferentes:
- #3 = *como pedir* (frase de prompt por pacote).
- #4 = *o que cada skill/MCP faz* (catálogo).
#4 é o mais antigo (2026-05-19) → contagens podem estar stale vs #3.

### 4.3 #8 README vs #6 PLUGIN_SCHEMA_NOTES
README (17 L) repete o tema "manifest gotchas" do #6 (216 L) em versão stub. **Redundante.**

### 4.4 #7 AGENTS.md vs routing do CLAUDE.md
**NÃO duplica.** AGENTS.md = 64 agentes do plugin ECC; CLAUDE.md = 10 agentes operacionais PT. Camadas diferentes — coexistem sem conflito de conteúdo (mas atenção a confusão conceptual entre os dois conjuntos).

### 4.5 Obsoletos por data
- `.bak.20260602` — backup explícito, obsoleto.
- `SKILLS_MCP_REFERENCE` (2026-05-19) — o mais velho, contagens divergem dos outros.
- `CAPABILITIES_INVENTORY` (CC 2.1.156) — versão atual é 2.1.178.

---

## 5. Tabela de decisão (proposta — decisão do utilizador depois)

| Ficheiro | Usado em? | Sobrepõe-se a | Classificação sugerida |
|---|---|---|---|
| BUILD_RULES_SECURITY_FIRST | não (citado dentro de #3/#4) | parcial: `rules/ecc/common` (security/testing) | **MANTER órfão** — ou consolidar com `rules/ecc/` |
| CAPABILITIES_INVENTORY | não | — (snapshot único) | **ARQUIVAR** — datado, envelhece |
| SKILLS_PROMPT_REFERENCE | não | `.bak` (#10), parcial #4 | **MANTER órfão** — versão viva |
| SKILLS_MCP_REFERENCE | não | parcial #3 | **MANTER** mas rever staleness / fundir c/ #3 |
| the-security-guide | não | — | **ARQUIVAR** — artigo de leitura, não regra |
| PLUGIN_SCHEMA_NOTES | não | README (#8) | **MANTER órfão** — referência sob demanda |
| AGENTS.md | startup refere só AGENTS.md *de projeto* | não (≠ routing) | **MANTER + verificar** se CC auto-lê |
| README.md | só palavra genérica | #6 (stub do schema) | **CANDIDATO a apagar** — fragmento redundante |
| global-lessons | **sim** (CLAUDE.md startup, por path) | — | **PROMOVER a `@import`** se obrigatório |
| .bak.20260602 | não | #3 (subconjunto antigo) | **ARQUIVAR → `backups/`** ou apagar |

**Legenda das classificações:**
- **MANTER órfão** — referência sob demanda, bom assim.
- **PROMOVER a `@import`** — preciso sempre em contexto.
- **ARQUIVAR** — backup/obsoleto/snapshot → mover para `backups/`.
- **CANDIDATO a apagar** — redundante/morto (só o utilizador confirma).

---

## 6. Recomendação resumida (sem agir)

1. **Apagar/arquivar primeiro (baixo risco):** `README.md` (stub redundante de #6) + `.bak.20260602` (subconjunto obsoleto de #3).
2. **Arquivar (snapshot/leitura):** `CAPABILITIES_INVENTORY` (datado) + `the-security-guide` (artigo).
3. **Promover:** `global-lessons.md` → `@global-lessons.md` no CLAUDE.md se o startup item 2 é mesmo obrigatório (hoje só carrega se eu seguir a instrução, não automaticamente).
4. **Verificar runtime:** se o Claude Code auto-lê `~/.claude/AGENTS.md` — se sim, o conteúdo ECC entra em contexto sem `@` e deve estar alinhado com os 10 agentes PT.
5. **Manter sob demanda:** BUILD_RULES, SKILLS_PROMPT_REFERENCE, SKILLS_MCP_REFERENCE, PLUGIN_SCHEMA_NOTES.

---

## 7. Limitações da inspeção

- Mostradas só as primeiras 30 linhas de cada ficheiro grande (objetivo: caracterizar, não despejar 2855 linhas). README e global-lessons lidos na íntegra (pequenos).
- Refs verificadas em: CLAUDE.md, RTK.md, settings.json, settings.local.json, `agents/`, `hooks/`, `commands/`. Não varri todo o disco — refs fora destes caminhos não estão cobertas.
- `~/.claude/AGENTS.md` auto-load: não testado em runtime (exigiria iniciar sessão limpa e inspecionar contexto injetado).
- `wc < redirect` devolveu 0 (hook RTK mexe no stdin) → usei `rtk proxy wc -l` raw (memória `rtk-diff-unreliable`).

---

## 8. Artefactos / paths (read-only)

- Lidos (30 linhas ou íntegra): os 10 `.md` da §3.
- Refs/diff: `rtk proxy grep -rIl` + `rtk proxy diff` (output em `/tmp/bak-diff.txt`, volátil).
- Este relatório: `~/.claude/scripts/orfaos-md-diagnostico-REPORT.md` (+ cópia Desktop).

**Veredicto:** 10 órfãos mapeados, 6 sem refs nenhumas, 1 com uso real (global-lessons), 2 obsoletos (README stub + .bak). **NÃO apaguei nada. Tudo intacto. Decisão é do utilizador.**
