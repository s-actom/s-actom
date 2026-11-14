#!/usr/bin/env node
// Regressão do achado CodeRabbit no PR #1: a recusa de autorização de uma tarefa ANTERIOR
// não pode encerrar o gate de uma tarefa nova (explicitRefusal recebia o transcript inteiro).
// Corre o hook como o Claude Code o corre: processo novo, JSON no stdin. Sem rede.
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const HOOK = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "claude-security-stop-hook.mjs");
const MARK = "OWNER_ACTION_REQUIRED";

function linha(obj) {
  return JSON.stringify(obj);
}

// Tarefa antiga: pedido de autorização + recusa. Tarefa atual: trabalho de código, sem relatório.
function transcriptComRecusaAntiga(file) {
  const linhas = [
    linha({ type: "user", message: { role: "user", content: `${MARK}: autoriza o scan? /claude-security` } }),
    linha({ type: "assistant", message: { role: "assistant", content: "Pergunto ao owner." } }),
    linha({ type: "user", message: { role: "user", content: "não autorizo" } }),
    // --- turno novo ---
    linha({ type: "user", message: { role: "user", content: "Implementa o hook no script do código" } }),
    linha({ type: "assistant", message: { role: "assistant", content: [
      { type: "tool_use", id: "t1", name: "Read", input: { file_path: "/tmp/x.js" } },
    ] } }),
  ];
  fs.writeFileSync(file, linhas.join("\n") + "\n");
}

function correr(input) {
  return spawnSync(process.execPath, [HOOK], {
    input: JSON.stringify(input),
    encoding: "utf8",
    timeout: 15000,
    env: { PATH: process.env.PATH, HOME: os.tmpdir() },
  });
}

test("recusa numa tarefa anterior não encerra o gate de uma tarefa nova", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "sec-hook-"));
  const tp = path.join(dir, "t.jsonl");
  transcriptComRecusaAntiga(tp);
  const r = correr({ hook_event_name: "Stop", transcript_path: tp, last_assistant_message: "", cwd: dir });
  const saida = `${r.stdout || ""}`.trim();
  assert.ok(saida.length > 0, `o hook devia decidir algo; stderr=${r.stderr}`);
  const obj = JSON.parse(saida.split("\n").pop());
  assert.equal(obj.decision, "block", "devia bloquear: recusa de outra tarefa não serve de prova");
  assert.match(obj.reason, /OWNER_ACTION_REQUIRED|relat[oó]rio|Claude Security/i);
});

test("recusa DENTRO do turno atual encerra o gate (sem bloqueio)", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "sec-hook-"));
  const tp = path.join(dir, "t.jsonl");
  const linhas = [
    linha({ type: "user", message: { role: "user", content: `Implementa o código do hook. ${MARK}: autoriza o scan? /claude-security` } }),
    linha({ type: "assistant", message: { role: "assistant", content: [
      { type: "tool_use", id: "t1", name: "Read", input: { file_path: "/tmp/x.js" } },
    ] } }),
    linha({ type: "user", message: { role: "user", content: "não autorizo" } }),
  ];
  fs.writeFileSync(tp, linhas.join("\n") + "\n");
  const r = correr({ hook_event_name: "Stop", transcript_path: tp, last_assistant_message: "", cwd: dir });
  assert.equal(`${r.stdout || ""}`.trim(), "", `recusa no turno atual deve terminar sem bloqueio; stdout=${r.stdout}`);
});

test("sem recusa e sem relatório: bloqueia com razão acionável", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "sec-hook-"));
  const tp = path.join(dir, "t.jsonl");
  const linhas = [
    linha({ type: "user", message: { role: "user", content: "Implementa o código do hook no script" } }),
    linha({ type: "assistant", message: { role: "assistant", content: [
      { type: "tool_use", id: "t1", name: "Read", input: { file_path: "/tmp/x.js" } },
    ] } }),
  ];
  fs.writeFileSync(tp, linhas.join("\n") + "\n");
  const r = correr({ hook_event_name: "Stop", transcript_path: tp, last_assistant_message: "", cwd: dir });
  const obj = JSON.parse(`${r.stdout || ""}`.trim().split("\n").pop());
  assert.equal(obj.decision, "block");
});
