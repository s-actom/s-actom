// modelos.mjs — Adaptive Model Intelligence, subordinado à Direção Geral.
//
// Regras que este módulo garante (não as viola nem por omissão):
//  - não conhece nenhum identificador de modelo: tudo vem de equipas/modelos/autorizacao.json;
//  - pertencer a um fornecedor permitido NÃO autoriza: exige `autorizado:true` e `ativo:true`;
//  - sem modelo autorizado adequado devolve uma limitação, nunca um fallback não autorizado;
//  - o histórico é append-only e só tem metadados (nunca texto do pedido).
//
// Não decide delegação: `escolher()` é uma proposta para a Direção Geral, como o JEV.
import fs from "node:fs";
import path from "node:path";
import { BASE, ESTADO, lerJson } from "./comum.mjs";

export const AUTORIZACAO = path.join(BASE, "modelos", "autorizacao.json");
export const HISTORICO = path.join(ESTADO, "modelos.jsonl");
const MAX_LINHAS = 5000;
const CATEGORIA = /^[a-z_]{1,32}$/;

const PESOS_POR_OMISSAO = { qualidade: 0.5, fiabilidade: 0.2, velocidade: 0.15, custo: 0.15 };

function pesos(politica) {
  const p = politica?.pesos && typeof politica.pesos === "object" ? politica.pesos : {};
  const out = {};
  for (const [k, def] of Object.entries(PESOS_POR_OMISSAO)) {
    const v = Number(p[k]);
    out[k] = Number.isFinite(v) && v >= 0 ? v : def;
  }
  const soma = Object.values(out).reduce((a, b) => a + b, 0);
  if (!(soma > 0)) return { ...PESOS_POR_OMISSAO };
  for (const k of Object.keys(out)) out[k] /= soma; // normaliza: os pesos do registo são relativos
  return out;
}

// Carrega e valida. Falha fechada: qualquer erro de forma devolve ok:false e o chamador
// não deve escolher modelo nenhum.
export function carregarAutorizacao(caminho = AUTORIZACAO) {
  let cru;
  try {
    const st = fs.lstatSync(caminho);
    if (!st.isFile() || st.isSymbolicLink()) return { ok: false, motivo: "registo_inseguro" };
    cru = JSON.parse(fs.readFileSync(caminho, "utf8"));
  } catch {
    return { ok: false, motivo: "registo_ilegivel" };
  }
  const permitidos = Array.isArray(cru?.politica?.fornecedores_permitidos)
    ? cru.politica.fornecedores_permitidos.filter((f) => typeof f === "string" && f.trim())
    : [];
  if (!permitidos.length) return { ok: false, motivo: "sem_fornecedores_permitidos" };

  const invalidos = [];
  const vistos = new Set();
  const modelos = [];
  for (const m of Array.isArray(cru?.modelos) ? cru.modelos : []) {
    const id = typeof m?.id === "string" ? m.id.trim() : "";
    const fornecedor = typeof m?.fornecedor === "string" ? m.fornecedor.trim() : "";
    if (!id || !fornecedor || typeof m?.runtime !== "string" || typeof m?.acesso !== "string") {
      invalidos.push({ motivo: "campos_em_falta", id: id || null });
      continue;
    }
    if (vistos.has(id)) { invalidos.push({ motivo: "duplicado", id }); continue; }
    vistos.add(id);
    modelos.push({
      id, fornecedor, runtime: m.runtime, acesso: m.acesso,
      origem: typeof m.origem === "string" ? m.origem : null,
      ativo: m.ativo === true,
      autorizado: m.autorizado === true,
      preco: Number.isFinite(Number(m.preco)) ? Number(m.preco) : null,
    });
  }
  return {
    ok: true,
    versao: cru?.v ?? null,
    politica: {
      fornecedores_permitidos: permitidos,
      pesos: pesos(cru?.politica),
      min_amostras: Number.isFinite(Number(cru?.politica?.min_amostras)) ? Number(cru.politica.min_amostras) : 3,
    },
    modelos,
    invalidos,
  };
}

export const fornecedorPermitido = (reg, fornecedor) =>
  reg?.ok === true && reg.politica.fornecedores_permitidos.includes(fornecedor);

// Candidatos elegíveis: ativos, explicitamente autorizados e de fornecedor permitido.
export function autorizados(reg) {
  if (reg?.ok !== true) return [];
  return reg.modelos.filter((m) => m.ativo && m.autorizado && fornecedorPermitido(reg, m.fornecedor));
}

export function autorizado(reg, id) {
  return autorizados(reg).some((m) => m.id === id);
}

// --- histórico de execuções (append-only, metadados) ----------------------
export function lerHistorico(caminho = HISTORICO, maxLinhas = MAX_LINHAS) {
  let texto;
  try {
    const st = fs.lstatSync(caminho);
    if (!st.isFile() || st.isSymbolicLink()) return [];
    texto = fs.readFileSync(caminho, "utf8");
  } catch { return []; }
  const linhas = texto.split("\n").filter((l) => l.trim());
  const ultimas = linhas.slice(-maxLinhas);
  const out = [];
  for (const l of ultimas) {
    try {
      const r = JSON.parse(l);
      if (r && typeof r.modelo === "string" && typeof r.categoria === "string" && CATEGORIA.test(r.categoria)) out.push(r);
    } catch { /* linha ilegível não conta */ }
  }
  return out;
}

