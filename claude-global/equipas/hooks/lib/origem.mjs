// origem.mjs — de onde veio cada objetivo (dono, app ou outra sessão), lido do transcript local.
// Só os pedidos com turnOrigin "human" são objetivos do dono: mensagens da app, notificações e briefs
// de outras sessões não contam para os 30. Lê metadados; o texto só sai para o ficheiro de revisão do dono.
import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import { sessaoValida } from "./comum.mjs";

export const TURNO_OK = /^[0-9a-f-]{8,64}$/i;
const ORIGEM_OK = /^[a-z_]{1,24}$/;
const LIMITE_BYTES = 64 * 1024 * 1024;
const DIA_MS = 24 * 3600 * 1000;

const linhas = (texto) => String(texto || "").split("\n").flatMap((l) => {
  if (!l.trim()) return [];
  try { const r = JSON.parse(l); return r && typeof r === "object" ? [r] : []; } catch { return []; }
});
export const lerRegisto = linhas;

// Objetivos que contam para a comparação: reais (não teste), com resposta do JEV, um por sessão + turno.
export function objetivosReais(texto) {
  const vistos = new Set();
  return linhas(texto).filter((r) => {
    if (r.tipo !== "objetivo" || r.teste === true || !["ok", "abaixo_limiar"].includes(r.jev?.estado)) return false;
    if (!sessaoValida(r.sessao) || !TURNO_OK.test(String(r.turno ?? ""))) return false;
    const chave = `${r.sessao}/${r.turno}`;
    if (vistos.has(chave)) return false; // a app pode repetir o UserPromptSubmit no mesmo turno
    vistos.add(chave);
    return true;
  });
}

export const chaveDe = (o) => `${o.sessao}/${o.turno}`;

export function limparCache(c) {
  const out = {};
  if (!c || typeof c !== "object" || Array.isArray(c)) return out;
  for (const [k, v] of Object.entries(c)) {
    const [s, t, ...resto] = k.split("/");
    if (!resto.length && sessaoValida(s) && TURNO_OK.test(t ?? "") && typeof v === "string" && ORIGEM_OK.test(v)) out[k] = v;
  }
  return out;
}

export function transcriptDe(sessao, home = process.env.HOME || "") {
  if (!sessaoValida(sessao) || !home) return null;
  const projetos = path.join(home, ".claude", "projects");
  let pastas;
  try { pastas = fs.readdirSync(projetos, { withFileTypes: true }); } catch { return null; }
  for (const d of pastas) {
    if (!d.isDirectory()) continue; // pastas ligadas por symlink não contam
    const f = path.join(projetos, d.name, `${sessao}.jsonl`);
    try { if (fs.lstatSync(f).isFile()) return f; } catch { /* não está nesta pasta */ }
  }
  return null;
}

const ehPedido = (r) => r?.type === "user" && typeof r.promptId === "string" && !r.toolUseResult && !r.isMeta &&
  !(Array.isArray(r.message?.content) && r.message.content.some((b) => b?.type === "tool_result"));

// Lê o turno: a entrada do pedido e o texto que o orquestrador escreveu até ao pedido seguinte.
// Sem o pedido nos primeiros `limite` bytes de um ficheiro maior: { cortado: true } (não é "ausente").
export async function lerTurno(ficheiro, turno, { comResposta = false, limite = LIMITE_BYTES } = {}) {
  if (!ficheiro || !TURNO_OK.test(String(turno))) return null;
  let fd;
  let tamanho;
  try {
    fd = fs.openSync(ficheiro, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    const st = fs.fstatSync(fd);
    if (!st.isFile()) { fs.closeSync(fd); return null; }
    tamanho = st.size;
  } catch { if (fd !== undefined) fs.closeSync(fd); return null; }
  const input = fs.createReadStream(ficheiro, { fd, encoding: "utf8", end: Number.isFinite(limite) ? limite - 1 : undefined });
  const rl = readline.createInterface({ input, crlfDelay: Infinity });
  let pedido = null;
  const resposta = [];
  try {
    for await (const l of rl) {
      if (!pedido && !l.includes(turno)) continue;
      let r;
      try { r = JSON.parse(l); } catch { continue; }
      if (!pedido) {
        if (ehPedido(r) && r.promptId === turno) { pedido = r; if (!comResposta) break; }
        continue;
      }
      if (ehPedido(r) && r.promptId !== turno) break;
      if (r?.type === "assistant" && Array.isArray(r.message?.content)) {
        for (const b of r.message.content) if (b?.type === "text" && typeof b.text === "string") resposta.push(b.text);
      }
    }
  } catch { /* ficheiro ilegível */ }
  finally { rl.close(); input.destroy(); }
  if (pedido) return { pedido, resposta: resposta.join("\n") };
  return tamanho > limite ? { cortado: true } : null;
}

export const origemDe = (pedido) => typeof pedido?.turnOrigin === "string" && ORIGEM_OK.test(pedido.turnOrigin) ? pedido.turnOrigin : "desconhecida";

export function textoDe(pedido) {
  const c = pedido?.message?.content;
  if (typeof c === "string") return c;
  return Array.isArray(c) ? c.filter((b) => b?.type === "text" && typeof b.text === "string").map((b) => b.text).join("\n") : "";
}

// Classifica os objetivos ainda sem origem. Sem o pedido no transcript: tenta de novo, salvo se já passou um dia.
export async function classificar(objetivos, cache, { home = process.env.HOME || "", prazoMs = Infinity, agora = Date.now(), limite = LIMITE_BYTES } = {}) {
  const novo = { ...limparCache(cache) };
  const t0 = Date.now();
  for (const o of objetivos) {
    const chave = chaveDe(o);
    if (novo[chave]) continue;
    if (Date.now() - t0 > prazoMs) break;
    const t = await lerTurno(transcriptDe(o.sessao, home), o.turno, { limite });
    if (t?.pedido) novo[chave] = origemDe(t.pedido);
    else if (!t?.cortado && agora - Date.parse(o.ts) > DIA_MS) novo[chave] = "ausente";
  }
  return novo;
}
