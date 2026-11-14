"""Atribuição de cada item a camada e equipa, segundo equipas.yaml, e verificações cruzadas."""
import re
from dataclasses import dataclass, field, replace

import yamlmini
from fontes import ErroEntrada, limpar_texto

# Nomes que seguranca.md escreve de forma curta e que existem com outro id.
ALIAS_NOMES = {"Snyk": "Snyk Security", "/claude-security": "claude-security:claude-security"}


@dataclass
class Regras:
    camadas: dict
    equipas: list
    por_slug: dict
    excecoes: dict
    prefixos: list
    por_funcao: dict
    r: dict
    partilhados: list
    dg: dict
    instantaneo: str = ""
    opcionais: set = field(default_factory=set)  # exceções posteriores ao snapshot: podem não existir
    excluidos: dict = field(default_factory=dict)  # id → motivo: fora de todas as listas publicadas (decisão do dono)


def carregar_regras(caminho):
    try:
        return _montar(yamlmini.carregar_ficheiro(caminho))
    except (OSError, yamlmini.ErroYaml) as e:
        raise ErroEntrada(f"equipas.yaml: {e}") from None
    except (KeyError, TypeError, AttributeError) as e:
        raise ErroEntrada(f"equipas.yaml incompleto ou com forma inesperada: {e!r}") from None


def _montar(d):
    por_slug, excecoes, prefixos, por_funcao, opcionais = {}, {}, [], {}, set()
    for e in d["equipas"]:
        s = e["slug"]
        if s in por_slug:
            raise ErroEntrada(f"slug repetido: {s}")
        if e["skill"] != f"equipa-{s}":
            raise ErroEntrada(f"skill de {s} tem de se chamar equipa-{s}")
        por_slug[s] = e
        for i in (e.get("excecoes") or []) + (e.get("excecoes_novas") or []):
            if i in excecoes:
                raise ErroEntrada(f"exceção repetida: {i}")
            excecoes[i] = s
        opcionais |= set(e.get("excecoes_novas") or [])
        prefixos += [(p, s) for p in e.get("prefixos") or []]
        for f in e["funcoes"]:
            if f in por_funcao:
                raise ErroEntrada(f"função em duas equipas: {f}")
            por_funcao[f] = s
    r = d["regras"]
    for chave in ("funcao_harness", "funcao_dados", "dados_para", "harness_resto_para", "qualidade_para",
                  "qualidade_funcoes", "qualidade_sufixos", "base"):
        r[chave]
    for destino in (r["dados_para"], r["harness_resto_para"], r["qualidade_para"]):
        if destino not in por_slug:
            raise ErroEntrada(f"equipa de destino desconhecida: {destino}")
    partilhados = d.get("partilhados") or []
    for p in partilhados:
        for s in p["tambem_em"]:
            if s not in por_slug:
                raise ErroEntrada(f"partilhado com equipa desconhecida: {s}")
    excluidos = {}
    for x in d.get("excluidos") or []:
        if x["item"] in excluidos:
            raise ErroEntrada(f"exclusão repetida: {x['item']}")
        if not str(x.get("motivo") or "").strip():
            raise ErroEntrada(f"exclusão sem motivo: {x['item']}")
        excluidos[x["item"]] = x["motivo"]
    for p in partilhados:
        if p["item"] in excluidos:
            raise ErroEntrada(f"'{p['item']}' está excluído e partilhado ao mesmo tempo")
    return Regras(camadas=d["camadas"], equipas=d["equipas"], por_slug=por_slug, excecoes=excecoes, prefixos=prefixos,
                  por_funcao=por_funcao, r=r, partilhados=partilhados, dg=d["direcao_geral"], instantaneo=d["instantaneo"],
                  opcionais=opcionais, excluidos=excluidos)


def _eh_base(item, b):
    return (item.origem in b["origens"] or item.id in b["ids"] or item.id.startswith(tuple(b["prefixos"]))
            or any(s in item.id for s in b["contem"]))


def atribuir(item, R):
    """(camada, slug). Camada: base | direcao-geral | equipa | sem-equipa."""
    if item.id in R.excecoes:
        return "equipa", R.excecoes[item.id]
    for prefixo, slug in R.prefixos:
        if item.id.startswith(prefixo):
            return "equipa", slug
    dg = R.camadas["direcao-geral"]
    if item.funcao in (dg.get("funcoes") or []) or item.id.startswith(tuple(dg.get("prefixos") or [])):
        return "direcao-geral", "direcao-geral"
    r = R.r
    if item.funcao in r["qualidade_funcoes"] and item.id.endswith(tuple(r["qualidade_sufixos"])):
        return "equipa", r["qualidade_para"]
    if item.funcao == r["funcao_harness"]:
        return ("base", "base") if _eh_base(item, r["base"]) else ("equipa", r["harness_resto_para"])
    if item.funcao == r["funcao_dados"]:
        return "equipa", r["dados_para"]
    slug = R.por_funcao.get(item.funcao)
    return ("equipa", slug) if slug else ("sem-equipa", "")


@dataclass
class Resultado:
    base: list = field(default_factory=list)
    direcao_geral: list = field(default_factory=list)
    por_slug: dict = field(default_factory=dict)
    sem_equipa: list = field(default_factory=list)
    partilhados: dict = field(default_factory=dict)
    duplicados: list = field(default_factory=list)
    atribuicao: dict = field(default_factory=dict)
    total: int = 0
    excluidos: list = field(default_factory=list)  # preenchido só por excluir()


