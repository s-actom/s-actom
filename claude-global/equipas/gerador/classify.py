"""Purpose categories for skills, agents and MCP servers. First matching rule wins; EXACT overrides everything."""
import re

CATS = {
    'seg': 'Segurança e auditoria', 're': 'Engenharia reversa', 'crypto': 'Crypto e blockchain',
    'fe': 'Frontend e animação web', 'design': 'Design, UI e UX', 'be': 'Backend, APIs, dados e arquitetura',
    'lang': 'Linguagens e frameworks', 'qual': 'Qualidade: testes e code review', 'work': 'Workflow e orquestração',
    'meta': 'Harness: skills, agentes, config, memória', 'devops': 'DevOps, deploy e infraestrutura', 'ai': 'IA, LLM e agentes (construir)',
    'data': 'Dados e analytics', 'seo': 'SEO e GEO', 'mkt': 'Marketing, copy e CRO', 'sales': 'Vendas e CRM',
    'biz': 'Negócio, e-commerce e gestão', 'media': 'Imagem, vídeo e 3D', 'docs': 'Pesquisa e documentação',
    'auto': 'Browser e automação', 'office': 'Documentos e produtividade', 'niche': 'Nichos específicos',
}

NS = {
    'agentic-actions-auditor': 'seg', 'audit-context-building': 'seg', 'burpsuite-project-parser': 'seg', 'constant-time-analysis': 'seg',
    'differential-review': 'seg', 'entry-point-analyzer': 'seg', 'insecure-defaults': 'seg', 'semgrep-rule-creator': 'seg', 'static-analysis': 'seg',
    'supply-chain-risk-auditor': 'seg', 'variant-analysis': 'seg', 'claude-security': 'seg', 'building-secure-contracts': 'seg',
    'second-opinion': 'qual', 'coderabbit': 'qual', 'code-review': 'qual', 'pr-review-toolkit': 'qual',
    'feature-dev': 'work', 'superpowers': 'work', 'agent-sdk-dev': 'ai',
    'claude-mem': 'meta', 'caveman': 'meta', 'ponytail': 'meta', 'i-have-adhd': 'meta', 'cowork-plugin-management': 'meta',
    'context7-plugin': 'docs', 'figma': 'design', 'design': 'design', 'design-superpowers': 'design', 'superdesign': 'design', 'vectorlab-ux-skills': 'design',
    'website-design': 'design', 'frontend-design': 'design', 'hyperframes': 'media', 'remotion': 'media', 'ai-video-editor': 'media', 'image-generation': 'media',
    'watch-video': 'media', 'hostinger': 'devops', 'upstash': 'devops', 'data': 'data', 'marketing': 'mkt', 'agency-mcp': 'mkt', 'sales': 'sales',
    'small-business': 'biz', 'telegram': 'office', 'i18n-expert': 'fe', 'ffmpeg-llm': 'media',
}

