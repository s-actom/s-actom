// Testes do Adaptive Model Intelligence (equipas/hooks/lib/modelos.mjs + modelo-executado.mjs).
// Cobrem as regras duras: sem modelos no código, fornecedor não autoriza, sem fallback,
// aprendizagem por categoria, registo do modelo efetivamente executado.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  carregarAutorizacao, autorizados, autorizado, fornecedorPermitido,
  agregar, pontuar, escolher, registarExecucao, lerHistorico,
} from "../lib/modelos.mjs";
import { ultimoModelo, ultimoUso, categoriaDaSessao, cauda } from "../modelo-executado.mjs";

const RAIZ = path.resolve(import.meta.dirname, "..", "..");
const OFICIAL = path.join(RAIZ, "modelos", "autorizacao.json");

function tmp() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "modelos-"));
}

// Registo sintético: nenhum id real, para provar que o algoritmo não depende de nomes.
function registoSintetico({ permitidos = ["openai", "anthropic", "deepseek", "glm"], modelos, min = 3 } = {}) {
  const p = path.join(tmp(), "autorizacao.json");
  fs.writeFileSync(p, JSON.stringify({
    v: 1,
    politica: { fornecedores_permitidos: permitidos, pesos: { qualidade: 0.5, fiabilidade: 0.2, velocidade: 0.15, custo: 0.15 }, min_amostras: min },
    modelos: modelos ?? [
      { id: "alfa", fornecedor: "openai", runtime: "r1", acesso: "cli", ativo: true, autorizado: true },
      { id: "beta", fornecedor: "anthropic", runtime: "r2", acesso: "cli", ativo: true, autorizado: true },
    ],
  }));
  return p;
}

const linha = (categoria, modelo, estado, extra = {}) => ({ categoria, modelo, estado, ...extra });

test("o registo oficial carrega e só devolve modelos ativos, autorizados e de fornecedor permitido", () => {
  const reg = carregarAutorizacao(OFICIAL);
  assert.equal(reg.ok, true, reg.motivo);
  const ids = autorizados(reg).map((m) => m.id);
  assert.ok(ids.length >= 1);
  for (const m of autorizados(reg)) {
    assert.equal(m.ativo, true);
    assert.equal(m.autorizado, true);
    assert.ok(reg.politica.fornecedores_permitidos.includes(m.fornecedor), m.fornecedor);
  }
  // Um modelo desativado no registo nunca é candidato.
  assert.deepEqual(autorizados(reg).filter((m) => m.ativo !== true), []);
});

test("pertencer a um fornecedor permitido NÃO autoriza", () => {
  const p = registoSintetico({ modelos: [
    { id: "nao-aprovado", fornecedor: "openai", runtime: "r1", acesso: "cli", ativo: true, autorizado: false },
    { id: "aprovado", fornecedor: "openai", runtime: "r1", acesso: "cli", ativo: true, autorizado: true },
  ] });
  const reg = carregarAutorizacao(p);
  assert.deepEqual(autorizados(reg).map((m) => m.id), ["aprovado"]);
  assert.equal(autorizado(reg, "nao-aprovado"), false);
});

test("fornecedor fora da política é rejeitado mesmo com autorizado:true", () => {
  const p = registoSintetico({ permitidos: ["openai"], modelos: [
    { id: "de-fora", fornecedor: "outro", runtime: "r", acesso: "cli", ativo: true, autorizado: true },
  ] });
  const reg = carregarAutorizacao(p);
  assert.equal(fornecedorPermitido(reg, "outro"), false);
  assert.deepEqual(autorizados(reg), []);
});

test("sem modelo autorizado devolve limitação e nunca um fallback", () => {
  const p = registoSintetico({ modelos: [
    { id: "x", fornecedor: "openai", runtime: "r", acesso: "cli", ativo: true, autorizado: false },
  ] });
  const r = escolher(carregarAutorizacao(p), [], "qualquer_categoria");
  assert.equal(r.limitacao, "sem_modelo_autorizado");
  assert.equal(r.modelo, undefined);
});

