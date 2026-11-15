#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync } from "node:child_process";

const MAX_INPUT_BYTES = 1024 * 1024;
const MAX_TRANSCRIPT_BYTES = 8 * 1024 * 1024;
const MAX_REPORT_BYTES = 512 * 1024;
const MAX_PATHS = 100;
const MAX_UNTRACKED_FILES = 5000;
const COMMAND = "/claude-security";
const OWNER_MARKER = "OWNER_ACTION_REQUIRED";
// Campos de ferramenta cujo valor É um caminho (usados tal como estão, sem regex de texto).
const PATH_FIELDS = ["file_path", "path", "notebook_path", "cwd", "working_directory", "directory"];
const BLOCKED_MARKERS = /CLAUDE_SECURITY_(?:BLOCKED|GATE_REQUIRED)/i;
const CODE_ACTION = /\b(?:implement\w*|build\w*|constru\w*|desenvolv\w*|faz|fazer|fa[çc]a|corrig\w*|fix\w*|alter\w*|modific\w*|edit\w*|cri(?:a|ar|e|ou)\w*|create\w*|review\w*|rever\w*|audit\w*|test\w*|scan\w*|release\w*|deploy\w*|commit\w*|push\w*)\b/i;
const CODE_NOUN = /\b(?:c[oó]digo|code|repo(?:sit[oó]rio|sitory)?|projecto|projeto|project|api|backend|frontend|hook|script|configura(?:ç|c)[aã]o|configuration|database|base de dados|schema|migration|branch|diff|seguran(?:ç|c)a|security)\b/i;
const REFUSAL = /(?:^|\n)\s*(?:n[aã]o(?:\s+(?:autorizo|quero|fa[çc]as?|corras?|execute|scan))?|no|recuso|recusar|cancel(?:a|ar|ado)?|sem\s+(?:o\s+)?scan|skip)\b/i;
const CODE_TOOLS = new Set([
  "Read",
  "Grep",
  "Glob",
  "Write",
  "Edit",
  "MultiEdit",
  "NotebookEdit",
  "Bash",
  "Agent",
  "Task",
]);

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

function readStdin() {
  return new Promise((resolve) => {
    let raw = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      if (raw.length <= MAX_INPUT_BYTES) raw += chunk;
    });
    process.stdin.on("end", () => resolve(raw.slice(0, MAX_INPUT_BYTES)));
  });
}

function cleanText(value, depth = 0) {
  if (depth > 5 || value == null) return "";
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map((item) => cleanText(item, depth + 1)).join("\n");
  if (typeof value !== "object") return "";
  if (typeof value.text === "string") return value.text;
  if (typeof value.content === "string") return value.content;
  if (Array.isArray(value.content)) return cleanText(value.content, depth + 1);
  return "";
}

function readJsonLines(file) {
  try {
    const stat = fs.statSync(file);
    const start = Math.max(0, stat.size - MAX_TRANSCRIPT_BYTES);
    const length = stat.size - start;
    const handle = fs.openSync(file, "r");
    const buffer = Buffer.alloc(length);
    fs.readSync(handle, buffer, 0, length, start);
    fs.closeSync(handle);
    let raw = buffer.toString("utf8");
    if (start > 0) raw = raw.slice(raw.indexOf("\n") + 1);
    return raw
      .split(/\r?\n/)
      .filter(Boolean)
      .flatMap((line) => {
        try {
          return [JSON.parse(line)];
        } catch {
          return [];
        }
      });
  } catch {
    return [];
  }
}

function latestTurn(records) {
  let start = -1;
  for (let index = 0; index < records.length; index += 1) {
    const record = records[index];
    if (
      record?.type === "user" &&
      record?.isMeta !== true &&
      typeof record?.message?.content === "string"
    ) {
      start = index;
    }
  }
  return start >= 0 ? { records: records.slice(start), first: records[start] } : { records, first: null };
}

function recordText(record) {
  return cleanText(record?.message?.content ?? record?.content ?? "");
}

