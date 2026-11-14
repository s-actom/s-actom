# Claude Code Capabilities Inventory

> **Atualização factual 2026-10-05** — corrigidas contagens, listas, caminhos e estados desfasados (fonte: inventário read-only de 2026-10-05). Política, decisões e conteúdo histórico (listas de quarentena e dual-use, guias de uso, backups) NÃO foram alterados. Versão anterior preservada em `~/.claude/CLAUDE_CODE_CAPABILITIES_INVENTORY.md.archived-2026-10-05`. Resumo das correções no fim ("Registo de atualizações").

## Generated
- Date/time: 2026-05-30 11:09:08 CEST
- Machine/user: goncaloferro@quiet-vanguard (no secrets)
- Claude Code version: 2.1.156
- RTK: 0.39.0
- Generator: controlled install of mukul975/Anthropic-Cybersecurity-Skills @ `0f429d0f96ee70d2a6c259c4ecc6c6e18e0d23ff`
- Atualizado em 2026-10-05: Claude Code 2.1.289 · RTK 0.49.0 · GSD 1.42.3 (os valores acima são do snapshot de 2026-05-30)

## Skill Roots Inspected
| Root | Discoverable (Claude Code) | Top-level skills |
|---|---|---|
| ~/.claude/skills | yes | 285 com SKILL.md (101 reais + 184 symlinks: 95 → ~/.agents/skills, 89 → ~/.claude/skills/ecc) · antes: 98 |
| ~/.agents/skills | no (não é raiz do Claude Code; das 243: 95 chegam por symlink, 83 têm cópia homónima própria em ~/.claude/skills e 65 não estão expostas) · antes: yes | 243 (211 reais + 32 symlinks → ~/.codex/skills) · antes: 96 |
| ~/.codex/skills | no (não é raiz do Claude Code; 19 das 40 não estão expostas ao Claude) · antes: yes | 40 (+ pasta `.system` sem SKILL.md) · antes: 6 |
| ~/.claude/skills/ecc | **NO** (contentor; só as 89 expostas por symlink no topo de ~/.claude/skills são descobertas) | 197 cópias reais ECC |
| ~/.claude/.agents/skills | **NO** (não é raiz do Claude Code; ex.: `deep-research`, `strategic-compact` não aparecem na lista de skills) | 33 |
| ~/.claude/security-skill-library/anthropic-cybersecurity | **NO (by design)** | 651 (curated, explicit/manual) — verificado 2026-10-05, inalterado |
| ~/.claude/skill-library/hyperframes | **NO (by design)** | 15 (md-only, explicit) — verificado 2026-10-05, inalterado |

> Discovery is NOT recursive over ~/.claude (proven: gsd-user-files-backup/skills/skill-router is not double-listed). The new library lives outside any discovery root, so its 651 skills are NEVER auto-activated.

