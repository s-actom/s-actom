// recibo-tentativa.mjs — PreToolUse: marca a chamada ao recurso antes de ela correr.
// Só metadados; nunca o pedido. Nunca bloqueia.
import path from "node:path";
import { ativa, lerEntrada, sessaoValida, lerSessao, guardarSessao, registar } from "./lib/comum.mjs";
import { ferramentaAlvo } from "./lib/recurso.mjs";

const TURNO = /^[0-9a-f-]{8,64}$/i;

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  if (!e || !sessaoValida(e.session_id) || !ferramentaAlvo(e.tool_name)) return;
  const s = lerSessao(e.session_id);
  const p = s.recurso_pedido && typeof s.recurso_pedido === "object" ? s.recurso_pedido : null;
  const turno = p && TURNO.test(String(p.turno ?? "")) ? p.turno : (TURNO.test(String(s.ultimo_turno ?? "")) ? s.ultimo_turno : null);
  s.recurso_tentativa = { ts: new Date().toISOString(), tool_use_id: typeof e.tool_use_id === "string" ? e.tool_use_id : null };
  guardarSessao(e.session_id, s);
  registar({ tipo: "tentativa", ts: new Date().toISOString(), sessao: e.session_id, turno,
    tool_use_id: typeof e.tool_use_id === "string" ? e.tool_use_id : null, ferramenta: e.tool_name });
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
