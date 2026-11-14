"""atualizar.py — refresca as listas das equipas se o disco mudou (Fase 1). Corre em segundo plano (arranque.mjs).

Gera numa cópia temporária (equipas.yaml, seguranca.md, entradas/) e só sincroniza para ~/.claude/skills
se a verificação passar. Só atualiza ficheiros que a Fase 1 instalou e que ninguém mudou à mão.
Falha: fica a última lista e o motivo vai para estado/arranque.json.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
ESTADO = BASE / "estado"
LOCK = ESTADO / "atualizar.lock.d"
MARCA = BASE / "FASE-1-ATIVA"
INST = ESTADO / "instalado.sha256"
SKILLS = Path.home() / ".claude" / "skills"
NOME_OK = re.compile(r"^(direcao-geral|equipa-[a-z]+)$")
FICH_OK = re.compile(r"^[A-Za-z0-9._-]+$")
INTERVALO_S = 600   # no máximo uma corrida a cada 10 minutos
# Fase 1 (M1): só se publica o frontmatter conhecido, name + description, em todas as skills. O guarda das equipas é um
# só hook global (settings.json → hooks/guarda-sessao.sh), por isso nenhuma skill leva hooks: um frontmatter com hooks
# ou com outra chave nova fica por publicar (conta em "recusados") até alguém o rever.
DESC = re.compile(r'^description: ".*"$')
LOCK_VELHO_S = 300


def sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def escrever_atomico(alvo: Path, dados: bytes, modo: int) -> None:
    if alvo.is_symlink() or alvo.parent.is_symlink():
        raise OSError(f"ligação simbólica recusada: {alvo}")
    tmp = alvo.with_name(f".{alvo.name}.{os.getpid()}.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(dados)
        os.chmod(tmp, modo)
        os.replace(tmp, alvo)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise


def ler_instalado() -> dict:
    out = {}
    try:
        for linha in INST.read_text(encoding="utf-8").splitlines():
            h, _, rel = linha.partition("  ")
            out[rel] = h
    except OSError:
        pass
    return out


def frontmatter_ok(nome: str, dados: bytes) -> bool:
    try:
        texto = dados.decode("utf-8")
    except UnicodeDecodeError:
        return False
    fim = texto.find("\n---\n", 4)
    if not texto.startswith("---\n") or fim < 0:
        return False
    l1, _, resto = texto[4:fim].partition("\n")
    l2, _, extra = resto.partition("\n")
    return l1 == f"name: {nome}" and bool(DESC.match(l2)) and not extra


def sincronizar(origem: Path) -> tuple:
    inst = ler_instalado()
    mudou = recusados = 0
    for d in sorted(origem.iterdir()):
        alvo_dir = SKILLS / d.name
        if not NOME_OK.match(d.name) or not d.is_dir() or not alvo_dir.is_dir() or alvo_dir.is_symlink():
            continue  # só skills que a Fase 1 instalou
        for f in sorted(d.iterdir()):
            if not FICH_OK.match(f.name) or not f.is_file() or f.is_symlink():
                continue
            rel = f"{d.name}/{f.name}"
            novo = f.read_bytes()
            alvo = alvo_dir / f.name
            atual = sha(alvo.read_bytes()) if alvo.is_file() and not alvo.is_symlink() else None
            if atual == sha(novo):
                inst[rel] = atual
                continue
            if alvo.exists() and (alvo.is_symlink() or inst.get(rel) != atual):
                continue  # mudado à mão: não se pisa
            if f.name == "SKILL.md" and not frontmatter_ok(d.name, novo):
                recusados += 1
                continue  # frontmatter desconhecido (ex.: hooks): não se publica sem revisão
            if not MARCA.exists():
                return mudou, recusados  # reversão a meio
            # Reconferir AGORA: o dono pode ter gravado o ficheiro entre a leitura (Line 90) e aqui.
            antes_de_escrever = sha(alvo.read_bytes()) if alvo.is_file() and not alvo.is_symlink() else None
            if antes_de_escrever != atual:
                continue  # mudou durante a geração: preserva a versão do dono
            escrever_atomico(alvo, novo, 0o644)
            inst[rel] = sha(novo)
            mudou += 1

    def gravar_registo() -> None:
        linhas = "".join(f"{h}  {rel}\n" for rel, h in sorted(inst.items()))
        escrever_atomico(INST, linhas.encode("utf-8"), 0o600)

    gravar_registo()
    return mudou, recusados


def correr() -> dict:
    tmp = Path(tempfile.mkdtemp(prefix="gerar-", dir=ESTADO))
    try:
        for nome in ("equipas.yaml", "seguranca.md"):
            shutil.copy2(BASE / nome, tmp / nome)
        shutil.copytree(BASE / "entradas", tmp / "entradas", symlinks=True)
        r = subprocess.run([sys.executable, "-I", "-B", str(BASE / "gerador" / "gerar.py"), "--modo", "vivo", "--saida", str(tmp)],
                           capture_output=True, text=True, timeout=120, cwd=str(tmp))
        sem = [l.strip()[len("- sem equipa: "):] for l in r.stdout.splitlines() if l.strip().startswith("- sem equipa: ")]
        out = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "codigo": r.returncode, "n_sem_equipa": len(sem), "sem_equipa": sem[:5]}
        if r.returncode == 0:
            out["sincronizados"], out["recusados"] = sincronizar(tmp / "rascunho")
        else:
            out["erro"] = "verificação falhou: ficou a última lista" if r.returncode == 1 else "erro de entrada: ficou a última lista"
        return out
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    if not MARCA.exists():
        return 0
    ESTADO.mkdir(mode=0o700, exist_ok=True)
    ultimo = ESTADO / "arranque.json"
    try:
        if time.time() - ultimo.stat().st_mtime < INTERVALO_S:
            return 0
    except OSError:
        pass
    try:
        os.mkdir(LOCK)
    except FileExistsError:
        try:
            if time.time() - LOCK.stat().st_mtime < LOCK_VELHO_S:
                return 0
            os.rmdir(LOCK)
            os.mkdir(LOCK)
        except OSError:
            return 0
    try:
        try:
            out = correr()
        except (OSError, subprocess.SubprocessError, ValueError) as e:
            out = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "codigo": 2, "erro": f"{type(e).__name__}: ficou a última lista"}
        escrever_atomico(ultimo, json.dumps(out, ensure_ascii=False).encode("utf-8"), 0o600)
    finally:
        try:
            os.rmdir(LOCK)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
