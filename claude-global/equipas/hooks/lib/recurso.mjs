// recurso.mjs — verifica a resposta do conector antes de a chamar de "ok".
// Guarda só metadados (hashes, host, booleanos); nunca conteúdo, título ou o pedido.
import crypto from "node:crypto";

const ALVO = /^mcp__claude_ai_Context_dev__(web-scrape|web-search|web-crawl)$/;
export const ferramentaAlvo = (nome) => ALVO.test(String(nome || ""));

const sha = (v) => crypto.createHash("sha256").update(String(v)).digest("hex");

function textoDe(resp) {
  if (resp == null) return "";
  if (typeof resp === "string") return resp;
  if (Array.isArray(resp)) {
    return resp.map((c) => (typeof c === "string" ? c : typeof c?.text === "string" ? c.text : "")).join("\n");
  }
  if (Array.isArray(resp?.content)) {
    return resp.content.map((c) => (typeof c?.text === "string" ? c.text : "")).join("\n");
  }
  return "";
}

// A resposta chega como objeto ou como texto JSON dentro de content[].text.
function objeto(resp) {
  if (Array.isArray(resp)) {
    try { return JSON.parse(textoDe(resp)); } catch { return null; }
  }
  if (resp && typeof resp === "object") {
    if (resp.content) {
      const t = textoDe(resp);
      try { return JSON.parse(t); } catch { /* fica o envelope */ }
    }
    return resp;
  }
  if (typeof resp === "string") {
    try { return JSON.parse(resp); } catch { return null; }
  }
  return null;
}

// Procura em profundidade limitada; devolve a primeira chave encontrada.
function achar(obj, nomes, prof = 0) {
  if (!obj || typeof obj !== "object" || prof > 6) return undefined;
  for (const n of nomes) {
    if (Object.prototype.hasOwnProperty.call(obj, n)) return { chave: n, valor: obj[n] };
  }
  for (const v of Object.values(obj)) {
    const r = achar(v, nomes, prof + 1);
    if (r) return r;
  }
  return undefined;
}

// Normaliza para comparar: host minúsculo, barra final fora da raiz, query preservada (ordem normalizada).
export function normalizar(url) {
  const x = new URL(url);
  const host = x.hostname.toLowerCase();
  let caminho = x.pathname || "/";
  if (caminho.length > 1) caminho = caminho.replace(/\/+$/u, "");
  const query = [...x.searchParams.entries()]
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0))
    .map(([k, v]) => `${k}=${v}`)
    .join("&");
  return { host, caminho, query };
}

const canonico = (n) => `${n.host}${n.caminho}?${n.query}`;

// Estados: ok | nao_verificavel | falhou. Motivos: url_diferente, conteudo_invalido, sem_prova_url_final, ...
export function verificar({ ferramenta, entrada, resposta }) {
  const o = objeto(resposta);
  const pedido = typeof entrada?.url === "string" ? entrada.url : null;
  const base = { caracteres: 0, tem_titulo: false, evidencia_url: "ausente",
    ...(pedido ? { url_pedida_sha256: sha(pedido) } : {}) };
  if (!o) return { ...base, estado: "falhou", motivo: "resposta_ilegivel" };

  const md = achar(o, ["markdown"]);
  const mdData = md?.valor && typeof md.valor === "object" ? md.valor.data : undefined;
  const chars = typeof mdData === "string" ? mdData.length : 0;
  const meta = achar(o, ["metadata"]);
  const titulo = meta?.valor && typeof meta.valor === "object" ? meta.valor.title : undefined;
  base.caracteres = chars;
  base.tem_titulo = typeof titulo === "string" && titulo.trim() !== "";

  const fin = achar(o, ["finalUrl", "final_url", "finalURL", "sourceURL", "requestUrl"]);
  const eco = achar(o, ["url"]);
  const rid = achar(o, ["request_id", "requestId"]);
  let reportado = null;
  let evid = "ausente";
  if (fin && typeof fin.valor === "string") { reportado = fin.valor; evid = "finalUrl"; }
  else if (eco && typeof eco.valor === "string" && (rid || meta)) { reportado = eco.valor; evid = "conector"; }
  else if (eco && typeof eco.valor === "string") { reportado = eco.valor; evid = "eco"; }
  base.evidencia_url = evid;
  if (reportado) base.url_final_sha256 = sha(reportado);

  // Pesquisa/notícias: não há uma página pedida; ok exige resultados ou conteúdo útil.
  if (String(ferramenta).includes("web-search")) {
    const res = achar(o, ["results"]);
    const n = Array.isArray(res?.valor) ? res.valor.length : 0;
    if (n > 0 || chars >= 200) return { ...base, estado: "ok", motivo: null };
    return { ...base, estado: "nao_verificavel", motivo: "sem_resultados" };
  }

  if (!pedido) return { ...base, estado: "nao_verificavel", motivo: "sem_url_pedida" };
  if (evid === "eco" || evid === "ausente") return { ...base, estado: "nao_verificavel", motivo: "sem_prova_url_final" };

  let a, b;
  try { a = normalizar(pedido); b = normalizar(reportado); }
  catch { return { ...base, estado: "nao_verificavel", motivo: "url_invalida" }; }

  const cmp = { host: a.host, caminho_igual: a.caminho === b.caminho, query_igual: a.query === b.query,
    redirecionou: canonico(a) !== canonico(b) };
  if (a.host !== b.host || a.caminho !== b.caminho || a.query !== b.query) {
    return { ...base, ...cmp, estado: "falhou", motivo: "url_diferente" };
  }
  if (chars < 200) return { ...base, ...cmp, estado: "falhou", motivo: "conteudo_invalido" };
  return { ...base, ...cmp, estado: "ok", motivo: null };
}
