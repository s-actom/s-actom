# Claude Code Skills Prompt Reference

> **Atualização factual 2026-10-05** — só contagens, versões, listas e estados (§1, §4 [1 nome de tool], §5, §6a/6b, §7 nota, §11, §13). A §8 e restante política NÃO foram alteradas. Versão anterior: `~/.claude/CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md.archived-2026-10-05`.

## 1. Como usar este ficheiro
- Cola este ficheiro (ou as secções 2-4 + 9-10) como contexto no início de um chat técnico.
- NÃO é a lista completa das skills — é um mapa prático para escolher pacotes e copiar frases de prompt corretas.
- Duas populações de skills distintas:
  - **285 skills routable** em `~/.claude/skills/` (auto-discoverable pelo Skill tool): 101 reais + 184 symlinks (95 → `~/.agents/skills/`, 89 → `~/.claude/skills/ecc/`). Loja universal `~/.agents/skills/` com 243 skills (65 não expostas ao Claude Code). *(2026-10-05; antes: ~186 e 103)*
  - **651 skills cibersegurança** em `~/.claude/security-skill-library/` — NÃO auto-discoverable; carregam-se por path, nunca auto-routed (ver §7).
- As skills `lab/manual-only` só com autorização explícita do owner.
- Quando em dúvida: indica o pacote tu mesmo no prompt; não deixes o agente escolher sozinho.
- Para tarefas de código/implementação, aplicar também `~/.claude/CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md`.

## 2. Regra principal (cola sempre)

> **"Não uses skills automaticamente. Usa apenas os pacotes/skills que eu indicar neste prompt. Não uses skills ofensivas, red-team, exploit, pentest, phishing, C2, credential attack, malware ou scanners ativos sem autorização explícita do owner."**

## 3. Pacotes principais e quando usar

| Pacote | Quando usar | Não usar para | Frase curta |
|---|---|---|---|
| **CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST** | qualquer feature/código novo | prompts só de design/mockup sem código | "Antes de codificar, lê e aplica CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md." |
| **SECURITY_DEFENSIVE_CORE** | detection, hardening, IR, forensics, threat-intel, cloud/container/IAM/crypto defensivo | ataque, pentest, exploit | "Usa SECURITY_DEFENSIVE_CORE (explicit_only), 1-3 skills do INDEX como checklist." |
| **SECURITY_AI_AGENT_DEFENSE** | prompt injection, LLM guardrails, output validation de agentes | tarefas não-IA | "Usa SECURITY_AI_AGENT_DEFENSE + agentic-actions-auditor + mcp-scan." |
| **SECURITY_REVIEW_SUPPORT** | review de API/auth/RBAC, CI/CD, dependências, config, threat model | build de UI/marketing | "Usa SECURITY_REVIEW_SUPPORT + api-security-best-practices + insecure-defaults." |
| **SECURITY_LAB_DUAL_USE_MANUAL_ONLY** | só lab/sandbox autorizado (dual-use/ofensivo) | qualquer auto-routing | "Usa SECURITY_LAB_DUAL_USE_MANUAL_ONLY só como checklist manual, com aprovação." |
| **skill-router** | tarefa multi-domínio, risco de empilhar skills | micro-edit óbvio | "Corre o skill-router: classifica a tarefa e escolhe no máx 3 skills." |
| **cc-skill-security-review** | baseline AppSec genérico antes de PASS | frontend puro | "Aplica cc-skill-security-review antes de declarar PASS." |
| **api-security-best-practices** | endpoints, auth, rate limit, input validation | sem superfície API | "Usa api-security-best-practices neste endpoint." |
| **insecure-defaults** (Trail of Bits) | configs fail-open, secrets hardcoded, defaults permissivos | — | "Corre insecure-defaults nas configs/env." |
| **supply-chain-risk-auditor** (Trail of Bits) | nova dependência, lockfile, package.json | — | "Corre supply-chain-risk-auditor antes de adicionar a dep." |
| **verification-before-completion** (superpowers) | antes de dizer 'feito'/PASS | — | "Aplica verification-before-completion: prova antes de afirmar." |
| **VIDEO_RENDER_HYPERFRAMES** | vídeo a partir de HTML (HeyGen HyperFrames): composições, GSAP/three/lottie, captions, voiceover, audio-reactive | tarefas sem vídeo | "Usa VIDEO_RENDER_HYPERFRAMES (explicit_only): lê INDEX, abre a SKILL relevante. CLI `hyperframes` à parte." |
| **profile BASS_SITE** | trabalho no site BASS (Next.js) | outros projetos | "Usa o profile BASS_SITE." |
| **profile ARCANEX_DASHBOARD** | dashboard privado ARCANEX (multi-tenant, RBAC) | site público | "Usa o profile ARCANEX_DASHBOARD (segurança primeiro)." |
| **profile ARCANEX_UI** | frontend ARCANEX (Astro + React + GSAP + Lenis, 3D Spline) | dashboard privado / backend | "Usa o profile ARCANEX_UI." |
| **profile ARCANEX_CRO** | marketing/conversão ARCANEX (copy, CTAs, landing) | runtime/dashboard | "Usa o profile ARCANEX_CRO." |
| **profile OPENCLAW_RUNTIME** | runtime/gateway OpenClaw (TS/Node) | UI/marketing | "Usa o profile OPENCLAW_RUNTIME, evidence-first." |
| **profile KAIROS_RUNTIME** | Kairos: Solana sniper/trading bot com IA (monorepo Node 20+ TS) | sites/UI/marketing | "Usa o profile KAIROS_RUNTIME, evidence-first, sem fundos sem aprovação." |