function toolUses(records) {
  const uses = [];
  for (const record of records) {
    const content = record?.message?.content;
    if (!Array.isArray(content)) continue;
    for (const item of content) {
      if (item?.type === "tool_use" && typeof item?.name === "string") uses.push(item);
    }
  }
  return uses;
}

function candidatePathsFromString(text, cwd) {
  const candidates = [];
  const absolute = text.match(/(?:\/Users|\/Volumes|\/private|\/tmp|\/var)\/[^\s"'`<>|;&]+/g) ?? [];
  for (const raw of absolute) {
    const cleaned = raw.replace(/[),.:]+$/g, "").replace(/:\d+(?::\d+)?$/, "");
    if (cleaned) candidates.push(cleaned);
  }
  for (const match of text.matchAll(/(?:git\s+-C|cd)\s+(?:"([^"]+)"|'([^']+)'|([^\s;&|]+))/g)) {
    const value = match[1] || match[2] || match[3];
    if (!value) continue;
    candidates.push(path.isAbsolute(value) ? value : path.resolve(cwd, value));
  }
  return candidates;
}

function collectStrings(value, result = [], depth = 0) {
  if (result.length >= MAX_PATHS || depth > 6 || value == null) return result;
  if (typeof value === "string") {
    result.push(value);
    return result;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectStrings(item, result, depth + 1);
    return result;
  }
  if (typeof value === "object") {
    for (const item of Object.values(value)) collectStrings(item, result, depth + 1);
  }
  return result;
}

function git(cwd, args, options = {}) {
  return execFileSync("git", ["-C", cwd, ...args], {
    encoding: options.encoding ?? "utf8",
    timeout: options.timeout ?? 5000,
    maxBuffer: options.maxBuffer ?? 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "ignore"],
    env: { ...process.env, GIT_CONFIG_GLOBAL: "/dev/null", GIT_TERMINAL_PROMPT: "0" },
  });
}

function existingDirectory(candidate) {
  let current = candidate;
  try {
    const stat = fs.statSync(current);
    if (stat.isFile()) current = path.dirname(current);
  } catch {
    while (current !== path.dirname(current) && !fs.existsSync(current)) current = path.dirname(current);
  }
  return current;
}

function excludedPath(candidate) {
  const resolved = path.resolve(candidate);
  const claude = path.join(os.homedir(), ".claude");
  return [
    path.join(claude, "plugins"),
    path.join(claude, "skills"),
    path.join(claude, "backups"),
    "/private/tmp",
    "/tmp",
  ].some((prefix) => resolved === prefix || resolved.startsWith(`${prefix}${path.sep}`)) ||
    resolved.split(path.sep).includes("node_modules") ||
    resolved.split(path.sep).some((part) => part.startsWith("CLAUDE-SECURITY-"));
}

function gitRoot(candidate) {
  try {
    const directory = existingDirectory(candidate);
    if (excludedPath(directory)) return null;
    const root = git(directory, ["rev-parse", "--show-toplevel"]).trim();
    if (!root || excludedPath(root)) return null;
    return fs.realpathSync(root);
  } catch {
    return null;
  }
}

export function discoverRoots(input, turnRecords, userText) {
  const paths = [input.cwd].filter((value) => typeof value === "string");
  paths.push(...candidatePathsFromString(userText, input.cwd || process.cwd()));
  for (const use of toolUses(turnRecords)) {
    if (!CODE_TOOLS.has(use.name)) continue;
    // Campos estruturados são caminhos COMPLETOS: não passam pela extração por regex dentro
    // de texto livre, que corta em espaços ("/app b/server.js" viraria "/app").
    for (const key of PATH_FIELDS) {
      const value = use.input?.[key];
      if (typeof value === "string" && value.length > 0) {
        paths.push(path.isAbsolute(value) ? value : path.resolve(input.cwd || process.cwd(), value));
      }
    }
    for (const text of collectStrings(use.input)) {
      paths.push(...candidatePathsFromString(text, input.cwd || process.cwd()));
    }
  }
  const roots = new Set();
  for (const candidate of paths.slice(0, MAX_PATHS)) {
    if (typeof candidate !== "string" || !path.isAbsolute(candidate)) continue;
    const root = gitRoot(candidate);
    if (root) roots.add(root);
  }
  return [...roots].sort();
}

