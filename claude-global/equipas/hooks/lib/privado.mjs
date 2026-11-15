import path from "node:path";

const SECRET_PATH = /(^|[/._-])(?:\.env|secrets?|credentials?|tokens?|private[_-]?key|id_rsa|certificates?)([/._-]|$)/i;
const SECRET_CONTENT = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/i,
  /\b(?:sk-|sk-proj-|ghp_|github_pat_|xox[baprs]-|AKIA)[A-Za-z0-9_\-]{12,}\b/,
  /\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|secret)\b\s*[:=]\s*["']?[A-Za-z0-9_\-./+=]{12,}/i,
  /\bBearer\s+[A-Za-z0-9_\-./+=]{16,}/i
];

export const DATA_CLASSES = ["PUBLIC", "PROJECT", "SENSITIVE", "SECRET"];

const ROUTING_TERMS = [
  "answer", "explain", "inspect", "review", "implement", "create", "write", "edit", "fix", "correct", "continue", "cancel", "question", "ask", "new", "task", "debug", "test", "verify", "research", "design", "architecture", "deploy",
  "security", "authentication", "authorization", "database", "api", "backend", "frontend", "mobile", "ios", "android", "cloud", "network", "observability",
  "javascript", "typescript", "python", "rust", "go", "java", "swift", "react", "next", "vue", "svelte", "postgres", "supabase", "solana", "docker", "kubernetes",
  "marketing", "documentation", "document", "docs", "offers", "offer", "competitors", "competitor", "plan", "agents", "agent",
  "commerce", "ecommerce", "shop", "store", "loja", "retalho", "product", "products", "produto", "produtos", "cart", "carrinho", "checkout", "marketplace",
  "responde", "explica", "inspeciona", "revê", "rever", "implementa", "cria", "escreve", "edita", "corrige", "continua", "avança", "cancela", "cancelar", "pergunta", "novo", "tarefa", "depura", "testa", "verifica", "pesquisa", "desenha", "arquitetura", "segurança", "oferta", "ofertas", "concorrente", "concorrentes", "plano", "agente", "agentes", "lança",
  "extract", "extrai", "extrair", "scrape", "scraping", "fetch", "recolher", "procurar", "markdown", "content", "conteudo", "title", "titulo", "page", "pagina", "url", "web", "news", "noticias", "noticia", "article", "artigo", "sources", "fontes",
  "three", "threejs", "webgl", "gltf", "glb", "ffmpeg", "codec", "transcode"
];

const ROUTING_DOMAINS = {
  agent_orchestration: ["jev", "codex", "agent", "agents", "agente", "agentes", "router", "roteador"],
  payments: ["stripe", "payment", "payments", "pagamento", "pagamentos"],
  business_strategy: ["offer", "offers", "oferta", "ofertas", "competitor", "competitors", "concorrente", "concorrentes"],
  ecommerce: ["commerce", "ecommerce", "shop", "store", "loja", "retalho", "product", "products", "produto", "produtos", "cart", "carrinho", "checkout", "marketplace"],
  research_web: ["research", "pesquisa", "pesquisar", "procurar", "scrape", "scraping", "extract", "extrai", "extrair", "fetch", "recolher", "url", "news", "noticias", "noticia", "article", "artigo", "sources", "fontes", "browser"]
};

function normalizedWords(text) {
  return String(text || "").toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "").match(/[a-z0-9]+/g) || [];
}

function routingWork(words) {
  const has = (...terms) => terms.some((term) => words.has(term));
  if (has("deploy", "deployment", "deployed", "implantacao", "publicacao") &&
      has("production", "producao", "rollback", "commerce", "post")) return "production_deployment";
  const reviewing = has("review", "rever", "reve", "revisao", "audit", "auditoria", "test", "verifica");
  if (reviewing && has("accessibility", "acessibilidade", "a11y", "wcag")) return "accessibility_audit";
  if (reviewing && has("visual", "ui", "playwright", "playwrite", "screenshot", "screenshots", "visualizacao")) return "visual_ui_review";
  if (has("frontend", "astro", "css", "responsive") &&
      has("frontend", "astro", "css", "mobile", "templates", "typography", "interface")) return "frontend_implementation";
  if (has("copy", "copywriting") ||
      (has("content", "conteudo", "texto", "textos") &&
       has("write", "escreve", "redige", "cria", "create", "translated", "traduzido"))) return "marketing_copy";
  if (has("jev", "codex", "router", "roteador") && has("agent", "agents", "agente", "agentes")) return "agent_orchestration";
  // Pesquisa web: notícias/descoberta, ou uma página/URL conhecida com intenção de extrair o conteúdo.
  if (has("news", "noticias", "noticia", "manchetes", "headlines")) return "web_research";
  const pagina = has("web", "url", "site", "website", "pagina", "page", "markdown", "scrape", "scraping", "fetch", "browser");
  if (pagina && has("extract", "extrai", "extrair", "scrape", "scraping", "fetch", "markdown", "conteudo", "content", "recolher", "obter", "obtem", "ler", "le")) return "web_research";
  return "general";
}

export function routingWorkFamily(text) {
  return routingWork(new Set(normalizedWords(text)));
}

