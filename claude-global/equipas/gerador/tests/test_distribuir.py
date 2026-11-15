import copy
import unittest
from dataclasses import replace
from pathlib import Path

import yamlmini
from distribuir import _montar, atribuir, carregar_regras, distribuir, existe_nome, nomes_de_seguranca, resumo_de, usado, verificar
from fontes import ErroEntrada, Item, ler_instantaneo

RAIZ = Path(__file__).resolve().parents[2]
DESENHO = {"marketing": 129, "seguranca": 63, "desenvolvimento": 106, "design": 122, "qualidade": 100, "ia": 26, "multimedia": 76,
           "ecommerce": 11, "vendas": 60, "infraestrutura": 45, "pesquisa": 21, "blockchain": 31, "reversa": 3, "operacoes": 94,
           "sistema": 45}


def item(ident, tipo="Skill", funcao="Nichos específicos", origem="local", **kw):
    base = dict(key=f"{tipo.lower()}/{ident}", tipo=tipo, id=ident, funcao=funcao, desc="", origem=origem, estado="ativa",
                usos=0, auto=0, vitalicio=None, d30=0, ultimo="", interno=False)
    base.update(kw)
    return Item(**base)


class TestGolden(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.R = carregar_regras(RAIZ / "equipas.yaml")
        cls.itens = ler_instantaneo(RAIZ / "entradas/auditoria-itens-2026-11-05.json")
        cls.res = distribuir(cls.itens, cls.R)

    def test_instantaneo_bate_com_o_desenho(self):
        problemas, _ = verificar(self.res, self.R, self.itens, exigir_desenho=True)
        self.assertEqual(problemas, [])

    def test_contagens_por_equipa(self):
        obtido = {s: len(v) for s, v in self.res.por_slug.items()}
        self.assertEqual(obtido, DESENHO)
        self.assertEqual(len(self.res.base), 37)
        self.assertEqual(len(self.res.direcao_geral), 175)
        self.assertEqual(self.res.total, 1144)

    def test_usados_321_no_total(self):
        todos = self.res.base + self.res.direcao_geral + [i for v in self.res.por_slug.values() for i in v]
        self.assertEqual(sum(1 for i in todos if usado(i)), 321)

    def test_sem_orfaos(self):
        self.assertEqual(self.res.sem_equipa, [])
        self.assertEqual(self.res.duplicados, [])

    def test_regra_dos_82(self):
        self.assertEqual(atribuir(next(i for i in self.itens if i.id == "plugin:claude-mem:mcp-search"), self.R), ("base", "base"))
        self.assertEqual(atribuir(next(i for i in self.itens if i.id == "hookify"), self.R), ("equipa", "sistema"))
        self.assertEqual(len(self.res.base) + len(self.res.por_slug["sistema"]), 82)

    def test_dados_vao_para_operacoes(self):
        dados = [i for i in self.itens if i.funcao == "Dados e analytics"]
        self.assertEqual(len(dados), 20)
        self.assertTrue(all(atribuir(i, self.R) == ("equipa", "operacoes") for i in dados))

    def test_partilhado_nao_duplica_a_contagem_primaria(self):
        ids_dev = {i.id for i in self.res.partilhados["desenvolvimento"]}
        self.assertIn("context7", ids_dev)
        self.assertIn("vibesec", ids_dev)
        self.assertEqual(sum(len(v) for v in self.res.por_slug.values()) + len(self.res.base) + len(self.res.direcao_geral), 1144)
        for slug, extras in self.res.partilhados.items():
            primarios = {id(i) for i in self.res.por_slug[slug]}
            self.assertFalse(primarios & {id(i) for i in extras}, slug)

    def test_resumo_de(self):
        r = resumo_de(self.res.por_slug["reversa"])
        self.assertEqual((r["itens"], r["usados"]), (3, 2))


class TestFalhas(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.R = carregar_regras(RAIZ / "equipas.yaml")
        cls.itens = ler_instantaneo(RAIZ / "entradas/auditoria-itens-2026-11-05.json")

    def test_item_novo_sem_regra_fica_sem_equipa(self):
        novo = item("coisa-nunca-vista", funcao="Função que ninguém conhece")
        res = distribuir(self.itens + [novo], self.R)
        self.assertEqual([i.id for i in res.sem_equipa], ["coisa-nunca-vista"])
        problemas, _ = verificar(res, self.R, self.itens + [novo], exigir_desenho=False)
        self.assertIn("sem equipa: Skill/coisa-nunca-vista", problemas)

    def test_mesmo_nome_em_duas_origens(self):
        a = item("repetida", origem="local", funcao="Pesquisa e documentação")
        b = replace(a, origem="plugin x", key="skill/repetida#2")
        res = distribuir([a, b], self.R)
        self.assertEqual(res.total, 1)
        self.assertEqual(res.duplicados, [("Skill", "repetida")])
        self.assertEqual(len(res.por_slug["pesquisa"]), 1)

    def test_mesmo_id_com_tipos_diferentes_conta_dois(self):
        a = item("igual", tipo="Skill", funcao="Pesquisa e documentação")
        b = item("igual", tipo="MCP", funcao="Pesquisa e documentação")
        self.assertEqual(distribuir([a, b], self.R).total, 2)

    def test_excecao_nova_nao_exige_existencia_mas_atribui_quando_existe(self):
        self.assertIn("plugin:hostinger:hostinger", self.R.opcionais)
        res = distribuir(self.itens, self.R)  # o snapshot não tem este id: não é problema
        problemas, _ = verificar(res, self.R, self.itens, exigir_desenho=True)
        self.assertEqual(problemas, [])
        novo = item("plugin:hostinger:hostinger", tipo="MCP", funcao="Nichos específicos", origem="Plugin")
        self.assertEqual(atribuir(novo, self.R), ("equipa", "infraestrutura"))

    def test_excecao_para_item_que_nao_existe_e_problema(self):
        pouco = [i for i in self.itens if i.id != "construcao"]
        res = distribuir(pouco, self.R)
        problemas, _ = verificar(res, self.R, pouco, exigir_desenho=False)
        self.assertTrue(any("'construcao' não existe" in p for p in problemas))

    def test_exclusao_exige_motivo_nao_se_partilha_e_pode_faltar(self):
        d = yamlmini.carregar_ficheiro(RAIZ / "equipas.yaml")
        d["excluidos"] = [{"item": "playwright", "motivo": "teste: o mecanismo, não a lista viva do dono"}]  # injetado: não depende do equipas.yaml vivo
        R = _montar(d)
        self.assertEqual(R.excluidos, {"playwright": "teste: o mecanismo, não a lista viva do dono"})
        sem_motivo = copy.deepcopy(d)
        sem_motivo["excluidos"][0]["motivo"] = " "
        partilhado = copy.deepcopy(d)
        partilhado["partilhados"].append({"item": "playwright", "tambem_em": ["design"], "razao": "x"})
        for mau in (sem_motivo, partilhado):
            with self.assertRaises(ErroEntrada):
                _montar(mau)
        # Se o excluído deixar de existir (ex.: sai do ~/.claude.json), o refresco não pára: é aviso, não problema.
        pouco = [i for i in self.itens if i.id != "playwright"]
        problemas, avisos = verificar(distribuir(pouco, R), R, pouco, exigir_desenho=False)
        self.assertEqual(problemas, [])
        self.assertTrue(any("playwright" in a for a in avisos), avisos)

    def test_contagem_errada_contra_o_desenho_e_problema(self):
        res = distribuir(self.itens[:-1], self.R)
        problemas, _ = verificar(res, self.R, self.itens[:-1], exigir_desenho=True)
        self.assertTrue(problemas)


class TestNomes(unittest.TestCase):
    def test_nomes_de_seguranca_so_identificadores(self):
        texto = "usa `security-reviewer` e `/claude-security`, ver `~/.claude/equipas/seguranca.md`, `building-secure-contracts:*`, `a b`, `x.md`"
        self.assertEqual(nomes_de_seguranca(texto), ["/claude-security", "building-secure-contracts:*", "security-reviewer"])

    def test_existe_nome_com_alias_folha_e_curinga(self):
        itens = ler_instantaneo(RAIZ / "entradas/auditoria-itens-2026-11-05.json")
        for nome in ("Snyk", "/claude-security", "building-secure-contracts:*", "insecure-defaults", "security-reviewer"):
            self.assertTrue(existe_nome(nome, itens), nome)
        self.assertFalse(existe_nome("não-existe-de-certeza", itens))


if __name__ == "__main__":
    unittest.main()