function splitZero(buffer) {
  return buffer
    .toString("utf8")
    .split("\0")
    .filter(Boolean);
}

function repositoryState(root) {
  try {
    const head = git(root, ["rev-parse", "HEAD"]).trim();
    const status = git(root, ["status", "--porcelain=v1", "-z", "--untracked-files=all"], {
      encoding: null,
    });
    const tracked = git(root, ["diff", "--name-only", "-z", "HEAD", "--"], { encoding: null });
    const untracked = git(root, ["ls-files", "--others", "--exclude-standard", "-z"], {
      encoding: null,
    });
    const dirtyPaths = [...new Set([...splitZero(tracked), ...splitZero(untracked)])]
      .filter((name) => !name.split("/", 1)[0].startsWith("CLAUDE-SECURITY-"))
      .sort();
    const untrackedAll = splitZero(untracked);
    // Se o limite corta ficheiros, o fingerprint não representa o estado real:
    // marcá-lo como parcial impede que um recibo antigo seja reutilizado para conteúdo que mudou.
    const fingerprintCompleto = untrackedAll.length <= MAX_UNTRACKED_FILES;
    const hash = crypto.createHash("sha256");
    hash.update(head);
    hash.update("\0");
    hash.update(status);
    hash.update(git(root, ["diff", "--binary", "HEAD", "--"], { encoding: null }));
    hash.update(fingerprintCompleto ? "untracked:full\0" : "untracked:partial\0");
    for (const name of untrackedAll.slice(0, MAX_UNTRACKED_FILES).sort()) {
      hash.update(name);
      hash.update("\0");
      hash.update(git(root, ["hash-object", "--no-filters", "--", name]).trim());
      hash.update("\0");
    }
    return {
      head,
      dirty: dirtyPaths.length > 0,
      dirtyPaths,
      fingerprint: hash.digest("hex"),
      complete: fingerprintCompleto,
    };
  } catch {
    return null;
  }
}

function latestPathMtime(root, paths) {
  let latest = 0;
  for (const relative of paths) {
    try {
      latest = Math.max(latest, fs.statSync(path.join(root, relative)).mtimeMs);
    } catch {
      try {
        latest = Math.max(latest, fs.statSync(path.dirname(path.join(root, relative))).mtimeMs);
      } catch {
        // A deleted path with an unavailable parent stays covered by the Git fingerprint check.
      }
    }
  }
  try {
    latest = Math.max(latest, fs.statSync(path.join(root, ".git", "index")).mtimeMs);
  } catch {
    // A missing index does not make a report valid; other checks still apply.
  }
  return latest;
}

