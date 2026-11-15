"""Testes de equipas/modelos/descobrir.py — descoberta local, sem rede, e autorização explícita.

O que se prova: só entram modelos de fornecedores permitidos e ativos na configuração;
entradas desativadas ficam de fora; `--escrever` nunca autoriza ninguém; a comparação
deteta configuração sem autorização.
"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("descobrir", RAIZ / "modelos" / "descobrir.py")
descobrir = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(descobrir)


def escrever(p, texto):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(texto, encoding="utf-8")


def home_sintetico(t, *, claude=True, codex=True, zcode=True, servidor=True):
    h = Path(t)
    if claude:
        escrever(h / ".claude/settings.json", json.dumps({
            "model": "claude-do-teste",
            "modelSettings": {"claude-do-teste": {}, "claude-pequeno": {"x": 1}},
        }))
    if codex:
        escrever(h / ".codex/config.toml", 'model = "gpt-exemplo"\n[outra.seccao]\nmodel = "ignorado"\n')
        escrever(h / ".codex/AGENTS.md", 'model="gpt-fixo" e model="gpt-fixo"\n')
    if zcode:
        escrever(h / ".zcode/v2/provider_config.json", json.dumps({
            "schemaVersion": 1,
            "config": {
                "providerOrder": ["zai-api", "deepseek"],
                "providerConfigRules": {"providerRules": [
                    {"providerId": "zai-api", "enabled": False},
                    {"providerId": "deepseek"},
                ]},
                "modelConfigRules": {"providerModelRules": [
                    {"providerId": "account:zai-individual-coding-plan", "modelId": "glm-ativo", "config": {"enabled": True}},
                    {"providerId": "account:zai-individual-coding-plan", "modelId": "glm-flash", "config": {"enabled": True}},
                    {"providerId": "account:zai-start-plan", "modelId": "glm-desativado", "config": {"enabled": False}},
                    {"providerId": "deepseek", "modelId": "ds-desativado", "config": {"enabled": False}},
                    {"providerId": "openrouter", "modelId": "slug-de-fora", "config": {"enabled": True}},
                ]},
                "defaultModelSelection": {"providerId": "account:zai-individual-coding-plan", "modelId": "glm-ativo"},
            },
        }))
    if servidor:
        escrever(h / ".deepseek-agent/server.py", 'MODEL = "ds-servidor"\n')
    return h


class TestDescoberta(unittest.TestCase):
    def test_so_entra_o_que_esta_ativo_e_em_fornecedor_permitido(self):
        with tempfile.TemporaryDirectory() as t:
            c = descobrir.descobrir(home_sintetico(t))
        ids = {x["id"] for x in c}
        self.assertIn("claude-do-teste", ids)
        self.assertIn("claude-pequeno", ids)
        self.assertIn("gpt-exemplo", ids)
        self.assertIn("gpt-fixo", ids)
        self.assertIn("glm-ativo", ids)
        self.assertIn("glm-flash", ids)
        self.assertIn("ds-servidor", ids)
        # desativado no config -> fora
        self.assertNotIn("glm-desativado", ids)
        self.assertNotIn("ds-desativado", ids)
        # fornecedor não permitido -> fora
        self.assertNotIn("slug-de-fora", ids)
        # o modelo de secção TOML não conta como modelo do runtime
        self.assertNotIn("ignorado", ids)
        # duplicado (modelo + defaultModelSelection) aparece uma só vez
        self.assertEqual(len([x for x in c if x["id"] == "glm-ativo"]), 1)

    def test_atribui_fornecedor_runtime_e_acesso(self):
        with tempfile.TemporaryDirectory() as t:
            c = {x["id"]: x for x in descobrir.descobrir(home_sintetico(t))}
        self.assertEqual((c["claude-do-teste"]["fornecedor"], c["claude-do-teste"]["runtime"]), ("anthropic", "claude-code"))
        self.assertEqual((c["gpt-exemplo"]["fornecedor"], c["gpt-exemplo"]["runtime"]), ("openai", "codex"))
        self.assertEqual((c["glm-ativo"]["fornecedor"], c["glm-ativo"]["runtime"]), ("glm", "zcode"))
        self.assertEqual((c["ds-servidor"]["fornecedor"], c["ds-servidor"]["runtime"]), ("deepseek", "deepseek-agent"))

    def test_comparar_detecta_configurado_sem_autorizacao(self):
        with tempfile.TemporaryDirectory() as t:
            c = descobrir.descobrir(home_sintetico(t))
            registo = {
                "politica": {"fornecedores_permitidos": ["openai", "anthropic", "deepseek", "glm"]},
                "modelos": [{"id": "claude-do-teste", "fornecedor": "anthropic", "ativo": True, "autorizado": True}],
            }
            dif = descobrir.comparar(c, registo)
        self.assertIn("gpt-exemplo", dif["configurados_sem_autorizacao"])
        self.assertNotIn("claude-do-teste", dif["configurados_sem_autorizacao"])

    def test_escrever_adiciona_pendentes_e_nunca_autoriza(self):
        with tempfile.TemporaryDirectory() as t:
            h = home_sintetico(t)
            registo = Path(t) / "autorizacao.json"
            registo.write_text(json.dumps({
                "politica": {"fornecedores_permitidos": ["openai", "anthropic", "deepseek", "glm"]},
                "modelos": [{"id": "claude-do-teste", "fornecedor": "anthropic", "runtime": "claude-code",
                             "acesso": "subscricao-cli", "ativo": True, "autorizado": True}],
            }), encoding="utf-8")
            n = descobrir.escrever(descobrir.descobrir(h), registo)
            dados = json.loads(registo.read_text(encoding="utf-8"))
        novos = [m for m in dados["modelos"] if m["id"] != "claude-do-teste"]
        self.assertGreater(n, 0)
        self.assertTrue(novos)
        for m in novos:
            self.assertFalse(m["ativo"], m["id"])
            self.assertFalse(m["autorizado"], m["id"])
        # o que já existia não é tocado
        antigo = [m for m in dados["modelos"] if m["id"] == "claude-do-teste"][0]
        self.assertTrue(antigo["autorizado"])

    def test_escrever_nao_duplica_em_segunda_passagem(self):
        with tempfile.TemporaryDirectory() as t:
            h = home_sintetico(t)
            registo = Path(t) / "autorizacao.json"
            registo.write_text(json.dumps({"politica": {"fornecedores_permitidos": ["openai", "anthropic", "deepseek", "glm"]}, "modelos": []}), encoding="utf-8")
            primeiro = descobrir.escrever(descobrir.descobrir(h), registo)
            segundo = descobrir.escrever(descobrir.descobrir(h), registo)
            total = len(json.loads(registo.read_text(encoding="utf-8"))["modelos"])
        self.assertGreater(primeiro, 0)
        self.assertEqual(segundo, 0)
        self.assertEqual(total, primeiro)

    def test_verificar_falha_quando_ha_configuracao_sem_autorizacao(self):
        with tempfile.TemporaryDirectory() as t:
            h = home_sintetico(t)
            registo = Path(t) / "autorizacao.json"
            registo.write_text(json.dumps({"politica": {"fornecedores_permitidos": ["openai", "anthropic", "deepseek", "glm"]}, "modelos": []}), encoding="utf-8")
            # Registo explícito: sem ele o teste compararia com o registo real da máquina.
            rc = descobrir.main(["--verificar", "--home", str(h), "--registo", str(registo)])
        self.assertEqual(rc, 1)

    def test_verificar_passa_quando_tudo_o_que_esta_configurado_esta_autorizado(self):
        with tempfile.TemporaryDirectory() as t:
            h = home_sintetico(t)
            registo = Path(t) / "autorizacao.json"
            registo.write_text(json.dumps({"politica": {"fornecedores_permitidos": ["openai", "anthropic", "deepseek", "glm"]}, "modelos": []}), encoding="utf-8")
            descobrir.escrever(descobrir.descobrir(h), registo)
            # Autorizar explicitamente o que a descoberta propôs (simula a decisão do dono).
            dados = json.loads(registo.read_text(encoding="utf-8"))
            for m in dados["modelos"]:
                m["ativo"] = True
                m["autorizado"] = True
            registo.write_text(json.dumps(dados), encoding="utf-8")
            rc = descobrir.main(["--verificar", "--home", str(h), "--registo", str(registo)])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