> Catálogo completo de packs (1-24) em `~/.claude/skills/skill-router/SKILL_PACKS.md`: PLANNING_STRATEGY · PATCH_EXECUTION · DEBUG_FORENSICS · SECURITY_REVIEW · WEBSITE_BUILD · MOTION_ANIMATION · BACKEND_DATA · MARKETING_COPY_CRO · ADS_SOCIAL_CREATIVE · SEO_GEO_CONTENT · AI_ASSET_GENERATION · DOCS_REPORTS_PDF · DEPLOY_RELEASE · AGENT_SYSTEMS · BLOCKCHAIN_SOLANA · MEMORY_CONTEXT · ARCANEX_DASHBOARD · PREMIUM_DESIGN_POLISH · SECURITY_TOOLS_CATALOG · … · VIDEO_RENDER_HYPERFRAMES (#24).

## 4. Frases prontas para prompts

### Construção segura de código
"Antes de codificar, lê e aplica `~/.claude/CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md`. Estas regras são obrigatórias durante a construção, não apenas na auditoria final. Cada feature nova deve incluir segurança, validação de input, autorização/ownership quando aplicável, tratamento de erro, logs seguros, tipos TypeScript e testes mínimos. Não faças deploy, commit ou push sem autorização. Cria backup antes de editar. Se não houver prova no código, diz `não confirmado`."

### Segurança defensiva normal
"Usa SECURITY_DEFENSIVE_CORE de forma explícita. Lê apenas o INDEX.md do pacote, escolhe no máximo 1-3 skills defensivas relevantes e usa-as como checklist. Não uses SECURITY_LAB_DUAL_USE_MANUAL_ONLY."

### Defesa de agentes IA
"Usa SECURITY_AI_AGENT_DEFENSE, agentic-actions-auditor, mcp-scan e security-review para verificar prompt injection, tool abuse, RAG poisoning, MCP risk, permissões excessivas, output validation, logs e HITL gates."

### Auditoria de código
"Usa SECURITY_REVIEW_SUPPORT, api-security-best-practices, insecure-defaults, supply-chain-risk-auditor e verification-before-completion. Primeiro inspeciona ficheiros reais, configs e testes; depois conclui; depois propõe patch."

### Red team controlado / lab
"Usa SECURITY_LAB_DUAL_USE_MANUAL_ONLY apenas como checklist manual em localhost/staging/lab autorizado. Não executar payloads destrutivos, C2, phishing real, credential theft, malware, persistência, exfiltração ou scanning externo sem aprovação explícita."

### Projeto visual/design
Packs/skills: WEBSITE_BUILD (frontend-design, impeccable), PREMIUM_DESIGN_POLISH (impeccable → high-end-visual-design fallback → huashu-design mockups), ui-ux-pro-max, interface-design, site-architecture, publishing-astro-websites, web-design-guidelines (Vercel), vercel-react-best-practices.
"Usa as skills de design/polish apenas depois de confirmar o mockup/screenshot fonte de verdade. Não redesenhar por gosto. Clonar a direção aprovada."

### Vídeo a partir de HTML (HyperFrames)
"Usa VIDEO_RENDER_HYPERFRAMES (library explicit_only em `~/.claude/skill-library/hyperframes`). Lê o INDEX.md, abre a SKILL.md relevante (core `hyperframes` + gsap/three/tailwind/lottie/animejs/waapi/css-animations/website-to-hyperframes). Markdown only: scripts/código do repo NÃO importados nem corridos. Render real precisa da CLI `hyperframes` (npm/bun), instalada à parte com aprovação."

### Vídeo IA / asset generation
"Usa ai-image-generation (inference.sh CLI) para imagens, remotion-best-practices para vídeo em React, seedance-20 para Seedance 2.0. Geração de imagem/vídeo só com pedido explícito; tokens/MCPs (nano-banana, higgsfield) DEFAULT-DENY."

### Backend / base de dados
"Usa supabase-postgres-best-practices para schema/queries/RLS Postgres. MCP Supabase: `list_tables` antes de mudar schema; `query_logs` (antes: `get_logs`)/`get_advisors` antes de alterar; `apply_migration` com cuidado (vai direto ao projeto remoto). Local-first quando houver CLI."

### BASS
"Usa o profile BASS_SITE. Fonte de verdade: mockup aprovado manda no design, moedas oficiais mandam na identidade visual, PDFs mandam no conteúdo/funcionamento. Não inventar dados; usar A DEFINIR ou Em validação técnica quando não houver prova."

### ARCANEX
"Usa o profile ARCANEX_DASHBOARD / ARCANEX_UI / ARCANEX_CRO conforme o caso. Segurança primeiro, dashboard separado do site público, permissões opt-in, logs sem dados sensíveis, e validação real por screenshots/testes."

### OpenClaw
"Usa OPENCLAW_RUNTIME apenas com evidence-first. Não mexer em WhatsApp, Meta, gateway, env, keys, plist, models ou runtime sem autorização explícita. Primeiro inspecionar, depois concluir, depois propor."

### Kairos (Solana trading bot)
"Usa o profile KAIROS_RUNTIME, evidence-first. Monorepo Node 20+ TS. Nada de transações/fundos reais, keys ou env sem autorização explícita. Inspecionar → concluir → propor → só depois agir."

## 5. Plugins instalados (31; antes: 26)

| Plugin | Versão | Para que serve | Quando chamar |
|---|---|---|---|
| superpowers | 5.0.2 | workflows: brainstorm, TDD, debug, verification | tarefa multi-passo / antes de PASS |
| code-review | — | comando `/code-review` (o `/security-review` é built-in do Claude Code, não deste plugin) | rever diff/branch |
| pr-review-toolkit | — | code-reviewer, silent-failure-hunter, type-design | rever PR |
| differential-review (ToB) | 1.0.0 | security review focada no diff | qualquer diff JS/TS |
| audit-context-building (ToB) | 1.1.0 | contexto arquitetural profundo | auditoria grande |
| insecure-defaults (ToB) | 1.0.0 | configs fail-open / secrets | rever config/env |
| supply-chain-risk-auditor (ToB) | 1.0.0 | risco de dependências | nova dep |
| static-analysis (ToB) | 1.2.0 | semgrep + codeql + SARIF | scan estático |
| semgrep-rule-creator (ToB) | 1.2.0 | criar regras semgrep | regra custom |
| entry-point-analyzer (ToB) | 1.0.0 | entry points state-changing | audit smart-contract |
| variant-analysis (ToB) | 1.0.0 | variantes de bug | audit |
| constant-time-analysis (ToB) | 0.1.0 | timing leaks cripto | código de assinatura/hash |
| agentic-actions-auditor (ToB) | 1.2.0 | audit de GitHub Actions / agentes | CI/CD, agentes |
| building-secure-contracts (ToB) | 1.0.1 | scanners smart-contract (Solana, Cairo, Cosmos, TON…) | blockchain |
| second-opinion (ToB) | 1.6.0 | cross-check via Codex | decisão difícil |
| burpsuite-project-parser (ToB) | 1.0.0 | parsing de projetos Burp | DFIR web |
| security-guidance | 2.0.9 | hooks (SessionStart, UserPromptSubmit, PostToolUse Edit/Write/Bash, Stop, SubagentStop): avisos regex + revisão LLM do diff + revisão no commit | sempre ativo |
| context7-plugin | 1.0.0 | docs atuais de libs/frameworks | usar lib externa |
| claude-mem | 10.6.2 | memória persistente cross-session | retomar trabalho |
| frontend-design | — | build UI distinto | dev frontend |
| feature-dev | — | feature end-to-end | dev feature |
| agent-sdk-dev | — | apps Agent SDK | build SDK app |
| figma | 2.2.120 | design / code connect | UI a partir de Figma |
| typescript-lsp | 1.0.0 | LSP TypeScript | navegação/types |
| i18n-expert | 1.0.0 | i18n/l10n (i18next, locales) | internacionalização |
| caveman | — | output curto/comprimido | conforme tarefa |
| claude-security | 0.12.0 | scan de segurança (codebase / alterações / patches) com agentes verificadores | só a pedido: `/claude-security` |
| coderabbit | 1.1.1 | review CodeRabbit (CLI) + autofix de threads de PR | fim de tarefa de código (rules/coderabbit-review.md) |
| upstash | 1.2.5 | MCP + skills para produtos Upstash (Redis, QStash, Workflow, Box, Vector, Search…) | usar Upstash |
| fast-jev-compaction | 0.3.0 | compactação de sessão guiada por Jev (hooks) | automático |
| i-have-adhd | 0.3.0 | formata o output para leitor com ADHD (ação primeiro, passos numerados…) | hook de sessão |

> 13 dos 31 plugins são Trail of Bits (ToB) — auditoria/segurança. Fonte: `~/.claude/plugins/installed_plugins.json`.

## 6. MCPs

### 6a. Configurados localmente em `~/.claude.json` (9; antes: 7) — secrets NÃO impressos

| MCP | Para que serve | Risco | Quando usar |
|---|---|---|---|
| playwright | screenshots, testes visuais | MÉDIO (browser exec) | prova visual frontend |
| nano-banana-mcp | geração de imagem (Gemini) | MÉDIO (token persiste) | só com pedido explícito |
| higgsfield | geração de vídeo | MÉDIO (OAuth remoto) | só com pedido explícito |
| stitch | geração de ecrãs (Google) | BAIXO-MÉDIO | mockups |
| motion | animação | MÉDIO (npx tarball remoto) | só se necessário |
| blender | 3D / render | **ALTO** (execute_blender_code = Python arbitrário) | só com aprovação por sessão |
| helius | Solana (wallet, tx, assets) | **ALTO** (transferSol/transferToken/etc. = fundos) | DEFAULT-DENY; aprovação por sessão |
| context7 | docs atualizadas de libs | BAIXO (classificação de 6b) | preferir a web search p/ libs |
| b2 | Backblaze B2 (buckets, objetos, chaves) | **por classificar** (tools de escrita/apagamento: b2_delete_bucket, s3_put_object, s3_delete_object, b2_create_key…) | por decidir |

> Por projeto (`~/.claude.json` → projects), 2026-10-05: bass-site → `supabase` · krea-video-lab → `krea-ai` · /private/tmp/core-ai → `helius`.

### 6b. MCPs bundled por plugin / conectores de sessão (NÃO em ~/.claude.json) — confirmados ativos

| MCP / conector | Para que serve | Risco | Nota |
|---|---|---|---|
| supabase | DB, auth, edge functions, migrations | **ALTO** (apply_migration vai ao remoto; execute_sql) | confirmar `list_tables` antes de mexer |
| vercel | deploy, logs, projetos, docs | MÉDIO-ALTO (deploy_to_vercel) | deploy só com aprovação |
| crypto.com exchange | market data (orderbook, trades, candles) | BAIXO (read-only) | dados de mercado |
| figma (conector) | design context, variables, screenshot | BAIXO-MÉDIO | leitura de design |
| 21st-dev magic | componentes UI / logos | MÉDIO | gerar componentes |
| context7 | docs atualizadas de libs | BAIXO | preferir a web search p/ libs (desde 2026-10-05 também configurado em 6a) |
| claude-mem (mcp-search) | memória/observações cross-session | BAIXO | recall de trabalho anterior |
| second-opinion (codex) | cross-check via Codex | BAIXO-MÉDIO | decisão difícil |
| scheduled-tasks | tarefas agendadas | MÉDIO | criar/listar routines |
| mcp-registry | descoberta de conectores | BAIXO | sugerir MCPs |
| Claude_Preview | dev server + preview no browser | MÉDIO | verificação previewable |
| marketing (plugin) | ahrefs, amplitude, canva, hubspot, klaviyo, notion, similarweb, slack, supermetrics | VARIÁVEL (OAuth por serviço) | só com `authenticate` explícito |

> Observado na sessão Desktop de 2026-10-05 e não listado acima: Snyk Security (code/SCA/container/IaC/SBOM/AIBOM; autenticação por confirmar), Claude Docs, computer-use, claude-in-chrome, Claude_Browser (browser embutido; equivalente ao antigo "Claude_Preview"), terminal, visualize, Claude_Code_iOS_Simulator, ccd_* (diretório, sessões, sidebar, janela), b2 (ver 6a). Plugins com MCP a pedir autenticação nesta sessão: data (atlassian, bigquery, hex; `definite` falhou com ENDPOINT_NOT_FOUND), design (asana, intercom, linear), marketing (+ amplitude-eu e figma), upstash, higgsfield. Não observados nesta sessão: crypto.com exchange e 21st-dev magic (estado por confirmar).

> Regra: tudo em 6b que escreva/deploy/transfira (supabase migrations, vercel deploy, helius transfer, blender exec) = **DEFAULT-DENY**, aprovação por sessão. Read-only (crypto.com, context7, mcp-registry) é seguro.

## 7. Cibersegurança importada (mukul975/Anthropic-Cybersecurity-Skills, Apache-2.0)
- Analisadas: **754** · Importadas: **651** (scripts/ excluídos) · Quarentena: **103**. *(inalterado desde 2026-05-30; MANIFEST.tsv = 652 linhas com header; reverificado 2026-10-05: contagens idênticas)*
- Importadas por pacote: DEFENSIVE_CORE **492** · REVIEW_SUPPORT **60** · AI_AGENT_DEFENSE **1** · LAB **98** *(verificado por contagem de diretórios)*.
- Quarentena revista (QUARANTINE_REVIEW_REPORT.md): **A=63** promovíveis defensivas · **B=6** explicit-only (redação prévia) · **C=34** lab-only · **D=0**.
- **SECURITY_LAB_DUAL_USE_MANUAL_ONLY é manual-only e NUNCA auto-route.** Library não-discoverable; carregar por path. Cada pacote tem `INDEX.md`.

**Mais úteis por categoria** (exemplos, não exaustivo):

- **API/Web security** (REVIEW_SUPPORT): detecting-api-enumeration-attacks, detecting-shadow-api-endpoints, detecting-broken-object-property-level-authorization, implementing-api-gateway-security-controls, implementing-api-rate-limiting-and-throttling, implementing-api-schema-validation-security, implementing-api-key-security-controls, implementing-web-application-logging-with-modsecurity.
- **Secrets/Supply chain** (REVIEW_SUPPORT + CORE): analyzing-sbom-for-supply-chain-vulnerabilities, detecting-typosquatting-packages-in-npm-pypi, implementing-sigstore-for-software-signing, implementing-code-signing-for-artifacts, detecting-aws-credential-exposure-with-trufflehog, implementing-secrets-management-with-vault, implementing-hashicorp-vault-dynamic-secrets.
- **Cloud/Container** (CORE): auditing-aws-s3-bucket-permissions, auditing-gcp-iam-permissions, auditing-cloud-with-cis-benchmarks, auditing-kubernetes-cluster-rbac, detecting-container-escape-with-falco-rules, hardening-docker-containers-for-production, hardening-docker-daemon-configuration, performing-kubernetes-cis-benchmark-with-kube-bench, scanning-docker-images-with-trivy.
- **AI agent security** (AI): implementing-llm-guardrails-for-security; (quarentena A) detecting-ai-model-prompt-injection-attacks.
- **Logging/Audit/Access control** (CORE): analyzing-windows-event-logs-in-splunk, building-detection-rule-with-splunk-spl, analyzing-dns-logs-for-exfiltration, configuring-multi-factor-authentication-with-duo, building-role-mining-for-rbac-optimization, implementing-privileged-access-management-with-cyberark, deploying-osquery-for-endpoint-monitoring.
- **Incident response** (CORE): building-incident-response-playbook, building-incident-response-dashboard, building-incident-timeline-with-timesketch, collecting-volatile-evidence-from-compromised-host, performing-log-analysis-for-forensic-investigation, performing-memory-forensics-with-volatility3, validating-backup-integrity-for-recovery.
- **Lab/manual-only** (LAB — só com aprovação, nunca auto): penetration-testing, red-teaming, exploit, C2 (Sliver/Havoc), BloodHound, phishing-sim, malware analysis de samples vivos. NÃO listar/usar sem autorização.

## 8. O que NUNCA pedir em automático
C2 (Sliver/Havoc/Covenant) · phishing real · execução de malware · credential theft · privilege escalation real · scanning externo · exploit contra terceiros · payload destrutivo · exfiltração · bypass de autenticação em sistemas não autorizados · MITM/SSL-strip · BGP hijack · DLL hijack / msfvenom. Tudo isto → SECURITY_LAB_DUAL_USE_MANUAL_ONLY, só lab autorizado.
**Também DEFAULT-DENY (MCP, exige aprovação por sessão):** transferências Solana (helius transferSol/transferToken), `blender execute_blender_code`, `supabase apply_migration`/`execute_sql` em remoto, `vercel deploy_to_vercel`.

## 9. Mini-router rápido

| Se a tarefa for... | Usa estes pacotes | Frase curta |
|---|---|---|
| "vou implementar uma feature" | BUILD_RULES_SECURITY_FIRST + SECURITY_REVIEW_SUPPORT + verification-before-completion | "Feature nova: aplica build rules security-first antes de codificar." |
| "vou criar uma API" | api-security-best-practices + insecure-defaults + DEFENSIVE_CORE | "API nova: api-security + insecure-defaults + defensive core." |
| "vou mexer numa BD Postgres/Supabase" | supabase-postgres-best-practices + MCP supabase (list_tables/advisors primeiro) | "DB: postgres-best-practices + list_tables + advisors antes de migrar." |
| "vou ligar agentes/MCP" | AI_AGENT_DEFENSE + mcp-scan + agentic-actions-auditor | "Agentes/MCP: AI agent defense + mcp-scan + agentic-actions-auditor." |
| "vou lançar site público" | SECURITY_REVIEW + rate limit + WAF/Cloudflare checklist + logging | "Site público: security review + rate limit + WAF + logging." |
| "vou rever PR/código" | differential-review + supply-chain-risk-auditor + verification | "Rever PR: differential-review + supply-chain + verification." |
| "vou gerar imagem/vídeo" | AI_ASSET_GENERATION (ai-image-generation / remotion / seedance-20) | "Asset IA: ai-image-generation; vídeo React: remotion. Tokens DEFAULT-DENY." |
| "vou testar staging meu" | LAB_DUAL_USE_MANUAL_ONLY (só checklist) | "Staging meu: lab manual-only, checklist, depois pedir aprovação." |
| "vou fazer design BASS" | BASS_SITE + frontend-design + PREMIUM_DESIGN_POLISH | "Design BASS: profile BASS_SITE + frontend-design + impeccable." |
| "vou mexer em OpenClaw" | OPENCLAW_RUNTIME + evidence-first | "OpenClaw: profile + evidence-first, sem side effects no runtime." |
| "vou mexer no Kairos" | KAIROS_RUNTIME + evidence-first | "Kairos: profile + evidence-first, sem fundos/keys sem aprovação." |
| "vou instalar skills novas" | find-skills (`npx skills add <repo> -s <skill> -g -y`) | "Instala global (-g) p/ ~/.claude/skills; verifica nome com -l antes." |

## 10. Template base para qualquer prompt técnico

```
Tarefa:
[descrever]

Fonte de verdade:
[ficheiros/screenshots/logs/configs]
~/.claude/CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md (quando houver código/feature/backend/API/auth/dados/testes)

Skills/pacotes permitidos:
[lista]

Proibido:
[lista — default: ofensivo/lab sem aprovação; MCP write/deploy/transfer sem aprovação]

Processo:
0. aplicar build rules security-first
1. inspeção real
2. diagnóstico
3. plano
4. patch mínimo
5. testes
6. segurança
7. evidência
8. relatório PASS/PARTIAL/BLOCKED/FAIL
```

## 11. Localização dos ficheiros
- Inventário completo: `~/.claude/CLAUDE_CODE_CAPABILITIES_INVENTORY.md`
- Skills routable: `~/.claude/skills/` (285: 101 reais + 184 symlinks) · loja universal partilhada: `~/.agents/skills/` (243; 95 symlinkadas para `~/.claude/skills/`, 65 não expostas ao Claude Code)
- Library cibersegurança: `~/.claude/security-skill-library/anthropic-cybersecurity/`
- Indexes por pacote: `~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_*/INDEX.md`
- Relatório de quarentena: `~/.claude/security-skill-library/anthropic-cybersecurity/QUARANTINE_REVIEW_REPORT.md`
- Router/packs: `~/.claude/skills/skill-router/SKILL_PACKS.md` · `skills-registry.json` · `profiles.json` (6 profiles)
- Regras de construção segura: `~/.claude/CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md`
- Library HyperFrames (vídeo): `~/.claude/skill-library/hyperframes/` (15 skills) · `INDEX.md` · pack VIDEO_RENDER_HYPERFRAMES (#24)
- Plugins instalados: `~/.claude/plugins/installed_plugins.json` · marketplaces: `~/.claude/plugins/marketplaces/`
- MCPs locais: `~/.claude.json` (chave `mcpServers`)
- Este ficheiro: `~/.claude/CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md`

## 12. Skills adicionadas nesta revisão (2026-06-02)
Instaladas via `npx skills add … -g -y` (loja universal `~/.agents/skills/`, symlinked p/ Claude Code). Socket 0 alertas; correm com permissões totais — rever antes do 1º uso:

| Skill | Repo | Para que serve |
|---|---|---|
| find-skills | vercel-labs/skills | descobrir/instalar skills (`npx skills`) |
| vercel-react-best-practices | vercel-labs/agent-skills | performance React/Next.js (Vercel Eng.) |
| web-design-guidelines | vercel-labs/agent-skills | review UI vs Web Interface Guidelines (a11y/UX) |
| remotion-best-practices | remotion-dev/skills | criação de vídeo em React (Remotion) |
| ai-image-generation | inference-sh-skills/skills | gerar imagens (FLUX, GPT-Image, Gemini, Seedream…) via inference.sh CLI |
| supabase-postgres-best-practices | supabase/agent-skills | otimização/best-practices Postgres |

## 13. Última atualização
2026-06-02 · Claude Code **2.1.160** · RTK ativo · CAVEMAN mode · sem secrets · read-only das fontes (exceto +6 skills instaladas explicitamente).
Deltas vs 2026-05-30: +6 skills (§12) · profiles 3→**6** (+ARCANEX_UI, ARCANEX_CRO, KAIROS_RUNTIME) · §6b MCPs bundled/conectores (supabase, vercel, crypto.com, figma, 21st, context7, marketing suite) documentados · ~186 skills routable · lib cibersegurança e packs 1-24 inalterados.

2026-10-05 · atualização factual (só contagens/versões/listas/estado; §8 e restante política inalteradas) · Claude Code **2.1.289** · RTK 0.49.0 · GSD 1.42.3. Deltas vs 2026-06-02: skills routable ~186→**285** · `~/.agents/skills` 103→**243** · plugins 26→**31** (+claude-security, coderabbit, upstash, fast-jev-compaction, i-have-adhd) · MCP locais 7→**9** (+context7, b2) · versões: security-guidance 2.0.2→2.0.9, figma 2.2.12→2.2.120 · tool §4 get_logs→query_logs · packs 1-24, profiles 6, lib cibersegurança (651 / quarentena 103) inalterados. Versão anterior: `CLAUDE_CODE_SKILLS_PROMPT_REFERENCE.md.archived-2026-10-05`.
