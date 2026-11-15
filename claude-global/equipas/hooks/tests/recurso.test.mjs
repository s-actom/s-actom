// Testes do encaminhamento para o recurso e do recibo verificado.
// Unidade: vocabulário/orçamento; integração: hooks numa BASE e HOME temporários (nada toca no registo real).
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ORIGEM = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const PEDIDO = "Extrai o conteúdo de https://www.python.org/ em Markdown e indica o título da página.";
const TOOL = "mcp__claude_ai_Context_dev__web-scrape";
const ID = "7f3c2a10-1b2c-4d5e-8f90-123456789abc";

const { buildRoutingEnvelope } = await import(path.join(ORIGEM, "lib", "privado.mjs"));
const { envelopeFechado, etiquetas } = await import(path.join(ORIGEM, "lib", "jev.mjs"));
const { detetar, selecionar } = await import(path.join(ORIGEM, "lib", "capacidade.mjs"));
const { verificar } = await import(path.join(ORIGEM, "lib", "recurso.mjs"));
const { encaminhar } = await import(path.join(ORIGEM, "portao.mjs"));

const respostaOk = (url, extra = {}) => ({
  url, request_id: "req-1", metadata: { title: "Welcome to Python.org" },
  markdown: { requested: true, success: true, data: "x".repeat(400) }, ...extra
});

test("o pedido de extração passa a ser web_research e o envelope é aceite", () => {
  const env = etiquetas(PEDIDO);
  assert.match(env, /work=web_research/);
  assert.match(env, /domains=research_web/);
  assert.match(env, /terms=[^;]*(extrai|markdown|conteudo|titulo)/);
  assert.match(env, /temas=[^;]*(extrai|markdown|conteudo|titulo)/);
  assert.equal(envelopeFechado(env), true);
  assert.equal(buildRoutingEnvelope(PEDIDO).includes("contains_url"), true);
});

test("detetor distingue extração, notícias, texto colado, preferência e URL privado", () => {
  assert.deepEqual(detetar(PEDIDO), { capacidade: "web_extract", url: "https://www.python.org/", preferencia: false, motivo: "url_conhecida" });
  const news = detetar("Pesquisa as notícias mais recentes sobre o Python 3.14.");
  assert.equal(news.capacidade, "web_search");
  assert.equal(news.motivo, "noticias");
  assert.equal(detetar("Resume em três bullets: a empresa cresceu 20% em 2025.").capacidade, null);
  assert.equal(detetar("Extrai o conteúdo de https://example.com/ com o playwright.").preferencia, true);
  assert.equal(detetar("Extrai o conteúdo de https://127.0.0.1/x").url, null);
  assert.equal(detetar("Extrai o conteúdo de https://example.com/ sem internet.").capacidade, null);
});

test("seleção: extração e pesquisa mapeiam para ferramentas distintas; preferência não é sobreposta", () => {
  assert.equal(selecionar(detetar(PEDIDO)).ferramenta, TOOL);
  assert.equal(selecionar(detetar("Pesquisa notícias sobre Python.")).ferramenta, "mcp__claude_ai_Context_dev__web-search");
  assert.equal(selecionar(detetar("Extrai https://example.com/ com o playwright.")).motivo, "preferencia_explicita");
  assert.equal(selecionar(detetar(PEDIDO), { web_extract: null, web_search: null }).motivo, "contextdev_indisponivel");
});

test("caminho A (Pesquisa vence) e caminho B (abaixo do limiar com intenção clara) escolhem o mesmo recurso", () => {
  const a = encaminhar({ estado: "ok", primaria: "pesquisa" }, PEDIDO);
  assert.equal(a.decisao.origem, "modelo");
  assert.equal(a.recurso.ferramenta, TOOL);
  const b = encaminhar({ estado: "abaixo_limiar" }, PEDIDO);
  assert.equal(b.decisao.origem, "regra");
  assert.equal(b.recurso.ferramenta, TOOL);
  const c = encaminhar({ estado: "ok", primaria: "desenvolvimento" }, PEDIDO);
  assert.equal(c.decisao, null);
  assert.equal(c.recurso, null);
});

test("verificação: ok só com URL final confiável; eco é nao_verificavel; página diferente é falhou", () => {
  const pedido = { url: "https://www.python.org/" };
  assert.equal(verificar({ ferramenta: TOOL, entrada: pedido, resposta: respostaOk("https://www.python.org/") }).estado, "ok");

  const eco = verificar({ ferramenta: TOOL, entrada: pedido, resposta: { url: pedido.url, markdown: { success: true, data: "x".repeat(400) } } });
  assert.equal(eco.estado, "nao_verificavel");
  assert.equal(eco.motivo, "sem_prova_url_final");

  const fora = verificar({ ferramenta: TOOL, entrada: { url: "https://site.test/about/" }, resposta: respostaOk("https://site.test/") });
  assert.equal(fora.estado, "falhou");
  assert.equal(fora.motivo, "url_diferente");

  const query = verificar({ ferramenta: TOOL, entrada: { url: "https://site.test/list?page=2" }, resposta: respostaOk("https://site.test/list?page=3") });
  assert.equal(query.estado, "falhou");
  assert.equal(query.query_igual, false);

  const ordem = verificar({ ferramenta: TOOL, entrada: { url: "https://site.test/list?a=1&b=2" }, resposta: respostaOk("https://site.test/list?b=2&a=1") });
  assert.equal(ordem.estado, "ok");

  const curto = verificar({ ferramenta: TOOL, entrada: pedido, resposta: respostaOk(pedido.url, { markdown: { success: true, data: "curto" } }) });
  assert.equal(curto.estado, "falhou");
  assert.equal(curto.motivo, "conteudo_invalido");

  const busca = verificar({ ferramenta: "mcp__claude_ai_Context_dev__web-search", entrada: {}, resposta: { results: [{ url: "https://x.test" }] } });
  assert.equal(busca.estado, "ok");
});

