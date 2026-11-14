// jev.mjs — adaptador pequeno do JEV (TypeSafe) para a Direção Geral, Fase 1.
// O JEV só recebe etiquetas de listas fechadas e o catálogo das 15 equipas: nunca o texto do pedido.
// A chave vem só de TYPESAFE_API_KEY no ambiente; nunca é escrita, impressa nem lida do keychain.
import { buildRoutingEnvelope, evaluateEgress } from "./privado.mjs";
import { lerJson, escreverJson, limpar } from "./comum.mjs";

const URL_JEV = "https://api.typesafe.ai/v1/systemone"; // fixo: a chave não pode ir para outro destino
const MODELO = "jev-latest";
export const LIMITE_DIARIO = 60;
export const PRAZO_MS = 2000;
export const LIMIAR = 0.5;
const MAX_EQUIPAS = 5;

// Vocabulário de trabalho por equipa (palavras genéricas, sem acentos). Só estas saem, e só se aparecerem.
const TEMAS = [
  "seo", "geo", "anuncio", "anuncios", "ads", "campanha", "campanhas", "cro", "conversao", "copy", "copywriting", "social", "instagram", "tiktok", "newsletter", "marketing", "landing", "branding", "marca",
  "seguranca", "auditoria", "pentest", "vulnerabilidade", "vulnerabilidades", "owasp", "ameaca", "ameacas", "cve", "exploit",
  "codigo", "frontend", "backend", "api", "apis", "react", "nextjs", "typescript", "javascript", "python", "node", "app", "aplicacao", "funcionalidade", "bug", "componente", "site", "website", "pagina", "web", "projeto",
  "design", "figma", "stitch", "interface", "ui", "ux", "layout", "animacao", "animacoes", "prototipo", "mockup", "visual", "tipografia",
  "teste", "testes", "qa", "tdd", "e2e", "playwright", "revisao", "review", "coderabbit", "cobertura", "regressao",
  "llm", "rag", "eval", "evals", "prompt", "prompts", "modelo", "modelos", "embeddings", "ia", "ai", "chatbot", "agente", "agentes",
  "video", "videos", "imagem", "imagens", "foto", "fotos", "audio", "musica", "remotion", "higgsfield", "blender", "render",
  "three", "threejs", "webgl", "gltf", "glb", "ffmpeg", "codec", "transcode",
  "shopify", "loja", "catalogo", "checkout", "produto", "produtos", "carrinho", "encomenda", "encomendas", "pagamento", "pagamentos", "stripe", "ecommerce",
  "vendas", "lead", "leads", "prospecao", "crm", "outreach", "cliente", "clientes", "proposta", "pipeline",
  "github", "git", "vercel", "docker", "deploy", "servidor", "dominio", "dns", "hosting", "cloud", "producao", "release",
  "pesquisa", "pesquisar", "research", "investigar", "documentacao", "docs", "comparar", "browser", "scraping", "apify",
  "solana", "helius", "token", "tokens", "contrato", "contratos", "defi", "wallet", "carteira", "crypto", "cripto", "nft", "blockchain", "mainnet", "devnet",
  "ghidra", "binario", "descompilar", "reversa", "apk", "firmware",
  "documento", "documentos", "docx", "pdf", "xlsx", "excel", "pptx", "apresentacao", "relatorio", "relatorios", "folha", "notas", "dados", "analytics", "dashboard",
  "conteudo", "extrai", "extrair", "extract", "scrape", "fetch", "markdown", "titulo", "url", "page", "pagina", "web", "news", "noticias", "noticia", "artigo", "fonte", "fontes", "recolher", "procurar",
  "hook", "hooks", "skill", "skills", "plugin", "plugins", "mcp", "settings", "configuracao", "claude", "subagente", "comando", "comandos"
];
const TEMAS_SET = new Set(TEMAS);
// Listas fechadas do envelope. TERMOS_ROUTER = ROUTING_TERMS de privado.mjs + os 2 que ele acrescenta (um teste compara).
export const TERMOS_ROUTER = new Set(["answer","explain","inspect","review","implement","create","write","edit","fix","correct","continue","cancel","question","ask","new","task","debug","test","verify","research","design","architecture","deploy","security","authentication","authorization","database","api","backend","frontend","mobile","ios","android","cloud","network","observability","javascript","typescript","python","rust","go","java","swift","react","next","vue","svelte","postgres","supabase","solana","docker","kubernetes","marketing","documentation","document","docs","offers","offer","competitors","competitor","plan","agents","agent","commerce","ecommerce","shop","store","loja","retalho","product","products","produto","produtos","cart","carrinho","checkout","marketplace","responde","explica","inspeciona","revê","rever","implementa","cria","escreve","edita","corrige","continua","avança","cancela","cancelar","pergunta","novo","tarefa","depura","testa","verifica","pesquisa","desenha","arquitetura","segurança","oferta","ofertas","concorrente","concorrentes","plano","agente","agentes","lança","extract","extrai","extrair","scrape","scraping","fetch","recolher","procurar","markdown","content","conteudo","title","titulo","page","pagina","url","web","news","noticias","noticia","article","artigo","sources","fontes","three","threejs","webgl","gltf","glb","ffmpeg","codec","transcode","ui","accessibility"]);
const TRABALHOS = new Set(["general", "production_deployment", "accessibility_audit", "visual_ui_review", "frontend_implementation", "marketing_copy", "agent_orchestration", "web_research"]);
const DOMINIOS = new Set(["frontend_web", "marketing_content", "ui_visual_review", "accessibility_review", "deployment_operations", "agent_orchestration", "payments", "business_strategy", "ecommerce", "research_web"]);
const SINAIS = new Set(["contains_code_block", "contains_path", "contains_url", "question_form", "contains_failure_signal", "contains_high_risk_signal"]);