def distribuir(itens, R):
    res = Resultado(por_slug={s: [] for s in R.por_slug}, partilhados={s: [] for s in R.por_slug})
    unicos = []
    for it in itens:
        chave = (it.tipo, it.id)
        if chave in res.atribuicao:
            res.duplicados.append(chave)  # fica o primeiro; o segundo é registado, nunca somado
            continue
        res.atribuicao[chave] = atribuir(it, R)
        unicos.append(it)
        camada, slug = res.atribuicao[chave]
        if camada == "base":
            res.base.append(it)
        elif camada == "direcao-geral":
            res.direcao_geral.append(it)
        elif camada == "equipa":
            res.por_slug[slug].append(it)
        else:
            res.sem_equipa.append(it)
    res.total = len(unicos)
    for p in R.partilhados:
        for it in unicos:
            if it.id != p["item"]:
                continue
            primaria = res.atribuicao[(it.tipo, it.id)][1]
            for s in p["tambem_em"]:
                if s != primaria and it not in res.partilhados[s]:
                    res.partilhados[s].append(it)
    return res


def excluir(res, R):
    """Resultado novo sem os itens de R.excluidos em nenhuma camada, equipa ou partilha; `res` fica igual.
    Corre depois de verificar(): o desenho conta-os na equipa das regras, as listas publicadas não os mostram."""
    fora = [i for i in res.base + res.direcao_geral + [x for v in res.por_slug.values() for x in v] + res.sem_equipa
            if i.id in R.excluidos]
    if not fora:
        return res

    def ficam(itens):
        return [i for i in itens if i.id not in R.excluidos]

    return replace(res, base=ficam(res.base), direcao_geral=ficam(res.direcao_geral), sem_equipa=ficam(res.sem_equipa),
                   por_slug={s: ficam(v) for s, v in res.por_slug.items()},
                   partilhados={s: ficam(v) for s, v in res.partilhados.items()},
                   atribuicao={k: ("excluido", "") if k[1] in R.excluidos else v for k, v in res.atribuicao.items()},
                   excluidos=sorted(fora, key=lambda i: (i.tipo, i.id)))


def usado(it):
    return (it.usos + it.auto) > 0


def resumo_de(itens):
    return {"itens": len(itens), "usados": sum(1 for i in itens if usado(i)),
            "skills": sum(1 for i in itens if i.tipo == "Skill"), "agentes": sum(1 for i in itens if i.tipo == "Agente"),
            "mcp": sum(1 for i in itens if i.tipo == "MCP")}


def nomes_existentes(itens):
    """Ids e folhas (`plugin:folha` conta também como `folha`)."""
    nomes = set()
    for i in itens:
        nomes.add(i.id)
        nomes.add(i.id.split(":")[-1])
    return nomes


def existe_nome(nome, itens, nomes=None):
    nomes = nomes if nomes is not None else nomes_existentes(itens)
    nome = ALIAS_NOMES.get(nome, nome)
    if nome.endswith(":*"):
        return any(i.id.startswith(nome[:-1]) for i in itens)
    return nome in nomes


_RE_NOME = re.compile(r"^/?[A-Za-z0-9_][A-Za-z0-9_:*-]*$")


def nomes_de_seguranca(texto):
    """Nomes entre crases em seguranca.md que parecem identificadores (sem '.' nem '/' a meio)."""
    return sorted({t for t in re.findall(r"`([^`\n]+)`", texto) if _RE_NOME.match(t)})


def verificar(res, R, itens, exigir_desenho=True):
    """(problemas, avisos). Problemas fazem o gerador falhar o fecho."""
    problemas, avisos = [], []
    problemas += [f"sem equipa: {i.tipo}/{limpar_texto(i.id, 80)}" for i in res.sem_equipa]
    atribuidos = len(res.base) + len(res.direcao_geral) + sum(len(v) for v in res.por_slug.values()) + len(res.sem_equipa)
    if atribuidos != res.total:
        problemas.append(f"total não bate: {atribuidos} atribuídos contra {res.total} itens")
    avisos += [f"duplicado ignorado: {t}/{limpar_texto(i, 80)}" for t, i in res.duplicados]
    ids = nomes_existentes(itens)
    for ident, slug in R.excecoes.items():
        if ident not in ids and ident not in R.opcionais and ident not in R.excluidos:
            problemas.append(f"exceção de {slug}: '{ident}' não existe")
    exatos = {i.id for i in itens}
    avisos += [f"exclusão sem efeito: '{limpar_texto(x, 80)}' não existe" for x in R.excluidos if x not in exatos]
    for p in R.partilhados:
        if p["item"] not in ids:
            problemas.append(f"partilhado '{p['item']}' não existe")
        for (tipo, ident), (_, slug) in res.atribuicao.items():
            if ident == p["item"] and slug in p["tambem_em"]:
                problemas.append(f"'{ident}' está partilhado com a sua própria equipa ({slug})")
    for rev in R.dg["revisores"]:
        if ("Agente", rev) not in res.atribuicao:
            problemas.append(f"revisor '{rev}' não existe como agente")
    if exigir_desenho:
        for slug, e in R.por_slug.items():
            r = resumo_de(res.por_slug[slug])
            for campo in ("itens", "usados"):
                if r[campo] != e["esperado"][campo]:
                    problemas.append(f"{slug}: {campo} {r[campo]} ≠ desenho {e['esperado'][campo]}")
        for camada, itens_c in (("base", res.base), ("direcao-geral", res.direcao_geral)):
            esperado = R.camadas[camada]["esperado_itens"]
            if len(itens_c) != esperado:
                problemas.append(f"{camada}: itens {len(itens_c)} ≠ desenho {esperado}")
    return problemas, avisos
