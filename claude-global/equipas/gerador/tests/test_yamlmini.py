import unittest
from pathlib import Path

import yamlmini
from yamlmini import ErroYaml, carregar

RAIZ = Path(__file__).resolve().parents[2]


class TestEscalares(unittest.TestCase):
    def test_escalares(self):
        d = carregar("a: 1\nb: true\nc: null\nd: texto simples\ne: -3\nf: false\n")
        self.assertEqual(d, {"a": 1, "b": True, "c": None, "d": "texto simples", "e": -3, "f": False})

    def test_dois_pontos_e_cardinal_dentro_de_aspas(self):
        d = carregar('a: "x: y # z"   # comentário\nb: \'it\'\'s # ok\'\nc: d\'água # nota\n')
        self.assertEqual(d["a"], "x: y # z")
        self.assertEqual(d["b"], "it's # ok")
        self.assertEqual(d["c"], "d'água")

    def test_escapes_em_aspas_duplas(self):
        self.assertEqual(carregar('a: "linha\\nseguinte \\"x\\" \\\\"\n')["a"], 'linha\nseguinte "x" \\')


class TestEstruturas(unittest.TestCase):
    def test_mapa_aninhado_e_lista_de_mapas(self):
        d = carregar(
            "raiz:\n  filho:\n    n: 2\nequipas:\n  - slug: a\n    nome: Um\n    itens:\n      - x\n      - y\n"
            "  - slug: b\n    nome: Dois\n    esperado:\n      itens: 5\n"
        )
        self.assertEqual(d["raiz"], {"filho": {"n": 2}})
        self.assertEqual(d["equipas"][0], {"slug": "a", "nome": "Um", "itens": ["x", "y"]})
        self.assertEqual(d["equipas"][1], {"slug": "b", "nome": "Dois", "esperado": {"itens": 5}})

    def test_lista_inline(self):
        d = carregar('x: ["a, b", c, 3, \'d\']\ny: []\n')
        self.assertEqual(d, {"x": ["a, b", "c", 3, "d"], "y": []})

    def test_lista_de_escalares_na_raiz(self):
        self.assertEqual(carregar("- a\n- 2\n- \"c: d\"\n"), ["a", 2, "c: d"])

    def test_chave_sem_filhos_e_none(self):
        self.assertEqual(carregar("a:\nb: 1\n"), {"a": None, "b": 1})


class TestFalhaFechada(unittest.TestCase):
    def assertErro(self, texto):
        with self.assertRaises(ErroYaml, msg=repr(texto)):
            carregar(texto)

    def test_rejeita_tabs(self):
        self.assertErro("a:\n\tb: 1\n")

    def test_rejeita_ancoras_e_tags(self):
        for t in ("a: &x 1\n", "a: *x\n", "a: !!str x\n", "a: !tag x\n"):
            self.assertErro(t)

    def test_rejeita_chave_duplicada(self):
        self.assertErro("a: 1\na: 2\n")

    def test_rejeita_indentacao_impar(self):
        self.assertErro("a:\n   b: 1\n")

    def test_rejeita_blocos_e_fluxo(self):
        for t in ("a: |\n  x\n", "a: >\n  x\n", "a: {b: 1}\n", "a: [[1], 2]\n"):
            self.assertErro(t)

    def test_rejeita_escalar_simples_ambiguo(self):
        self.assertErro("a: texto: com dois pontos\n")

    def test_rejeita_aspas_por_fechar(self):
        self.assertErro('a: "aberta\n')

    def test_rejeita_elemento_vazio_em_lista_inline(self):
        self.assertErro("a: [1, , 2]\n")


class TestRegistoReal(unittest.TestCase):
    def test_carrega_equipas_yaml_real(self):
        caminho = RAIZ / "equipas.yaml"
        if not caminho.exists():
            self.skipTest("equipas.yaml ainda não existe")
        d = yamlmini.carregar_ficheiro(caminho)
        self.assertIsInstance(d, dict)
        self.assertIn("equipas", d)


if __name__ == "__main__":
    unittest.main()