test("three.js e ffmpeg: sinal de multimédia, envelope válido e sem recurso web", () => {
  const casos = [
    "Cria uma cena three.js com um modelo GLB, orbit controls e iluminação para a landing page.",
    "Corta este vídeo com ffmpeg, converte para 1080p e exporta o áudio."
  ];
  for (const p of casos) {
    const env = etiquetas(p);
    assert.equal(envelopeFechado(env), true, env);
    assert.match(env, /temas=[^;]*(three|ffmpeg)/);
    assert.equal(detetar(p).capacidade, null);
    assert.equal(encaminhar({ estado: "ok", primaria: "multimedia" }, p).recurso, null);
  }
});

// --- integração dos hooks ---
function montar() {
  const base = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "equipas-rec-")), "equipas");
  fs.cpSync(ORIGEM, path.join(base, "hooks"), { recursive: true, filter: (s) => !s.includes(`${path.sep}tests`) });
  fs.writeFileSync(path.join(base, "FASE-1-ATIVA"), "teste\n");
  fs.mkdirSync(path.join(base, "estado", "sessoes"), { recursive: true });
  fs.writeFileSync(path.join(base, "estado", "sessoes", "s1.json"),
    JSON.stringify({ ultimo_turno: ID, recurso_pedido: { turno: ID, tipo: "web_extract", ferramenta: TOOL } }));
  return base;
}
const correr = (base, script, entrada) => spawnSync(process.execPath, [path.join(base, "hooks", script)],
  { input: JSON.stringify(entrada), env: { PATH: process.env.PATH, HOME: base }, encoding: "utf8", timeout: 10000 });
const registo = (base) => fs.readFileSync(path.join(base, "registo.jsonl"), "utf8").trim().split("\n").map((l) => JSON.parse(l));

test("PostToolUse grava recibo ok sem conteúdo nem título", () => {
  const base = montar();
  const r = correr(base, "recibo-recurso.mjs", { hook_event_name: "PostToolUse", session_id: "s1", tool_use_id: "toolu_1",
    tool_name: TOOL, tool_input: { url: "https://www.python.org/" }, tool_response: respostaOk("https://www.python.org/") });
  assert.equal(r.status, 0);
  const [l] = registo(base);
  assert.equal(l.tipo, "recurso");
  assert.equal(l.estado, "ok");
  assert.equal(l.turno, ID);
  assert.equal(l.tool_use_id, "toolu_1");
  assert.equal(l.evidencia_url, "conector");
  const bruto = fs.readFileSync(path.join(base, "registo.jsonl"), "utf8");
  for (const proibido of ["https://", "Welcome", "xxxx"]) assert.ok(!bruto.includes(proibido), proibido);
  assert.equal(fs.statSync(path.join(base, "registo.jsonl")).mode & 0o777, 0o600);
});

test("PermissionDenied e PostToolUseFailure ficam em estados distintos", () => {
  const base = montar();
  correr(base, "recibo-permissao.mjs", { hook_event_name: "PermissionDenied", session_id: "s1", tool_use_id: "toolu_2", tool_name: TOOL });
  correr(base, "recibo-recurso.mjs", { hook_event_name: "PostToolUseFailure", session_id: "s1", tool_use_id: "toolu_3", tool_name: TOOL, tool_input: { url: "https://www.python.org/" } });
  const l = registo(base);
  assert.deepEqual(l.map((x) => x.estado), ["recusado_permissao", "falhou"]);
  assert.equal(l[1].motivo, "execucao");
});

function transcript(base, entradas) {
  const p = path.join(base, ".claude", "projects", "-p");
  fs.mkdirSync(p, { recursive: true });
  fs.writeFileSync(path.join(p, "s1.jsonl"), entradas.map((e) => JSON.stringify(e)).join("\n") + "\n");
}
const uso = { type: "assistant", message: { content: [{ type: "tool_use", id: "toolu_9", name: TOOL, input: { url: "https://www.python.org/" } }] } };
const resultado = (is_error, texto) => ({ type: "user", message: { content: [{ type: "tool_result", tool_use_id: "toolu_9", is_error, content: [{ type: "text", text: texto }] }] } });

test("Stop: recusa explícita no transcript, sucesso verificado e ausência de chamada", () => {
  const recusa = montar();
  transcript(recusa, [uso, resultado(true, "Claude requested permissions to use web-scrape, but you haven't granted it yet.")]);
  correr(recusa, "recibo-fecho.mjs", { hook_event_name: "Stop", session_id: "s1" });
  assert.equal(registo(recusa)[0].estado, "recusado_permissao");

  const sucesso = montar();
  transcript(sucesso, [uso, resultado(false, JSON.stringify(respostaOk("https://www.python.org/")))]);
  correr(sucesso, "recibo-fecho.mjs", { hook_event_name: "Stop", session_id: "s1" });
  assert.equal(registo(sucesso)[0].estado, "ok");

  const nada = montar();
  transcript(nada, [{ type: "user", message: { content: "sem ferramenta" } }]);
  correr(nada, "recibo-fecho.mjs", { hook_event_name: "Stop", session_id: "s1" });
  assert.equal(registo(nada)[0].estado, "sem_resultado");
  assert.equal(registo(nada)[0].motivo, "sem_chamada");
});
