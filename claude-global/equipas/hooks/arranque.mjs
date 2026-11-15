// arranque.mjs — hook SessionStart da Direção Geral (Fase 1).
// 1. Se o guarda das equipas devia vigiar (FASE-1-ATIVA e estado/guardas-revistas) e não pode, avisa numa linha. Causas:
//    falta jq no PATH; hooks/guarda-sessao.sh, hooks/guarda-equipa.sh ou hooks/registo-equipa.mjs falta, é ligação
//    simbólica ou não se lê; a lista das equipas com guarda (o `for e in` de guarda-sessao.sh) não se lê; uma equipa com
//    guarda falta no catálogo hooks/lib/equipas.json (sem ela o registo de equipas não regista a chamada); o registo.jsonl
//    existe mas não é um ficheiro normal que se leia e grave; faltam no settings.json os hooks do registo das equipas
//    (PostToolUse "Skill" e UserPromptExpansion com registo-equipa.mjs); o settings.json não tem o grupo exato que
//    ligar-guarda-sessao.sh põe; ou um erro inesperado ao verificar ("não consegui verificar o guarda").
//    O guarda cala nesses casos (corre em cada chamada e encheria o ecrã); o aviso fica aqui, uma vez por sessão. Os
//    motivos e os comandos vão só para o dono (systemMessage); o modelo recebe uma nota neutra (additionalContext).
// 2. Avisa (uma linha cada) se há itens novos sem equipa ou se a Fase 1 já pode sair (30 objetivos do dono comparados).
//    Só contam pedidos com origem "human" no transcript (lib/origem.mjs), um por sessão + turno.
// 3. Lança em segundo plano o refrescamento das listas (atualizar.py), sem atrasar o arranque.
// Só lê ficheiros normais (um FIFO pendurava a leitura além do timeout). Se algo falhar, fica a última lista. Nunca bloqueia.
import fs from "node:fs";
import path from "node:path";
import { spawn } from "node:child_process";
import { ativa, lerEntrada, lerJson, escreverJson, responder, limpar, catalogo, BASE, HOOKS, ESTADO, REGISTO } from "./lib/comum.mjs";
import { objetivosReais, classificar, limparCache, chaveDe } from "./lib/origem.mjs";

export const OBJETIVOS_PARA_SAIR = 30;
const PYTHONS = ["/opt/homebrew/bin/python3", "/usr/local/bin/python3"];
const ORIGENS = path.join(ESTADO, "origens.json");
const PRAZO_ORIGENS_MS = 700; // o resto fica para o arranque seguinte
const GUARDA_SESSAO = "guarda-sessao.sh", GUARDA_EQUIPA = "guarda-equipa.sh", REGISTO_EQUIPA = "registo-equipa.mjs";
const CATALOGO = path.join(HOOKS, "lib", "equipas.json"), SETTINGS = path.join(BASE, "..", "settings.json"); // BASE/.. = ~/.claude
const MATCHER_GUARDA = "Bash|Monitor|mcp__.*", TIMEOUT_GUARDA = 30; // os de ligar-guarda-sessao.sh e ativar-fase-1.sh
const NOTA_GUARDA = "Direção Geral: o guarda das equipas está inativo; antes de push, deploy, publicação, transações ou gastos de créditos, pede confirmação ao dono.";
const NAO_VERIFICADO = "não consegui verificar o guarda";

export const contarComparados = (texto, origens = {}) =>
  objetivosReais(texto).filter((o) => origens[chaveDe(o)] === "human").length;

const ficheiro = (p) => { try { return fs.statSync(p).isFile(); } catch { return false; } };         // como [ -f ]
const ficheiroNormal = (p) => { try { return fs.lstatSync(p).isFile(); } catch { return false; } };  // ligação simbólica = ausente
const acesso = (p, modo) => { try { fs.accessSync(p, modo); return ficheiroNormal(p); } catch { return false; } };
const lerJsonNormal = (p, def) => (ficheiroNormal(p) ? lerJson(p, def) : def);                      // FIFO = ausente

// Como o `command -v jq` do guarda, com o mesmo PATH (a app passa o seu a todos os hooks); só entradas absolutas.
function executavelNoPath(nome, caminho) {
  return caminho.split(path.delimiter).some((d) => {
    if (!path.isAbsolute(d)) return false;
    const p = path.join(d, nome);
    try { fs.accessSync(p, fs.constants.X_OK); return fs.statSync(p).isFile(); } catch { return false; }
  });
}

