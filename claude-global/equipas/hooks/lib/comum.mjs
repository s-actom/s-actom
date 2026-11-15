// comum.mjs — peças partilhadas pelos hooks da Fase 1 (Direção Geral).
// Regras: nunca guardar o texto do pedido; falhar em aberto; escrever só dentro de BASE.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const BASE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
export const HOOKS = path.join(BASE, "hooks");
export const ESTADO = path.join(BASE, "estado");
export const REGISTO = path.join(BASE, "registo.jsonl");
export const MARCA = path.join(BASE, "FASE-1-ATIVA");
export const TESTE = process.env.EQUIPAS_TESTE === "1";

const MAX_ENTRADA = 1 << 20;
const MAX_LINHA = 3500; // < PIPE_BUF: append de uma linha fica atómico entre processos

export const ativa = () => fs.existsSync(MARCA);

export async function lerEntrada() {
  const partes = [];
  let total = 0;
  for await (const p of process.stdin) {
    total += p.length;
    if (total > MAX_ENTRADA) return null;
    partes.push(p);
  }
  try { return JSON.parse(Buffer.concat(partes).toString("utf8")); } catch { return null; }
}

export const sessaoValida = (id) => typeof id === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(id);

// Texto de terceiros ou do orquestrador: sem controlo, invisíveis nem quebras; cortado.
export function limpar(texto, max = 120) {
  if (typeof texto !== "string") return "";
  const t = texto.normalize("NFKC")
    .replace(/[\p{Cc}\p{Cf}\p{Co}\p{Cn}\p{Default_Ignorable_Code_Point}᠋-᠏︀-️]/gu, " ")
    .replace(/\s+/g, " ").trim();
  return t.length > max ? t.slice(0, max - 1) + "…" : t;
}

function garantirPasta(p) {
  fs.mkdirSync(p, { recursive: true, mode: 0o700 });
  const st = fs.lstatSync(p);
  if (!st.isDirectory() || st.isSymbolicLink()) throw new Error("pasta insegura");
}

export function registar(entrada) {
  const linha = JSON.stringify({ v: 1, ...entrada, ...(TESTE ? { teste: true } : {}) });
  if (linha.length > MAX_LINHA) throw new Error("linha demasiado grande");
  const fd = fs.openSync(REGISTO, fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_CREAT | fs.constants.O_NOFOLLOW, 0o600);
  try { fs.writeSync(fd, linha + "\n"); } finally { fs.closeSync(fd); }
}

export function lerJson(p, def) {
  try {
    if (fs.lstatSync(p).isSymbolicLink()) return def;
    return JSON.parse(fs.readFileSync(p, "utf8"));
  } catch { return def; }
}

export function escreverJson(p, valor) {
  garantirPasta(path.dirname(p));
  const tmp = `${p}.${process.pid}.${Date.now()}.tmp`;
  const fd = fs.openSync(tmp, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW, 0o600);
  try { fs.writeSync(fd, JSON.stringify(valor)); } finally { fs.closeSync(fd); }
  fs.renameSync(tmp, p);
}

const ficheiroSessao = (id) => path.join(ESTADO, "sessoes", `${id}.json`);
export const lerSessao = (id) => lerJson(ficheiroSessao(id), {});
export const guardarSessao = (id, s) => escreverJson(ficheiroSessao(id), s);

export function catalogo() {
  const c = lerJson(path.join(HOOKS, "lib", "equipas.json"), []);
  return Array.isArray(c) ? c.filter((e) => e && /^[a-z]+$/.test(e.slug)) : [];
}

export function responder(objeto) { process.stdout.write(JSON.stringify(objeto)); }