function normalizeScope(value) {
  if (typeof value !== "string") return null;
  const normalized = path.posix.normalize(value.replaceAll("\\", "/")).replace(/^\.\//, "");
  if (!normalized || normalized === "." || normalized.startsWith("../") || path.posix.isAbsolute(normalized)) {
    return normalized === "." ? "" : null;
  }
  return normalized.replace(/\/$/, "");
}

function scopeCovers(dirtyPaths, scope) {
  if (!Array.isArray(scope) || scope.length === 0) return true;
  const scopes = scope.map(normalizeScope).filter((value) => value != null);
  if (scopes.length !== scope.length) return false;
  if (scopes.includes("")) return true;
  return dirtyPaths.every((file) => scopes.some((entry) => file === entry || file.startsWith(`${entry}/`)));
}

function receiptDirectory() {
  return process.env.CLAUDE_SECURITY_GATE_STATE_DIR || path.join(os.homedir(), ".claude", "security-gate-receipts");
}

function receiptPath(root) {
  const key = crypto.createHash("sha256").update(root).digest("hex");
  return path.join(receiptDirectory(), `${key}.json`);
}

function readReceipt(root) {
  try {
    return JSON.parse(fs.readFileSync(receiptPath(root), "utf8"));
  } catch {
    return null;
  }
}

function writeReceipt(root, reportPath, stamp, state) {
  try {
    const directory = receiptDirectory();
    fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
    const target = receiptPath(root);
    const temporary = `${target}.${process.pid}.tmp`;
    const receipt = {
      version: 1,
      root,
      report_path: reportPath,
      report_generated_at: stamp.generated_at,
      revision: state.head,
      fingerprint: state.fingerprint,
      recorded_at: new Date().toISOString(),
    };
    fs.writeFileSync(temporary, `${JSON.stringify(receipt, null, 2)}\n`, { mode: 0o600 });
    fs.renameSync(temporary, target);
  } catch {
    // Failure to persist a receipt means later turns will conservatively request a fresh scan.
  }
}

function reportDirectories(root) {
  try {
    return fs
      .readdirSync(root, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && /^CLAUDE-SECURITY-\d{8}-\d{6}$/.test(entry.name))
      .map((entry) => path.join(root, entry.name))
      .sort()
      .reverse();
  } catch {
    return [];
  }
}

function readStamp(reportDirectory) {
  try {
    const stamps = fs
      .readdirSync(reportDirectory, { withFileTypes: true })
      .filter(
        (entry) =>
          entry.isFile() && /^CLAUDE-SECURITY-REVISION-[A-Fa-f0-9]{12}(?:-dirty)?\.json$/.test(entry.name),
      );
    if (stamps.length !== 1) return null;
    const target = path.join(reportDirectory, stamps[0].name);
    if (fs.statSync(target).size > MAX_REPORT_BYTES) return null;
    return JSON.parse(fs.readFileSync(target, "utf8"));
  } catch {
    return null;
  }
}

function taskStartedAt(firstRecord) {
  const value = Date.parse(firstRecord?.timestamp || "");
  return Number.isFinite(value) ? value : Date.now();
}

function validReport(root, state, startedAt) {
  const receipt = readReceipt(root);
  for (const directory of reportDirectories(root)) {
    const stamp = readStamp(directory);
    if (!stamp || typeof stamp !== "object") continue;
    let scanRoot;
    try {
      scanRoot = fs.realpathSync(stamp.scan_root);
    } catch {
      continue;
    }
    if (scanRoot !== root) continue;
    if (stamp?.revision?.commit !== state.head) continue;
    if (stamp?.verification?.status !== "verified") continue;
    if (!fs.existsSync(path.join(directory, "CLAUDE-SECURITY-RESULTS.md"))) continue;
    if (!fs.existsSync(path.join(directory, "CLAUDE-SECURITY-RESULTS.jsonl"))) continue;
    if (state.dirty) {
      if (stamp.mode !== "scan" || stamp?.revision?.dirty !== true) continue;
      if (!scopeCovers(state.dirtyPaths, stamp.scope)) continue;
    } else if (stamp?.revision?.dirty !== false || !["scan", "changes", "commit"].includes(stamp.mode)) {
      continue;
    }
    const generatedAt = Date.parse(stamp.generated_at || "");
    if (!Number.isFinite(generatedAt)) continue;
    // Um fingerprint parcial nunca casa com recibo: só um relatório fresco nesta janela vale.
    const receiptMatches =
      state.complete !== false &&
      receipt?.root === root &&
      receipt?.report_path === directory &&
      receipt?.revision === state.head &&
      receipt?.fingerprint === state.fingerprint;
    const freshForTurn = generatedAt + 5000 >= startedAt;
    if (!receiptMatches && !freshForTurn) continue;
    if (freshForTurn && latestPathMtime(root, state.dirtyPaths) > generatedAt + 2000) continue;
    if (!receiptMatches) writeReceipt(root, directory, stamp, state);
    return { directory, stamp };
  }
  return null;
}

function ownerQuestion(message) {
  return (
    message.includes(OWNER_MARKER) &&
    /\/claude-security(?::claude-security)?\b/i.test(message) &&
    /(?:autoriza|autorizas|execute|executa|are you sure)/i.test(message) &&
    message.includes("?")
  );
}

function explicitRefusal(records) {
  let requestIndex = -1;
  for (let index = 0; index < records.length; index += 1) {
    if (ownerQuestion(recordText(records[index]))) requestIndex = index;
  }
  if (requestIndex < 0) return false;
  for (let index = requestIndex + 1; index < records.length; index += 1) {
    if (records[index]?.type !== "user") continue;
    if (REFUSAL.test(recordText(records[index]))) return true;
  }
  return false;
}

function recommendedAction(root, state) {
  if (!state) return `${root}: estado Git não verificável — abrir o repositório e usar ${COMMAND}.`;
  if (state.dirty) {
    return `${root}: working tree com ${state.dirtyPaths.length} caminho(s) alterado(s) — usar Scan codebase; Scan changes ignora alterações não commitadas.`;
  }
  try {
    const upstream = git(root, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]).trim();
    const mergeBase = git(root, ["merge-base", upstream, "HEAD"]).trim();
    if (mergeBase && mergeBase !== state.head) return `${root}: alterações commitadas — usar Scan changes.`;
  } catch {
    // No upstream or no range means a codebase scan is the conservative option.
  }
  return `${root}: sem range de commits comprovado — usar Scan codebase.`;
}