export function envelopeFechado(env) {
  const m = typeof env === "string" && env.match(/^@public;sz=([sml]);work=([a-z_]+);terms=([^;]+);domains=([^;]+);flags=([^;]+);temas=([^;]+)$/u);
  if (!m) return false;
  const dentro = (valor, conjunto) => valor === "-" || valor.split(",").every((x) => conjunto.has(x));
  return TRABALHOS.has(m[2]) && dentro(m[3], TERMOS_ROUTER) && dentro(m[4], DOMINIOS) && dentro(m[5], SINAIS) && dentro(m[6], TEMAS_SET);
}

// Segredos que o detetor do router não cobre. Na dúvida, é segredo: o pedido só deixa de ir ao JEV.
const SEGREDOS_LOCAIS = [
  /\b[rsp]k_(?:live|test)_[A-Za-z0-9]{10,}/,                      // Stripe
  /\bAIza[0-9A-Za-z_-]{30,}/,                                      // Google
  /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/,  // JWT
  /\b[a-z][a-z0-9+.-]*:\/\/[^\s/:@]+:[^\s/@]+@/i,                  // URL com credenciais
  /\b[1-9A-HJ-NP-Za-km-z]{64,}\b/,                                 // chave base58 (ex.: Solana)
  /\b(?:0x)?[0-9a-fA-F]{64}\b/,                                    // chave hexadecimal de 32 bytes
  /\b(?:password|passwd|palavra-passe|senha|pass|token|secret|segredo|chave)\b\s*(?:é|is|=|:)\s*\S{4,}/i,
  /\b(?:seed|mnemonic|recovery|semente|recupera[cç][aã]o)\b[\s\S]{0,120}?(?:\b[a-z]{3,8}\b[\s,]+){11}\b[a-z]{3,8}\b/i // intervalo limitado: sem tempo quadrático
];
export const segredoLocal = (texto) => SEGREDOS_LOCAIS.some((p) => p.test(String(texto || "")));

export const palavras = (texto) =>
  String(texto || "").toLowerCase().normalize("NFD").replace(/\p{Diacritic}/gu, "").match(/[a-z0-9]+/g) || [];

export function etiquetas(texto) {
  const vistos = new Set(palavras(texto));
  const temas = [...TEMAS_SET].filter((t) => vistos.has(t));
  return `${buildRoutingEnvelope(texto)};temas=${temas.length ? temas.join(",") : "-"}`;
}

// SECRET e SENSITIVE nunca chamam o JEV.
export function classe(texto) {
  if (segredoLocal(texto)) return "SECRET";
  return evaluateEgress({ text: texto, policy: { default_class: "PROJECT", external_egress: { PUBLIC: true, PROJECT: true } } }).class;
}