## Installed Skill Packages
| Package | Purpose | Auto-routing | Manual/explicit only | Skills | Path / source |
|---|---|---|---|---|---|
| (1-18 existing packs) | capability packs (planning, patch, security-review, website, etc.) | per skill-router | n/a | — | ~/.claude/skills/skill-router/SKILL_PACKS.md |
| SECURITY_TOOLS_CATALOG (#19) | canonical security tooling registry | n/a | n/a | — | SKILL_PACKS.md |
| **SECURITY_DEFENSIVE_CORE (#20)** | blue-team defense (detect/IR/forensics/hardening) | NO | explicit_only | 492 | ~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_DEFENSIVE_CORE |
| **SECURITY_AI_AGENT_DEFENSE (#21)** | AI/LLM agent defense | NO | explicit_only | 1 (+1 quarantine) | ~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_AI_AGENT_DEFENSE |
| **SECURITY_REVIEW_SUPPORT (#22)** | code/API/CI-CD/dep review support | NO | explicit_only | 60 | ~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_REVIEW_SUPPORT |
| **SECURITY_LAB_DUAL_USE_MANUAL_ONLY (#23)** | offensive/dual-use | **NEVER** | **manual_lab_only + owner approval** | 98 (+17 quarantine) | ~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| **VIDEO_RENDER_HYPERFRAMES (#24)** | HTML→MP4 video (HeyGen HyperFrames) | NO | explicit_only | 15 (md-only) | ~/.claude/skill-library/hyperframes |

## All Skills
Complete per-skill detail lives in machine-readable form:
- Existing discoverable skills: listed below by root (names are authoritative; routed metadata in `skills-registry.json`).
- Imported cybersecurity skills (651): full table in `~/.claude/security-skill-library/anthropic-cybersecurity/MANIFEST.tsv` and per-package `INDEX.md` (name, subdomain, scan severity, description, path, mode).

### Discoverable skills — ~/.claude/skills (285 com SKILL.md; antes: 98)
Reais (101): agency-commander, ai-image-prompts, api-security-best-practices, arcanex-dashboard-design, arcanex-dashboard-security, blender-product-polish, blender-threejs-export, cc-skill-security-review, code-review-skill, frontend-design, gsd-add-tests, gsd-ai-integration-phase, gsd-audit-fix, gsd-audit-milestone, gsd-audit-uat, gsd-autonomous, gsd-capture, gsd-cleanup, gsd-code-review, gsd-complete-milestone, gsd-config, gsd-debug, gsd-discuss-phase, gsd-docs-update, gsd-eval-review, gsd-execute-phase, gsd-explore, gsd-extract-learnings, gsd-fast, gsd-forensics, gsd-graphify, gsd-health, gsd-help, gsd-import, gsd-inbox, gsd-ingest-docs, gsd-manager, gsd-map-codebase, gsd-milestone-summary, gsd-mvp-phase, gsd-new-milestone, gsd-new-project, gsd-ns-context, gsd-ns-ideate, gsd-ns-manage, gsd-ns-project, gsd-ns-review, gsd-ns-workflow, gsd-pause-work, gsd-phase, gsd-plan-phase, gsd-plan-review-convergence, gsd-pr-branch, gsd-profile-user, gsd-progress, gsd-quick, gsd-resume-work, gsd-review, gsd-review-backlog, gsd-secure-phase, gsd-settings, gsd-ship, gsd-sketch, gsd-spec-phase, gsd-spike, gsd-stats, gsd-surface, gsd-thread, gsd-ui-phase, gsd-ui-review, gsd-ultraplan-phase, gsd-undo, gsd-update, gsd-validate-phase, gsd-verify-work, gsd-workspace, gsd-workstreams, helius, helius-dflow, helius-phantom, impeccable, interface-design, memory, meteora-sendai, nano-banana-pro-prompts-recommend, owasp-security, perfect-loop, polyhaven-studio-setup, publishing-astro-websites, pumpfun-sendai, raydium-sendai, seedance-20, skill-router, solana-dev, solana-dev-skill, svm, test-probe, turntable, typescript-expert, ui-ux-pro-max, VibeSec-Skill
Symlinks → ~/.agents/skills (95): ab-test-setup, ad-creative, ai-film-director, ai-image-generation, ai-seo, analytics-tracking, brandkit, churn-prevention, cold-email, competitor-alternatives, content-strategy, copy-editing, copywriting, design-taste-frontend, email-sequence, find-skills, form-cro, free-tool-strategy, full-output-enforcement, geo, geo-audit, geo-brand-mentions, geo-citability, geo-compare, geo-content, geo-crawlers, geo-llmstxt, geo-platform-optimizer, geo-proposal, geo-prospect, geo-report, geo-report-pdf, geo-schema, geo-technical, gpt-taste, gsap-core, gsap-frameworks, gsap-performance, gsap-plugins, gsap-react, gsap-scrolltrigger, gsap-timeline, gsap-utils, higgsfield, higgsfield-generate, higgsfield-product-photoshoot, higgsfield-soul-id, higgsfield-video-explainer, high-end-visual-design, huashu-design, image-to-code, imagegen-frontend-mobile, imagegen-frontend-web, industrial-brutalist-ui, launch-strategy, lead-magnets, marketing-ideas, marketing-psychology, minimalist-ui, onboarding-cro, page-cro, paid-ads, paywall-upgrade-cro, popup-cro, pricing-strategy, product-marketing-context, programmatic-seo, redesign-existing-projects, referral-program, remotion-best-practices, revops, sales-enablement, schema-markup, seo, seo-audit, seo-competitor-pages, seo-content, seo-geo, seo-hreflang, seo-images, seo-local, seo-page, seo-plan, seo-programmatic, seo-schema, seo-sitemap, seo-technical, signup-flow-cro, site-architecture, social-content, stitch-design-taste, supabase-postgres-best-practices, typesafe-ai, vercel-react-best-practices, web-design-guidelines
Symlinks → ~/.claude/skills/ecc (89): agent-architecture-audit, agent-harness-construction, agentic-engineering, ai-first-engineering, ai-regression-testing, angular-developer, api-connector-builder, api-design, article-writing, automation-audit-ops, autonomous-loops, backend-patterns, brand-voice, clickhouse-io, coding-standards, content-engine, cost-aware-llm-pipeline, cpp-coding-standards, cpp-testing, dart-flutter-patterns, dashboard-builder, data-throughput-accelerator, database-migrations, defi-amm-security, deployment-patterns, django-patterns, django-security, docker-patterns, e2e-testing, error-handling, eval-harness, evm-token-decimals, exa-search, fal-ai-media, fastapi-patterns, frontend-design-direction, frontend-patterns, github-ops, golang-patterns, golang-testing, hookify-rules, java-coding-standards, jpa-patterns, knowledge-ops, kotlin-patterns, kotlin-testing, laravel-patterns, laravel-security, latency-critical-systems, liquid-glass-design, llm-trading-agent-security, make-interfaces-feel-better, manim-video, market-research, mcp-server-patterns, motion-ui, mysql-patterns, nestjs-patterns, nodejs-keccak256, parallel-execution-optimizer, postgres-patterns, prisma-patterns, production-audit, prompt-optimizer, python-patterns, python-testing, quarkus-patterns, quarkus-security, react-patterns, react-performance, react-testing, remotion-video-creation, research-ops, rust-patterns, rust-testing, search-first, security-bounty-hunter, skill-scout, springboot-patterns, springboot-security, swift-concurrency-6-2, swiftui-patterns, tdd-workflow, team-builder, token-budget-advisor, ui-to-vue, verification-loop, video-editing, workspace-surface-audit
Pastas sem SKILL.md (não são skills): .trash, ecc, synced

### Skills — ~/.agents/skills (243; antes: 96) — raiz NÃO descoberta pelo Claude Code, ver tabela acima
Reais (211): ab-test-setup, ad-creative, agentic-engineering, ai-film-director, ai-first-engineering, ai-image-generation, ai-seo, analytics-tracking, brandkit, cavecrew, caveman, caveman-commit, caveman-compress, caveman-help, caveman-review, caveman-stats, churn-prevention, cold-email, competitor-alternatives, compress, connections-optimizer, content-strategy, continuous-agent-loop, copy-editing, copywriting, dashboard-builder, design-taste-frontend, dotnet-patterns, email-sequence, find-skills, form-cro, foundation-models-on-device, free-tool-strategy, frontend-implementation-review, full-output-enforcement, geo, geo-audit, geo-brand-mentions, geo-citability, geo-compare, geo-content, geo-crawlers, geo-llmstxt, geo-platform-optimizer, geo-proposal, geo-prospect, geo-report, geo-report-pdf, geo-schema, geo-technical, gpt-taste, gsap-core, gsap-frameworks, gsap-performance, gsap-plugins, gsap-react, gsap-scrolltrigger, gsap-timeline, gsap-utils, gsd-add-backlog, gsd-add-phase, gsd-add-tests, gsd-add-todo, gsd-ai-integration-phase, gsd-analyze-dependencies, gsd-audit-fix, gsd-audit-milestone, gsd-audit-uat, gsd-autonomous, gsd-check-todos, gsd-cleanup, gsd-code-review, gsd-code-review-fix, gsd-complete-milestone, gsd-debug, gsd-discuss-phase, gsd-do, gsd-docs-update, gsd-eval-review, gsd-execute-phase, gsd-explore, gsd-extract_learnings, gsd-fast, gsd-forensics, gsd-from-gsd2, gsd-graphify, gsd-health, gsd-help, gsd-import, gsd-inbox, gsd-ingest-docs, gsd-insert-phase, gsd-intel, gsd-join-discord, gsd-list-phase-assumptions, gsd-list-workspaces, gsd-manager, gsd-map-codebase, gsd-milestone-summary, gsd-new-milestone, gsd-new-project, gsd-new-workspace, gsd-next, gsd-note, gsd-pause-work, gsd-plan-milestone-gaps, gsd-plan-phase, gsd-plant-seed, gsd-pr-branch, gsd-profile-user, gsd-progress, gsd-quick, gsd-reapply-patches, gsd-remove-phase, gsd-remove-workspace, gsd-research-phase, gsd-resume-work, gsd-review, gsd-review-backlog, gsd-scan, gsd-secure-phase, gsd-session-report, gsd-set-profile, gsd-settings, gsd-ship, gsd-sketch, gsd-sketch-wrap-up, gsd-spec-phase, gsd-spike, gsd-spike-wrap-up, gsd-stats, gsd-thread, gsd-ui-phase, gsd-ui-review, gsd-ultraplan-phase, gsd-undo, gsd-update, gsd-validate-phase, gsd-verify-work, gsd-workstreams, higgsfield, higgsfield-generate, higgsfield-product-photoshoot, higgsfield-soul-id, higgsfield-video-explainer, high-end-visual-design, huashu-design, image-to-code, imagegen-frontend-mobile, imagegen-frontend-web, industrial-brutalist-ui, java-coding-standards, launch-strategy, lead-magnets, liquid-glass-design, market-research, marketing-ideas, marketing-psychology, messages-ops, minimalist-ui, nanoclaw-repl, onboarding-cro, page-cro, paid-ads, paywall-upgrade-cro, popup-cro, postgres-patterns, prediction-market-oracle-research, premium-visual-polish, pricing-strategy, product-marketing-context, programmatic-seo, project-flow-ops, recursive-decision-ledger, redesign-existing-projects, referral-program, remotion-best-practices, research-ops, revops, sales-enablement, schema-markup, scholar-evaluation, seo, seo-audit, seo-competitor-pages, seo-content, seo-geo, seo-hreflang, seo-images, seo-local, seo-page, seo-plan, seo-programmatic, seo-schema, seo-sitemap, seo-technical, signup-flow-cro, site-architecture, social-content, social-graph-ranker, springboot-tdd, stitch-design-taste, supabase-postgres-best-practices, swift-concurrency-6-2, swift-protocol-di-testing, typesafe-ai, vercel-react-best-practices, web-design-guidelines, web-frontend-design, website-architecture, website-cro-copy-seo
Symlinks → ~/.codex/skills (32): ai-image-prompts, api-security-best-practices, arcanex-dashboard-security, bootstrap-enforcer, cc-skill-security-review, code-review-skill, constant-time-analysis, fastapi-patterns, frontend-design, helius, helius-dflow, helius-phantom, mem-search, meteora-sendai, nano-banana-pro-prompts-recommend, perfect-loop, publishing-astro-websites, pumpfun-sendai, raydium-sendai, security-best-practices, security-threat-model, seedance-20, semgrep-rule-creator, smart-explore, solana-dev, supply-chain-risk-auditor, svm, systematic-debugging, typescript-expert, ui-ux-pro-max, variant-analysis, verification-before-completion
Não expostas ao Claude Code (65): bootstrap-enforcer, cavecrew, caveman, caveman-commit, caveman-compress, caveman-help, caveman-review, caveman-stats, compress, connections-optimizer, constant-time-analysis, continuous-agent-loop, dotnet-patterns, foundation-models-on-device, frontend-implementation-review, gsd-add-backlog, gsd-add-phase, gsd-add-todo, gsd-analyze-dependencies, gsd-check-todos, gsd-code-review-fix, gsd-do, gsd-extract_learnings, gsd-from-gsd2, gsd-insert-phase, gsd-intel, gsd-join-discord, gsd-list-phase-assumptions, gsd-list-workspaces, gsd-new-workspace, gsd-next, gsd-note, gsd-plan-milestone-gaps, gsd-plant-seed, gsd-reapply-patches, gsd-remove-phase, gsd-remove-workspace, gsd-research-phase, gsd-scan, gsd-session-report, gsd-set-profile, gsd-sketch-wrap-up, gsd-spike-wrap-up, mem-search, messages-ops, nanoclaw-repl, prediction-market-oracle-research, premium-visual-polish, project-flow-ops, recursive-decision-ledger, scholar-evaluation, security-best-practices, security-threat-model, semgrep-rule-creator, smart-explore, social-graph-ranker, springboot-tdd, supply-chain-risk-auditor, swift-protocol-di-testing, systematic-debugging, variant-analysis, verification-before-completion, web-frontend-design, website-architecture, website-cro-copy-seo

### Skills — ~/.codex/skills (40; antes: 6) — raiz NÃO descoberta pelo Claude Code, ver tabela acima
adaptive-orchestration, ai-image-prompts, api-security-best-practices, arcanex-dashboard-security, bootstrap-enforcer, cc-skill-security-review, code-review-skill, constant-time-analysis, constraint-driven-development, documentation-and-adrs, fastapi-patterns, frontend-design, google-maps-scraper, hatch-pet, helius, helius-dflow, helius-phantom, humanizer, mem-search, meteora-sendai, nano-banana-pro-prompts-recommend, observability-and-instrumentation, penetration-testing-with-strix, perfect-loop, publishing-astro-websites, pumpfun-sendai, raydium-sendai, security-best-practices, security-threat-model, seedance-20, semgrep-rule-creator, smart-explore, solana-dev, supply-chain-risk-auditor, svm, systematic-debugging, typescript-expert, ui-ux-pro-max, variant-analysis, verification-before-completion
Pasta sem SKILL.md: .system
Não expostas ao Claude Code (19): adaptive-orchestration, bootstrap-enforcer, constant-time-analysis, constraint-driven-development, documentation-and-adrs, google-maps-scraper, hatch-pet, humanizer, mem-search, observability-and-instrumentation, penetration-testing-with-strix, security-best-practices, security-threat-model, semgrep-rule-creator, smart-explore, supply-chain-risk-auditor, systematic-debugging, variant-analysis, verification-before-completion


## Cybersecurity Skills Imported From mukul975/Anthropic-Cybersecurity-Skills
- Repo: https://github.com/mukul975/Anthropic-Cybersecurity-Skills · commit `0f429d0f96ee70d2a6c259c4ecc6c6e18e0d23ff` · Apache-2.0
- Imported: 651 (SKILL.md + references/ + assets/ + LICENSE). **scripts/ (agent.py/process.py) excluded — not imported, not executed.**
- Full per-skill table: `~/.claude/security-skill-library/anthropic-cybersecurity/MANIFEST.tsv` (name · package · mode · severity · subdomain · repo · commit · src_path · installed_path).
- Per-package indexes: `~/.claude/security-skill-library/anthropic-cybersecurity/<PACKAGE>/INDEX.md`.

| Package | Safety classification | Mode | Imported |
|---|---|---|---|
| SECURITY_DEFENSIVE_CORE | defensive | explicit_only | 492 |
| SECURITY_AI_AGENT_DEFENSE | defensive | explicit_only | 1 |
| SECURITY_REVIEW_SUPPORT | defensive/review | explicit_only | 60 |
| SECURITY_LAB_DUAL_USE_MANUAL_ONLY | offensive/dual-use | manual_lab_only | 98 |

## Skills Not Imported
- **scripts/ directories (754 × agent.py + extras)** — executable payloads; excluded by policy (supply-chain/exec risk). Future handling: audit individually before any execution; never run against external targets.
- **Quarantined skills (103)** — skill-scanner max_severity HIGH/CRITICAL (educational attack-examples / placeholder secrets). Withheld pending manual review. Remain in staging only. Full list: `~/.claude/security-skill-library/anthropic-cybersecurity/QUARANTINE.md`.

### Quarantine list (103)
| Skill | Subdomain | Severity | Intended package |
|---|---|---|---|
| `analyzing-bootkit-and-rootkit-samples` | malware-analysis | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `analyzing-browser-forensics-with-hindsight` | digital-forensics | HIGH | SECURITY_DEFENSIVE_CORE |
| `analyzing-disk-image-with-autopsy` | digital-forensics | HIGH | SECURITY_DEFENSIVE_CORE |
| `analyzing-docker-container-forensics` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-email-headers-for-phishing-investigation` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-linux-system-artifacts` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-network-traffic-with-wireshark` | network-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-pdf-malware-with-pdfid` | malware-analysis | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `analyzing-persistence-mechanisms-in-linux` | threat-hunting | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-ransomware-network-indicators` | threat-hunting | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-slack-space-and-file-system-artifacts` | digital-forensics | HIGH | SECURITY_DEFENSIVE_CORE |
| `analyzing-supply-chain-malware-artifacts` | malware-analysis | HIGH | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `analyzing-uefi-bootkit-persistence` | firmware-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `analyzing-web-server-logs-for-intrusion` | security-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `auditing-tls-certificate-transparency-logs` | threat-intelligence | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `building-c2-infrastructure-with-sliver-framework` | red-teaming | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `building-incident-response-dashboard` | soc-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `building-red-team-c2-infrastructure-with-havoc` | red-teaming | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `building-soc-metrics-and-kpi-tracking` | soc-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `building-vulnerability-exception-tracking-system` | vulnerability-management | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `collecting-volatile-evidence-from-compromised-host` | incident-response | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `conducting-mobile-app-penetration-test` | penetration-testing | HIGH | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `configuring-snort-ids-for-intrusion-detection` | network-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `configuring-tls-1-3-for-secure-communications` | cryptography | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `deploying-decoy-files-for-ransomware-detection` | ransomware-defense | HIGH | SECURITY_DEFENSIVE_CORE |
| `deploying-osquery-for-endpoint-monitoring` | endpoint-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `deploying-ransomware-canary-files` | ransomware-defense | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `deploying-software-defined-perimeter` | zero-trust-architecture | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `detecting-ai-model-prompt-injection-attacks` | ai-security | HIGH | SECURITY_AI_AGENT_DEFENSE |
| `detecting-aws-credential-exposure-with-trufflehog` | cloud-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `detecting-azure-service-principal-abuse` | cloud-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `detecting-rootkit-activity` | malware-analysis | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `detecting-serverless-function-injection` | cloud-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `detecting-sql-injection-via-waf-logs` | security-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `detecting-t1003-credential-dumping-with-edr` | threat-hunting | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `eradicating-malware-from-infected-systems` | incident-response | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `exploiting-api-injection-vulnerabilities` | api-security | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `exploiting-bgp-hijacking-vulnerabilities` | network-security | HIGH | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `exploiting-mass-assignment-in-rest-apis` | web-application-security | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `exploiting-sql-injection-vulnerabilities` | penetration-testing | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `exploiting-websocket-vulnerabilities` | web-application-security | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `extracting-browser-history-artifacts` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `generating-threat-intelligence-reports` | threat-intelligence | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `hardening-docker-daemon-configuration` | container-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-alert-fatigue-reduction` | soc-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-canary-tokens-for-network-intrusion` | security-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-ebpf-security-monitoring` | security-operations | HIGH | SECURITY_DEFENSIVE_CORE |
| `implementing-epss-score-for-vulnerability-prioritization` | vulnerability-management | HIGH | SECURITY_DEFENSIVE_CORE |
| `implementing-gdpr-data-subject-access-request` | privacy-compliance | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-hashicorp-vault-dynamic-secrets` | identity-access-management | HIGH | SECURITY_DEFENSIVE_CORE |
| `implementing-mtls-for-zero-trust-services` | security-operations | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-pci-dss-compliance-controls` | compliance-governance | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-privileged-access-management-with-cyberark` | identity-access-management | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-privileged-session-monitoring` | identity-access-management | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-ransomware-backup-strategy` | ransomware-defense | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-rsa-key-pair-management` | cryptography | HIGH | SECURITY_DEFENSIVE_CORE |
| `implementing-runtime-security-with-tetragon` | container-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-secrets-management-with-vault` | cloud-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `implementing-vulnerability-sla-breach-alerting` | vulnerability-management | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `implementing-zero-trust-network-access-with-zscaler` | zero-trust-architecture | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `monitoring-darkweb-sources` | threat-intelligence | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-active-directory-bloodhound-analysis` | red-teaming | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `performing-api-fuzzing-with-restler` | api-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-authenticated-scan-with-openvas` | vulnerability-management | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-cloud-log-forensics-with-athena` | cloud-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-container-image-hardening` | devsecops | HIGH | SECURITY_REVIEW_SUPPORT |
| `performing-content-security-policy-bypass` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-cryptographic-audit-of-application` | cryptography | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-dynamic-analysis-of-android-app` | mobile-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-external-network-penetration-test` | penetration-testing | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `performing-file-carving-with-foremost` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-graphql-security-assessment` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-ios-app-security-assessment` | mobile-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-jwt-none-algorithm-attack` | api-security | HIGH | SECURITY_REVIEW_SUPPORT |
| `performing-kubernetes-cis-benchmark-with-kube-bench` | container-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-kubernetes-penetration-testing` | container-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-log-analysis-for-forensic-investigation` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-malware-persistence-investigation` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-memory-forensics-with-volatility3` | digital-forensics | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-network-forensics-with-wireshark` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-phishing-simulation-with-gophish` | phishing-defense | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-post-quantum-cryptography-migration` | cryptography | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-privilege-escalation-assessment` | penetration-testing | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `performing-security-headers-audit` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-service-account-credential-rotation` | identity-access-management | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-soap-web-service-security-testing` | api-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-ssl-certificate-lifecycle-management` | cryptography | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `performing-ssl-stripping-attack` | network-security | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-thick-client-application-penetration-test` | penetration-testing | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `performing-threat-emulation-with-atomic-red-team` | threat-intelligence | HIGH | SECURITY_DEFENSIVE_CORE |
| `performing-web-application-firewall-bypass` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `performing-web-application-penetration-test` | penetration-testing | CRITICAL | SECURITY_LAB_DUAL_USE_MANUAL_ONLY |
| `recovering-deleted-files-with-photorec` | digital-forensics | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `scanning-docker-images-with-trivy` | container-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `testing-android-intents-for-vulnerabilities` | mobile-security | CRITICAL | SECURITY_DEFENSIVE_CORE |
| `testing-api-for-broken-object-level-authorization` | api-security | HIGH | SECURITY_REVIEW_SUPPORT |
| `testing-api-security-with-owasp-top-10` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `testing-for-json-web-token-vulnerabilities` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `testing-for-xml-injection-vulnerabilities` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `testing-for-xss-vulnerabilities-with-burpsuite` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `testing-jwt-token-security` | web-application-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `testing-websocket-api-security` | api-security | CRITICAL | SECURITY_REVIEW_SUPPORT |
| `validating-backup-integrity-for-recovery` | incident-response | CRITICAL | SECURITY_DEFENSIVE_CORE |

## Dual-use / Offensive Skills (manual_lab_only — NEVER auto-route)
Risk: offensive capability. Why manual only: misuse potential against third parties/production. Required owner authorization: explicit, per session. Lab/sandbox only. scripts/ not imported.

### Imported dual-use (98) — `~/.claude/security-skill-library/anthropic-cybersecurity/SECURITY_LAB_DUAL_USE_MANUAL_ONLY`
| Skill | Subdomain | Scan |
|---|---|---|
| `analyzing-android-malware-with-apktool` | malware-analysis | SAFE |
| `analyzing-cobalt-strike-beacon-configuration` | malware-analysis | SAFE |
| `analyzing-cobaltstrike-malleable-c2-profiles` | malware-analysis | SAFE |
| `analyzing-command-and-control-communication` | malware-analysis | MEDIUM |
| `analyzing-golang-malware-with-ghidra` | malware-analysis | SAFE |
| `analyzing-heap-spray-exploitation` | malware-analysis | SAFE |
| `analyzing-linux-elf-malware` | malware-analysis | SAFE |
| `analyzing-macro-malware-in-office-documents` | malware-analysis | SAFE |
| `analyzing-malicious-pdf-with-peepdf` | malware-analysis | SAFE |
| `analyzing-malware-behavior-with-cuckoo-sandbox` | malware-analysis | MEDIUM |
| `analyzing-malware-persistence-with-autoruns` | malware-analysis | SAFE |
| `analyzing-malware-sandbox-evasion-techniques` | malware-analysis | SAFE |
| `analyzing-memory-dumps-with-volatility` | malware-analysis | SAFE |
| `analyzing-network-covert-channels-in-malware` | malware-analysis | SAFE |
| `analyzing-network-traffic-of-malware` | malware-analysis | MEDIUM |
| `analyzing-packed-malware-with-upx-unpacker` | malware-analysis | SAFE |
| `analyzing-ransomware-encryption-mechanisms` | malware-analysis | SAFE |
| `bypassing-authentication-with-forced-browsing` | web-application-security | MEDIUM |
| `conducting-api-security-testing` | penetration-testing | MEDIUM |
| `conducting-domain-persistence-with-dcsync` | red-teaming | SAFE |
| `conducting-external-reconnaissance-with-osint` | penetration-testing | MEDIUM |
| `conducting-full-scope-red-team-engagement` | red-teaming | SAFE |
| `conducting-internal-network-penetration-test` | penetration-testing | SAFE |
| `conducting-internal-reconnaissance-with-bloodhound-ce` | red-teaming | SAFE |
| `conducting-network-penetration-test` | penetration-testing | SAFE |
| `conducting-pass-the-ticket-attack` | red-teaming | SAFE |
| `conducting-social-engineering-penetration-test` | penetration-testing | MEDIUM |
| `conducting-social-engineering-pretext-call` | red-teaming | SAFE |
| `conducting-spearphishing-simulation-campaign` | red-teaming | MEDIUM |
| `conducting-wireless-network-penetration-test` | penetration-testing | SAFE |
| `deobfuscating-javascript-malware` | malware-analysis | MEDIUM |
| `deobfuscating-powershell-obfuscated-malware` | malware-analysis | SAFE |
| `detecting-fileless-malware-techniques` | malware-analysis | SAFE |
| `detecting-process-injection-techniques` | malware-analysis | SAFE |
| `executing-active-directory-attack-simulation` | penetration-testing | SAFE |
| `executing-phishing-simulation-campaign` | penetration-testing | MEDIUM |
| `executing-red-team-engagement-planning` | red-teaming | SAFE |
| `executing-red-team-exercise` | penetration-testing | MEDIUM |
| `exploiting-active-directory-certificate-services-esc1` | red-teaming | SAFE |
| `exploiting-active-directory-with-bloodhound` | red-teaming | MEDIUM |
| `exploiting-broken-function-level-authorization` | api-security | MEDIUM |
| `exploiting-broken-link-hijacking` | web-application-security | MEDIUM |
| `exploiting-constrained-delegation-abuse` | red-teaming | SAFE |
| `exploiting-deeplink-vulnerabilities` | mobile-security | SAFE |
| `exploiting-excessive-data-exposure-in-api` | api-security | MEDIUM |
| `exploiting-http-request-smuggling` | web-application-security | MEDIUM |
| `exploiting-idor-vulnerabilities` | web-application-security | MEDIUM |
| `exploiting-insecure-data-storage-in-mobile` | mobile-security | SAFE |
| `exploiting-insecure-deserialization` | web-application-security | MEDIUM |
| `exploiting-ipv6-vulnerabilities` | network-security | SAFE |
| `exploiting-jwt-algorithm-confusion-attack` | api-security | SAFE |
| `exploiting-kerberoasting-with-impacket` | red-teaming | SAFE |
| `exploiting-ms17-010-eternalblue-vulnerability` | red-teaming | SAFE |
| `exploiting-nopac-cve-2021-42278-42287` | red-teaming | SAFE |
| `exploiting-nosql-injection-vulnerabilities` | web-application-security | MEDIUM |
| `exploiting-oauth-misconfiguration` | web-application-security | MEDIUM |
| `exploiting-prototype-pollution-in-javascript` | web-application-security | MEDIUM |
| `exploiting-race-condition-vulnerabilities` | web-application-security | MEDIUM |
| `exploiting-server-side-request-forgery` | web-application-security | MEDIUM |
| `exploiting-smb-vulnerabilities-with-metasploit` | network-security | SAFE |
| `exploiting-sql-injection-with-sqlmap` | web-application-security | SAFE |
| `exploiting-template-injection-vulnerabilities` | web-application-security | MEDIUM |
| `exploiting-type-juggling-vulnerabilities` | web-application-security | MEDIUM |
| `exploiting-vulnerabilities-with-metasploit-framework` | vulnerability-management | MEDIUM |
| `exploiting-zerologon-vulnerability-cve-2020-1472` | red-teaming | SAFE |
| `extracting-config-from-agent-tesla-rat` | malware-analysis | SAFE |
| `extracting-iocs-from-malware-samples` | malware-analysis | MEDIUM |
| `implementing-attack-surface-management` | offensive-security | SAFE |
| `intercepting-mobile-traffic-with-burpsuite` | mobile-security | SAFE |
| `performing-active-directory-forest-trust-attack` | red-team | SAFE |
| `performing-active-directory-penetration-test` | penetration-testing | SAFE |
| `performing-automated-malware-analysis-with-cape` | malware-analysis | MEDIUM |
| `performing-binary-exploitation-analysis` | offensive-security | SAFE |
| `performing-credential-access-with-lazagne` | red-teaming | SAFE |
| `performing-dynamic-analysis-with-any-run` | malware-analysis | MEDIUM |
| `performing-firmware-malware-analysis` | malware-analysis | SAFE |
| `performing-initial-access-with-evilginx3` | red-teaming | SAFE |
| `performing-iot-security-assessment` | penetration-testing | MEDIUM |
| `performing-kerberoasting-attack` | red-teaming | SAFE |
| `performing-lateral-movement-with-wmiexec` | red-teaming | SAFE |
| `performing-malware-triage-with-yara` | malware-analysis | SAFE |
| `performing-memory-forensics-with-volatility3-plugins` | malware-analysis | SAFE |
| `performing-open-source-intelligence-gathering` | red-teaming | MEDIUM |
| `performing-physical-intrusion-assessment` | red-teaming | SAFE |
| `performing-privilege-escalation-on-linux` | red-teaming | MEDIUM |
| `performing-purple-team-atomic-testing` | purple-team | SAFE |
| `performing-red-team-with-covenant` | red-team | MEDIUM |
| `performing-static-malware-analysis-with-pe-studio` | malware-analysis | SAFE |
| `performing-vulnerability-scanning-with-nessus` | penetration-testing | MEDIUM |
| `performing-wireless-network-penetration-test` | penetration-testing | SAFE |
| `performing-yara-rule-development-for-detection` | malware-analysis | SAFE |
| `reverse-engineering-android-malware-with-jadx` | malware-analysis | SAFE |
| `reverse-engineering-dotnet-malware-with-dnspy` | malware-analysis | SAFE |
| `reverse-engineering-ios-app-with-frida` | mobile-security | SAFE |
| `reverse-engineering-malware-with-ghidra` | malware-analysis | SAFE |
| `reverse-engineering-ransomware-encryption-routine` | malware-analysis | SAFE |
| `reverse-engineering-rust-malware` | malware-analysis | SAFE |
| `testing-for-xss-vulnerabilities` | penetration-testing | MEDIUM |

## Plugins Installed (31; antes: 26)
Source: `~/.claude/plugins/installed_plugins.json`
| Plugin | Marketplace/source | Notes |
|---|---|---|
| agent-sdk-dev | claude-plugins-official | enabled |
| agentic-actions-auditor | trailofbits | enabled |
| audit-context-building | trailofbits | enabled |
| building-secure-contracts | trailofbits | enabled |
| burpsuite-project-parser | trailofbits | enabled |
| caveman | caveman | enabled |
| claude-mem | thedotmack | enabled |
| claude-security | claude-plugins-official | enabled |
| code-review | claude-plugins-official | enabled |
| coderabbit | claude-plugins-official | enabled |
| constant-time-analysis | trailofbits | enabled |
| context7-plugin | context7-marketplace | enabled |
| differential-review | trailofbits | enabled |
| entry-point-analyzer | trailofbits | enabled |
| fast-jev-compaction | fast-jev-compaction | enabled |
| feature-dev | claude-plugins-official | enabled |
| figma | claude-plugins-official | enabled |
| frontend-design | claude-plugins-official | enabled |
| i-have-adhd | i-have-adhd | enabled |
| i18n-expert | daymade-skills | enabled |
| insecure-defaults | trailofbits | enabled |
| pr-review-toolkit | claude-plugins-official | enabled |
| second-opinion | trailofbits | enabled |
| security-guidance | claude-plugins-official | enabled |
| semgrep-rule-creator | trailofbits | enabled |
| static-analysis | trailofbits | enabled |
| superpowers | superpowers-dev | enabled |
| supply-chain-risk-auditor | trailofbits | enabled |
| typescript-lsp | claude-plugins-official | enabled |
| upstash | upstash | enabled |
| variant-analysis | trailofbits | enabled |

## MCP Servers Installed (9 globais; antes: 7)
Source: `~/.claude.json` (global mcpServers). Secrets/tokens NOT read or printed.
| MCP | Risk | Notes (secrets redacted) |
|---|---|---|
| b2 | n/c (não classificado) | Backblaze B2 (storage); tools de escrita/apagamento (ex.: b2_delete_bucket, s3_put_object, s3_delete_object, b2_create_key) — classificação de risco por decidir |
| blender | HIGH | execute_blender_code = arbitrary Python; owner approval per session |
| context7 | LOW (classificação do SKILLS_PROMPT_REFERENCE §6b) | docs atualizadas de libs (read-only) |
| helius | HIGH | funds-moving tools (transferSol/transferToken/generateKeypair/payRenewal) DEFAULT_DENY |
| higgsfield | MEDIUM | remote OAuth; video generation; explicit request only |
| motion | MEDIUM | npx via remote tarball (TOFU risk) |
| nano-banana-mcp | MEDIUM | Gemini token persists; image gen; explicit request only |
| playwright | MEDIUM | browser execution (visual proof) |
| stitch | LOW-MEDIUM | Google HTTP screen generation |

(Por projeto, em ~/.claude.json a 2026-10-05: 3 — `helius` em /private/tmp/core-ai · `krea-ai` em ~/repos/krea-video-lab · `supabase` em ~/repos/bass-site; antes: "nenhum configurado".)

## Config Files Inspected (no secrets revealed)
- ~/.claude/skills/skill-router/{SKILL.md, SKILL_PACKS.md, skills-registry.json, profiles.json}  (router — EDITED)
- ~/.claude/plugins/installed_plugins.json  (read-only)
- ~/.claude.json  (structure + mcpServers names only; values NOT read)
- ~/.claude/ tree, ~/.agents/skills, ~/.codex/skills  (read-only)

## Backups
- Backup: `/Users/goncaloferro/.claude/backups/anthropic-cybersecurity-skills-install-20260530-105444`
- Restore script: `/Users/goncaloferro/.claude/backups/anthropic-cybersecurity-skills-install-20260530-105444/RESTORE.sh` (executable; restores skill-router, lists+confirms before removing new items)
- Pre-state manifest: `/Users/goncaloferro/.claude/backups/anthropic-cybersecurity-skills-install-20260530-105444/PRE_STATE_MANIFEST.md`

## Usage Guidance

### Segurança defensiva normal
"Usa SECURITY_DEFENSIVE_CORE para auditar este endpoint/API/configuração. Lê o INDEX.md do pacote, escolhe 1-3 skills por path. Não uses skills ofensivas."

### Defesa de agentes IA
"Usa SECURITY_AI_AGENT_DEFENSE (+ arcanex-dashboard-security, agentic-actions-auditor, mcp-scan) para verificar prompt injection, tool abuse, RAG poisoning e permissões excessivas."

### Auditoria de código
"Usa SECURITY_REVIEW_SUPPORT (+ Trail of Bits: differential-review, insecure-defaults, supply-chain-risk-auditor) para rever auth, RBAC, logs, rate limits, validação input e supply-chain."

### Laboratório manual
"SECURITY_LAB_DUAL_USE_MANUAL_ONLY: apenas em lab/sandbox local e SÓ após autorização explícita do owner. Nunca auto-route. Nunca contra alvos externos. scripts/ não importados."

## Registo de atualizações

### 2026-10-09 — skills Solana/Helius e bloqueio de transferências do Helius MCP
Backup: `~/.claude/backups/20261009T143754Z-helius-solana-skills-deny/`. As contagens de 2026-10-05 acima não foram recalculadas.
- **Atualizadas (cópia do upstream):** `helius` 1.0.0 → 1.1.2, `helius-dflow` 1.0.0 → 1.3.0, `helius-phantom` 1.0.0 → 1.0.2, `svm` 1.0.0 → 1.2.0 (helius-labs/core-ai); `solana-dev` 1.1.0 → 2.6.0 (solana-foundation/solana-dev-skill). `~/.codex/skills` não alterado.
- **Removida de `~/.claude/skills` (movida para o backup):** `solana-dev-skill` 1.1.0, duplicado de `solana-dev`. Referências atualizadas: agente `solana-launchpad-specialist`, `skill-router/SKILL_PACKS.md`, `SKILLS_MCP_REFERENCE.md`.
- **Permissões (atualizado 2026-10-12; backup `~/.claude/backups/20261012T044001Z-helius-deny-account-streaming-pin/`):** `permissions.deny` em `~/.claude/settings.json` bloqueia `mcp__helius__heliusWrite` (transferências, staking), `mcp__helius__heliusAccount` (`setHeliusApiKey`, `generateKeypair`, signup, pagamentos e leituras de conta/plano) e `mcp__helius__heliusStreaming` (webhooks, incluindo listagem, e subscrições). Custo por método continua em `heliusKnowledge`. MCP `helius` (user scope, `~/.claude.json`) fixo em `helius-mcp@2.2.0`, só o pacote de topo; antes de subir, comparar as ações (`dist/router/actions.d.ts`) com o deny. A skill `helius` pode sugerir `heliusAccount`: bloqueado de propósito.

### 2026-10-05 — correção factual (sem alterações de política)
Fonte: inventário read-only de 2026-10-05 (contagens por script; nada instalado, removido ou ativado). Versão anterior: `CLAUDE_CODE_CAPABILITIES_INVENTORY.md.archived-2026-10-05`.
- **Skills (contagens):** `~/.claude/skills` 98 → 285 (nenhuma removida; +187); `~/.agents/skills` 96 → 243 (+147); `~/.codex/skills` 6 → 40.
- **Estado:** `~/.agents/skills` e `~/.codex/skills` não são raízes de descoberta do Claude Code (constavam "yes"); evidência: `gsd-session-report`, `connections-optimizer`, `continuous-agent-loop` e `dotnet-patterns` existem só em `~/.agents/skills` (sem pasta em `~/.claude/skills`) e não constam da lista de skills da sessão; das 243, 95 chegam por symlink, 83 têm cópia homónima própria e 65 não estão expostas. Novas linhas na tabela de raízes: `~/.claude/skills/ecc` (197 cópias; 89 expostas) e `~/.claude/.agents/skills` (33).
- **Plugins:** 26 → 31 (+claude-security, coderabbit, fast-jev-compaction, i-have-adhd, upstash); todos `enabled`.
- **MCP globais:** 7 → 9 (+b2, context7); "nenhum mcpServers por projeto" → 3 por projeto.
- **Verificado e inalterado:** biblioteca 651 (492/1/60/98), quarentena 103, hyperframes 15, packs 1–24 do skill-router, 6 profiles, scripts/ não importados.
- **Não alterado (histórico/política):** listas de quarentena (103) e dual-use (98), "Config Files Inspected", "Backups", "Usage Guidance".
