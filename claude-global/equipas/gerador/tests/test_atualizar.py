"""Guarda de publicação do refresco automático (hooks/atualizar.py, Fase 1, passo 1.9).

O refresco corre no SessionStart e copia o rascunho gerado para ~/.claude/skills. Só publica o frontmatter conhecido,
name + description, em todas as skills: o guarda das equipas é um só hook global em settings.json (hooks/guarda-sessao.sh),
por isso nenhuma equipa leva hooks. Um frontmatter com hooks ou com outra chave nova fica por publicar até alguém o rever.
"""
import contextlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

import escrever as E
import yamlmini
from distribuir import carregar_regras, distribuir
from fontes import ler_instantaneo

RAIZ = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("atualizar", RAIZ / "hooks" / "atualizar.py")
atualizar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(atualizar)
REGISTO = yamlmini.carregar_ficheiro(RAIZ / "equipas.yaml")


def skill(nome, extra=""):
    return f'---\nname: {nome}\ndescription: "Descrição da equipa com mais de vinte caracteres."{extra}\n---\ncorpo\n'.encode()


def bloco_antigo(slug):
    """O guarda que 5 equipas levavam no frontmatter até ao M1 (passou para settings.json). Tem de ser recusado."""
    return ('\nhooks:\n  PreToolUse:\n    - matcher: "Bash|Monitor|mcp__.*"\n      hooks:\n        - type: command\n'
            f"          command: 'bash \"$HOME/.claude/equipas/hooks/guarda-equipa.sh\" {slug} || true'\n          timeout: 5")


def nomes_das_skills():
    return ["direcao-geral"] + [e["skill"] for e in REGISTO["equipas"]]


@contextlib.contextmanager
def instalacao(t, instalados, novos):
    """Pasta t com skills/ instaladas (registadas em instalado.sha256), o rascunho novo em origem/ e a marca da Fase 1.
    Aponta o atualizar para lá enquanto dura."""
    for nome, dados in instalados.items():
        (t / "skills" / nome).mkdir(parents=True)
        (t / "skills" / nome / "SKILL.md").write_bytes(dados)
    for nome, dados in novos.items():
        (t / "origem" / nome).mkdir(parents=True)
        (t / "origem" / nome / "SKILL.md").write_bytes(dados)
    (t / "estado").mkdir()
    (t / "FASE-1-ATIVA").write_text("x\n")
    (t / "estado" / "instalado.sha256").write_text("".join(f"{atualizar.sha(d)}  {n}/SKILL.md\n" for n, d in instalados.items()))
    velhos = (atualizar.SKILLS, atualizar.INST, atualizar.MARCA)
    atualizar.SKILLS, atualizar.INST, atualizar.MARCA = t / "skills", t / "estado/instalado.sha256", t / "FASE-1-ATIVA"
    try:
        yield
    finally:
        atualizar.SKILLS, atualizar.INST, atualizar.MARCA = velhos


