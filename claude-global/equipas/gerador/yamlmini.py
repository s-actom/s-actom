"""Leitor do subconjunto de YAML usado em equipas.yaml. Só biblioteca padrão.

Falha fechada: tudo o que não entende é ErroYaml (tabs, âncoras, tags, blocos | e >, mapas em linha,
chaves duplicadas, indentação ímpar, escalares simples com ': '). Listas ficam sempre mais
indentadas do que a chave que as contém.
"""
import re
from pathlib import Path


class ErroYaml(ValueError):
    pass


_CHAVE = r"[A-Za-z0-9_][A-Za-z0-9_.-]*"
_RE_CHAVE_VALOR = re.compile(rf"^({_CHAVE}):(?:\s+(.*))?$")
_RE_INT = re.compile(r"^-?\d+$")
_ESCAPES = {"n": "\n", "t": "\t", '"': '"', "\\": "\\"}


def _erro(n, msg):
    raise ErroYaml(f"linha {n}: {msg}")


def _sem_comentario(s, n):
    aspa, i = None, 0
    while i < len(s):
        c = s[i]
        if aspa == '"':
            if c == "\\":
                i += 2
                continue
            if c == '"':
                aspa = None
        elif aspa == "'":
            if c == "'":
                if s[i + 1:i + 2] == "'":
                    i += 2
                    continue
                aspa = None
        elif c in "\"'" and (i == 0 or s[i - 1] in " [,"):
            aspa = c
        elif c == "#" and (i == 0 or s[i - 1] in " \t"):
            return s[:i].rstrip()
        i += 1
    if aspa:
        _erro(n, "aspas por fechar")
    return s.rstrip()


def _fim_aspas(t, n):
    q, i = t[0], 1
    while i < len(t):
        c = t[i]
        if q == '"' and c == "\\":
            i += 2
            continue
        if c == q:
            if q == "'" and t[i + 1:i + 2] == "'":
                i += 2
                continue
            if i != len(t) - 1:
                _erro(n, "texto depois das aspas")
            return i
        i += 1
    _erro(n, "aspas por fechar")


def _desescapar(corpo, n):
    saida, i = [], 0
    while i < len(corpo):
        c = corpo[i]
        if c == "\\":
            i += 1
            if i >= len(corpo) or corpo[i] not in _ESCAPES:
                _erro(n, "escape inválido")
            saida.append(_ESCAPES[corpo[i]])
        else:
            saida.append(c)
        i += 1
    return "".join(saida)


def _lista_inline(t, n):
    if t[-1] != "]":
        _erro(n, "lista em linha sem ']'")
    corpo = t[1:-1]
    itens, atual, aspa, i = [], [], None, 0
    while i < len(corpo):
        c = corpo[i]
        if aspa:
            atual.append(c)
            if aspa == '"' and c == "\\":
                if i + 1 < len(corpo):
                    atual.append(corpo[i + 1])
                i += 2
                continue
            if c == aspa:
                if aspa == "'" and corpo[i + 1:i + 2] == "'":
                    atual.append("'")
                    i += 2
                    continue
                aspa = None
        elif c in "\"'" and "".join(atual).strip() == "":
            aspa = c
            atual.append(c)
        elif c == ",":
            itens.append("".join(atual))
            atual = []
        elif c in "[]{}":
            _erro(n, "listas aninhadas ou mapas em linha não suportados")
        else:
            atual.append(c)
        i += 1
    if aspa:
        _erro(n, "aspas por fechar")
    ultimo = "".join(atual)
    if not itens and not ultimo.strip():
        return []
    itens.append(ultimo)
    if any(not x.strip() for x in itens):
        _erro(n, "elemento vazio na lista em linha")
    return [_escalar(x, n) for x in itens]