// Produce an allowlisted, non-extractive routing envelope. It intentionally
// carries no names, literals, paths, quoted text, code or arbitrary source spans.
export function buildRoutingEnvelope(text) {
  const value = String(text || "");
  const words = new Set(normalizedWords(value));
  const work = routingWorkFamily(value);
  const excluded = work === "production_deployment"
    ? new Set(["edit", "security"])
    : ["frontend_implementation", "marketing_copy", "visual_ui_review", "accessibility_audit"].includes(work)
      ? new Set(["agent", "agents", "agente", "agentes", "architecture", "arquitetura"])
      : new Set();
  const terms = ROUTING_TERMS.filter((term) =>
    !excluded.has(term) && words.has(term.normalize("NFD").replace(/\p{Diacritic}/gu, "")));
  if (work === "production_deployment" && !terms.includes("deploy")) terms.push("deploy");
  if (["visual_ui_review", "accessibility_audit"].includes(work) && !terms.includes("review")) terms.push("review");
  if (work === "visual_ui_review") terms.push("ui");
  if (work === "accessibility_audit") terms.push("accessibility");
  const domains = work === "frontend_implementation" ? ["frontend_web"]
    : work === "marketing_copy" ? ["marketing_content"]
      : work === "visual_ui_review" ? ["ui_visual_review"]
        : work === "accessibility_audit" ? ["accessibility_review"]
      : work === "production_deployment" ? ["deployment_operations"]
        : Object.entries(ROUTING_DOMAINS)
          .filter(([domain, markers]) => (domain !== "agent_orchestration" || work === "agent_orchestration") &&
            markers.some((marker) => words.has(marker)))
          .map(([domain]) => domain);
  const size = value.length < 160 ? "s" : (value.length < 1200 ? "m" : "l");
  const flags = [
    /```|~~~/.test(value) ? "contains_code_block" : null,
    /(?:^|\s)(?:\.?\.?\/|~\/|\/Users\/|[A-Za-z]:\\)/m.test(value) ? "contains_path" : null,
    /https?:\/\//i.test(value) ? "contains_url" : null,
    /\?\s*$/.test(value) ? "question_form" : null,
    /\b(?:error|exception|failed|failure|erro|falhou|falha)\b/i.test(value) ? "contains_failure_signal" : null,
    /\b(?:production|produ[cç][aã]o|deploy|payment|pagamento|delete|drop|force push)\b/i.test(value) ? "contains_high_risk_signal" : null
  ].filter(Boolean);
  return `@public;sz=${size};work=${work};terms=${terms.length ? terms.join(",") : "-"};domains=${domains.length ? domains.join(",") : "-"};flags=${flags.length ? flags.join(",") : "-"}`;
}

export function classifyData({ filePath = "", text = "", policy = {} } = {}) {
  if (!policy || typeof policy !== "object") {
    return { class: "SENSITIVE", reason: "classification_uncertain" };
  }
  const normalizedPath = String(filePath).split(path.sep).join("/");
  const value = String(text || "");
  if (SECRET_PATH.test(normalizedPath) || SECRET_CONTENT.some((pattern) => pattern.test(value))) {
    return { class: "SECRET", reason: "secret_pattern" };
  }
  if (/data-classification\s*:\s*SECRET|@secret\b/i.test(value)) return { class: "SECRET", reason: "explicit_marker" };
  if (/data-classification\s*:\s*SENSITIVE|@sensitive\b/i.test(value)) return { class: "SENSITIVE", reason: "explicit_marker" };
  const sensitiveTerms = Array.isArray(policy.sensitive_path_terms) ? policy.sensitive_path_terms : [];
  if (sensitiveTerms.some((term) => normalizedPath.toLowerCase().includes(String(term).toLowerCase()))) {
    return { class: "SENSITIVE", reason: "sensitive_path" };
  }
  const publicMarkers = Array.isArray(policy.public_markers) ? policy.public_markers : [];
  if (publicMarkers.some((marker) => value.includes(marker))) return { class: "PUBLIC", reason: "explicit_marker" };
  const defaultClass = policy.default_class || "PROJECT";
  if (!DATA_CLASSES.includes(defaultClass)) return { class: "SENSITIVE", reason: "classification_uncertain" };
  return { class: defaultClass, reason: "default_policy" };
}

export function canEgress(classification, policy = {}) {
  return policy.external_egress?.[classification] === true;
}

// This result never contains the source text, so it is safe to use in metrics
// and routing decisions without retaining sensitive prompt material.
export function evaluateEgress({ filePath = "", text = "", policy = {} } = {}) {
  try {
    const classification = classifyData({ filePath, text, policy });
    if (!DATA_CLASSES.includes(classification.class) || classification.reason === "classification_uncertain") {
      return { allowed: false, class: "SENSITIVE", reason: "classification_uncertain" };
    }
    // A secret can never be made externally eligible by policy configuration.
    if (classification.class === "SECRET") {
      return { allowed: false, class: "SECRET", reason: classification.reason };
    }
    return {
      allowed: canEgress(classification.class, policy),
      class: classification.class,
      reason: classification.reason
    };
  } catch {
    return { allowed: false, class: "SENSITIVE", reason: "classification_uncertain" };
  }
}