test("registo inválido falha fechado (não escolhe nada)", () => {
  const p = path.join(tmp(), "mau.json");
  fs.writeFileSync(p, "{ isto não é json");
  const reg = carregarAutorizacao(p);
  assert.equal(reg.ok, false);
  assert.equal(escolher(reg, [], "x").limitacao, "registo_invalido");
});

test("política sem fornecedores permitidos falha fechado", () => {
  const p = path.join(tmp(), "sem-fornecedores.json");
  fs.writeFileSync(p, JSON.stringify({ v: 1, politica: { fornecedores_permitidos: [] }, modelos: [] }));
  const reg = carregarAutorizacao(p);
  assert.equal(reg.ok, false);
  assert.equal(reg.motivo, "sem_fornecedores_permitidos");
});

test("entradas inválidas ou duplicadas são rejeitadas e reportadas", () => {
  const p = path.join(tmp(), "dups.json");
  fs.writeFileSync(p, JSON.stringify({ v: 1, politica: { fornecedores_permitidos: ["openai"] }, modelos: [
    { id: "a", fornecedor: "openai", runtime: "r", acesso: "cli", ativo: true, autorizado: true },
    { id: "a", fornecedor: "openai", runtime: "r", acesso: "cli", ativo: true, autorizado: true },
    { id: "", fornecedor: "openai", runtime: "r", acesso: "cli" },
  ] }));
  const reg = carregarAutorizacao(p);
  assert.equal(autorizados(reg).length, 1);
  assert.ok(reg.invalidos.some((i) => i.motivo === "duplicado"));
  assert.ok(reg.invalidos.some((i) => i.motivo === "campos_em_falta"));
});

test("aprende por categoria: o modelo com melhor histórico ganha nessa categoria", () => {
  const reg = carregarAutorizacao(registoSintetico());
  const hist = [
    ...Array.from({ length: 5 }, () => linha("revisao", "alfa", "falhou")),
    ...Array.from({ length: 5 }, () => linha("revisao", "beta", "ok", { ms: 200 })),
    ...Array.from({ length: 5 }, () => linha("escrita", "alfa", "ok", { ms: 200 })),
    ...Array.from({ length: 5 }, () => linha("escrita", "beta", "falhou")),
  ];
  assert.equal(escolher(reg, hist, "revisao").modelo, "beta");
  assert.equal(escolher(reg, hist, "escrita").modelo, "alfa");
});

test("velocidade e custo desempatam quando a qualidade é igual", () => {
  const reg = carregarAutorizacao(registoSintetico());
  const hist = [
    ...Array.from({ length: 5 }, () => linha("t", "alfa", "ok", { ms: 9000, custo: 5 })),
    ...Array.from({ length: 5 }, () => linha("t", "beta", "ok", { ms: 200, custo: 1 })),
  ];
  assert.equal(escolher(reg, hist, "t").modelo, "beta");
});

test("abaixo de min_amostras a decisão é neutra e marcada sem_dados", () => {
  const reg = carregarAutorizacao(registoSintetico({ min: 3 }));
  const r = escolher(reg, [linha("x", "alfa", "ok")], "x");
  assert.equal(r.sem_dados, true);
  assert.equal(r.amostras, 1);
});

test("histórico de outra categoria não influencia a escolha", () => {
  const reg = carregarAutorizacao(registoSintetico());
  const hist = Array.from({ length: 10 }, () => linha("outra", "alfa", "ok"));
  const r = escolher(reg, hist, "revisao");
  assert.equal(r.sem_dados, true);
});

test("agregar ignora linhas ilegíveis e agrega métricas", () => {
  const m = agregar([
    linha("c", "m", "ok", { ms: 100, custo: 2 }),
    linha("c", "m", "falhou", { ms: 300 }),
    linha("c", "m", "sem_resultado"),
  ]);
  const a = m.get("c\u0000m");
  assert.equal(a.n, 3);
  assert.equal(a.ok, 1);
  assert.equal(a.falhas, 1);
  assert.equal(a.sem_resultado, 1);
  assert.equal(a.msMedio, 200);
  assert.equal(a.custoN, 1);
});

