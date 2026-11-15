#!/usr/bin/env python3
"""descobrir.py — propõe candidatos a partir da configuração LOCAL dos runtimes.

Regras (Adaptive Model Intelligence):
  - não faz rede: só lê ficheiros locais;
  - pertencer a um dos fornecedores permitidos NÃO autoriza: as entradas novas entram
    sempre com `ativo:false` e `autorizado:false` (pendentes do proprietário);
  - não remove nem reescreve autorizações existentes;
  - `--verificar` reporta divergências e falha (exit 1), sem alterar nada.

Uso:
  descobrir.py                 # tabela de candidatos e diferenças face ao registo
  descobrir.py --verificar     # exit 1 se houver divergência
  descobrir.py --escrever      # junta candidatos NOVOS como pendentes (nunca autoriza)
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
REGISTO = AQUI / "autorizacao.json"

# Estrutura -> fornecedor. É a configuração que diz de quem é o modelo; não o nome do modelo.
FORNECEDOR_POR_PROVIDER = {
    "deepseek": "deepseek",
    "zai-api": "glm",
    "zai-standard-api": "glm",
    "bigmodel-api": "glm",
    "bigmodel-standard-api": "glm",
}
# Contas de plano (ex.: "account:zai-individual-coding-plan") herdam o fornecedor da família.
FAMILIAS_PROVIDER = (("account:zai", "glm"), ("account:bigmodel", "glm"), ("account:deepseek", "deepseek"))
FORNECEDOR_POR_RUNTIME = {"claude-code": "anthropic", "codex": "openai"}


def _fornecedor_de_provider(pid):
    if pid in FORNECEDOR_POR_PROVIDER:
        return FORNECEDOR_POR_PROVIDER[pid]
    for prefixo, fornecedor in FAMILIAS_PROVIDER:
        if pid.startswith(prefixo):
            return fornecedor
    return None


def _ler(caminho):
    try:
        p = Path(caminho)
        if p.is_symlink() or not p.is_file():
            return None
        return p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None


def _add(saida, vistos, mid, fornecedor, runtime, acesso, origem):
    mid = (mid or "").strip()
    if not mid or not fornecedor:
        return
    chave = (mid, runtime)
    if chave in vistos:
        return
    vistos.add(chave)
    saida.append({"id": mid, "fornecedor": fornecedor, "runtime": runtime,
                  "acesso": acesso, "origem": origem, "ativo": True, "autorizado": True})


def claude_code(home, saida, vistos):
    txt = _ler(home / ".claude/settings.json")
    if not txt:
        return
    try:
        cfg = json.loads(txt)
    except ValueError:
        return
    if isinstance(cfg.get("model"), str):
        _add(saida, vistos, cfg["model"], "anthropic", "claude-code", "subscricao-cli",
             "~/.claude/settings.json (model)")
    ms = cfg.get("modelSettings")
    if isinstance(ms, dict):
        for mid in ms:
            _add(saida, vistos, mid, "anthropic", "claude-code", "subscricao-cli",
                 "~/.claude/settings.json (modelSettings)")


def codex(home, saida, vistos):
    txt = _ler(home / ".codex/config.toml")
    if txt:
        for linha in txt.splitlines():
            if linha.startswith("["):
                break  # só o bloco de topo
            m = re.match(r'\s*model\s*=\s*"([^"]+)"', linha)
            if m:
                _add(saida, vistos, m.group(1), "openai", "codex", "cli", "~/.codex/config.toml (model)")
                break
    agents = _ler(home / ".codex/AGENTS.md")
    if agents:
        for m in re.finditer(r'model\s*=\s*"([^"]+)"', agents):
            _add(saida, vistos, m.group(1), "openai", "codex", "cli", "~/.codex/AGENTS.md (model lock)")


def zcode(home, saida, vistos):
    """Estrutura real: config.providerConfigRules.providerRules e
    config.modelConfigRules.providerModelRules (com `config.enabled` por modelo)."""
    txt = _ler(home / ".zcode/v2/provider_config.json")
    if txt:
        try:
            cfg = json.loads(txt)
        except ValueError:
            cfg = None
        cfg = (cfg or {}).get("config") if isinstance(cfg, dict) else None
        if isinstance(cfg, dict):
            regras = (cfg.get("providerConfigRules") or {}).get("providerRules") or []
            desativados = {r.get("providerId") for r in regras
                           if isinstance(r, dict) and r.get("enabled") is False}
            for r in (cfg.get("modelConfigRules") or {}).get("providerModelRules") or []:
                if not isinstance(r, dict):
                    continue
                pid = str(r.get("providerId") or "")
                if pid in desativados:
                    continue
                fornecedor = _fornecedor_de_provider(pid)
                if not fornecedor:
                    continue
                conf = r.get("config") if isinstance(r.get("config"), dict) else {}
                if conf.get("enabled") is False:
                    continue
                _add(saida, vistos, r.get("modelId"), fornecedor, "zcode", "subscricao",
                     "~/.zcode/v2/provider_config.json (providerModelRules de %s)" % pid)
            sel = cfg.get("defaultModelSelection")
            if isinstance(sel, dict) and isinstance(sel.get("modelId"), str):
                fornecedor = _fornecedor_de_provider(str(sel.get("providerId") or ""))
                if fornecedor:
                    _add(saida, vistos, sel["modelId"], fornecedor, "zcode", "subscricao",
                         "~/.zcode/v2/provider_config.json (defaultModelSelection)")
    # Servidor MCP local que fixa um modelo para si próprio (não é o ZCode).
    srv = _ler(home / ".deepseek-agent/server.py")
    if srv:
        m = re.search(r'^\s*MODEL\s*=\s*"([^"]+)"', srv, re.M)
        if m:
            _add(saida, vistos, m.group(1), "deepseek", "deepseek-agent", "api-key",
                 "~/.deepseek-agent/server.py (MODEL)")


def descobrir(home=None):
    home = Path(home or os.path.expanduser("~"))
    saida, vistos = [], set()
    claude_code(home, saida, vistos)
    codex(home, saida, vistos)
    zcode(home, saida, vistos)
    return sorted(saida, key=lambda m: (m["fornecedor"], m["id"], m["runtime"]))


def carregar_registo(caminho=None):
    try:
        return json.loads(Path(caminho or REGISTO).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def autorizados_local(registo):
    """IDs autorizados e ativos, e o conjunto de fornecedores permitidos."""
    if not isinstance(registo, dict):
        return set(), set()
    permitidos = set((registo.get("politica") or {}).get("fornecedores_permitidos") or [])
    ids = {m.get("id") for m in registo.get("modelos") or []
           if isinstance(m, dict) and m.get("ativo") is True and m.get("autorizado") is True
           and m.get("fornecedor") in permitidos}
    return ids, permitidos


def comparar(candidatos, registo):
    ids_aut, permitidos = autorizados_local(registo)
    configurados = {c["id"] for c in candidatos if c["fornecedor"] in permitidos}
    return {
        "configurados_sem_autorizacao": sorted(configurados - ids_aut),
        "autorizados_sem_configuracao": sorted(ids_aut - configurados),
        "fora_dos_fornecedores_permitidos": sorted({c["id"] for c in candidatos if c["fornecedor"] not in permitidos}),
    }


def escrever(candidatos, caminho=None):
    """Junta candidatos AUSENTES como pendentes. Nunca promove a autorizado."""
    caminho = Path(caminho or REGISTO)
    registo = carregar_registo(caminho)
    if not isinstance(registo, dict):
        raise SystemExit("registo ilegível: nada escrito")
    permitidos = set((registo.get("politica") or {}).get("fornecedores_permitidos") or [])
    existentes = {m.get("id") for m in registo.get("modelos") or [] if isinstance(m, dict)}
    novos = 0
    for c in candidatos:
        if c["fornecedor"] not in permitidos or c["id"] in existentes:
            continue
        registo["modelos"].append({
            "id": c["id"], "fornecedor": c["fornecedor"], "runtime": c["runtime"],
            "acesso": c["acesso"], "origem": c["origem"],
            "ativo": False, "autorizado": False,
            "autorizado_por": None, "autorizado_em": None, "preco": None,
        })
        existentes.add(c["id"])
        novos += 1
    if novos:
        Path(caminho).write_text(json.dumps(registo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return novos


def main(argv):
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--verificar", action="store_true")
    ap.add_argument("--escrever", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--home", default=None)
    ap.add_argument("--registo", default=None, help="registo alternativo (testes)")
    a = ap.parse_args(argv)

    caminho_registo = a.registo or REGISTO
    candidatos = descobrir(a.home)
    registo = carregar_registo(caminho_registo)
    dif = comparar(candidatos, registo)

    if a.json:
        print(json.dumps({"candidatos": candidatos, "diferencas": dif}, ensure_ascii=False, indent=2))
    else:
        print("candidatos encontrados na configuração local: %d" % len(candidatos))
        for c in candidatos:
            print("  %-22s %-9s %-11s %-14s %s" % (c["id"], c["fornecedor"], c["runtime"], c["acesso"], c["origem"]))
        for chave, rotulo in (("configurados_sem_autorizacao", "configurados e NÃO autorizados"),
                              ("autorizados_sem_configuracao", "autorizados mas já não configurados"),
                              ("fora_dos_fornecedores_permitidos", "ignorados (fornecedor não permitido)")):
            if dif[chave]:
                print("%s: %s" % (rotulo, ", ".join(dif[chave])))

    if a.escrever:
        n = escrever(candidatos, caminho_registo)
        print("pendentes adicionados: %d (ficam ativo:false e autorizado:false)" % n, file=sys.stderr)

    if a.verificar:
        # Só é divergência o que o proprietário configurou e o registo não autoriza.
        # `autorizados_sem_configuracao` é aviso: pode ser um modelo usado por API direta.
        if dif["configurados_sem_autorizacao"]:
            print("DIVERGÊNCIA: configurado sem autorização explícita", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
