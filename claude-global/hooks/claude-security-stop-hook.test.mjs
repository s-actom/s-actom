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

// --- Regressão: caminho estruturado com espaços (2 repos, só o 1.º com relatório) ---
// Antes: file_path era extraído por regex de texto livre e cortava em "/app b/server.js" -> "/app".
// O 2.º repositório desaparecia de `roots` e o gate liberava a tarefa sem verificação.
function repo(dir) {
  fs.mkdirSync(dir, { recursive: true });
  const run = (args) => spawnSync("git", ["-C", dir, ...args], { encoding: "utf8" });
  run(["init", "-q"]);
  fs.writeFileSync(path.join(dir, "server.js"), "1\n");
  run(["add", "."]);
  run(["-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-qm", "base"]);
  return run(["rev-parse", "HEAD"]).stdout.trim();
}

function relatorioValido(root, head) {
  const dir = path.join(root, "CLAUDE-SECURITY-20260101-000000");
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, "CLAUDE-SECURITY-RESULTS.md"), "# results\n");
  fs.writeFileSync(path.join(dir, "CLAUDE-SECURITY-RESULTS.jsonl"), "{}\n");
  fs.writeFileSync(
    path.join(dir, `CLAUDE-SECURITY-REVISION-${head.slice(0, 12)}.json`),
    JSON.stringify({
      scan_root: fs.realpathSync(root),
      revision: { commit: head, dirty: false },
      verification: { status: "verified" },
      mode: "scan",
      scope: [],
      generated_at: new Date().toISOString(),
    }),
  );
}

test("Edit num 2.º repositório com espaço no nome não escapa ao gate", () => {
  const base = fs.mkdtempSync(path.join(os.tmpdir(), "sec-2repos-"));
  const A = path.join(base, "app-a");
  const B = path.join(base, "app b");
  const headA = repo(A);
  repo(B); // B fica SEM relatório

  relatorioValido(A, headA);

  const tp = path.join(base, "t.jsonl");
  const linhas = [
    linha({ type: "user", message: { role: "user", content: "Implementa o código do hook" } }),
    linha({
      type: "assistant",
      message: {
        role: "assistant",
        content: [
          { type: "tool_use", id: "t1", name: "Read", input: { file_path: path.join(A, "server.js") } },
          { type: "tool_use", id: "t2", name: "Edit", input: { file_path: path.join(B, "server.js") } },
        ],
      },
    }),
  ];
  fs.writeFileSync(tp, linhas.join("\n") + "\n");

  const r = correr({ hook_event_name: "Stop", transcript_path: tp, last_assistant_message: "", cwd: A });
  const obj = JSON.parse(`${r.stdout || ""}`.trim().split("\n").pop());
  assert.equal(
    obj.decision,
    "block",
    "o gate tem de bloquear: o 2.º repo não tem relatório (caminho com espaços tem de ser reconhecido)",
  );
});
