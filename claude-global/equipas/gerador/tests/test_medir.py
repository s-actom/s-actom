import json
import tempfile
import unittest
from pathlib import Path

import medir
from fontes import ler_disco, ler_instantaneo
from tests.test_fontes import montar_home

RAIZ = Path(__file__).resolve().parents[2]


class TestMedir(unittest.TestCase):
    def test_estimar_conta_hooks_e_itens_de_um_home_de_teste(self):
        with tempfile.TemporaryDirectory() as tmp:
            ficheiro = RAIZ / "entradas/auditoria-itens-2026-11-05.json"
            e = medir.estimar(ler_instantaneo(ficheiro), ler_disco(montar_home(tmp)), json.loads(ficheiro.read_text(encoding="utf-8")))
        self.assertEqual((e["hooks_settings"], e["hooks_plugins"], e["hooks_total"]), (2, 1, 3))
        self.assertEqual((e["skills"], e["agentes"], e["mcp_servidores"]), (736, 285, 123))
        self.assertGreater(e["skills_tokens_com_descricoes_max"], e["skills_tokens_so_nomes"])
        self.assertEqual(e["mcp_ferramentas"], 1179)  # soma das contagens do snapshot (só 26 dos 123 servidores a trazem); o desenho diz 1182 por sessão
        self.assertEqual(e["mcp_tokens_nomes_adiados"], 1179 * medir.TOKENS_POR_NOME_MCP)

    def test_main_erro_de_entrada_exit_2(self):
        self.assertEqual(medir.main(["--instantaneo", "/nao/existe.json"]), 2)


if __name__ == "__main__":
    unittest.main()