SKILL_RULES = [
    (r'^(gsd-|epic-|orch-|multi-|prp-|plan($|-)|loop($|-)|gan-|santa-loop|autonomous-loops|dmux-workflows|parallel-execution-optimizer|grilling|checkpoint|save-session|resume-session|sessions|aside|projects|project-init|promote|evolve|instinct-|learn|schedule|team-builder|agency-commander|feature-dev|run$)', 'work'),
    (r'(security|owasp|vibesec|bounty)', 'seg'),
    (r'^(ghidra|reverse-engineer)', 're'),
    (r'^(helius|solana|svm|pumpfun|raydium|meteora|evm-|nodejs-keccak)', 'crypto'),
    (r'^(gsap-|motion-ui|make-interfaces-feel|image-to-code|frontend-patterns|react-patterns|react-performance|vercel-react|publishing-astro|ui-to-vue|angular-developer)', 'fe'),
    (r'^(design-taste|frontend-design|gpt-taste|high-end-visual|huashu|impeccable|industrial-brutalist|interface-design|liquid-glass|minimalist-ui|redesign-existing|stitch-design|ui-ux-pro|design-md|polish|brandkit|web-design-guidelines|dashboard-builder|arcanex-dashboard-design|imagegen-frontend)', 'design'),
    (r'^(api-design|backend-patterns|clickhouse|database-migrations|mysql-patterns|postgres-patterns|prisma-patterns|supabase-postgres|api-connector|data-throughput|latency-critical|domain-modeling|error-handling|codebase-design)', 'be'),
    (r'^(cpp-|dart-|django-|golang-|go-|java-|jpa-|kotlin-|laravel-|python-|quarkus-|rust-|springboot-|swift|typescript-expert|coding-standards|flutter-|gradle-|build-fix|fastapi|nestjs|react-(build|review|test)|react-testing|vue-review)', 'lang'),
    (r'^(ai-regression|code-review|e2e-testing|tdd-workflow|verification-loop|test-coverage|quality-gate|refactor-clean|review-pr|pr$|simplify|production-audit|audit$)', 'qual'),
    (r'^(deployment-patterns|docker-patterns|github-ops|pm2)', 'devops'),
    (r'^(cost-aware-llm|eval-harness|prompt-optimizer|typesafe-ai|agentic-engineering|ai-first-engineering|agent-harness|mcp-server-patterns|claude-api|agent-architecture)', 'ai'),
    (r'^(init$|skill-|find-skills|hookify|harness-audit|workspace-surface|automation-audit|update-config|keybindings|fewer-permission|plugin-authoring|workflow-authoring|artifact-|knowledge-ops|ecc-guide|prune|cost-report|token-budget|full-output|model-route|auto-update|setup-pm|memory|test-probe)', 'meta'),
    (r'^(research-ops|search-first|exa-search|update-docs|update-codemaps)', 'docs'),
    (r'^(dataviz)', 'data'),
    (r'^(seo|geo($|-)|ai-seo|schema-markup|programmatic-seo|site-architecture)', 'seo'),
    (r'^(ab-test|ad-creative|analytics-tracking|anuncios-meta|article-writing|brand-voice|churn|cold-email|competitor-alt|content-|copy-editing|copywriting|email-sequence|form-cro|free-tool|launch-strategy|lead-magnets|market-research|marketing-|onboarding-cro|page-cro|paid-ads|paywall|popup-cro|pricing-strategy|product-marketing|referral|revops|sales-enablement|signup-flow|social-content|util-competitive)', 'mkt'),
    (r'^(ai-film|ai-image|blender-|fal-ai|higgsfield|manim|nano-banana|perfect-loop|polyhaven|remotion-|seedance|turntable|video-editing)', 'media'),
    (r'^(agent-browser)', 'auto'),
    (r'^(jira)', 'office'),
]

SKILL_EXACT = {
    'anthropic-skills:docx': 'office', 'anthropic-skills:pptx': 'office', 'anthropic-skills:xlsx': 'office', 'anthropic-skills:pdf': 'office',
    'anthropic-skills:docs': 'office', 'anthropic-skills:google-workspace': 'office', 'anthropic-skills:morning': 'office',
    'anthropic-skills:built-in-browser': 'auto', 'anthropic-skills:chrome-browser': 'auto', 'anthropic-skills:computer-use': 'auto',
    'anthropic-skills:deep-research': 'docs', 'anthropic-skills:artifact-emulator': 'meta', 'anthropic-skills:consolidate-memory': 'meta',
    'anthropic-skills:explain-usage': 'meta', 'anthropic-skills:import-memory': 'meta', 'anthropic-skills:setup-claude': 'meta', 'anthropic-skills:skill-creator': 'meta',
    'agency-mcp:seo-audit': 'seo', 'agency-mcp:seo-content': 'seo', 'agency-mcp:keyword-research': 'seo', 'agency-mcp:local-seo-gbp': 'seo', 'marketing:seo-audit': 'seo',
    'small-business:seo-ai-visibility': 'seo', 'small-business:contract-review': 'biz', 'hostinger:hostinger-headless': 'devops',
    'superpowers:systematic-debugging': 'qual', 'superpowers:test-driven-development': 'qual', 'superpowers:verification-before-completion': 'qual',
    'superpowers:receiving-code-review': 'qual', 'superpowers:requesting-code-review': 'qual', 'superpowers:writing-skills': 'meta', 'superpowers:using-superpowers': 'meta',
    'superpowers:diagnosing-superpowers': 'meta', 'caveman:caveman-review': 'qual', 'ponytail:ponytail-review': 'qual', 'ponytail:ponytail-audit': 'qual',
    'claude-mem:make-plan': 'work', 'claude-mem:do': 'work', 'gsd-secure-phase': 'seg', 'gsd-code-review': 'qual', 'gsd-ui-review': 'design', 'gsd-ui-phase': 'design',
    'security-review': 'seg', 'security-scan': 'seg', 'audit': 'qual', 'improve-codebase-architecture': 'be',
    'design:accessibility-review': 'design',
}

