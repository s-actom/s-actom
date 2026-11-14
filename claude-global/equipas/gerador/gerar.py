#!/usr/bin/env python3
"""Gerador do registo de equipas (Fase 0). Só biblioteca padrão; escreve apenas dentro da pasta --saida.

Uso: python3 -I gerar.py [--modo vivo|instantaneo] [--home CAMINHO] [--saida CAMINHO] [--verificar]
  vivo         snapshot de 2026-11-05 + disco de agora; escreve relatorio/ e rascunho/
  instantaneo  só o snapshot; verifica que as regras reproduzem o desenho (nunca escreve)
Saída: 0 tudo bate · 1 verificação falhou (ficheiros escritos, com os problemas) · 2 erro de entrada (nada escrito)
"""
import argparse
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
sys.path.insert(0, str(AQUI))  # com -I o diretório do script não entra sozinho

import classify as K  # noqa: E402
import distribuir as D  # noqa: E402
import escrever as E  # noqa: E402
import fontes as F  # noqa: E402


def classificar(tipo, ident):
    cat = K.skill_category(ident) if tipo == "Skill" else K.agent_category(ident) if tipo == "Agente" else K.mcp_category(ident)
    return K.CATS[cat]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--modo", choices=("vivo", "instantaneo"), default="vivo")
    ap.add_argument("--home", default=str(Path.home()))
    ap.add_argument("--saida", default=str(AQUI.parent))
    ap.add_argument("--verificar", action="store_true")
    a = ap.parse_args(argv)
    saida = Path(a.saida)
    somente_verificar = a.verificar or a.modo == "instantaneo"
    try:
        R = D.carregar_regras(saida / "equipas.yaml")
        snap = F.ler_instantaneo(saida / R.instantaneo)
        disco = dif = None
        if a.modo == "vivo":
            disco = F.ler_disco(a.home)
            itens, dif = F.juntar(snap, disco, classificar)
        else:
            itens = snap
        seguranca = saida / "seguranca.md"
        texto_seg = seguranca.read_text(encoding="utf-8") if seguranca.exists() else None
    except (F.ErroEntrada, OSError) as e:
        print(f"ERRO DE ENTRADA (nada escrito): {e}", file=sys.stderr)
        return 2

    res = D.distribuir(itens, R)
    problemas, avisos = D.verificar(res, R, itens, exigir_desenho=a.modo == "instantaneo")
    if texto_seg is None:
        problemas.append("seguranca.md em falta")
    else:
        nomes = D.nomes_existentes(itens)
        problemas += [f"seguranca.md cita '{n}', que não existe" for n in D.nomes_de_seguranca(texto_seg) if not D.existe_nome(n, itens, nomes)]

    pub = D.excluir(res, R)  # depois da verificação do desenho: o que se escreve e mostra já não tem os excluídos
    if not somente_verificar:
        try:
            escritos = E.escrever_tudo(R, pub, dif, disco, a.modo, saida, AQUI / "modelos")
        except (E.ErroEscrita, OSError) as e:
            print(f"ERRO DE ESCRITA: {e}", file=sys.stderr)
            return 2
        print(f"escritos {len(escritos)} ficheiros em {saida}")

    print(E.render_resumo(R, pub, a.modo))
    for linha in avisos:
        print(f"aviso: {linha}")
    if problemas:
        print(f"VERIFICAÇÃO FALHOU ({len(problemas)}):")
        for p in problemas:
            print(f"  - {p}")
        return 1
    print(f"VERIFICAÇÃO OK: {res.total} itens · {len(R.equipas)} equipas + Base {len(res.base)} + Direção Geral {len(res.direcao_geral)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
