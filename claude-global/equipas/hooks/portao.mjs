// portao.mjs — hook UserPromptSubmit da Direção Geral (Fase 1: JEV às escuras; Fase 2 preparada).
// Portão de código: comando, mensagem da app, mesmo turno, segredo, sensível, trivial, continuação ou objetivo novo.
// Só num objetivo novo: etiquetas → JEV (≤ 2 s) → registo local; lembra invocar direcao-geral.
// Modo em estado/jev-modo.json: "escuras" (por omissão) não mostra a proposta; "falar" mostra-a em ≤ 5 linhas.
// Nunca guarda o texto do pedido. Nunca bloqueia.
import path from "node:path";
import { ativa, lerEntrada, sessaoValida, lerSessao, guardarSessao, registar, catalogo, responder, lerJson, ESTADO } from "./lib/comum.mjs";
import { etiquetas, classe, palavras, proporEquipas, LIMIAR } from "./lib/jev.mjs";
import { detetar, decidir, selecionar } from "./lib/capacidade.mjs";

const ARGS = "Ao chamar uma `equipa-*`, põe em `args` a razão numa frase curta, sem segredos nem dados do projeto.";
const LEMBRETE = "Direção Geral (Fase 1): objetivo novo. Se não for trivial, invoca já a skill `direcao-geral` e segue-a. " + ARGS;
const TURNO_OK = /^[0-9a-f-]{8,64}$/i;
// Tags com que a app injeta eventos como se fossem pedidos. Lista fechada: um pedido do dono com outra tag conta.
const APP = /^<(system-reminder|task-notification|side-sessions-event|ci-monitor-event|cross-session-message|local-command-stdout|local-command-stderr|local-command-caveat|command-name|command-message|scheduled-task)[\s>]/;
const fmt = (v) => (Number.isFinite(v) ? v : 0).toFixed(2).replace(".", ",");

export const modoJev = (estado = ESTADO) => lerJson(path.join(estado, "jev-modo.json"), {})?.modo === "falar" ? "falar" : "escuras";

export function portao(prompt, sessao, turno = null) {
  const t = prompt.trim();
  if (t.startsWith("/")) return "comando";
  if (APP.test(t)) return "app";
  if (turno && sessao.ultimo_turno === turno) return "mesmo_turno";
  const c = classe(t);
  if (c === "SECRET") return "segredo";
  if (c === "SENSITIVE") return "sensivel";
  if (palavras(t).length <= 3 && t.length < 40) return "trivial";
  if (sessao.equipa_ativa) return "continuacao";
  return "novo";
}

// Fase 2: proposta do JEV para o orquestrador confirmar ou corrigir. Só slugs do catálogo e números.
export function textoProposta(jev, slugs) {
  const linha1 = "Direção Geral (Fase 2): objetivo novo. Se não for trivial, invoca já a skill `direcao-geral` e segue-a.";
  let proposta;
  if (jev?.estado === "ok") {
    const sel = [jev.primaria, ...(Array.isArray(jev.colaboradoras) ? jev.colaboradoras : [])].filter((s) => slugs.has(s)).slice(0, 5);
    proposta = sel.length
      ? `Proposta do JEV (probabilidade; limiar ${fmt(LIMIAR)}): ${sel.map((s) => `${s} ${fmt(jev.scores?.[s])}`).join("; ")}.`
      : "Proposta do JEV: indisponível. Escolhe sozinho.";
  } else if (jev?.estado === "abaixo_limiar") {
    proposta = `Proposta do JEV: nenhuma equipa acima do limiar ${fmt(LIMIAR)}.`;
  } else {
    const m = /^[a-z0-9_]{1,24}$/.test(String(jev?.motivo ?? "")) ? jev.motivo : "erro";
    proposta = `Proposta do JEV: indisponível (${m}). Escolhe sozinho.`;
  }
  return [linha1, proposta, "Confirma ou corrige. Se corrigires, escreve numa linha: `JEV: X. Eu: Y. Porquê: Z.`", ARGS].join("\n");
}

// Texto que o orquestrador vê num objetivo novo. Puro: testável sem rede, sem estado.
// Contrato: em "escuras" o JEV nunca aparece — nem a equipa nem o recurso. Só o lembrete.
export function textoDoObjetivo({ modo, decisao, recurso, jev, cat }) {
  if (modo !== "falar") return LEMBRETE;
  if (recurso?.ferramenta && decisao?.equipa) {
    const nome = `${decisao.equipa[0].toUpperCase()}${decisao.equipa.slice(1)}`;
    return [
      `Direção Geral: objetivo novo. Equipa ${nome}.`,
      `Recurso: usa \`${recurso.ferramenta}\` via ToolSearch (URL do pedido; formats.markdown=true; responseMode="full"). Não uses WebFetch nem Bash para isto.`,
      "Se o utilizador nomeou outra ferramenta, respeita-a.",
      ARGS
    ].join("\n");
  }
  const texto = textoProposta(jev, new Set((cat ?? []).map((x) => x.slug)));
  if (recurso && ["contextdev_indisponivel", "sem_ferramenta_pesquisa"].includes(recurso.motivo)) {
    return `${texto}\nRecurso: indisponível (${recurso.motivo}).`;
  }
  return texto;
}

// Decide equipa e recurso a partir do resultado do JEV. Testável sem rede.
export function encaminhar(jev, prompt, mapa) {
  const det = detetar(prompt);
  const decisao = decidir(jev, det);
  return { det, decisao, recurso: decisao ? selecionar(det, mapa) : null };
}

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  if (!e || !sessaoValida(e.session_id) || typeof e.prompt !== "string") return;
  const s = lerSessao(e.session_id);
  s.pedidos = (Number.isInteger(s.pedidos) ? s.pedidos : 0) + 1;
  const turno = typeof e.prompt_id === "string" && TURNO_OK.test(e.prompt_id) ? e.prompt_id : null;
  const p = portao(e.prompt, s, turno);
  if (turno) s.ultimo_turno = turno;
  const base = { tipo: "pedido", ts: new Date().toISOString(), sessao: e.session_id, turno, ordem: s.pedidos, portao: p };
  if (p !== "novo") {
    guardarSessao(e.session_id, s);
    registar(base);
    return;
  }
  s.objetivos = (Number.isInteger(s.objetivos) ? s.objetivos : 0) + 1;
  guardarSessao(e.session_id, s);
  const modo = modoJev();
  const envelope = etiquetas(e.prompt);
  const cat = catalogo();
  const jev = await proporEquipas({ envelope, catalogo: cat, estadoPath: path.join(ESTADO, "jev.json") });
  // Equipa e recurso andam juntos: só quando a decisão é Pesquisa se escolhe a ferramenta.
  const { decisao, recurso } = encaminhar(jev, e.prompt);
  delete s.recurso_resultado;
  delete s.recurso_tentativa;
  if (recurso?.ferramenta) {
    s.recurso_pedido = { ts: new Date().toISOString(), turno, tipo: recurso.tipo, ferramenta: recurso.ferramenta };
  } else {
    delete s.recurso_pedido;
  }
  guardarSessao(e.session_id, s);
  // Sem caminho do transcript: na revisão chega-se a ele por sessão e turno (prompt_id).
  registar({ ...base, tipo: "objetivo", modo, envelope, jev,
    ...(decisao ? { decisao } : {}),
    ...(recurso ? { recurso: { tipo: recurso.tipo, ferramenta: recurso.ferramenta, motivo: recurso.motivo ?? null } } : {}) });
  const texto = textoDoObjetivo({ modo, decisao, recurso, jev, cat });
  responder({ hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: texto } });
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0)); // falha em aberto
}
