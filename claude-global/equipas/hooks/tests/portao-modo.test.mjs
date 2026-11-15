// Testes do contrato do modo do JEV: "escuras" nunca revela a equipa nem o recurso.
// Regressão do achado CodeRabbit no PR #1 (portao.mjs): o ramo do recurso precedia o gate do modo.
import { test } from "node:test";
import assert from "node:assert/strict";
import { textoDoObjetivo, modoJev, textoProposta } from "../portao.mjs";

const CAT = [{ slug: "pesquisa", nome: "Pesquisa", descricao: "pesquisa web" }];
const JEV_PESQUISA = { estado: "ok", primaria: "pesquisa", colaboradoras: [], scores: { pesquisa: 0.91 } };
const RECURSO = { tipo: "web_search", ferramenta: "ToolSearch:web_search", motivo: null };

test("modo escuras: decisão de pesquisa COM ferramenta não revela equipa nem recurso", () => {
  const t = textoDoObjetivo({ modo: "escuras", decisao: { equipa: "pesquisa", origem: "modelo" }, recurso: RECURSO, jev: JEV_PESQUISA, cat: CAT });
  assert.doesNotMatch(t, /Equipa Pesquisa/i, "não pode nomear a equipa em escuras");
  assert.doesNotMatch(t, /ToolSearch/, "não pode revelar a ferramenta em escuras");
  assert.doesNotMatch(t, /Proposta do JEV/, "não pode mostrar a proposta em escuras");
  assert.match(t, /^Direção Geral \(Fase 1\)/, "mantém o lembrete padrão da Fase 1");
});

test("modo escuras: decisão SEM ferramenta também fica silenciosa", () => {
  const t = textoDoObjetivo({ modo: "escuras", decisao: { equipa: "pesquisa", origem: "regra" }, recurso: { tipo: "web_search", ferramenta: null, motivo: "sem_ferramenta_pesquisa" }, jev: JEV_PESQUISA, cat: CAT });
  assert.doesNotMatch(t, /indisponível/, "nem o aviso de recurso indisponível aparece em escuras");
  assert.doesNotMatch(t, /Equipa Pesquisa/i);
});

test("modo falar: mostra a equipa e a ferramenta quando há recurso", () => {
  const t = textoDoObjetivo({ modo: "falar", decisao: { equipa: "pesquisa", origem: "modelo" }, recurso: RECURSO, jev: JEV_PESQUISA, cat: CAT });
  assert.match(t, /Equipa Pesquisa/);
  assert.match(t, /ToolSearch/);
});

test("modo falar sem recurso: mostra a proposta do JEV", () => {
  const t = textoDoObjetivo({ modo: "falar", decisao: null, recurso: null, jev: JEV_PESQUISA, cat: CAT });
  assert.match(t, /Proposta do JEV/);
  assert.match(t, /pesquisa 0,91/);
});

test("modo falar com recurso indisponível: acrescenta o motivo", () => {
  const t = textoDoObjetivo({ modo: "falar", decisao: null, recurso: { tipo: "web_search", ferramenta: null, motivo: "sem_ferramenta_pesquisa" }, jev: JEV_PESQUISA, cat: CAT });
  assert.match(t, /Recurso: indisponível \(sem_ferramenta_pesquisa\)/);
});

test("modoJev: por omissão e com valor inválido é escuras; só 'falar' ativa", () => {
  const dir = fsTmp();
  assert.equal(modoJev(dir), "escuras", "sem ficheiro = escuras");
  escrever(dir, { modo: "escuras" });
  assert.equal(modoJev(dir), "escuras");
  escrever(dir, { modo: "FALAR" });
  assert.equal(modoJev(dir), "escuras", "valor inválido não ativa");
  escrever(dir, { modo: "falar" });
  assert.equal(modoJev(dir), "falar");
});

test("textoProposta nunca imprime valores fora de [0,1] como fração inventada", () => {
  const t = textoProposta({ estado: "indisponivel", motivo: "http_500" }, new Set(["pesquisa"]));
  assert.match(t, /indisponível \(http_500\)/);
  assert.doesNotMatch(t, /NaN|undefined/);
});

// --- helpers locais (sem dependências) ---
import fsMod from "node:fs";
import osMod from "node:os";
import pathMod from "node:path";
function fsTmp() {
  return fsMod.mkdtempSync(pathMod.join(osMod.tmpdir(), "modo-jev-"));
}
function escrever(dir, obj) {
  fsMod.writeFileSync(pathMod.join(dir, "jev-modo.json"), JSON.stringify(obj));
}
