"""troca.py — trocas de texto exatas e reversíveis, para a Fase 1 da Direção Geral.

Uso (python3 -I troca.py ...):
  preparar <CLAUDE.md> <SKILL.md do agency-commander> <textos> <pares>
      lê os textos atuais e escreve em <pares> os pares NN-antes.txt / NN-depois.txt
  aplicar  <ficheiro> <pares> <prefixo>   troca cada "antes" por "depois" (tem de existir 1 vez)
  desfazer <ficheiro> <pares> <prefixo>   troca cada "depois" por "antes" (tem de existir 1 vez)

Tudo ou nada: se um par não bater, o ficheiro fica como estava e a saída é 1.
Escrita atómica no mesmo diretório, com o mesmo modo; recusa ligações simbólicas.
Saída: 0 ok · 1 texto não bate · 2 uso ou erro de ficheiro.
"""
import os
import re
import sys
from pathlib import Path

CLAUDE_A = ("## Agentes — Routing\n", "## Segurança\n")
CLAUDE_B = ("## Especialistas Agency — precedência\n", "## Browser Automation\n")
CLAUDE_C = "Daybreak/auditorias de segurança só a pedido"


class Falha(Exception):
    pass


def ler(caminho: Path) -> str:
    if caminho.is_symlink() or not caminho.is_file():
        raise Falha(f"não é ficheiro normal: {caminho}")
    return caminho.read_text(encoding="utf-8")


def escrever_atomico(caminho: Path, texto: str) -> None:
    if caminho.is_symlink():
        raise Falha(f"ligação simbólica recusada: {caminho}")
    modo = caminho.stat().st_mode & 0o777 if caminho.exists() else 0o600
    tmp = caminho.with_name(f".{caminho.name}.troca-{os.getpid()}")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(texto)
        os.chmod(tmp, modo)
        os.replace(tmp, caminho)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def entre(texto: str, inicio: str, fim: str) -> str:
    i = texto.find(inicio)
    if i < 0 or texto.find(inicio, i + 1) >= 0:
        raise Falha(f"cabeçalho não encontrado uma só vez: {inicio.strip()}")
    j = texto.find(fim, i + len(inicio))
    if j < 0:
        raise Falha(f"fim da secção não encontrado: {fim.strip()}")
    return texto[i:j]


def pares(pasta: Path, prefixo: str) -> list:
    antes = sorted(pasta.glob(f"{prefixo}-*-antes.txt"))
    if not antes:
        raise Falha(f"sem pares {prefixo} em {pasta}")
    out = []
    for a in antes:
        d = a.with_name(a.name.replace("-antes.txt", "-depois.txt"))
        out.append((ler(a), ler(d)))
    return out


def trocar(texto: str, lista: list) -> str:
    for velho, novo in lista:
        if texto.count(velho) != 1:
            raise Falha(f"texto esperado aparece {texto.count(velho)} vezes (tem de ser 1): {velho[:60]!r}")
        if novo != velho and texto.count(novo) != 0:
            raise Falha(f"texto novo já existe: {novo[:60]!r}")
        texto = texto.replace(velho, novo, 1)
    return texto


def preparar(claude_md: Path, skill_md: Path, textos: Path, saida: Path) -> None:
    c = ler(claude_md)
    s = ler(skill_md)
    desc = re.search(r"(?m)^description: .*\n", s)
    if not desc:
        raise Falha("description do agency-commander não encontrada")
    lista = [
        ("claude-1", entre(c, *CLAUDE_A), ler(textos / "claude-1-depois.txt")),
        ("claude-2", entre(c, *CLAUDE_B), ler(textos / "claude-2-depois.txt")),
        ("claude-3", CLAUDE_C, ler(textos / "claude-3-depois.txt").rstrip("\n")),
        ("commander-1", desc.group(0), ler(textos / "commander-1-depois.txt")),
    ]
    saida.mkdir(mode=0o700, exist_ok=True)
    for nome, antes, depois in lista:
        for sufixo, t in (("antes", antes), ("depois", depois)):
            alvo = saida / f"{nome}-{sufixo}.txt"
            if alvo.exists():
                raise Falha(f"já existe: {alvo}")
            escrever_atomico(alvo, t)
    trocar(c, pares(saida, "claude"))  # ensaio: falha já, antes de tocar em qualquer ficheiro
    trocar(s, pares(saida, "commander"))


def main(argv: list) -> int:
    try:
        if len(argv) == 5 and argv[0] == "preparar":
            preparar(*(Path(a) for a in argv[1:]))
            return 0
        if len(argv) == 4 and argv[0] in ("aplicar", "desfazer"):
            alvo, pasta, prefixo = Path(argv[1]), Path(argv[2]), argv[3]
            lista = pares(pasta, prefixo)
            if argv[0] == "desfazer":
                lista = [(d, a) for a, d in reversed(lista)]
            escrever_atomico(alvo, trocar(ler(alvo), lista))
            return 0
    except Falha as e:
        print(f"troca.py: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"troca.py: erro de ficheiro: {e}", file=sys.stderr)
        return 2
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
