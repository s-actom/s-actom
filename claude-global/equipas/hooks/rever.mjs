// rever.mjs — revisão do JEV pelo dono: fim da Fase 1 e cada 30 casos da Fase 2 (desenho, secção 8).
// gerar: todos os desacordos + 5 acordos ao acaso, sem casos já revistos → ficheiro privado (0600, pasta 0700) em
//   ~/Library/Application Support/equipas-revisoes/, fora de ~/.claude (repo git, CodeRabbit). O pedido (≤ 300 caracteres,
//   omitido se parecer ter um segredo) e a linha "JEV: X. Eu: Y. Porquê: Z." vêm do transcript local (sessão + prompt_id)
//   e só ficam nesse ficheiro, para o dono. No terminal saem só contagens (o caminho só num terminal do dono).
// contar <ficheiro>: lê os vereditos e compara JEV e orquestrador; com tudo marcado, apaga do ficheiro pedidos e correções.
// Retenção: ficheiros com mais de 14 dias são apagados no gerar seguinte. O assistente não abre estes ficheiros.
// Uso: node ~/.claude/equipas/hooks/rever.mjs gerar | contar <ficheiro>
import fs from "node:fs";
import path from "node:path";
import { randomInt } from "node:crypto";
import { REGISTO, ESTADO, lerJson, escreverJson, limpar, sessaoValida } from "./lib/comum.mjs";
import { classe } from "./lib/jev.mjs";
import { lerRegisto, objetivosReais, classificar, chaveDe, transcriptDe, lerTurno, textoDe } from "./lib/origem.mjs";

export const ACORDOS_AO_ACASO = 5;
const PASTA = path.join(process.env.HOME || "/nao-existe", "Library", "Application Support", "equipas-revisoes");
const HISTORICO = path.join(ESTADO, "revisoes.jsonl");
const RETENCAO_MS = 14 * 24 * 3600 * 1000;
const NOME = /^revisao-[0-9T]+-[0-9]+\.txt$/;
const APAGADO = "(apagado depois da contagem)";
const ORIGENS = path.join(ESTADO, "origens.json");
const SLUG = /^[a-z]+$/;
const DESACORDO = /JEV:\s*[^\n]{1,200}?\.\s*Eu:\s*[^\n]{1,200}?\.\s*Porquê:\s*[^\n]{1,400}/u;
const fmt = (v) => (Number.isFinite(v) ? v : 0).toFixed(2).replace(".", ",");
const nomes = (l, scores) => (l.length ? l.map((s) => (scores ? `${s} ${fmt(scores[s])}` : s)).join("; ") : "nenhuma");

// Cada objetivo do dono com as equipas que o orquestrador chamou nesse turno (thread principal, sem subagentes).
export function casos(texto, origens) {
  const reais = new Set(objetivosReais(texto).filter((o) => origens[chaveDe(o)] === "human").map(chaveDe));
  const porSessao = new Map();
  for (const r of lerRegisto(texto)) {
    if (!sessaoValida(r.sessao)) continue;
    if (!porSessao.has(r.sessao)) porSessao.set(r.sessao, []);
    porSessao.get(r.sessao).push(r);
  }
  const out = [];
  for (const [sessao, rs] of porSessao) {
    rs.forEach((r, i) => {
      const chave = `${sessao}/${r.turno}`;
      if (r.tipo !== "objetivo" || !reais.has(chave)) return;
      reais.delete(chave); // um caso por turno
      const noTurno = new Set();
      const depois = new Set();
      let fora = false;
      for (const x of rs.slice(i + 1)) {
        if (x.tipo === "objetivo" && x.turno !== r.turno) break;
        if ((x.tipo === "pedido" || x.tipo === "objetivo") && x.turno !== r.turno && x.portao !== "app") fora = true;
        if (x.tipo === "equipa" && x.ok !== false && !x.subagente && SLUG.test(x.equipa ?? "")) (fora ? depois : noTurno).add(x.equipa);
      }
      const jev = [...new Set(r.jev.estado === "ok" ? [r.jev.primaria, ...(Array.isArray(r.jev.colaboradoras) ? r.jev.colaboradoras : [])] : [])]
        .filter((s) => SLUG.test(s ?? "")).sort();
      const orq = [...noTurno].sort();
      out.push({
        sessao, turno: r.turno, ts: String(r.ts ?? ""), modo: r.modo === "falar" ? "falar" : "escuras",
        jev, scores: r.jev.scores && typeof r.jev.scores === "object" ? r.jev.scores : {}, orq,
        depois: [...depois].filter((s) => !noTurno.has(s)).sort(),
        acordo: jev.length === orq.length && jev.every((s, k) => s === orq[k])
      });
    });
  }
  return out;
}