AGENT_RULES = [
    (r'^gsd-(security|ui-)', None),
    (r'^(claude-security:|audit-context-building:|static-analysis:semgrep)', 'seg'),
    (r'(security|secops|penetration|threat-|incident-responder|compliance-auditor|privacy-engineer|secrets-credential|identity-access|crypto-protocol-auditor)', 'seg'),
    (r'^(helius|solana|solidity|crypto$)', 'crypto'),
    (r'^gsd-', 'work'),
    (r'^(planner|code-explorer|workflow-optimizer|spec-miner|construcao|feature-dev:code-explorer|minimal-change|senior-developer|rapid-prototyper|codebase-onboarding|gan-|general-purpose|Explore$|Plan$|claude$|caveman:cavecrew-(builder|investigator))', 'work'),
    (r'^(harness-optimizer|loop-operator|gestor-de-agentes|statusline-setup|conversation-analyzer|workspace-automation-auditor|claude-code-guide|tool-evaluator)', 'meta'),
    (r'^(agent-platform|agent-sdk-dev:|ai-engineer|ai-data-remediation|autonomous-optimization|llm-post|mle-reviewer|multi-agent|prompt-engineer|rag-|voice-ai)', 'ai'),
    (r'^(cpp-|csharp-|dart-|django-|fastapi-|flutter-|fsharp-|go-|java-|jvm-|kotlin-|node-backend|php-|python-|pytorch-|quarkus-|react-(build|reviewer)|rust-|swift-|typescript-|vue-reviewer|angular-|harmonyos|mobile-app|desktop-app|developer-tooling|webassembly|build-error)', 'lang'),
    (r'^(a11y|accessibility|frontend-|gsap-|motion-ui|image-to-interface|astro-|vue-interface|internationalization|site$|section-508|uswds)', 'fe'),
    (r'^(arcanex|huashu|interface-|ui-|ux-|web-design-reviewer|brand-guardian|whimsy|visual-storyteller|inclusive-visuals|behavioral-nudge)', 'design'),
    (r'^(architect$|code-architect|feature-dev:code-architect|software-architect|backend-architect|api-platform|database-|sistema|payments-billing|realtime-|search-relevance|email-intelligence|gaussdb)', 'be'),
    (r'^(code-reviewer|code-simplifier|comment-analyzer|pr-test|pr-review-toolkit:|type-design|silent-failure|refactor-cleaner|e2e-runner|tdd-guide|test-|api-tester|evidence-collector|reality-checker|performance-|auditoria|coderabbit:|feature-dev:code-reviewer|caveman:cavecrew-reviewer)', 'qual'),
    (r'^(container-|devops-|finops|git-workflow|github-|lancamento|network-|homelab|sre-|mobile-release|it-service|incident-response)', 'devops'),
    (r'^(data-visualization|data-engineer)', 'data'),
    (r'^(seo-|geo-|programmatic-seo)', 'seo'),
    (r'^(content-editor|conteudo|conversion-journey|email-marketing|marketing-agent|paid-media|persona-walkthrough|product-marketing|retention-|revenue-growth|social-content|outbound)', 'mkt'),
    (r'^(discovery-coach)', 'sales'),
    (r'^(product-manager|sprint-prioritizer|feedback-synthesizer|trend-researcher)', 'biz'),
    (r'^(ai-media|blender-|brand-asset|image-prompt|midia|mobile-image|video-|web-image)', 'media'),
    (r'^(pesquisa|docs-lookup|doc-updater|technical-writer|context7-plugin:|web-fetch)', 'docs'),
    (r'^(ffmpeg-llm:|ffmpeg-expert)', 'media'),
    (r'^(cms-|drupal-|wordpress-|embedded-|feishu|filament|healthcare|iot-|orgscript|wechat)', 'niche'),
]
AGENT_EXACT = {
    'gsd-security-auditor': 'seg', 'gsd-ui-auditor': 'design', 'gsd-ui-checker': 'design', 'gsd-ui-researcher': 'design', 'gsd-code-reviewer': 'qual', 'gsd-code-fixer': 'qual',
    'gsd-eval-auditor': 'ai', 'gsd-eval-planner': 'ai', 'gsd-ai-researcher': 'ai', 'gsd-framework-selector': 'ai', 'gsd-debugger': 'qual', 'gsd-debug-session-manager': 'qual',
    'gsd-nyquist-auditor': 'qual', 'gsd-verifier': 'qual', 'gsd-doc-writer': 'docs', 'gsd-doc-verifier': 'docs', 'gsd-doc-classifier': 'docs', 'gsd-doc-synthesizer': 'docs',
    'data-visualization-engineer': 'data', 'angular-developer': 'fe', 'ai-generated-code-security-auditor': 'seg', 'blockchain-security-auditor': 'seg', 'incident-response-commander': 'devops',
}

