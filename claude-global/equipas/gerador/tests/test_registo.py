import unittest
from pathlib import Path

import yamlmini
from distribuir import carregar_regras

RAIZ = Path(__file__).resolve().parents[2]


class TestRegisto(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.d = yamlmini.carregar_ficheiro(RAIZ / "equipas.yaml")

    def test_15_equipas_slugs_unicos(self):
        slugs = [e["slug"] for e in self.d["equipas"]]
        self.assertEqual(len(slugs), 15)
        self.assertEqual(len(set(slugs)), 15)

    def test_esperado_soma_932(self):
        self.assertEqual(sum(e["esperado"]["itens"] for e in self.d["equipas"]), 932)

    def test_camadas_e_equipas_somam_1144(self):
        c = self.d["camadas"]
        total = c["base"]["esperado_itens"] + c["direcao-geral"]["esperado_itens"] + 932
        self.assertEqual(total, 1144)

    def test_descricao_uma_linha_ate_160(self):
        for e in self.d["equipas"]:
            self.assertNotIn("\n", e["descricao"], e["slug"])
            self.assertLessEqual(len(e["descricao"]), 160, e["slug"])

    def test_skill_segue_o_slug(self):
        for e in self.d["equipas"]:
            self.assertEqual(e["skill"], "equipa-" + e["slug"])

    def test_excecoes_so_numa_equipa(self):
        R = carregar_regras(RAIZ / "equipas.yaml")  # levanta ErroEntrada se uma exceção se repetir
        n = sum(len(e.get("excecoes") or []) + len(e.get("excecoes_novas") or []) for e in self.d["equipas"])
        self.assertEqual(len(R.excecoes), n)  # nenhum id aparece em duas equipas
        self.assertTrue(R.opcionais <= set(R.excecoes))

    def test_funcao_so_numa_equipa(self):
        R = carregar_regras(RAIZ / "equipas.yaml")
        n = sum(len(e["funcoes"]) for e in self.d["equipas"])
        self.assertEqual(len(R.por_funcao), n)

    def test_hooks_previstos_ainda_nao_ativos(self):
        # Fase 0: os hooks de equipa são só texto; ativá-los é decisão da Fase 1
        for e in self.d["equipas"]:
            self.assertIsInstance(e["hooks_previstos"], list)


if __name__ == "__main__":
    unittest.main()
