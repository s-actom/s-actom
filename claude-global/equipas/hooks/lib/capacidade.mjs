// capacidade.mjs — liga a equipa Pesquisa ao recurso certo, sem enviar texto do pedido para fora.
// Só lê o pedido localmente; devolve etiquetas de capacidade e o URL público. O URL nunca vai para o registo.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const AQUI = path.dirname(fileURLToPath(import.meta.url));
const FICHEIRO = path.join(AQUI, "recursos.json");
const TOOL = /^mcp__[A-Za-z0-9_]+__[A-Za-z0-9_-]+$/;

export function recursos() {
  try {
    const r = JSON.parse(fs.readFileSync(FICHEIRO, "utf8"));
    const ok = (v) => (typeof v === "string" && TOOL.test(v) ? v : null);
    return { web_extract: ok(r.web_extract), web_search: ok(r.web_search) };
  } catch {
    return { web_extract: null, web_search: null };
  }
}

const URL_RE = /https:\/\/[^\s<>"'`)\]]+/gi;
const CREDENCIAIS = /^https:\/\/[^/\s]+@/i;
function hostPrivado(host) {
  const h = String(host || "").toLowerCase();
  return h === "localhost" || h === "::1" || h === "[::1]" || h === "0.0.0.0" || h.endsWith(".local") ||
    /^127\./u.test(h) || /^10\./u.test(h) || /^192\.168\./u.test(h) || /^169\.254\./u.test(h) ||
    /^172\.(?:1[6-9]|2\d|3[01])\./u.test(h);
}
const EXTRAI = /\b(extrai|extrair|extract|scrape|scraping|descarrega|descarregar|download|converte|converter|obtem|obter|recolhe|recolher|ler|lê)\b/i;
const CONTEUDO = /\b(conteudo|conteúdo|markdown|html|texto|titulo|título|pagina|página|artigo|artigos)\b/i;
const PESQUISA = /\b(pesquisa|pesquisar|procurar|procura|search|encontra|encontrar|noticias|notícias|noticia|notícia|news|manchetes|headlines|fontes|sources|atualidade|ultimas|últimas)\b/i;
const NOTICIAS = /\b(noticias|notícias|noticia|notícia|news|manchetes|headlines)\b/i;
const PREFERENCIA = /\b(context\.dev|contextdev|web-scrape|web-search|web-crawl|webfetch|web fetch|curl|playwright|apify|context7|browser|mcp__[a-z0-9_]+)\b/i;
const SEM_WEB = /\b(sem internet|offline|nao uses a web|não uses a web|nao uses internet|não uses internet|usa (apenas|so|só) o texto|com base no texto|usa o texto (acima|fornecido|colado))\b/i;

// O primeiro URL https público. Rejeita localhost, IP privado e credenciais embutidas.
export function urlPublica(texto) {
  const urls = String(texto || "").match(URL_RE) || [];
  for (const bruto of urls) {
    const u = bruto.replace(/[.,;:!?]+$/u, "");
    if (CREDENCIAIS.test(u)) continue;
    try {
      const x = new URL(u);
      if (x.protocol !== "https:") continue;
      if (hostPrivado(x.hostname)) continue;
      return u;
    } catch { /* URL inválido */ }
  }
  return null;
}

// Capacidade pretendida. "web_extract" = URL conhecida (inclui ler um artigo); "web_search" = descobrir sem URL.
export function detetar(texto) {
  const t = String(texto || "");
  const url = urlPublica(t);
  const preferencia = PREFERENCIA.test(t);
  if (SEM_WEB.test(t)) return { capacidade: null, url: null, preferencia, motivo: "sem_web" };
  const extrai = EXTRAI.test(t) || (url && CONTEUDO.test(t));
  const pesquisa = PESQUISA.test(t);
  const noticias = NOTICIAS.test(t);
  if (url && extrai) return { capacidade: "web_extract", url, preferencia, motivo: "url_conhecida" };
  if (pesquisa) return { capacidade: "web_search", url: null, preferencia, motivo: noticias ? "noticias" : "pesquisa" };
  return { capacidade: null, url: null, preferencia, motivo: "sem_capacidade" };
}

// Equipa: o modelo manda quando acerta em Pesquisa; a regra só cobre intenção clara abaixo do limiar.
export function decidir(jev, det) {
  if (jev?.estado === "ok" && jev.primaria === "pesquisa") return { equipa: "pesquisa", origem: "modelo" };
  if (jev?.estado === "abaixo_limiar" && det?.capacidade && !det.preferencia) return { equipa: "pesquisa", origem: "regra" };
  return null;
}

// Recurso: extração para página conhecida, pesquisa para notícias/descoberta. Preferência explícita nunca é sobreposta.
export function selecionar(det, mapa = recursos()) {
  if (!det?.capacidade) return null;
  if (det.preferencia) return { tipo: det.capacidade, ferramenta: null, motivo: "preferencia_explicita" };
  const f = det.capacidade === "web_extract" ? mapa.web_extract : mapa.web_search;
  if (!f) {
    return { tipo: det.capacidade, ferramenta: null,
      motivo: det.capacidade === "web_search" ? "sem_ferramenta_pesquisa" : "contextdev_indisponivel" };
  }
  return { tipo: det.capacidade, ferramenta: f, motivo: null };
}