// Agrega por (categoria, modelo): sucesso, falha, sem_resultado, ms e custo médios.
export function agregar(linhas) {
  const acc = new Map();
  for (const r of linhas) {
    const chave = `${r.categoria}\u0000${r.modelo}`;
    let a = acc.get(chave);
    if (!a) { a = { categoria: r.categoria, modelo: r.modelo, n: 0, ok: 0, falhas: 0, sem_resultado: 0, msSoma: 0, msN: 0, custoSoma: 0, custoN: 0 }; acc.set(chave, a); }
    a.n += 1;
    if (r.estado === "ok") a.ok += 1;
    else if (r.estado === "falhou" || r.estado === "recusado_permissao") a.falhas += 1;
    else a.sem_resultado += 1;
    if (Number.isFinite(r.ms) && r.ms >= 0) { a.msSoma += r.ms; a.msN += 1; }
    if (Number.isFinite(r.custo) && r.custo >= 0) { a.custoSoma += r.custo; a.custoN += 1; }
  }
  for (const a of acc.values()) {
    a.msMedio = a.msN ? a.msSoma / a.msN : null;
    a.custoMedio = a.custoN ? a.custoSoma / a.custoN : null;
  }
  return acc;
}

// Pontuação transparente: qualidade (Laplace), fiabilidade, velocidade e custo.
// Sem amostras suficientes o valor é neutro e a decisão fica marcada `sem_dados`.
export function pontuar(stats, pesosEfetivos, minAmostras, preco) {
  if (!stats || stats.n < minAmostras) {
    return { pontuacao: 0.5, sem_dados: true, componentes: null };
  }
  const qualidade = (stats.ok + 1) / (stats.ok + stats.falhas + 2);
  const fiabilidade = 1 - (stats.sem_resultado + stats.falhas) / Math.max(1, stats.n);
  const velocidade = stats.msMedio == null ? 0.5 : 1 / (1 + stats.msMedio / 1000);
  const custoRef = stats.custoMedio ?? preco;
  const custo = custoRef == null ? 0.5 : 1 / (1 + custoRef);
  const p = pesosEfetivos;
  const pontuacao = qualidade * p.qualidade + fiabilidade * p.fiabilidade + velocidade * p.velocidade + custo * p.custo;
  return { pontuacao, sem_dados: false, componentes: { qualidade, fiabilidade, velocidade, custo } };
}

// Proposta de modelo para uma categoria de tarefa. Nunca devolve um id fora dos autorizados.
export function escolher(reg, historico, categoria) {
  if (reg?.ok !== true) return { limitacao: "registo_invalido", motivo: reg?.motivo ?? "desconhecido" };
  if (!CATEGORIA.test(String(categoria ?? ""))) return { limitacao: "categoria_invalida" };
  const candidatos = autorizados(reg);
  if (!candidatos.length) return { limitacao: "sem_modelo_autorizado" };

  const hist = (historico ?? []).filter((r) => r.categoria === categoria);
  const porModelo = agregar(hist);
  const p = reg.politica.pesos;
  const minA = reg.politica.min_amostras;

  const avaliados = candidatos.map((m) => {
    const stats = porModelo.get(`${categoria}\u0000${m.id}`) ?? null;
    const s = pontuar(stats, p, minA, m.preco);
    return { id: m.id, runtime: m.runtime, acesso: m.acesso, ...s, amostras: stats?.n ?? 0 };
  });
  // Desempate determinístico e sem nomes no código: maior pontuação, depois mais amostras, depois id.
  avaliados.sort((a, b) => (b.pontuacao - a.pontuacao) || (b.amostras - a.amostras) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  const melhor = avaliados[0];
  return {
    modelo: melhor.id,
    runtime: melhor.runtime,
    acesso: melhor.acesso,
    pontuacao: Number(melhor.pontuacao.toFixed(4)),
    sem_dados: melhor.sem_dados,
    componentes: melhor.componentes,
    amostras: melhor.amostras,
    alternativas: avaliados.slice(1).map((a) => ({ modelo: a.id, pontuacao: Number(a.pontuacao.toFixed(4)), amostras: a.amostras })),
  };
}

// Registo de uma execução observada. Só metadados; nunca texto.
export function registarExecucao({ sessao, turno, categoria, modelo, estado, ms, tokensIn, tokensOut, custo }, caminho = HISTORICO) {
  if (typeof modelo !== "string" || !modelo) return false;
  if (!CATEGORIA.test(String(categoria ?? ""))) return false;
  const reg = carregarAutorizacao();
  const linha = JSON.stringify({
    v: 1,
    ts: new Date().toISOString(),
    sessao: typeof sessao === "string" ? sessao.slice(0, 128) : null,
    turno: typeof turno === "string" ? turno.slice(0, 64) : null,
    categoria,
    modelo,
    // `autorizado:false` é observação (drift), não uso: permite detetar modelo fora da lista.
    autorizado: autorizado(reg, modelo),
    runtime: autorizados(reg).find((m) => m.id === modelo)?.runtime ?? null,
    estado: ["ok", "falhou", "sem_resultado", "recusado_permissao"].includes(estado) ? estado : "sem_resultado",
    ms: Number.isFinite(ms) ? Math.round(ms) : null,
    tokens_in: Number.isFinite(tokensIn) ? Math.round(tokensIn) : null,
    tokens_out: Number.isFinite(tokensOut) ? Math.round(tokensOut) : null,
    custo: Number.isFinite(custo) ? custo : null,
  });
  if (linha.length > 3500) return false; // < PIPE_BUF, como o registo.jsonl
  try {
    fs.mkdirSync(path.dirname(caminho), { recursive: true, mode: 0o700 });
    const fd = fs.openSync(caminho, fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_CREAT | fs.constants.O_NOFOLLOW, 0o600);
    try { fs.writeSync(fd, linha + "\n"); } finally { fs.closeSync(fd); }
    return true;
  } catch { return false; }
}

export const _lerJson = lerJson; // reexport util para os testes não irem ao comum
