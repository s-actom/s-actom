import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "reverter" / "reverter-fase-0.sh"


def correr(base, *args):
    p = subprocess.run(["bash", str(Path(base) / "reverter/reverter-fase-0.sh"), *args], capture_output=True, text=True, timeout=60)
    return p.returncode, p.stdout, p.stderr


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fora = Path(self.tmp.name) / "fora"
        self.fora.mkdir()
        (self.fora / "intocavel.txt").write_text("fora da base")
        self.base = Path(self.tmp.name) / "equipas"
        for rel, txt in (("PLANO.md", "plano"), ("a/b.md", "b"), ("gerador/x.py", "x = 1\n")):
            (self.base / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.base / rel).write_text(txt)
        (self.base / "gerador/__pycache__").mkdir()
        (self.base / "gerador/__pycache__/x.pyc").write_bytes(b"\0")
        (self.base / "reverter").mkdir()
        shutil.copy(SCRIPT, self.base / "reverter/reverter-fase-0.sh")
        self.rc, self.out, _ = correr(self.base, "--manifesto")
        assert self.rc == 0

    def tearDown(self):
        self.tmp.cleanup()

    def manifesto(self):
        return (self.base / "reverter/MANIFESTO.sha256").read_text().splitlines()


class TestReverter(Base):
    def test_manifesto_lista_ficheiros_sem_pycache_nem_ele_proprio(self):
        rels = [l.split("  ", 1)[1] for l in self.manifesto()]
        self.assertEqual(sorted(rels), ["PLANO.md", "a/b.md", "gerador/x.py", "reverter/reverter-fase-0.sh"])

    def test_dry_run_por_omissao(self):
        rc, out, _ = correr(self.base)
        self.assertEqual(rc, 0)
        self.assertIn("REMOVERIA: PLANO.md", out)
        self.assertTrue((self.base / "PLANO.md").exists())
        self.assertTrue((self.base / "a/b.md").exists())

    def test_manifesto_nunca_inclui_dados_nem_backups(self):
        for rel in ("backups/fase-1-x/ficheiros/settings.json", "estado/jev.json", "registo.jsonl"):
            (self.base / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.base / rel).write_text("dados")
        rc, _, _ = correr(self.base, "--manifesto")
        self.assertEqual(rc, 0)
        rels = [l.split("  ", 1)[1] for l in (self.base / "reverter/MANIFESTO.sha256").read_text().splitlines()]
        self.assertFalse([r for r in rels if r.startswith(("backups/", "estado/")) or r == "registo.jsonl"], rels)

    def test_recusa_aplicar_com_fase_1_ativa(self):
        # As skills da Fase 1 citam seguranca.md e equipas.yaml: reverter a Fase 0 primeiro deixá-las-ia órfãs.
        (self.base / "FASE-1-ATIVA").write_text("backup=backups/fase-1-20261108-000000\n")
        rc, _, err = correr(self.base, "--aplicar")
        self.assertEqual(rc, 2)
        self.assertIn("reverter-fase-1.sh", err)
        self.assertTrue((self.base / "PLANO.md").exists())
        rc, _, _ = correr(self.base)  # o ensaio continua permitido
        self.assertEqual(rc, 0)

    def test_aplicar_remove_so_o_do_manifesto(self):
        (self.base / "extra.md").write_text("não é do manifesto")
        rc, out, _ = correr(self.base, "--aplicar")
        self.assertEqual(rc, 0)
        self.assertFalse((self.base / "PLANO.md").exists())
        self.assertFalse((self.base / "a").exists())  # pasta ficou vazia
        self.assertTrue((self.base / "extra.md").exists())
        self.assertTrue((self.base / "reverter/reverter-fase-0.sh").exists())  # script e manifesto ficam
        self.assertIn("ficam 1 ficheiro(s)", out)

    def test_ficheiro_alterado_pelo_dono_fica(self):
        (self.base / "a/b.md").write_text("alterado pelo dono")
        rc, out, _ = correr(self.base, "--aplicar")
        self.assertEqual(rc, 0)
        self.assertIn("FICA (alterado depois): a/b.md", out)
        self.assertEqual((self.base / "a/b.md").read_text(), "alterado pelo dono")

    def test_remove_tudo_quando_nada_mais(self):
        rc, out, _ = correr(self.base, "--aplicar")
        self.assertEqual(rc, 0)
        self.assertIn("Fase 0 revertida", out)
        self.assertFalse(self.base.exists())
        self.assertTrue((self.fora / "intocavel.txt").exists())

    def test_recusa_caminho_fora_da_base(self):
        linha = f"{'0' * 64}  ../fora/intocavel.txt\n"
        with open(self.base / "reverter/MANIFESTO.sha256", "a") as fh:
            fh.write(linha)
        rc, _, erro = correr(self.base, "--aplicar")
        self.assertEqual(rc, 2)
        self.assertIn("caminho inseguro", erro)
        self.assertTrue((self.fora / "intocavel.txt").exists())

    def test_recusa_caminho_absoluto(self):
        with open(self.base / "reverter/MANIFESTO.sha256", "a") as fh:
            fh.write(f"{'0' * 64}  {self.fora}/intocavel.txt\n")
        rc, _, _ = correr(self.base, "--aplicar")
        self.assertEqual(rc, 2)
        self.assertTrue((self.fora / "intocavel.txt").exists())

    def test_ligacao_simbolica_nao_e_seguida(self):
        os.symlink(self.fora / "intocavel.txt", self.base / "atalho.md")
        with open(self.base / "reverter/MANIFESTO.sha256", "a") as fh:
            fh.write(f"{'0' * 64}  atalho.md\n")
        rc, out, _ = correr(self.base, "--aplicar")
        self.assertEqual(rc, 0)
        self.assertIn("FICA (ligação simbólica): atalho.md", out)
        self.assertEqual((self.fora / "intocavel.txt").read_text(), "fora da base")

    def test_manifesto_invalido_exit_1(self):
        (self.base / "reverter/MANIFESTO.sha256").write_text("isto não é um manifesto\n")
        rc, _, erro = correr(self.base, "--aplicar")
        self.assertEqual(rc, 1)
        self.assertIn("manifesto inválido", erro)
        self.assertTrue((self.base / "PLANO.md").exists())

    def test_sem_manifesto_exit_1(self):
        (self.base / "reverter/MANIFESTO.sha256").unlink()
        self.assertEqual(correr(self.base)[0], 1)

    def test_argumento_desconhecido_exit_2(self):
        self.assertEqual(correr(self.base, "--apagar-tudo")[0], 2)
        self.assertTrue((self.base / "PLANO.md").exists())


if __name__ == "__main__":
    unittest.main()
