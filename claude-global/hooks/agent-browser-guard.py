#!/usr/bin/env python3
"""PreToolUse (global): nega Playwright/Puppeteer e aponta para o agent-browser.

Entrada : JSON do hook em stdin (tool_name, tool_input).
Nega    : ferramentas MCP cujo nome contém playwright/puppeteer; comandos Bash
          que instalam ou executam playwright/puppeteer/pyppeteer.
Saída   : deny -> JSON de decisão em stdout, exit 0.
          resto -> sem output, exit 0 (sem opinião: nunca emite "allow", que
          saltaria o fluxo normal de permissões).
Erro interno -> stderr + exit 1 (erro não bloqueante: falha aberta mas visível).
Limites conhecidos: não vê scripts em ficheiro que importam playwright/puppeteer,
nem comandos dentro de aspas duplas com $(...), nem a tool Monitor.
Compatível com Python 3.9+. Só stdlib.
"""
import json
import os
import re
import shlex
import sys

MAX_DEPTH = 3
MAX_POSITIONALS = 8

# Pacotes alvo (npm / PyPI), por nome exato: "playwright-report-viewer" passa.
PKG = (
    r"(?:@playwright/[\w.-]+"
    r"|playwright(?:-core|-chromium|-firefox|-webkit|-cli)?"
    r"|pytest-playwright"
    r"|puppeteer(?:-core|-extra(?:-plugin-[\w-]+)?)?"
    r"|pyppeteer)"
)
PKG_RE = re.compile(PKG, re.I)
BINARIES = {"playwright", "puppeteer", "pyppeteer", "playwright-cli"}
# Atalho: sem uma destas palavras nada disto se aplica ("ppeteer" cobre pyppeteer).
FAST_RE = re.compile(r"playwright|ppeteer", re.I)
# import/require/from de um desses pacotes em código inline ou heredoc.
IMPORT_RE = re.compile(
    r"\b(?:from|import|require)\s*\(?\s*['\"]?" + PKG + r"(?![\w-])", re.I
)

RUNNERS = {"npx", "bunx", "pnpx", "uvx"}
TOOLS = {"npm", "pnpm", "yarn", "bun", "pip", "pip3", "pipx", "uv", "poetry", "pdm"}
BIN_RUNNERS = {"yarn", "pnpm", "bun"}  # `yarn playwright test` corre o binário local
ACTIONS = {"i", "install", "add", "a", "exec", "x", "dlx", "run", "tool"}
WRAPPERS = {
    "sudo", "doas", "time", "nohup", "nice", "ionice", "env", "command", "exec",
    "builtin", "timeout", "xargs", "stdbuf", "caffeinate", "rtk", "proxy",
}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
INTERPRETERS = re.compile(r"python[\d.]*|node|nodejs|bun|deno|tsx|ts-node")
CODE_FLAGS = {"-c", "-e", "--eval", "-p", "--print"}
ASSIGN_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*=")
HEREDOC_RE = re.compile(r"(?<!<)<<(-?)\s*(['\"]?)([A-Za-z_]\w*)\2")
SEPARATORS = ";|&()\n"
REDIRECTS = "<>"

REASON = (
    "Bloqueado por hook global: {detail}. Playwright e Puppeteer não são usados "
    "neste setup. Usa `agent-browser` (instalado; `agent-browser --help`): sempre "
    "com `--session <nome>`; fluxo `open <url>` -> `snapshot -i` -> `click @e1` / "
    "`fill @e2 \"texto\"`. Para o Chrome real do utilizador (logins) usa "
    "mcp__claude-in-chrome__*, só quando o utilizador pedir."
)


def pkg_name(token):
    """'playwright@1.2' / 'playwright==1.2' / '@playwright/test@x' -> nome base."""
    m = re.match(r"(@[^/@\s]+/[^@=<>!~\[\s]+|[^@=<>!~\[\s]+)", token.strip("'\""))
    return m.group(1) if m else ""


def is_pkg(token):
    return bool(PKG_RE.fullmatch(pkg_name(token)))


def split_heredocs(cmd):
    """Separa os corpos de heredocs (<<EOF ... EOF) do resto do comando."""
    lines, kept, bodies, i = cmd.split("\n"), [], [], 0
    while i < len(lines):
        line = lines[i]
        kept.append(line)
        i += 1
        for m in HEREDOC_RE.finditer(line):
            body = []
            while i < len(lines) and lines[i].strip() != m.group(3):
                body.append(lines[i])
                i += 1
            i += 1  # linha do delimitador
            bodies.append("\n".join(body))
    return "\n".join(kept), bodies


def segments(cmd):
    """Parte o comando em segmentos (listas de palavras) respeitando aspas."""
    lex = shlex.shlex(cmd.replace("`", ";"), posix=True,
                      punctuation_chars=SEPARATORS + REDIRECTS)
    lex.whitespace = " \t\r"          # "\n" separa comandos
    lex.whitespace_split = True
    lex.commenters = ""               # no bash "#" só abre comentário no início de palavra;
                                      # o shlex cortaria "x#y; npx playwright" a meio
    punct = set(SEPARATORS + REDIRECTS)
    segs, cur, skip_next = [], [], False
    for tok in lex:
        if skip_next:                  # alvo de um redirect (> ficheiro)
            skip_next = False
            continue
        if set(tok) <= punct:
            is_redirect = any(c in REDIRECTS for c in tok) and not any(
                c in tok for c in ";|\n()")
            if is_redirect:
                skip_next = True
                if cur and cur[-1].isdigit():   # fd antes do redirect (2>...)
                    cur.pop()
            else:
                segs.append(cur)
                cur = []
        else:
            cur.append(tok)
    segs.append(cur)
    return [s for s in segs if s]