test("registarExecucao grava o modelo executado e marca autorização; recusa categorias inválidas", () => {
  const caminho = path.join(tmp(), "modelos.jsonl");
  const reg = carregarAutorizacao(OFICIAL);
  const um = autorizados(reg)[0];
  assert.equal(registarExecucao({ sessao: "s", turno: "t", categoria: "revisao", modelo: um.id, estado: "ok", ms: 1200 }, caminho), true);
  // Modelo fora do registo: regista-se como observação (autorizado:false), para detetar drift.
  assert.equal(registarExecucao({ sessao: "s", categoria: "revisao", modelo: "nao-lista-xyz", estado: "ok" }, caminho), true);
  // Categoria inválida: não grava.
  assert.equal(registarExecucao({ categoria: "Maiúsculas!", modelo: um.id, estado: "ok" }, caminho), false);
  const linhas = fs.readFileSync(caminho, "utf8").trim().split("\n").map(JSON.parse);
  assert.equal(linhas.length, 2);
  assert.equal(linhas[0].autorizado, true);
  assert.equal(linhas[1].autorizado, false);
  assert.equal(fs.statSync(caminho).mode & 0o777, 0o600);
});

test("lerHistorico tolera lixo e lê o que interessa", () => {
  const caminho = path.join(tmp(), "h.jsonl");
  fs.writeFileSync(caminho, [
    "não é json",
    JSON.stringify({ categoria: "revisao", modelo: "a", estado: "ok" }),
    JSON.stringify({ categoria: "MAU", modelo: "b", estado: "ok" }),
    JSON.stringify({ categoria: "escrita", modelo: "c", estado: "sem_resultado" }),
  ].join("\n") + "\n");
  const h = lerHistorico(caminho);
  assert.equal(h.length, 2);
  assert.deepEqual(h.map((x) => x.modelo), ["a", "c"]);
});

test("ultimoModelo lê o último modelo da cauda do transcript", () => {
  const texto = ['{"message":{"model":"um"}}', '{"message":{"model":"dois"}}'].join("\n");
  assert.equal(ultimoModelo(texto), "dois");
  assert.equal(ultimoModelo(""), null);
  assert.equal(ultimoModelo('{"model":"três"}'), "três");
});

test("ultimoUso lê os tokens da mensagem mais recente", () => {
  const texto = [
    JSON.stringify({ message: { usage: { input_tokens: 10, output_tokens: 2 } } }),
    JSON.stringify({ message: { usage: { input_tokens: 50, output_tokens: 7 } } }),
  ].join("\n");
  assert.deepEqual(ultimoUso(texto), { tokensIn: 50, tokensOut: 7 });
  assert.equal(ultimoUso("sem nada"), null);
});

test("categoriaDaSessao usa a família work do último objetivo da sessão", () => {
  const caminho = path.join(tmp(), "registo.jsonl");
  fs.writeFileSync(caminho, [
    JSON.stringify({ tipo: "objetivo", sessao: "s1", envelope: "@public;sz=1;work=marketing_copy;domains=x" }),
    JSON.stringify({ tipo: "objetivo", sessao: "s2", envelope: "@public;work=web_research" }),
    JSON.stringify({ tipo: "recurso", sessao: "s1", estado: "ok" }),
  ].join("\n") + "\n");
  assert.equal(categoriaDaSessao("s1", caminho), "marketing_copy");
  assert.equal(categoriaDaSessao("s2", caminho), "web_research");
  assert.equal(categoriaDaSessao("s3", caminho), "geral");
});

test("cauda não segue ligações simbólicas", () => {
  const base = tmp();
  const real = path.join(base, "real.txt");
  fs.writeFileSync(real, "conteudo");
  const lig = path.join(base, "lig.txt");
  fs.symlinkSync(real, lig);
  assert.equal(cauda(lig), "");
});