def _escalar(txt, n):
    t = txt.strip()
    if not t:
        _erro(n, "valor vazio")
    if t[0] in "\"'":
        _fim_aspas(t, n)
        corpo = t[1:-1]
        return _desescapar(corpo, n) if t[0] == '"' else corpo.replace("''", "'")
    if t[0] == "[":
        return _lista_inline(t, n)
    if t[0] in "&*!|>%@`{}]":
        _erro(n, f"construção não suportada: {t[0]!r}")
    if ": " in t or t.endswith(":"):
        _erro(n, "escalar simples com ':' — põe aspas")
    if t in ("true", "false"):
        return t == "true"
    if t in ("null", "~"):
        return None
    if _RE_INT.match(t):
        return int(t)
    return t


def _linhas(texto):
    saida = []
    for n, bruta in enumerate(texto.splitlines(), 1):
        espaco = bruta[: len(bruta) - len(bruta.lstrip())]
        if "\t" in espaco:
            _erro(n, "tabs não são permitidos")
        sem = _sem_comentario(bruta, n)
        if not sem.strip():
            continue
        indent = len(sem) - len(sem.lstrip(" "))
        if indent % 2:
            _erro(n, "a indentação tem de ser múltiplo de 2")
        saida.append((indent, sem.strip(), n))
    return saida


class _Leitor:
    def __init__(self, linhas):
        self.l = linhas
        self.i = 0

    def bloco(self, indent):
        ind, txt, n = self.l[self.i]
        if ind != indent:
            _erro(n, "indentação inesperada")
        if txt == "-" or txt.startswith("- "):
            return self.lista(indent)
        return self.mapa(indent)

    def mapa(self, indent):
        d = {}
        while self.i < len(self.l):
            ind, txt, n = self.l[self.i]
            if ind < indent:
                break
            if ind > indent:
                _erro(n, "indentação inesperada")
            m = _RE_CHAVE_VALOR.match(txt)
            if not m:
                _erro(n, "esperava 'chave: valor'")
            chave, valor = m.group(1), m.group(2)
            if chave in d:
                _erro(n, f"chave duplicada: {chave}")
            self.i += 1
            if not valor:
                if self.i < len(self.l) and self.l[self.i][0] > indent:
                    if self.l[self.i][0] != indent + 2:
                        _erro(self.l[self.i][2], "o filho tem de ter +2 de indentação")
                    d[chave] = self.bloco(indent + 2)
                else:
                    d[chave] = None
            else:
                d[chave] = _escalar(valor, n)
        return d

    def lista(self, indent):
        out = []
        while self.i < len(self.l):
            ind, txt, n = self.l[self.i]
            if ind < indent:
                break
            if ind > indent:
                _erro(n, "indentação inesperada")
            if not (txt == "-" or txt.startswith("- ")):
                _erro(n, "esperava item de lista '- '")
            resto = txt[1:].strip()
            if not resto:
                self.i += 1
                if self.i < len(self.l) and self.l[self.i][0] == indent + 2:
                    out.append(self.bloco(indent + 2))
                else:
                    _erro(n, "item de lista vazio")
            elif resto[0] not in "\"'[" and _RE_CHAVE_VALOR.match(resto):
                self.l[self.i] = (indent + 2, resto, n)
                out.append(self.mapa(indent + 2))
            else:
                self.i += 1
                out.append(_escalar(resto, n))
        return out


def carregar(texto):
    linhas = _linhas(texto)
    if not linhas:
        return {}
    if linhas[0][0] != 0:
        _erro(linhas[0][2], "o documento tem de começar na coluna 0")
    leitor = _Leitor(linhas)
    valor = leitor.bloco(0)
    if leitor.i != len(linhas):
        _erro(linhas[leitor.i][2], "conteúdo inesperado")
    return valor


def carregar_ficheiro(caminho):
    caminho = Path(caminho)
    try:
        return carregar(caminho.read_text(encoding="utf-8"))
    except ErroYaml as e:
        raise ErroYaml(f"{caminho.name}: {e}") from None
