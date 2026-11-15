#!/usr/bin/env python3
"""Contagens e estimativas do custo fixo (Fase 0 / repetir na Fase 3). Só leitura; nada é escrito.

Uso: python3 -I medir.py [--home CAMINHO]
Estimativas = caracteres / 4 (aproximação) e vêm marcadas como "estimativa". Os valores medidos
(get_usage da app, <usage> de subagentes, claude -p) registam-se à mão em medida-de-partida.md.
"""
import argparse
import json
import re
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))

import fontes as F  # noqa: E402
import gerar  # noqa: E402

TOKENS_POR_NOME_MCP = 9  # estimativa: um nome mcp__servidor__ferramenta na lista de ferramentas adiadas


def tokens(caracteres):
    return round(caracteres / 4)


def estimar(itens, disco, bruto):
    """Contagens e estimativas dos itens que carregam. `bruto` = snapshot em JSON (para o nº de ferramentas MCP)."""
    sk = [i for i in itens if i.tipo == "Skill"]
    ag = [i for i in itens if i.tipo == "Agente"]
    so_nomes = sum(len(i.id) + 3 for i in sk)
    com_desc = sum(len(i.id) + len(i.desc) + 5 for i in sk)
    t_ag = sum(len(i.id) + len(disco.agentes.get(i.id, {}).get("desc", i.desc)) + len(disco.agentes.get(i.id, {}).get("tools", "")) + 25 for i in ag)
    vivos = {i.id for i in itens if i.tipo == "MCP"}  # um servidor que já não existe não conta ferramentas
    ferramentas = sum(int(m.group(1)) for r in bruto if r.get("tipo") == "MCP" and r.get("id") in vivos
                      for m in [re.search(r"(\d+) ferramentas", r.get("desc") or "")] if m)
    return {
        "skills": len(sk), "skills_tokens_so_nomes": tokens(so_nomes), "skills_tokens_com_descricoes_max": tokens(com_desc),
        "agentes": len(ag), "agentes_tokens": tokens(t_ag),
        "mcp_servidores": sum(1 for i in itens if i.tipo == "MCP"), "mcp_ferramentas": ferramentas,
        "mcp_tokens_nomes_adiados": ferramentas * TOKENS_POR_NOME_MCP,
        "hooks_settings": disco.hooks["settings"], "hooks_plugins": disco.hooks["plugins"],
        "hooks_total": disco.hooks["settings"] + disco.hooks["plugins"],
    }


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--home", default=str(Path.home()))
    ap.add_argument("--instantaneo", default=str(AQUI.parent / "entradas/auditoria-itens-2026-11-05.json"))
    a = ap.parse_args(argv)
    try:
        snap = F.ler_instantaneo(a.instantaneo)
        bruto = json.loads(Path(a.instantaneo).read_text(encoding="utf-8"))
        disco = F.ler_disco(a.home)
        itens, _ = F.juntar(snap, disco, gerar.classificar)
        e = estimar(itens, disco, bruto)
    except (F.ErroEntrada, OSError) as err:
        print(f"ERRO DE ENTRADA: {err}", file=sys.stderr)
        return 2
    for k, v in e.items():
        print(f"{k}\t{v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