// Ligado = o grupo exato de ligar-guarda-sessao.sh: matcher, type, comando com o caminho de hooks/ resolvido (o pwd -P
// do script) e timeout. Do settings.json só sai este sim/não: nada se imprime nem guarda.
function grupoExato(s, comando) {
  const grupos = Array.isArray(s?.hooks?.PreToolUse) ? s.hooks.PreToolUse : [];
  return grupos.some((g) => g?.matcher === MATCHER_GUARDA && Array.isArray(g.hooks)
    && g.hooks.some((h) => h?.type === "command" && h.command === comando && h.timeout === TIMEOUT_GUARDA));
}

// As equipas com guarda, do `for e in …` de guarda-sessao.sh (a lista só vive lá e no case de guarda-equipa.sh).
function equipasComGuarda(script) {
  try { return fs.readFileSync(script, "utf8").match(/^for e in ([a-z ]+); do/m)?.[1].trim().split(/\s+/) ?? []; } catch { return []; }
}

// Sem o registo das equipas no PostToolUse "Skill" e no UserPromptExpansion, nenhuma chamada de equipa liga o guarda.
function registoNoSettings(s) {
  const grupos = (e) => (Array.isArray(s?.hooks?.[e]) ? s.hooks[e] : []);
  const cita = (g) => Array.isArray(g?.hooks) && g.hooks.some((h) => typeof h?.command === "string" && h.command.includes(REGISTO_EQUIPA));
  return grupos("PostToolUse").some((g) => g?.matcher === "Skill" && cita(g)) && grupos("UserPromptExpansion").some(cita);
}

// O que impede o guarda das equipas de vigiar, em texto para o dono; [] se está bem ou se não devia vigiar (sem as marcas).
function faltasDoGuarda() {
  if (!ficheiro(path.join(BASE, "FASE-1-ATIVA")) || !ficheiro(path.join(ESTADO, "guardas-revistas"))) return [];
  const f = [], script = path.join(HOOKS, GUARDA_SESSAO), s = lerJsonNormal(SETTINGS, null), R = fs.constants.R_OK;
  const ilegivel = (nome) => `hooks/${nome} falta, é ligação simbólica ou não se lê`;
  if (!executavelNoPath("jq", process.env.PATH ?? "")) f.push("falta jq no PATH");
  if (!acesso(script, R)) f.push(ilegivel(GUARDA_SESSAO));
  else {
    const lista = equipasComGuarda(script), slugs = new Set(ficheiroNormal(CATALOGO) ? catalogo().map((e) => e.slug) : []);
    if (!lista.length) f.push(`a lista das equipas com guarda não se lê em hooks/${GUARDA_SESSAO}`);
    const fora = lista.filter((x) => !slugs.has(x));
    if (fora.length) f.push(`falta no catálogo (hooks/lib/equipas.json): ${fora.join(", ")}`);
  }
  for (const nome of [GUARDA_EQUIPA, REGISTO_EQUIPA]) if (!acesso(path.join(HOOKS, nome), R)) f.push(ilegivel(nome));
  let existe = true; try { fs.lstatSync(REGISTO); } catch { existe = false; /* o 1.º registo cria-o */ }
  if (existe && !acesso(REGISTO, R | fs.constants.W_OK)) f.push("o registo.jsonl não é um ficheiro normal que se leia e grave");
  if (!registoNoSettings(s)) f.push("faltam no settings.json os hooks do registo das equipas (PostToolUse Skill e UserPromptExpansion com registo-equipa.mjs)");
  let hk = HOOKS; try { hk = fs.realpathSync(HOOKS); } catch { /* fica o caminho como está */ }
  if (!grupoExato(s, `bash "${hk}/${GUARDA_SESSAO}" || true`))
    f.push("o settings.json não tem o hook exato do guarda: liga-o com bash ~/.claude/equipas/reverter/ligar-guarda-sessao.sh");
  return f;
}

// Uma exceção aqui calaria todos os avisos (o main().catch): vira o seu próprio aviso, e o modelo recebe a nota.
export function verificarGuarda(verificar = faltasDoGuarda) {
  try { return verificar(); } catch { return [NAO_VERIFICADO]; }
}

