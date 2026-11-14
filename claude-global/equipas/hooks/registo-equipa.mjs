// registo-equipa.mjs — regista as equipas finais escolhidas pela Direção Geral (Fase 1).
// PostToolUse[Skill]: skill invocada pela ferramenta; guarda a razão que o orquestrador pôs em `args`.
// UserPromptExpansion: `/equipa-x` escrito à mão pelo dono; nunca guarda os argumentos (são texto do dono).
// Regista só direcao-geral, equipa-* do catálogo e agency-commander. Nunca bloqueia.
import path from "node:path";
import { ativa, lerEntrada, sessaoValida, lerSessao, guardarSessao, registar, catalogo, limpar } from "./lib/comum.mjs";
import { etiquetasRazao } from "./lib/jev.mjs";

// A razão em texto livre fica só no transcript local (vê-se na revisão); o registo guarda as etiquetas dela.
export function ler(e) {
  if (e?.hook_event_name === "PostToolUse" && e.tool_name === "Skill") {
    return { nome: String(e.tool_input?.skill ?? ""), via: "ferramenta", razao: etiquetasRazao(limpar(String(e.tool_input?.args ?? ""), 4000)),
      ok: e.tool_response?.success !== false, subagente: typeof e.agent_id === "string" || undefined };
  }
  if (e?.hook_event_name === "UserPromptExpansion") {
    const nome = e.command_name ?? String(e.prompt ?? "").trim().match(/^\/([A-Za-z0-9:_-]+)/)?.[1] ?? "";
    return { nome: String(nome), via: "comando", razao: null, ok: true };
  }
  return null;
}

export function classificar(nome, slugs) {
  const n = nome.replace(/^\//, "");
  if (n === "direcao-geral") return { tipo: "direcao" };
  if (n === "agency-commander") return { tipo: "commander" };
  const m = n.match(/^equipa-([a-z]+)$/);
  if (m && slugs.has(m[1])) return { tipo: "equipa", equipa: m[1] };
  return null;
}

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  if (!e || !sessaoValida(e.session_id)) return;
  const l = ler(e);
  if (!l) return;
  const c = classificar(l.nome, new Set(catalogo().map((x) => x.slug)));
  if (!c) return;
  registar({ ...c, ts: new Date().toISOString(), sessao: e.session_id, via: l.via, razao_etiquetas: l.razao, ok: l.ok, subagente: l.subagente });
  if (c.tipo === "equipa" && l.ok && !l.subagente) {
    const s = lerSessao(e.session_id);
    s.equipa_ativa = true;
    s.equipas = [...new Set([...(Array.isArray(s.equipas) ? s.equipas : []), c.equipa])].slice(0, 15);
    guardarSessao(e.session_id, s);
  }
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