export function escolher(lista, rng = randomInt) {
  const resto = lista.filter((c) => c.acordo);
  const acordos = [];
  while (acordos.length < ACORDOS_AO_ACASO && resto.length) acordos.push(resto.splice(rng(resto.length), 1)[0]);
  return { desacordos: lista.filter((c) => !c.acordo), acordos };
}

export function renderRevisao({ desacordos, acordos, total }, extras, agora = new Date()) {
  const linhas = [
    `# Revisão do JEV — ${agora.toISOString().slice(0, 16).replace("T", " ")} (UTC)`,
    "",
    "Privado: tem pedidos teus, lidos do transcript local. Fica só nesta máquina; não o partilhes nem o coles numa sessão.",
    "",
    "Em cada caso, escreve uma letra dentro de `[ ]` no Veredicto:",
    "J = o JEV tinha razão · O = o orquestrador tinha razão · A = ambos servem · N = nenhum serve",
    "Depois corre: `node ~/.claude/equipas/hooks/rever.mjs contar <este ficheiro>`",
    "",
    `Objetivos do dono comparados: ${total} · desacordos: ${desacordos.length} (todos) · acordos ao acaso: ${acordos.length}.`
  ];
  [...desacordos.map((c) => [c, "desacordo"]), ...acordos.map((c) => [c, "acordo"])].forEach(([c, tipo], i) => {
    const x = extras.get(chaveDe(c)) ?? {};
    linhas.push("", `## Caso ${i + 1} — ${tipo}`,
      `- Chave: ${c.sessao}/${c.turno}`,
      `- Quando: ${limpar(c.ts, 25)} · sessão ${c.sessao.slice(0, 8)} · turno ${c.turno.slice(0, 8)} · JEV ${c.modo === "falar" ? "a falar" : "às escuras"}`,
      `- JEV: ${nomes(c.jev, c.scores)}`,
      `- Orquestrador: ${nomes(c.orq)}`,
      ...(c.depois.length ? [`- Chamadas mais tarde na sessão: ${nomes(c.depois)}`] : []),
      `- Pedido: ${x.pedido ? `«${x.pedido}»` : "(não encontrado no transcript)"}`,
      ...(c.modo === "falar" ? [`- Correção escrita: ${x.correcao ? `«${x.correcao}»` : "(nenhuma)"}`] : []),
      "- Veredicto: [ ]");
  });
  return linhas.join("\n") + "\n";
}

