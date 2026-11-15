#!/usr/bin/env node
// Testes de context-handoff.js. Correr: node --test ~/.claude/hooks/context-handoff.test.js
// Cada teste corre o hook como o Claude Code o corre: processo novo, JSON no stdin.

const { test, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const HOOK = path.join(__dirname, 'context-handoff.js');
const SESSION_ID = '4f48f35f-aaaa-bbbb-cccc-000000000000';
const OPUS = 'claude-opus-5-5';
const HAIKU = 'claude-haiku-5-5';

let home;

function writeSettings(settings) {
  fs.writeFileSync(path.join(home, '.claude', 'settings.json'), JSON.stringify(settings));
}

function assistantEntry(tokens, model = OPUS, extra = {}) {
  return {
    type: 'assistant',
    ...extra,
    message: {
      model,
      usage: {
        input_tokens: 2,
        cache_read_input_tokens: tokens - 102,
        cache_creation_input_tokens: 100,
        output_tokens: 50,
      },
    },
  };
}

function writeTranscript(lines) {
  const transcriptPath = path.join(home, 'transcript.jsonl');
  const body = lines.map((line) => (typeof line === 'string' ? line : JSON.stringify(line))).join('\n');
  fs.writeFileSync(transcriptPath, `${body}\n`);
  return transcriptPath;
}

function spawnHook(stdin, env = {}) {
  const result = spawnSync(process.execPath, [HOOK], {
    input: stdin,
    encoding: 'utf8',
    env: { PATH: process.env.PATH, HOME: home, TMPDIR: path.join(home, 'tmp'), ...env },
  });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout;
}

function runHook(input, env) {
  const stdout = spawnHook(JSON.stringify(input), env);
  return stdout ? JSON.parse(stdout).hookSpecificOutput : null;
}

function toolUse(lines, { env, ...fields } = {}) {
  return runHook(
    {
      hook_event_name: 'PostToolUse',
      session_id: SESSION_ID,
      transcript_path: writeTranscript(lines),
      ...fields,
    },
    env,
  );
}

function compact(fields = {}) {
  return runHook({ hook_event_name: 'SessionStart', source: 'compact', session_id: SESSION_ID, ...fields });
}

function saveState(content, date = '2026-11-01', shortId = '4f48f35f') {
  const dir = path.join(home, '.claude', 'session-data');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${date}-${shortId}-session.tmp`);
  fs.writeFileSync(file, content);
  return file;
}

beforeEach(() => {
  home = fs.mkdtempSync(path.join(os.tmpdir(), 'context-handoff-'));
  fs.mkdirSync(path.join(home, '.claude'));
  fs.mkdirSync(path.join(home, 'tmp'));
  writeSettings({
    autoCompactWindow: 400000,
    modelSettings: {
      [OPUS]: { autoCompactWindow: 600000 },
      [HAIKU]: { autoCompactWindow: 400000 },
    },
  });
});

afterEach(() => fs.rmSync(home, { recursive: true, force: true }));

// Aviso

test('fica em silêncio abaixo de 80% da janela', () => {
  assert.equal(toolUse([assistantEntry(479000)]), null);
});

test('avisa uma só vez ao chegar a 80%', () => {
  const notice = toolUse([assistantEntry(480000)]);
  assert.equal(notice.hookEventName, 'PostToolUse');
  assert.match(notice.additionalContext, /CONTEXT HANDOFF/);
  assert.match(notice.additionalContext, /80%/);
  assert.match(notice.additionalContext, /rules\/context-handoff\.md/);
  assert.match(notice.additionalContext, /\d{4}-\d{2}-\d{2}-4f48f35f-session\.tmp/);
  assert.doesNotMatch(notice.additionalContext, /URGENTE/);
  assert.equal(toolUse([assistantEntry(490000)]), null);
});

test('escala a 90% depois do aviso de 80%', () => {
  toolUse([assistantEntry(480000)]);
  const notice = toolUse([assistantEntry(540000)]);
  assert.match(notice.additionalContext, /URGENTE/);
  assert.match(notice.additionalContext, /90%/);
  assert.equal(toolUse([assistantEntry(550000)]), null);
});

test('salta logo para urgente quando a primeira medição já passa 90%', () => {
  assert.match(toolUse([assistantEntry(560000)]).additionalContext, /URGENTE/);
});

test('volta a avisar depois de a compactação baixar o uso', () => {
  assert.ok(toolUse([assistantEntry(480000)]));
  assert.equal(toolUse([assistantEntry(100000)]), null);
  assert.ok(toolUse([assistantEntry(480000)]));
});

test('ignora subagentes sem gastar o aviso da sessão principal', () => {
  assert.equal(toolUse([assistantEntry(590000)], { agent_id: 'abc' }), null);
  assert.ok(toolUse([assistantEntry(590000)]));
});

// Medição

test('ignora uso de sidechain', () => {
  assert.equal(toolUse([assistantEntry(100000), assistantEntry(590000, OPUS, { isSidechain: true })]), null);
});

test('ignora entradas com uso a zero', () => {
  const synthetic = {
    type: 'assistant',
    message: {
      model: '<synthetic>',
      usage: { input_tokens: 0, cache_read_input_tokens: 0, cache_creation_input_tokens: 0, output_tokens: 0 },
    },
  };
  assert.ok(toolUse([assistantEntry(480000), synthetic]));
});

test('usa a última resposta, não a maior', () => {
  assert.equal(toolUse([assistantEntry(590000), assistantEntry(100000)]), null);
});

// Janela

test('aplica a janela própria de cada modelo', () => {
  assert.ok(toolUse([assistantEntry(320000, HAIKU)]));
});

test('não aplica a janela geral a modelo com janela própria', () => {
  assert.equal(toolUse([assistantEntry(320000, OPUS)]), null);
});

test('aceita variantes datadas do nome do modelo', () => {
  assert.equal(toolUse([assistantEntry(320000, `${OPUS}-20270101`)]), null);
  assert.ok(toolUse([assistantEntry(480000, `${OPUS}-20270101`)]));
});

test('prefere a chave de modelo mais específica', () => {
  writeSettings({
    modelSettings: {
      'claude-opus-5': { autoCompactWindow: 200000 },
      [OPUS]: { autoCompactWindow: 600000 },
    },
  });
  assert.equal(toolUse([assistantEntry(200000, OPUS)]), null);
});

test('usa a janela geral quando o modelo não tem janela própria', () => {
  assert.ok(toolUse([assistantEntry(320000, 'claude-outro')]));
});

test('"auto" usa a janela geral', () => {
  writeSettings({ autoCompactWindow: 400000, modelSettings: { [OPUS]: { autoCompactWindow: 'auto' } } });
  assert.ok(toolUse([assistantEntry(320000, OPUS)]));
});

test('fica em silêncio quando a janela é desconhecida', () => {
  writeSettings({});
  assert.equal(toolUse([assistantEntry(590000)]), null);
  fs.rmSync(path.join(home, '.claude', 'settings.json'));
  assert.equal(toolUse([assistantEntry(590000)]), null);
});

test('CLAUDE_CODE_AUTO_COMPACT_WINDOW prevalece sobre as settings', () => {
  const env = { CLAUDE_CODE_AUTO_COMPACT_WINDOW: '1000000' };
  assert.equal(toolUse([assistantEntry(590000)], { env }), null);
});

test('CONTEXT_HANDOFF_WINDOW prevalece sobre tudo', () => {
  const env = { CONTEXT_HANDOFF_WINDOW: '1000', CLAUDE_CODE_AUTO_COMPACT_WINDOW: '1000000' };
  assert.match(toolUse([assistantEntry(900)], { env }).additionalContext, /URGENTE/);
});

// Robustez

test('sobrevive a transcript inexistente', () => {
  const input = {
    hook_event_name: 'PostToolUse',
    session_id: SESSION_ID,
    transcript_path: path.join(home, 'nao-existe.jsonl'),
  };
  assert.equal(runHook(input), null);
});

test('ignora linha final cortada', () => {
  assert.ok(toolUse([assistantEntry(480000), '{"type":"assistant","message":{"usage":{"input_tok']));
});

test('mede transcripts maiores do que o excerto lido', () => {
  const big = JSON.stringify({ type: 'user', text: 'x'.repeat(3 * 1024 * 1024) });
  const toolResult = JSON.stringify({ type: 'user', text: 'y'.repeat(200 * 1024) });
  assert.ok(toolUse([big, assistantEntry(480000), toolResult]));
});

test('recusa session_id com separadores de caminho', () => {
  // path.join normaliza este id para <home>/fuga.json, fora da pasta temporária.
  assert.equal(toolUse([assistantEntry(590000)], { session_id: 'x/../../fuga' }), null);
  assert.equal(fs.existsSync(path.join(home, 'fuga.json')), false);
  assert.deepEqual(fs.readdirSync(path.join(home, 'tmp')), []);
});

test('ignora evento desconhecido e stdin inválido', () => {
  assert.equal(runHook({ hook_event_name: 'Stop', session_id: SESSION_ID }), null);
  assert.equal(spawnHook('nao-e-json'), '');
});

// Ficheiro de estado

test('aponta para o ficheiro de estado que já existe', () => {
  const file = saveState('estado', '2026-10-30');
  assert.ok(toolUse([assistantEntry(480000)]).additionalContext.includes(file));
});

test('não aponta para o ficheiro de outra sessão', () => {
  saveState('outro', '2026-10-30', 'ffffffff');
  assert.doesNotMatch(toolUse([assistantEntry(480000)]).additionalContext, /ffffffff/);
});

// Reinjeção depois de compactar

test('depois de compactar reinjeta o estado da sessão', () => {
  const file = saveState('## Exact Next Step\nCorrer testes');
  const output = compact();
  assert.equal(output.hookEventName, 'SessionStart');
  assert.match(output.additionalContext, /Correr testes/);
  assert.match(output.additionalContext, /não autorização/);
  assert.ok(output.additionalContext.includes(file));
});

test('sem ficheiro de estado da sessão não reinjeta nada', () => {
  assert.equal(compact(), null);
  saveState('outro', '2026-11-01', 'ffffffff');
  assert.equal(compact(), null);
});

test('só reinjeta quando a origem é compact', () => {
  saveState('estado');
  assert.equal(compact({ source: 'startup' }), null);
  assert.equal(compact({ source: 'resume' }), null);
});

test('estado longo mantém o fim e aponta para o ficheiro completo', () => {
  const file = saveState(`INICIO\n${'a'.repeat(30000)}\nExact Next Step: X`);
  const { additionalContext } = compact();
  assert.match(additionalContext, /Exact Next Step: X/);
  assert.doesNotMatch(additionalContext, /INICIO/);
  assert.match(additionalContext, /truncado/);
  assert.ok(additionalContext.includes(file));
  assert.ok(additionalContext.length < 10000);
});
