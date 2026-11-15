// recibo-fecho.mjs — Stop: fecha o turno. Se não houve resultado nem recusa registada, marca sem_resultado.
// Também serve de rede quando o evento PermissionDenied não chegou: lê o transcript local e procura recusa explícita.
// Só metadados; nunca guarda texto do pedido ou conteúdo. Nunca bloqueia.
import fs from "node:fs";
import path from "node:path";
import { ativa, lerEntrada, sessaoValida, lerSessao, guardarSessao, registar } from "./lib/comum.mjs";
import { ferramentaAlvo, verificar } from "./lib/recurso.mjs";
import { transcriptDe } from "./lib/origem.mjs";

const TURNO = /^[0-9a-f-]{8,64}$/i;
const RECUSA = /\b(permission|permiss(?:a|ã)o|haven'?t granted|not granted|negad[oa]|denied|recusad[oa])\b/i;
const MAX_BYTES = 64 * 1024 * 1024;

function lerTranscript(ficheiro) {
  const usos = new Map();
  const resultados = new Map();
  let tam = 0;
  let texto;
  try {
    const st = fs.lstatSync(ficheiro);
    if (!st.isFile() || st.size > MAX_BYTES) return { usos, resultados };
    texto = fs.readFileSync(ficheiro, "utf8");
  } catch { return { usos, resultados }; }
  for (const linha of texto.split("\n")) {
    if (!linha.trim()) continue;
    tam += linha.length;
    if (tam > MAX_BYTES) break;
    let r;
    try { r = JSON.parse(linha); } catch { continue; }
    const c = r?.message?.content;
    if (Array.isArray(c)) {
      for (const b of c) {
        if (b?.type === "tool_use" && typeof b.id === "string") usos.set(b.id, { nome: b.name, entrada: b.input });
        if (b?.type === "tool_result" && typeof b.tool_use_id === "string") {
          resultados.set(b.tool_use_id, { content: b.content, is_error: b.is_error === true });
        }
      }
    }
  }
  return { usos, resultados };
}

async function main() {
  if (!ativa()) return;
  const e = await lerEntrada();
  if (!e || !sessaoValida(e.session_id)) return;
  const s = lerSessao(e.session_id);
  const p = s.recurso_pedido && typeof s.recurso_pedido === "object" ? s.recurso_pedido : null;
  if (!p || !ferramentaAlvo(p.ferramenta)) return;
  if (s.recurso_resultado && typeof s.recurso_resultado === "object") return; // já fechado

  const turno = TURNO.test(String(p.turno ?? "")) ? p.turno : (TURNO.test(String(s.ultimo_turno ?? "")) ? s.ultimo_turno : null);
  const ficheiro = transcriptDe(e.session_id) || (typeof e.transcript_path === "string" ? e.transcript_path : null);
  const { usos, resultados } = ficheiro ? lerTranscript(ficheiro) : { usos: new Map(), resultados: new Map() };

  // Chamadas ao recurso pedido, na ordem; interessa a última e o respetivo resultado.
  const chamadas = [...usos.entries()].filter(([, v]) => v?.nome === p.ferramenta);
  let estado, motivo, v = null, toolUseId = null;
  if (!chamadas.length) {
    estado = "sem_resultado";
    motivo = "sem_chamada";
  } else {
    const [id, uso] = chamadas[chamadas.length - 1];
    toolUseId = id;
    const res = resultados.get(id);
    if (!res) {
      estado = "sem_resultado";
      motivo = "sem_resultado_da_chamada";
    } else if (res.is_error) {
      const txt = JSON.stringify(res.content ?? "");
      estado = RECUSA.test(txt) ? "recusado_permissao" : "falhou";
      motivo = estado === "recusado_permissao" ? "permissao" : "execucao";
    } else {
      v = verificar({ ferramenta: p.ferramenta, entrada: uso.entrada, resposta: res.content });
      estado = v.estado;
      motivo = v.motivo;
    }
  }

  registar({ tipo: "recurso", ts: new Date().toISOString(), sessao: e.session_id, turno, tool_use_id: toolUseId,
    ferramenta: p.ferramenta, capacidade: p.tipo ?? null, estado, motivo: motivo ?? null, fonte: "stop",
    caracteres: v?.caracteres ?? 0, tem_titulo: v?.tem_titulo ?? false, evidencia_url: v?.evidencia_url ?? "ausente",
    ...(v?.url_pedida_sha256 ? { url_pedida_sha256: v.url_pedida_sha256 } : {}),
    ...(v?.url_final_sha256 ? { url_final_sha256: v.url_final_sha256 } : {}),
    ...(v?.host ? { host: v.host } : {}),
    ...(typeof v?.caminho_igual === "boolean" ? { caminho_igual: v.caminho_igual } : {}),
    ...(typeof v?.query_igual === "boolean" ? { query_igual: v.query_igual } : {}),
    ...(typeof v?.redirecionou === "boolean" ? { redirecionou: v.redirecionou } : {}) });

  s.recurso_resultado = { ts: new Date().toISOString(), estado, tool_use_id: toolUseId, fonte: "stop" };
  delete s.recurso_tentativa;
  guardarSessao(e.session_id, s);
}

if (process.argv[1] && import.meta.url.endsWith(path.basename(process.argv[1]))) {
  main().catch(() => {}).finally(() => process.exit(0));
}