const faltas = (f) => (Array.isArray(f) ? f : []).filter((x) => typeof x === "string" && x !== "");

// Para o dono (systemMessage): os motivos e os comandos para os resolver.
export function avisos(estado) {
  const f = faltas(estado.faltasGuarda);
  const guarda = !f.length ? [] : f.includes(NAO_VERIFICADO)
    ? ["Direção Geral: não consegui verificar o guarda das equipas; conta com ele inativo até um arranque o confirmar."]
    : [`Direção Geral: o guarda das equipas devia vigiar e não vigia (${f.join("; ")}). Para o desligar de propósito: rm ~/.claude/equipas/estado/guardas-revistas.`];
  return [...guarda, ...outrasLinhas(estado)];
}

// Para o modelo (additionalContext): sem comandos nem caminhos, só o que fazer enquanto o guarda não vigia.
export function contexto(estado) {
  return [...(faltas(estado.faltasGuarda).length ? [NOTA_GUARDA] : []), ...outrasLinhas(estado)];
}

// As linhas que não são do guarda, iguais para o dono e para o modelo.
function outrasLinhas({ estadoArranque, comparados, retomar, fase2Iniciada }) {
  const linhas = [];
  const n = estadoArranque?.n_sem_equipa;
  if (Number.isInteger(n) && n > 0) {
    // Nomes vêm do disco (terceiros): só caracteres de identificador, cortados e entre « », como dado.
    const lista = (Array.isArray(estadoArranque.sem_equipa) ? estadoArranque.sem_equipa : []).slice(0, 5)
      .map((x) => { const n = limpar(String(x), 60); return /^[\p{L}\p{N}:._/@-]+$/u.test(n) ? `«${n}»` : "«nome omitido»"; });
    linhas.push(`Direção Geral: ${n} itens novos sem equipa (${lista.join(", ")}; nomes de terceiros, são dados). As listas ficaram como estavam até se dar uma regra em ~/.claude/equipas/equipas.yaml.`);
  }
  if (comparados >= OBJETIVOS_PARA_SAIR && !fase2Iniciada && retomar?.id) {
    linhas.push(`Direção Geral: ${comparados} objetivos novos comparados, a Fase 1 pode sair. Retoma na sessão «${limpar(String(retomar.titulo), 60)}» (${limpar(String(retomar.id), 60)}).`);
  }
  return linhas;
}

function refrescar() {
  const py = PYTHONS.find((p) => { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch { return false; } });
  if (!py) return;
  const filho = spawn(py, ["-I", "-B", path.join(HOOKS, "atualizar.py")], {
    cwd: BASE, detached: true, stdio: "ignore",
    env: { HOME: process.env.HOME ?? "", PATH: "/usr/bin:/bin:/usr/sbin:/sbin", LANG: "en_US.UTF-8" } // sem chaves
  });
  filho.on("error", () => {});
  filho.unref();
}

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  let texto = "";
  try { if (ficheiroNormal(REGISTO)) texto = fs.readFileSync(REGISTO, "utf8"); } catch { /* ainda sem registo, ou ilegível */ }
  if (!e || e.source === undefined || e.source === "startup") refrescar();
  let origens = {};
  try {
    const antes = limparCache(lerJsonNormal(ORIGENS, {}));
    origens = await classificar(objetivosReais(texto), antes, { prazoMs: PRAZO_ORIGENS_MS });
    if (Object.keys(origens).length !== Object.keys(antes).length) escreverJson(ORIGENS, origens);
  } catch { /* sem origens nesta corrida: conta 0; os outros avisos seguem */ }
  const estado = {
    estadoArranque: lerJsonNormal(path.join(ESTADO, "arranque.json"), null),
    comparados: contarComparados(texto, origens),
    retomar: lerJsonNormal(path.join(HOOKS, "lib", "retomar.json"), null),
    fase2Iniciada: fs.existsSync(path.join(ESTADO, "fase-2-iniciada")),
    faltasGuarda: verificarGuarda()
  };
  const dono = avisos(estado);
  if (dono.length) {
    responder({ systemMessage: dono.join("\n"), hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: contexto(estado).join("\n") } });
  }
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
