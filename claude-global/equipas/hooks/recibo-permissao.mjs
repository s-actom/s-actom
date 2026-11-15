// recibo-permissao.mjs — PermissionDenied: recusa explícita de permissão, distinta de falha de execução.
// Guarda só metadados. Nunca bloqueia.
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
  const toolUseId = typeof e.tool_use_id === "string" ? e.tool_use_id : null;

  registar({ tipo: "recurso", ts: new Date().toISOString(), sessao: e.session_id, turno, tool_use_id: toolUseId,
    ferramenta: e.tool_name, capacidade: p?.tipo ?? null, estado: "recusado_permissao", motivo: "permissao",
    caracteres: 0, tem_titulo: false, evidencia_url: "ausente" });

  s.recurso_resultado = { ts: new Date().toISOString(), estado: "recusado_permissao", tool_use_id: toolUseId };
  delete s.recurso_tentativa;
  guardarSessao(e.session_id, s);
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