def strip_prefix(tokens):
    """Remove VAR=x, sudo/time/env/timeout/xargs... do início do segmento."""
    t = list(tokens)
    while t:
        word = os.path.basename(t[0])
        if ASSIGN_RE.match(t[0]):
            t.pop(0)
        elif word in WRAPPERS:
            if word == "command" and len(t) > 1 and t[1] in ("-v", "-V"):
                return []              # `command -v x` só consulta
            t.pop(0)
            while t and (t[0].startswith("-") or ASSIGN_RE.match(t[0])
                         or re.fullmatch(r"\d+(?:\.\d+)?[smhd]?", t[0])):
                t.pop(0)
        else:
            break
    return t


def runner_target(args):
    """Alvo de npx/bunx/dlx...: primeiro argumento não-flag (ou -p/--package)."""
    it = iter(args)
    for a in it:
        if a in ("-p", "--package"):
            val = next(it, "")
            if is_pkg(val):
                return val
        elif a.startswith("--package="):
            val = a.split("=", 1)[1]
            if is_pkg(val):
                return val
        elif a.startswith("-"):
            continue
        else:
            return a if is_pkg(a) else None
    return None


def check_segment(tokens, depth, state):
    t = strip_prefix(tokens)
    if not t:
        return None
    word = os.path.basename(t[0])
    low, args = word.lower(), t[1:]

    if low in BINARIES:
        return f"executa `{word}`"

    if low in RUNNERS:
        hit = runner_target(args)
        if hit:
            return f"`{word} {hit}`"

    if low in TOOLS:
        pos = [a for a in args if not a.startswith("-")][:MAX_POSITIONALS]
        if pos and low in BIN_RUNNERS and is_pkg(pos[0]):
            return f"`{word} {pos[0]}`"
        # Subcomando nos 3 primeiros posicionais: tolera `npm --prefix x install`,
        # `yarn workspace w add`, `pnpm --filter w exec`.
        sub = next((i for i, a in enumerate(pos[:3])
                    if a in ACTIONS or (low == "uv" and a == "pip")), None)
        if sub is not None:
            hit = next((a for a in pos[sub + 1:] if is_pkg(a)), None)
            if hit:
                return f"`{word} {pos[sub]} {hit}`"

    if re.fullmatch(r"python[\d.]*", low) and "-m" in args:
        i = args.index("-m")
        mod = args[i + 1].split(".")[0] if i + 1 < len(args) else ""
        if is_pkg(mod):
            return f"`{word} -m {mod}`"
        if mod == "pip":
            rest = [a for a in args[i + 2:] if not a.startswith("-")][:MAX_POSITIONALS]
            if rest and rest[0] == "install":
                hit = next((a for a in rest[1:] if is_pkg(a)), None)
                if hit:
                    return f"`{word} -m pip install {hit}`"

    if INTERPRETERS.fullmatch(low):
        state["interpreter"] = True
        for i, a in enumerate(args[:-1]):
            if a in CODE_FLAGS and IMPORT_RE.search(args[i + 1]):
                return f"código inline (`{word} {a}`) que importa playwright/puppeteer"
        for a in args:
            if a.startswith("--eval=") and IMPORT_RE.search(a):
                return f"código inline (`{word} --eval`) que importa playwright/puppeteer"

    if low in SHELLS and depth < MAX_DEPTH:
        for i, a in enumerate(args[:-1]):
            if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", a):
                hit = find_violation(args[i + 1], depth + 1)
                if hit:
                    return hit
    if low == "eval" and depth < MAX_DEPTH:
        return find_violation(" ".join(args), depth + 1)
    return None


def find_violation(cmd, depth=0):
    cmd = cmd.replace("\\\n", " ")
    if not FAST_RE.search(cmd):
        return None
    text, bodies = split_heredocs(cmd)
    try:
        segs = segments(text)
    except ValueError:                 # aspas por fechar: o bash também falharia
        return None
    state = {"interpreter": False}
    for seg in segs:
        hit = check_segment(seg, depth, state)
        if hit:
            return hit
    if state["interpreter"] and any(IMPORT_RE.search(b) for b in bodies):
        return "heredoc que importa playwright/puppeteer"
    return None


def deny(detail):
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": REASON.format(detail=detail),
        }
    }
    sys.stdout.write(json.dumps(out) + "\n")
    return 0


def main():
    raw = sys.stdin.buffer.read().decode("utf-8", "replace")
    if not FAST_RE.search(raw):
        return 0
    data = json.loads(raw)
    name = str(data.get("tool_name") or "")
    if name.startswith("mcp__"):
        return deny(f"ferramenta MCP `{name}`") if FAST_RE.search(name) else 0
    if name == "Bash":
        tool_input = data.get("tool_input") or {}
        hit = find_violation(str(tool_input.get("command") or ""))
        if hit:
            return deny(hit)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:  # falha aberta, mas visível (exit 1 = não bloqueante)
        print(f"agent-browser-guard: {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
