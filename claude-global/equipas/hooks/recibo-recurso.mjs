// recibo-recurso.mjs — PostToolUse/PostToolUseFailure: verifica a resposta e fecha o recibo.
// Estados: ok (URL final confere), nao_verificavel (sem prova do URL final), falhou (execução ou página diferente).
// Guarda só metadados; nunca conteúdo, título ou o pedido. Nunca bloqueia.
import path from "node:path";
import { ativa, lerEntrada, sessaoValida, lerSessao, guardarSessao, registar } from "./lib/comum.mjs";
import { ferramentaAlvo, verificar } from "./lib/recurso.mjs";

const TURNO = /^[0-9a-f-]{8,64}$/i;

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  if (!e || !sessaoValida(e.session_id) || !ferramentaAlvo(e.tool_name)) return;
  const s = lerSessao(e.session_id);
  const p = s.recurso_pedido && typeof s.recurso_pedido === "object" ? s.recurso_pedido : null;
  const turno = p && TURNO.test(String(p.turno ?? "")) ? p.turno : (TURNO.test(String(s.ultimo_turno ?? "")) ? s.ultimo_turno : null);
  const toolUseId = typeof e.tool_use_id === "string" ? e.tool_use_id : null;

  let v;
  if (e.hook_event_name === "PostToolUseFailure") {
    v = { estado: "falhou", motivo: "execucao", caracteres: 0, tem_titulo: false, evidencia_url: "ausente" };
  } else {
    v = verificar({ ferramenta: e.tool_name, entrada: e.tool_input, resposta: e.tool_response });
  }

  registar({ tipo: "recurso", ts: new Date().toISOString(), sessao: e.session_id, turno, tool_use_id: toolUseId,
    ferramenta: e.tool_name, capacidade: p?.tipo ?? null, estado: v.estado, motivo: v.motivo ?? null,
    caracteres: v.caracteres, tem_titulo: v.tem_titulo, evidencia_url: v.evidencia_url,
    ...(v.url_pedida_sha256 ? { url_pedida_sha256: v.url_pedida_sha256 } : {}),
    ...(v.url_final_sha256 ? { url_final_sha256: v.url_final_sha256 } : {}),
    ...(v.host ? { host: v.host } : {}),
    ...(typeof v.caminho_igual === "boolean" ? { caminho_igual: v.caminho_igual } : {}),
    ...(typeof v.query_igual === "boolean" ? { query_igual: v.query_igual } : {}),
    ...(typeof v.redirecionou === "boolean" ? { redirecionou: v.redirecionou } : {}) });

  s.recurso_resultado = { ts: new Date().toISOString(), estado: v.estado, tool_use_id: toolUseId };
  delete s.recurso_tentativa;
  guardarSessao(e.session_id, s);
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