// Razão do orquestrador → só as etiquetas das listas fechadas (termos e temas). Nunca texto livre.
export function etiquetasRazao(texto) {
  const m = etiquetas(texto).match(/;terms=([^;]+);domains=[^;]+;flags=[^;]+;temas=([^;]+)$/u);
  const lista = m ? [...m[1].split(","), ...m[2].split(",")].filter((x) => x !== "-") : [];
  return lista.length ? [...new Set(lista)].slice(0, 12).join(",") : null;
}

const diaLocal = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;

export async function proporEquipas({ envelope, catalogo, estadoPath, chave = process.env.TYPESAFE_API_KEY,
  fetchImpl = globalThis.fetch, agora = new Date(), limite = LIMITE_DIARIO, prazoMs = PRAZO_MS }) {
  const t0 = Date.now();
  const fim = (o) => ({ ...o, ms: Date.now() - t0 });
  if (!envelopeFechado(envelope)) return fim({ estado: "indisponivel", motivo: "envelope_invalido" });
  if (!Array.isArray(catalogo) || catalogo.length === 0) return fim({ estado: "indisponivel", motivo: "sem_catalogo" });
  if (!chave) return fim({ estado: "indisponivel", motivo: "sem_chave" });
  const dia = diaLocal(agora);
  const est = lerJson(estadoPath, {});
  if (typeof est.desligado_ate === "string" && est.desligado_ate > dia) return fim({ estado: "indisponivel", motivo: "disjuntor" });
  const chamadas = est.dia === dia && Number.isInteger(est.chamadas) ? est.chamadas : 0;
  if (chamadas >= limite) return fim({ estado: "indisponivel", motivo: "teto_diario" });
  // shortcut: sem lock entre sessões simultâneas o teto pode passar por 1 ou 2; rever se o uso real o mostrar
  escreverJson(estadoPath, { ...est, dia, chamadas: chamadas + 1 }); // conta antes de chamar: falhas também gastam

  const questions = Object.fromEntries(catalogo.map((e, i) => ["team_" + i, { type: "noul", instructions: "The task requires this team: " + e.slug }]));
  const teams = catalogo.map((e) => ({ id: e.slug, name: e.nome, description: e.descricao }));
  const body = JSON.stringify({ state: { envelope, teams }, questions, model: MODELO });
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), Math.min(prazoMs, PRAZO_MS));
  try {
    const res = await fetchImpl(URL_JEV, {
      method: "POST", redirect: "error", signal: ctl.signal, body,
      headers: { Authorization: `Bearer ${chave}`, "Content-Type": "application/json" }
    });
    if (res.status === 429 || res.status === 529) {
      const amanha = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + 1);
      escreverJson(estadoPath, { ...lerJson(estadoPath, {}), desligado_ate: diaLocal(amanha), motivo: "http_" + res.status });
      return fim({ estado: "indisponivel", motivo: "limite_" + res.status });
    }
    if (!res.ok) return fim({ estado: "indisponivel", motivo: "http_" + res.status });
    const dados = await res.json();
    const lista = catalogo.map((e, i) => ({ id: e.slug, v: dados?.answers?.["team_" + i]?.noul }));
    if (lista.some((r) => !Number.isFinite(r.v) || r.v < 0 || r.v > 1)) return fim({ estado: "indisponivel", motivo: "resposta_invalida" });
    lista.sort((a, b) => b.v - a.v || a.id.localeCompare(b.id));
    const scores = Object.fromEntries(lista.map((r) => [r.id, Math.round(r.v * 1000) / 1000]));
    const extra = { scores, modelo: limpar(String(dados?.model ?? ""), 40).replace(/[^A-Za-z0-9._-]/g, "") || null,
      tokens: Number.isInteger(dados?.usage?.input_tokens) ? dados.usage.input_tokens : null };
    const sel = lista.filter((r) => r.v >= LIMIAR).slice(0, MAX_EQUIPAS);
    if (!sel.length) return fim({ estado: "abaixo_limiar", ...extra });
    return fim({ estado: "ok", primaria: sel[0].id, colaboradoras: sel.slice(1).map((r) => r.id), ...extra });
  } catch (e) {
    return fim({ estado: "indisponivel", motivo: e?.name === "AbortError" ? "prazo" : "falha_rede" });
  } finally {
    clearTimeout(timer);
  }
}