function blockingReason(roots, states) {
  const targets = roots.length
    ? roots.map((root) => `- ${recommendedAction(root, states.get(root))}`).join("\n")
    : `- O repositório não foi identificado. Peça ao owner para abrir/indicar cada repo e executar ${COMMAND}.`;
  return [
    "CLAUDE_SECURITY_OWNER_AUTH_REQUIRED.",
    "Não termine apenas com CLAUDE_SECURITY_BLOCKED.",
    `Faça agora uma pergunta bloqueante ao owner, começando exatamente por ${OWNER_MARKER}, incluindo ${COMMAND}, o modo e o âmbito de cada repositório, e pergunte explicitamente se autoriza continuar.`,
    "Informe que o plugin apresentará a confirmação oficial de tempo/tokens. Aguarde a ação/resposta do owner antes do veredito.",
    targets,
  ].join("\n");
}

const raw = await readStdin();
let input;
try {
  input = JSON.parse(raw || "{}");
} catch {
  emit({
    decision: "block",
    reason: "CLAUDE_SECURITY_HOOK_INPUT_INVALID: não foi possível validar o gate. Peça ao owner para reiniciar a sessão e não declare PASS de segurança.",
  });
  process.exit(0);
}

if (input.hook_event_name !== "Stop") process.exit(0);

const transcript = readJsonLines(input.transcript_path || "");
const turn = latestTurn(transcript);
const userText = turn.first ? recordText(turn.first) : "";
const assistantMessage = typeof input.last_assistant_message === "string" ? input.last_assistant_message : "";
const uses = toolUses(turn.records).filter((item) => CODE_TOOLS.has(item.name));
const actionIntent = CODE_ACTION.test(userText) && CODE_NOUN.test(userText);
const markerPresent = BLOCKED_MARKERS.test(assistantMessage) || turn.records.some((item) => BLOCKED_MARKERS.test(recordText(item)));
const roots = discoverRoots(input, turn.records, userText);
const requiresGate = markerPresent || actionIntent || (roots.length > 0 && uses.length > 0);

if (!requiresGate) process.exit(0);

const states = new Map(roots.map((root) => [root, repositoryState(root)]));
const startedAt = taskStartedAt(turn.first);
const reports = new Map();
for (const root of roots) {
  const state = states.get(root);
  reports.set(root, state ? validReport(root, state, startedAt) : null);
}
const allReportsValid = roots.length > 0 && roots.every((root) => reports.get(root));

// A recusa só conta dentro do turno atual: uma recusa dada noutra tarefa não encerra este gate.
if (allReportsValid || explicitRefusal(turn.records) || ownerQuestion(assistantMessage)) process.exit(0);

const reason = blockingReason(roots, states);
if (input.stop_hook_active === true) {
  emit({
    continue: false,
    stopReason: `${OWNER_MARKER}: o gate Claude Security continua sem relatório atual ou recusa explícita. ${reason}`,
  });
  process.exit(0);
}

emit({ decision: "block", reason });
