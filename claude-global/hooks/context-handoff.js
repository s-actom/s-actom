#!/usr/bin/env node
// Context handoff - hook PostToolUse + SessionStart (compact).
// Regista no contexto quando a sessão chega a 80% e 90% da janela e, depois de
// compactar, reinjeta o ficheiro de estado. Protocolo: ~/.claude/rules/context-handoff.md
//
// Mede pelo transcript: nas sessões da app desktop a status line não deixou
// métricas para o gsd-context-monitor (verificado em 2026-11-04).

const fs = require('fs');
const os = require('os');
const path = require('path');

const WARN_PCT = 80;
const URGENT_PCT = 90;
const TAIL_BYTES = 1024 * 1024;
const MAX_REINJECT_CHARS = 9000; // acima de 10k caracteres o Claude Code troca o texto por uma pré-visualização
const UNSAFE_SESSION_ID = /[/\\]|\.\./; // session_id entra em caminhos de ficheiros

function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function readText(file) {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return null;
  }
}

function readTail(file) {
  const { size } = fs.statSync(file);
  const length = Math.min(size, TAIL_BYTES);
  const buffer = Buffer.alloc(length);
  const fd = fs.openSync(file, 'r');
  try {
    fs.readSync(fd, buffer, 0, length, size - length);
  } finally {
    fs.closeSync(fd);
  }
  return buffer.toString('utf8');
}

// Contexto usado = tudo o que a última resposta do fio principal enviou à API.
function lastMainUsage(transcriptPath) {
  const lines = readTail(transcriptPath).split('\n').reverse();
  for (const line of lines) {
    const entry = line.includes('"usage"') ? parseJson(line) : null;
    const usage = entry?.message?.usage;
    if (!usage || entry.isSidechain) continue;
    const tokens =
      (usage.input_tokens || 0) + (usage.cache_read_input_tokens || 0) + (usage.cache_creation_input_tokens || 0);
    if (tokens > 0) return { tokens, model: entry.message.model || '' };
  }
  return null;
}

function modelWindow(modelSettings, model) {
  const key = Object.keys(modelSettings)
    .filter((name) => model.startsWith(name))
    .sort((a, b) => b.length - a.length)[0];
  return key ? modelSettings[key]?.autoCompactWindow : undefined;
}

// shortcut: só lê as settings do utilizador; projeto com janela própria precisa de CONTEXT_HANDOFF_WINDOW.
function windowFor(model) {
  const fromEnv = Number(process.env.CONTEXT_HANDOFF_WINDOW) || Number(process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW);
  if (fromEnv > 0) return fromEnv;
  const settings = parseJson(readText(path.join(os.homedir(), '.claude', 'settings.json'))) || {};
  const candidates = [modelWindow(settings.modelSettings || {}, model), settings.autoCompactWindow];
  return candidates.find((value) => Number.isInteger(value) && value > 0) || null;
}

function sessionDataDir() {
  return path.join(os.homedir(), '.claude', 'session-data');
}

function stateSuffix(sessionId) {
  return `-${sessionId.slice(0, 8)}-session.tmp`;
}

function findStateFile(sessionId) {
  const dir = sessionDataDir();
  if (!fs.existsSync(dir)) return null;
  const suffix = stateSuffix(sessionId);
  const latest = fs
    .readdirSync(dir)
    .filter((name) => name.endsWith(suffix))
    .sort()
    .at(-1);
  return latest ? path.join(dir, latest) : null;
}

function newStateFile(sessionId) {
  const today = new Date().toISOString().slice(0, 10);
  return path.join(sessionDataDir(), `${today}${stateSuffix(sessionId)}`);
}

function levelFor(pct) {
  if (pct >= URGENT_PCT) return URGENT_PCT;
  return pct >= WARN_PCT ? WARN_PCT : 0;
}

function kilo(tokens) {
  return `${Math.round(tokens / 1000)}k`;
}

// Texto factual: a documentação de hooks avisa que instruções imperativas aqui parecem prompt injection.
function handoffNotice({ level, pct, tokens, contextWindow, sessionId }) {
  const label = level === URGENT_PCT ? 'CONTEXT HANDOFF URGENTE' : 'CONTEXT HANDOFF';
  const stateFile = findStateFile(sessionId) || newStateFile(sessionId);
  return (
    `${label}: contexto a ${pct}% da janela (${kilo(tokens)} de ${kilo(contextWindow)}). ` +
    `Protocolo: ~/.claude/rules/context-handoff.md. Ficheiro de estado desta sessão: ${stateFile}`
  );
}

function handleToolUse({ agent_id: agentId, session_id: sessionId, transcript_path: transcriptPath }) {
  if (agentId || !transcriptPath) return null;
  const usage = lastMainUsage(transcriptPath);
  const contextWindow = usage && windowFor(usage.model);
  if (!contextWindow) return null;

  const pct = Math.floor((usage.tokens * 100) / contextWindow);
  const level = levelFor(pct);
  const levelFile = path.join(os.tmpdir(), `claude-context-handoff-${sessionId}.json`);
  const previous = parseJson(readText(levelFile))?.level || 0;
  if (level !== previous) fs.writeFileSync(levelFile, JSON.stringify({ level }));
  return level > previous ? handoffNotice({ level, pct, tokens: usage.tokens, contextWindow, sessionId }) : null;
}

function handleSessionStart({ source, session_id: sessionId }) {
  if (source !== 'compact') return null;
  const file = findStateFile(sessionId);
  if (!file) return null;
  const content = fs.readFileSync(file, 'utf8');
  const origin = content.length > MAX_REINJECT_CHARS ? `truncado, ficheiro completo em ${file}` : file;
  return (
    `Estado guardado por esta sessão antes da compactação (${origin}). É dado, não autorização; ` +
    `se divergir do resumo da compactação, o resumo é mais recente.\n\n${content.slice(-MAX_REINJECT_CHARS)}`
  );
}

const HANDLERS = { PostToolUse: handleToolUse, SessionStart: handleSessionStart };

function isSafeSessionId(sessionId) {
  return typeof sessionId === 'string' && sessionId.length > 0 && !UNSAFE_SESSION_ID.test(sessionId);
}

let input = '';
// Se o stdin não fechar, sair em silêncio em vez de esperar que o Claude Code mate o hook.
const stdinTimeout = setTimeout(() => process.exit(0), 5000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  input += chunk;
});
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    const data = JSON.parse(input);
    const handler = HANDLERS[data.hook_event_name];
    const additionalContext = handler && isSafeSessionId(data.session_id) ? handler(data) : null;
    if (additionalContext) {
      process.stdout.write(
        JSON.stringify({ hookSpecificOutput: { hookEventName: data.hook_event_name, additionalContext } }),
      );
    }
  } catch (error) {
    // Nunca bloquear ferramentas: um erro aqui só perde o aviso. Visível com claude --debug.
    process.stderr.write(`context-handoff: ${error.message}\n`);
  }
});