class TestPublicacao(unittest.TestCase):
    def test_nenhuma_equipa_publica_hooks(self):
        # Antes comparava as duas cópias do bloco do guarda (gerador e atualizar); com o M1 nenhuma das 16 o pode trazer.
        nomes = nomes_das_skills()
        self.assertEqual(len(nomes), 16)
        for nome in nomes:
            slug = nome.removeprefix("equipa-")
            self.assertTrue(atualizar.frontmatter_ok(nome, skill(nome)), nome)
            self.assertFalse(atualizar.frontmatter_ok(nome, skill(nome, bloco_antigo(slug))), nome)

    def test_aceita_o_que_o_gerador_escreve(self):
        # As duas pontas concordam: cada SKILL.md que o gerador escreve passa o guarda de publicação.
        R = carregar_regras(RAIZ / "equipas.yaml")
        res = distribuir(ler_instantaneo(RAIZ / "entradas/auditoria-itens-2026-11-05.json"), R)
        conteudos = E.montar(R, res, None, None, "teste", RAIZ / "gerador" / "modelos")
        skills = {rel.split("/")[1]: texto for rel, texto in conteudos.items() if rel.endswith("/SKILL.md")}
        self.assertEqual(sorted(skills), sorted(nomes_das_skills()))
        for nome, texto in skills.items():
            self.assertTrue(atualizar.frontmatter_ok(nome, texto.encode("utf-8")), nome)

    def test_recusa_frontmatter_fora_do_previsto(self):
        sem_monitor = bloco_antigo("blockchain").replace('"Bash|Monitor|mcp__.*"', '"Bash|mcp__.*"')
        self.assertNotEqual(sem_monitor, bloco_antigo("blockchain"))
        casos = [
            ("equipa-blockchain", skill("equipa-blockchain", bloco_antigo("blockchain"))),  # o guarda antigo (v4)
            ("equipa-blockchain", skill("equipa-blockchain", sem_monitor)),                 # o guarda antigo (v3)
            ("equipa-sistema", skill("equipa-sistema", bloco_antigo("sistema"))),           # equipa sem guarda
            ("equipa-ia", skill("equipa-ia", "\nhooks: {}")),                               # hooks vazios
            ("direcao-geral", skill("direcao-geral", "\nallowed-tools: Bash")),             # chave nova
            ("equipa-ia", skill("equipa-sistema")),                                         # nome errado
            ("equipa-ia", b"sem frontmatter"),
            ("equipa-ia", b"\xff\xfe"),
        ]
        for nome, dados in casos:
            self.assertFalse(atualizar.frontmatter_ok(nome, dados), nome)

    def test_sincronizar_nao_publica_frontmatter_desconhecido(self):
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            antigos = {"equipa-sistema": skill("equipa-sistema"), "equipa-ia": skill("equipa-ia")}
            novos = {"equipa-sistema": skill("equipa-sistema", bloco_antigo("sistema")), "equipa-ia": skill("equipa-ia") + b"novo\n"}
            with instalacao(t, antigos, novos):
                self.assertEqual(atualizar.sincronizar(t / "origem"), (1, 1))
            self.assertEqual((t / "skills/equipa-sistema/SKILL.md").read_bytes(), antigos["equipa-sistema"])
            self.assertTrue((t / "skills/equipa-ia/SKILL.md").read_bytes().endswith(b"novo\n"))

    def test_nao_pisa_o_ficheiro_se_o_dono_gravar_durante_a_geracao(self):
        """Regressão (CodeRabbit PR #1): o dono pode gravar entre a leitura e a substituição.
        A reconferência do hash imediatamente antes do replace tem de preservar a versão dele.

        A edição é injetada na PRIMEIRA leitura do alvo — ou seja, depois de `atual` ser
        calculado e antes da reconferência. Sem a reconferência, a publicação sobrescrevia.
        (A janela entre a reconferência e o `rename` átómico continua a existir: sem
        cooperação do editor não é eliminável; ver docs/AUDITORIA.md.)"""
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            nome = "equipa-ia"
            base = skill(nome)
            dono = ('---\nname: equipa-ia\ndescription: "Editado pelo dono agora, com mais de vinte caracteres."\n---\neditado\n').encode()
            with instalacao(t, {nome: base}, {nome: skill(nome).replace(b"corpo", b"corpo novo")}):
                original_sha = atualizar.sha
                feito = {"sim": False}

                def sha_que_edita(dados):
                    resultado = original_sha(dados)
                    if not feito["sim"] and dados == base:
                        feito["sim"] = True
                        (t / "skills" / nome / "SKILL.md").write_bytes(dono)
                    return resultado

                atualizar.sha = sha_que_edita
                try:
                    mudou, _ = atualizar.sincronizar(t / "origem")
                finally:
                    atualizar.sha = original_sha
                atual = (t / "skills" / nome / "SKILL.md").read_bytes()
                self.assertTrue(feito["sim"], "o teste não injetou a edição do dono")
                self.assertEqual(atual, dono, "a gravação do dono foi perdida")
                self.assertEqual(mudou, 0, "nada devia ter sido publicado")

    def test_registo_reflete_a_publicacao_parcial(self):
        """Regressão (CodeRabbit PR #1): se uma gravação falhar a meio do ciclo, o registo
        `instalado.sha256` tem de refletir o que ficou REALMENTE publicado.

        Sem isto, o registo ficava com o hash antigo para o ficheiro já publicado: a
        sincronização seguinte via `inst.get(rel) != atual`, concluía "mudado à mão" e
        deixava de atualizar essa skill para sempre."""
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            antigos = {"equipa-ia": skill("equipa-ia"), "equipa-sistema": skill("equipa-sistema")}
            novos = {n: skill(n) + b"novo\n" for n in antigos}
            with instalacao(t, antigos, novos):
                original = atualizar.escrever_atomico
                alvos = []

                def falha_no_segundo(alvo, dados, modo):
                    if Path(alvo).name == "SKILL.md":
                        alvos.append(Path(alvo))
                        if len(alvos) == 2:
                            raise OSError("falha injetada na segunda gravação")
                    return original(alvo, dados, modo)

                atualizar.escrever_atomico = falha_no_segundo
                try:
                    mudou, recusados = atualizar.sincronizar(t / "origem")
                finally:
                    atualizar.escrever_atomico = original

            self.assertEqual(len(alvos), 2, "o teste não injetou a falha na segunda gravação")
            self.assertEqual((mudou, recusados), (1, 1))
            publicada = alvos[0]
            registo = (t / "estado" / "instalado.sha256").read_text()
            self.assertIn(f"{atualizar.sha(publicada.read_bytes())}  {publicada.parent.name}/SKILL.md",
                          registo, "o registo ficou com o hash antigo do ficheiro já publicado")

    def test_sincronizar_tira_o_guarda_antigo_das_equipas_vigiadas(self):
        # Migração do M1: as skills instaladas com o bloco antigo (e registadas) passam a sair sem ele; as outras ficam.
        vigiadas = sorted(e["skill"] for e in REGISTO["equipas"] if e.get("hooks_previstos"))
        self.assertEqual(len(vigiadas), 5)
        antigos = {n: skill(n, bloco_antigo(n.removeprefix("equipa-"))) for n in vigiadas}
        antigos["equipa-sistema"] = skill("equipa-sistema")
        novos = {n: skill(n) for n in antigos}
        with tempfile.TemporaryDirectory() as t:
            t = Path(t)
            with instalacao(t, antigos, novos):
                self.assertEqual(atualizar.sincronizar(t / "origem"), (5, 0))
            for n in antigos:
                self.assertEqual((t / "skills" / n / "SKILL.md").read_bytes(), novos[n], n)
            registado = (t / "estado/instalado.sha256").read_text().splitlines()
            self.assertEqual(sorted(registado), sorted(f"{atualizar.sha(d)}  {n}/SKILL.md" for n, d in novos.items()))


if __name__ == "__main__":
    unittest.main()
