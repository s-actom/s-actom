import contextlib
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path

import gerar
from tests.test_fontes import SEGREDO, escrever, montar_home

RAIZ = Path(__file__).resolve().parents[2]


def correr(*args):
    saida, erro = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(saida), contextlib.redirect_stderr(erro):
        rc = gerar.main(list(args))
    return rc, saida.getvalue(), erro.getvalue()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.saida = Path(self.tmp.name) / "equipas"
        (self.saida / "entradas").mkdir(parents=True)
        for rel in ("equipas.yaml", "seguranca.md", "entradas/auditoria-itens-2026-11-05.json"):
            shutil.copy(RAIZ / rel, self.saida / rel)
        self.home = montar_home(Path(self.tmp.name) / "home")

    def tearDown(self):
        self.tmp.cleanup()


class TestCli(Base):
    def test_modo_instantaneo_exit_0_e_nao_escreve(self):
        rc, out, _ = correr("--modo", "instantaneo", "--saida", str(self.saida))
        self.assertEqual(rc, 0, out)
        self.assertIn("VERIFICAÇÃO OK: 1144 itens", out)
        self.assertFalse((self.saida / "rascunho").exists())
        self.assertFalse((self.saida / "relatorio").exists())

    def test_modo_vivo_regista_diferencas_e_nao_vaza_segredos(self):
        rc, out, _ = correr("--modo", "vivo", "--home", str(self.home), "--saida", str(self.saida))
        self.assertEqual(rc, 1)  # o home de teste quase não tem os itens do snapshot: exceções ficam sem destino
        diff = (self.saida / "relatorio/DIFERENCAS.md").read_text(encoding="utf-8")
        self.assertIn("## Já não estão no disco", diff)
        self.assertIn("p1:foo", diff)  # novo no disco
        for p in self.saida.rglob("*"):
            if p.is_file():
                self.assertNotIn(SEGREDO, p.read_text(encoding="utf-8"), str(p))
        self.assertNotIn(SEGREDO, out)

    def test_excluido_nao_aparece_em_nenhuma_equipa_e_fica_no_relatorio(self):
        # Mecanismo de exclusão, independente da lista viva do dono: injeta-se um excluído no equipas.yaml de teste.
        y = self.saida / "equipas.yaml"
        t = y.read_text(encoding="utf-8")
        self.assertEqual(t.count("\nexcluidos: []\n"), 1)
        y.write_text(t.replace("\nexcluidos: []\n", '\nexcluidos:\n  - item: "playwright"\n    motivo: "teste: o mecanismo, não a lista viva do dono"\n'), encoding="utf-8")
        # Os browsers que ficam (Claude_Browser e agent-browser) continuam visíveis na Qualidade.
        cj = self.home / ".claude.json"
        dados = json.loads(cj.read_text(encoding="utf-8"))
        dados["mcpServers"]["playwright"] = {}
        cj.write_text(json.dumps(dados), encoding="utf-8")
        escrever(self.home / ".claude/skills/agent-browser/SKILL.md", "---\nname: agent-browser\ndescription: browser\n---\n")
        rc, out, _ = correr("--modo", "vivo", "--home", str(self.home), "--saida", str(self.saida))
        self.assertEqual(rc, 1, out)  # como acima: o home de teste quase não tem os itens do snapshot
        for p in (self.saida / "rascunho").rglob("*"):
            if p.is_file():
                self.assertNotIn("playwright", p.read_text(encoding="utf-8").lower(), str(p))
        qualidade = (self.saida / "rascunho/equipa-qualidade/SKILL.md").read_text(encoding="utf-8")
        for nome in ("Claude_Browser", "agent-browser"):
            self.assertIn(f"- {nome} (", qualidade)
        self.assertIn("MCP\tplaywright\texcluido\t\t", (self.saida / "relatorio/atribuicao.tsv").read_text(encoding="utf-8"))
        for rel in ("relatorio/RESUMO.md", "relatorio/DIFERENCAS.md"):
            texto = (self.saida / rel).read_text(encoding="utf-8")
            self.assertIn("playwright", texto, rel)
            self.assertIn("o mecanismo, não a lista viva do dono", texto, rel)  # o motivo vai com o item

    def test_entrada_corrompida_exit_2_e_nada_escrito(self):
        escrever(self.home / ".claude/settings.json", "{corrompido")
        rc, _, erro = correr("--modo", "vivo", "--home", str(self.home), "--saida", str(self.saida))
        self.assertEqual(rc, 2)
        self.assertIn("ERRO DE ENTRADA", erro)
        self.assertFalse((self.saida / "rascunho").exists())
        self.assertFalse((self.saida / "relatorio").exists())

    def test_snapshot_em_falta_exit_2(self):
        (self.saida / "entradas/auditoria-itens-2026-11-05.json").unlink()
        rc, _, erro = correr("--modo", "instantaneo", "--saida", str(self.saida))
        self.assertEqual(rc, 2)
        self.assertIn("ERRO DE ENTRADA", erro)

    def test_nomes_referidos_existem(self):
        seg = self.saida / "seguranca.md"
        seg.write_text(seg.read_text(encoding="utf-8") + "\nUsa também `agente-que-nao-existe`.\n", encoding="utf-8")
        rc, out, _ = correr("--modo", "instantaneo", "--saida", str(self.saida))
        self.assertEqual(rc, 1)
        self.assertIn("agente-que-nao-existe", out)

    def test_seguranca_md_em_falta_falha(self):
        (self.saida / "seguranca.md").unlink()
        rc, out, _ = correr("--modo", "instantaneo", "--saida", str(self.saida))
        self.assertEqual(rc, 1)
        self.assertIn("seguranca.md em falta", out)

    def test_seguranca_md_real_passa(self):
        rc, out, _ = correr("--modo", "instantaneo", "--saida", str(RAIZ))
        self.assertEqual(rc, 0, out)


if __name__ == "__main__":
    unittest.main()