MCP_EXACT = {
    'vibesec': 'seg', 'Snyk Security': 'seg', 'rea': 're', 'helius': 'crypto', 'stitch': 'design', 'Figma': 'design', 'Canva': 'design', 'motion': 'fe',
    'nano-banana-mcp': 'media', 'higgsfield': 'media', 'higgsfield (claude.ai)': 'media', 'HyperFrames by HeyGen': 'media', 'playwright': 'auto', 'Apify': 'auto',
    'claude-in-chrome': 'auto', 'Claude_Browser': 'auto', 'computer-use': 'auto', 'Claude_Code_iOS_Simulator': 'auto',
    'context7': 'docs', 'Context7': 'docs', 'Claude Docs': 'office', 'b2': 'devops', 'hostinger': 'devops', 'Vercel': 'devops', 'Supabase': 'be', 'Shopify': 'biz',
    'Ahrefs': 'seo', 'meta-ads': 'mkt', 'scheduled-tasks': 'meta', 'mcp-registry': 'meta', 'terminal': 'meta', 'visualize': 'meta',
    'Stripe (claude.ai)': 'biz', 'Arcads (claude.ai)': 'media', 'Crypto.com (claude.ai)': 'crypto', 'Gmail (claude.ai)': 'office', 'Google Calendar (claude.ai)': 'office',
    'Google Drive (claude.ai)': 'office', 'Claude Code Remote (claude.ai)': 'meta', 'krea-ai': 'media', 'supabase (bass-site)': 'be', 'helius (core-ai)': 'crypto',
}
MCP_PLUGIN_LEAF = {
    'codex': 'qual', 'mcp-search': 'meta', 'uxkin': 'design', 'ugc-video-ads': 'media', 'abracadabrax-ai-video-generator': 'media', 'ai-video-editor': 'media',
    'telegram': 'office', 'agency-mcp': 'mkt', 'upstash': 'devops', 'slack': 'office', 'canva': 'design', 'figma': 'design', 'hubspot': 'sales', 'amplitude': 'data',
    'amplitude-eu': 'data', 'notion': 'office', 'ahrefs': 'seo', 'similarweb': 'seo', 'klaviyo': 'mkt', 'supermetrics': 'mkt', 'google calendar': 'office', 'gmail': 'office',
    'google-calendar': 'office', 'google-drive': 'office', 'google drive': 'office', 'snowflake': 'data', 'databricks': 'data', 'bigquery': 'data', 'hex': 'data', 'atlassian': 'office',
    'definite': 'data', 'linear': 'office', 'asana': 'office', 'intercom': 'sales', 'microsoft-365': 'office', 'zoom': 'office', 'otter-ai': 'office', 'calendly': 'office',
    'trello': 'office', 'docusign': 'office', 'zapier': 'auto', 'emergent': 'fe', 'wix': 'biz', 'tiktok': 'mkt', 'intuit-mailchimp': 'mkt', 'zoho-projects': 'office',
}

def skill_category(ident):
    if ident in SKILL_EXACT:
        return SKILL_EXACT[ident]
    if ':' in ident:
        ns = ident.split(':')[0]
        if ns in NS:
            return NS[ns]
    for rule, cat in SKILL_RULES:
        if re.search(rule, ident, re.I):
            return cat
    return 'niche'

def agent_category(ident):
    if ident in AGENT_EXACT:
        return AGENT_EXACT[ident]
    for rule, cat in AGENT_RULES:
        if cat and re.search(rule, ident):
            return cat
    return 'niche'

def mcp_category(name):
    if name in MCP_EXACT:
        return MCP_EXACT[name]
    if name.startswith('ccd_'):
        return 'meta'
    if name.startswith('plugin:'):
        _, plugin, leaf = name.split(':', 2)
        if leaf in MCP_PLUGIN_LEAF:
            return MCP_PLUGIN_LEAF[leaf]
        return {'sales': 'sales', 'small-business': 'biz', 'data': 'data', 'marketing': 'mkt', 'design': 'design'}.get(plugin, 'niche')
    return 'niche'
