// modelo-executado.mjs — identifica o modelo que o runtime executou e regista-o.
// Lê apenas a CAUDA do transcript local (o modelo do turno está nas últimas mensagens):
// não carrega o ficheiro inteiro, não guarda texto e nunca bloqueia.
import fs from "node:fs";
import { REGISTO, sessaoValida } from "./lib/comum.mjs";
import { registarExecucao, autorizado, carregarAutorizacao } from "./lib/modelos.mjs";

const CAUDA_BYTES = 256 * 1024;
const MAX_LINHAS_REGISTO = 400;
const CATEGORIA = /^[a-z_]{1,32}$/;

// Lê os últimos N bytes de um ficheiro (sem seguir ligações, sem ficheiros gigantes).
export function cauda(ficheiro, maxBytes = CAUDA_BYTES) {
  try {
    const st = fs.lstatSync(ficheiro);
    if (!st.isFile() || st.isSymbolicLink()) return "";
    const inicio = Math.max(0, st.size - maxBytes);
    const fd = fs.openSync(ficheiro, "r");
    try {
      const buf = Buffer.alloc(st.size - inicio);
      fs.readSync(fd, buf, 0, buf.length, inicio);
      return buf.toString("utf8");
    } finally { fs.closeSync(fd); }
  } catch { return ""; }
}

// Último `"model": "<id>"` encontrado na cauda. Devolve null se não houver.
export function ultimoModelo(texto) {
  if (typeof texto !== "string" || !texto) return null;
  const re = /"model"\s*:\s*"([^"\\\u0000-\u001f]{1,120})"/g;
  let m, ultimo = null;
  while ((m = re.exec(texto)) !== null) ultimo = m[1];
  return ultimo;
}

// Tokens do primeiro `usage` encontrado a andar de trás para a frente (o mais recente).
export function ultimoUso(texto) {
  if (typeof texto !== "string" || !texto) return null;
  const linhas = texto.split("\n").reverse();
  for (const l of linhas) {
    if (!l.includes('"usage"')) continue;
    try {
      const r = JSON.parse(l);
      const u = r?.message?.usage ?? r?.usage;
      if (u && typeof u === "object") {
        return { tokensIn: Number(u.input_tokens), tokensOut: Number(u.output_tokens) };
      }
    } catch { /* linha parcial da cauda: ignora */ }
  }
  return null;
}

// Categoria de trabalho do último objetivo da sessão (família `work` do envelope fechado).
// Sem objetivo legível devolve "geral" — nunca inventa uma categoria.
export function categoriaDaSessao(sessao, caminhoRegisto = REGISTO) {
  if (!sessaoValida(sessao)) return "geral";
  const texto = cauda(caminhoRegisto, 512 * 1024);
  if (!texto) return "geral";
  const linhas = texto.split("\n").filter((l) => l.trim());
  let visto = 0;
  for (let i = linhas.length - 1; i >= 0 && visto < MAX_LINHAS_REGISTO; i--, visto++) {
    let r;
    try { r = JSON.parse(linhas[i]); } catch { continue; }
    if (r?.sessao !== sessao) continue;
    if (r?.tipo === "objetivo" && typeof r?.envelope === "string") {
      const w = r.envelope.match(/(?:^|;)work=([a-z_]{1,32})(?:;|$)/);
      if (w && CATEGORIA.test(w[1])) return w[1];
      return "geral";
    }
  }
  return "geral";
}

// Junta o que é observável de um turno. `estado` tem de vir do chamador (é quem sabe o resultado).
export function observar({ sessao, turno = null, ficheiro, estado = "sem_resultado", ms = null, categoria = null }) {
  const texto = ficheiro ? cauda(ficheiro) : "";
  const modelo = ultimoModelo(texto);
  if (!modelo) return null;
  const uso = ultimoUso(texto);
  const cat = categoria && CATEGORIA.test(categoria) ? categoria : categoriaDaSessao(sessao);
  const reg = carregarAutorizacao();
  return {
    sessao, turno, categoria: cat, modelo,
    autorizado: autorizado(reg, modelo),
    estado, ms, tokensIn: uso?.tokensIn, tokensOut: uso?.tokensOut,
  };
}

// Regista (append-only). Devolve o que registou, ou null se não havia modelo legível.
export function registarTurno(opcoes) {
  const obs = observar(opcoes);
  if (!obs) return null;
  const ok = registarExecucao(obs);
  return ok ? obs : null;
}