export function contarVereditos(texto) {
  const r = { desacordo: { n: 0, J: 0, O: 0, A: 0, N: 0, vazio: 0 }, acordo: { n: 0, J: 0, O: 0, A: 0, N: 0, vazio: 0 } };
  let tipo = null;
  for (const l of String(texto).split("\n")) {
    const h = l.match(/^## Caso \d+ — (desacordo|acordo)$/);
    if (h) { tipo = h[1]; r[tipo].n += 1; continue; }
    const v = l.match(/^- Veredicto: \[\s*([JOAN]?)\s*\]/i);
    if (v && tipo) { r[tipo][v[1].toUpperCase() || "vazio"] += 1; tipo = null; }
  }
  return r;
}

export function resumo({ desacordo: d, acordo: a }) {
  const jev = d.J + d.A;
  const orq = d.O + d.A;
  const falta = d.vazio + a.vazio + (d.n - d.J - d.O - d.A - d.N - d.vazio) + (a.n - a.J - a.O - a.A - a.N - a.vazio);
  return [
    `Desacordos: ${d.n} — JEV ${d.J} · orquestrador ${d.O} · ambos ${d.A} · nenhum ${d.N}`,
    `Acordos ao acaso: ${a.n} — certos ${a.J + a.O + a.A} · errados ${a.N}`,
    falta ? `Faltam ${falta} vereditos: ainda sem resultado.`
      : `Nos desacordos, o JEV acerta ${jev} e o orquestrador ${orq}: ${jev > orq ? "o JEV acerta mais" : jev === orq ? "empate" : "o JEV acerta menos"}.`
  ];
}

function abrirPrivado(f, flags) {
  return fs.openSync(f, flags | fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_NOFOLLOW, 0o600);
}

function pastaSegura() {
  fs.mkdirSync(PASTA, { recursive: true, mode: 0o700 });
  const st = fs.lstatSync(PASTA);
  if (!st.isDirectory() || st.isSymbolicLink()) throw new Error("pasta de revisões insegura");
  fs.chmodSync(PASTA, 0o700);
}

function escreverNovo(f, conteudo) {
  const fd = abrirPrivado(f, fs.constants.O_EXCL);
  try { fs.writeSync(fd, conteudo); fs.closeSync(fd); }
  catch (e) { fs.closeSync(fd); fs.rmSync(f, { force: true }); throw e; }
}

function apagarAntigos(agora = Date.now()) {
  for (const n of fs.readdirSync(PASTA)) {
    const f = path.join(PASTA, n);
    const st = fs.lstatSync(f);
    if (NOME.test(n) && st.isFile() && agora - st.mtimeMs > RETENCAO_MS) fs.rmSync(f);
  }
}

const jaRevistas = () => new Set((fs.existsSync(HISTORICO) ? fs.readFileSync(HISTORICO, "utf8") : "").split("\n")
  .flatMap((l) => { try { const c = JSON.parse(l).chaves; return Array.isArray(c) ? c : []; } catch { return []; } }));

const privado = (texto, max) => (classe(texto) === "SECRET" ? "(omitido: parece ter um segredo)" : limpar(texto, max));

async function gerar() {
  let texto = "";
  try { texto = fs.readFileSync(REGISTO, "utf8"); } catch { /* sem registo: 0 casos */ }
  const origens = await classificar(objetivosReais(texto), lerJson(ORIGENS, {}), { limite: Infinity });
  escreverJson(ORIGENS, origens);
  const revistas = jaRevistas();
  const lista = casos(texto, origens).filter((c) => !revistas.has(chaveDe(c)));
  const sel = escolher(lista);
  const extras = new Map();
  for (const c of [...sel.desacordos, ...sel.acordos]) {
    const t = await lerTurno(transcriptDe(c.sessao), c.turno, { comResposta: c.modo === "falar", limite: Infinity });
    const m = t?.resposta?.match(DESACORDO);
    extras.set(chaveDe(c), { pedido: t?.pedido ? privado(textoDe(t.pedido), 300) : null, correcao: m ? privado(m[0], 200) : null });
  }
  pastaSegura();
  apagarAntigos();
  const f = path.join(PASTA, `revisao-${new Date().toISOString().replace(/[-:]/g, "").slice(0, 15)}-${process.pid}.txt`);
  escreverNovo(f, renderRevisao({ ...sel, total: lista.length }, extras));
  console.log(`Revisão: ${lista.length} objetivos do dono por rever, ${sel.desacordos.length} desacordos, ${sel.acordos.length} acordos ao acaso.`);
  console.log(process.stdout.isTTY ? `Ficheiro privado, para abrires tu: ${f}` : "Ficheiro privado criado na pasta de revisões do dono (o assistente não o abre).");
}

function contar(arg) {
  const real = fs.realpathSync(arg);
  if (path.dirname(real) !== fs.realpathSync(PASTA) || !NOME.test(path.basename(real))) {
    throw new Error("só se contam ficheiros da pasta de revisões do dono");
  }
  const texto = fs.readFileSync(real, "utf8");
  const r = contarVereditos(texto);
  const linhas = resumo(r);
  console.log(linhas.join("\n"));
  if (linhas[2].startsWith("Faltam")) return;
  // Tudo marcado: guarda só contagens e chaves (sem texto) e apaga do ficheiro pedidos e correções.
  const chaves = [...texto.matchAll(/^- Chave: ([A-Za-z0-9_-]{1,128}\/[0-9a-f-]{8,64})$/gmi)].map((m) => m[1]);
  const fd = abrirPrivado(HISTORICO, fs.constants.O_APPEND);
  try { fs.writeSync(fd, JSON.stringify({ ts: new Date().toISOString(), ficheiro: path.basename(real), ...r, chaves }) + "\n"); }
  finally { fs.closeSync(fd); }
  const tmp = `${real}.${process.pid}.tmp`;
  escreverNovo(tmp, texto.replace(/^- (Pedido|Correção escrita): .*$/gm, (_, k) => `- ${k}: ${APAGADO}`));
  fs.renameSync(tmp, real);
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  const [cmd, arg] = process.argv.slice(2);
  const tarefa = cmd === "gerar" ? gerar() : cmd === "contar" && arg ? Promise.resolve().then(() => contar(arg)) : null;
  if (!tarefa) { console.error("Uso: node rever.mjs gerar | contar <ficheiro>"); process.exit(2); }
  tarefa.catch((e) => { console.error(`Erro: ${e?.message ?? e}`); process.exit(1); });
}
