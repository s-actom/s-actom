"""Leitura do snapshot e do disco. Só leitura.

Do disco só saem nomes e texto limpo: nunca valores de configuração MCP (env, headers, args, url).
Todo o texto de terceiros passa por limpar_texto() antes de ir para um ficheiro.
"""
import glob
import json
import os
import re
import unicodedata
from dataclasses import dataclass, field, replace
from pathlib import Path

PT = {"auditoria", "construcao", "conteudo", "crypto", "gestor-de-agentes", "lancamento", "midia", "pesquisa", "sistema", "site"}
ORIGENS_EMBUTIDAS = {"embutida (app/CLI)", "embutido (app/CLI)"}
ORIGENS_MCP_DECLARADAS = {"Conector claude.ai", "App (embutido)", "Extensão desktop", "Só num projeto"}


class ErroEntrada(Exception):
    """Entrada ilegível ou incompleta: o gerador pára e não escreve nada."""


@dataclass(frozen=True)
class Item:
    key: str
    tipo: str  # Skill | Agente | MCP
    id: str
    funcao: str
    desc: str
    origem: str
    estado: str
    usos: int
    auto: int
    vitalicio: object
    d30: int
    ultimo: str
    interno: bool
    fonte: str = "snapshot"  # snapshot | disco


# ---------------------------------------------------------------- texto de terceiros
_RE_INSTR = re.compile(
    r"(?i)\b(?:ignor\w*|disregard|forget|esquec\w*)\b[^.]{0,40}\b(?:instru\w*|prompts?|rules?|regras?)\b"
    r"|\bsystem\s*prompt\b|\byou\s+are\s+now\b"
)
_SUBST = (("<", "‹"), (">", "›"), ("`", "'"), ("«", '"'), ("»", '"'), ("|", "¦"), ("[", "("), ("]", ")"))


# Invisíveis para quem lê mas legíveis por um modelo (bloco "tags" U+E0000, selectores de variação, preenchimentos): apagam-se.
_OCULTOS_EXTRA = frozenset((0x034F, 0x115F, 0x1160, 0x17B4, 0x17B5, 0x180E, 0x3164, 0xFFA0))


def _caracter_limpo(c):
    cat = unicodedata.category(c)
    if cat in ("Cc", "Zl", "Zp"):
        return " "  # controlos e quebras de linha viram espaço
    o = ord(c)
    if cat in ("Cf", "Cs", "Co", "Cn") or 0x180B <= o <= 0x180F or 0xFE00 <= o <= 0xFE0F or 0xE0100 <= o <= 0xE01EF or o in _OCULTOS_EXTRA:
        return ""  # apaga, para que uma palavra partida por um invisível volte a juntar-se antes da procura abaixo
    return c


def limpar_texto(texto, max_len=120):
    """Neutraliza marcação, texto invisível e frases de instrução e trunca. O resultado é sempre dado, nunca instrução.
    A procura de frases de instrução é cosmética (heurística); a defesa real é estrutural: texto de terceiros só entra como dado."""
    t = "".join(_caracter_limpo(c) for c in unicodedata.normalize("NFKC", str(texto or "")))
    t = _RE_INSTR.sub("(removido)", t)
    for velho, novo in _SUBST:
        t = t.replace(velho, novo)
    t = re.sub(r"\s+", " ", t).strip()
    return t if len(t) <= max_len else t[: max_len - 1].rstrip() + "…"


# ---------------------------------------------------------------- snapshot
def ler_instantaneo(caminho):
    try:
        bruto = json.loads(Path(caminho).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        raise ErroEntrada(f"snapshot ilegível: {caminho}: {e}") from None
    if not isinstance(bruto, list) or not bruto:
        raise ErroEntrada("snapshot vazio ou com formato inesperado")
    itens, chaves = [], set()
    for r in bruto:
        try:
            item = Item(
                key=r["key"], tipo=r["tipo"], id=r["id"], funcao=r["funcao"], desc=limpar_texto(r.get("desc", "")),
                origem=r["origem"], estado=r["estado"], usos=int(r["usos"]), auto=int(r["auto"]),
                vitalicio=r.get("vitalicio"), d30=int(r["d30"]), ultimo=r.get("ultimo") or "", interno=bool(r.get("interno")),
            )
        except (KeyError, TypeError, ValueError, AttributeError) as e:
            raise ErroEntrada(f"item inválido no snapshot: {e!r}") from None
        if item.key in chaves:
            raise ErroEntrada(f"key repetida no snapshot: {item.key}")
        chaves.add(item.key)
        itens.append(item)
    return itens


# ---------------------------------------------------------------- disco
@dataclass
class Disco:
    skills: dict = field(default_factory=dict)
    agentes: dict = field(default_factory=dict)
    mcp: dict = field(default_factory=dict)
    plugins: dict = field(default_factory=dict)
    hooks: dict = field(default_factory=dict)
    mcp_projetos: list = field(default_factory=list)
    avisos: list = field(default_factory=list)

    def _add(self, mapa, ident, meta):
        if ident in mapa:
            self.avisos.append(f"nome repetido no disco, fica o primeiro: {limpar_texto(ident, 80)}")
            return
        mapa[ident] = meta


def _json(caminho, obrigatorio=False):
    try:
        return json.loads(Path(caminho).read_text(encoding="utf-8"))
    except FileNotFoundError:
        if obrigatorio:
            raise ErroEntrada(f"em falta: {caminho}") from None
        return None
    except (OSError, ValueError) as e:
        raise ErroEntrada(f"ilegível: {caminho}: {e}") from None


def _frontmatter(caminho):
    try:
        with open(caminho, encoding="utf-8", errors="replace") as fh:
            texto = fh.read(24000)
    except OSError:
        return {}
    if not texto.startswith("---"):
        return {}
    fim = texto.find("\n---", 3)
    linhas = (texto[3:fim] if fim > 0 else "").splitlines()
    out, i = {}, 0
    while i < len(linhas):
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", linhas[i])
        if m:
            chave, valor = m.group(1), m.group(2).strip()
            if valor in (">", "|", ">-", "|-", ">+", "|+", ""):
                buf, j = [], i + 1
                while j < len(linhas) and (linhas[j].startswith((" ", "\t")) or not linhas[j].strip()):
                    buf.append(linhas[j].strip())
                    j += 1
                if buf:
                    valor = " ".join(x for x in buf if x)
                i = j - 1
            out[chave] = valor.strip("\"'")
        i += 1
    return out


def _contar_hooks(hooks):
    por_evento = {}
    if isinstance(hooks, dict):
        for ev, grupos in hooks.items():
            if isinstance(grupos, list):
                por_evento[str(ev)] = sum(len(g.get("hooks") or []) for g in grupos if isinstance(g, dict))
    return por_evento


def _padrao(raiz, skill):
    partes = Path(skill).relative_to(raiz).parts
    return partes == ("SKILL.md",) or (len(partes) == 3 and partes[0] == "skills")


def _meta(origem, fm, padrao=True):
    return {"origem": origem, "desc": limpar_texto(fm.get("description", ""), 170), "padrao": padrao,
            "tools": limpar_texto(fm.get("tools", ""), 200),
            "so_manual": str(fm.get("disable-model-invocation", "")).lower() == "true"}


def _nomes_de_servidores(dados):
    """Só as chaves (nomes dos servidores). Os valores (env, headers, args, url) nunca são tocados."""
    if not isinstance(dados, dict):
        return []
    servidores = dados.get("mcpServers") if isinstance(dados.get("mcpServers"), dict) else dados
    return sorted(str(k) for k in servidores)


def _nomes_mcp_do_plugin(raiz):
    """`.mcp.json` na raiz, ou `mcpServers` em .claude-plugin/plugin.json (em linha, ou caminho dentro da raiz)."""
    nomes = set(_nomes_de_servidores(_json(raiz / ".mcp.json")))
    plugin = _json(raiz / ".claude-plugin" / "plugin.json")
    if isinstance(plugin, dict):
        m = plugin.get("mcpServers")
        if isinstance(m, dict):
            nomes |= set(map(str, m))
        elif isinstance(m, str):
            alvo = (raiz / m).resolve()
            if raiz.resolve() in alvo.parents:
                nomes |= set(_nomes_de_servidores(_json(alvo)))
    return sorted(nomes)


def _ler_plugin(d, nome, raiz):
    raiz = Path(raiz)
    for skill in sorted(glob.glob(f"{raiz}/**/SKILL.md", recursive=True)):
        if "/node_modules/" in skill or "/.trash/" in skill:
            continue
        fm = _frontmatter(skill)
        folha = fm.get("name") or Path(skill).parent.name
        if Path(skill).parent == raiz:
            folha = fm.get("name") or nome
        d._add(d.skills, f"{nome}:{folha}", _meta(f"plugin {nome}", fm, _padrao(raiz, skill)))
    for cmd in sorted(glob.glob(f"{raiz}/commands/**/*.md", recursive=True)):
        folha = os.path.relpath(cmd, raiz / "commands")[:-3].replace(os.sep, ":")
        d._add(d.skills, f"{nome}:{folha}", _meta(f"plugin {nome}", _frontmatter(cmd)))
    for ag in sorted(glob.glob(f"{raiz}/agents/**/*.md", recursive=True)):
        fm = _frontmatter(ag)
        d._add(d.agentes, f"{nome}:{fm.get('name') or Path(ag).stem}", _meta(f"plugin {nome}", fm))
    for leaf in _nomes_mcp_do_plugin(raiz):
        d._add(d.mcp, f"plugin:{nome}:{leaf}", {"origem": "Plugin"})
    hooks = _json(raiz / "hooks" / "hooks.json")
    return sum(_contar_hooks(hooks.get("hooks")).values()) if isinstance(hooks, dict) else 0


def ler_disco(home):
    c = Path(home) / ".claude"
    d = Disco()
    settings = _json(c / "settings.json") or {}
    ligados = settings.get("enabledPlugins") if isinstance(settings.get("enabledPlugins"), dict) else {}
    por_evento = _contar_hooks(settings.get("hooks"))
    d.hooks = {"settings": sum(por_evento.values()), "por_evento": por_evento, "plugins": 0, "por_plugin": {}}

    skills = c / "skills"
    if skills.is_dir():
        for nome in sorted(os.listdir(skills)):
            cheio = skills / nome
            if nome.startswith(".") or nome in ("ecc", "synced") or not cheio.is_dir() or not (cheio / "SKILL.md").exists():
                continue
            if nome == "direcao-geral" or re.fullmatch(r"equipa-[a-z]+", nome):
                continue  # saída deste gerador (Fase 1), não item do inventário
            if cheio.is_symlink():
                alvo = os.readlink(cheio)
                origem = "ECC" if alvo.startswith("ecc") else ("skills.sh" if ".agents/skills" in alvo else "local")
            else:
                origem = "GSD" if nome.startswith("gsd-") else "local"
            d._add(d.skills, nome, _meta(origem, _frontmatter(cheio / "SKILL.md")))
        for skill in sorted(glob.glob(f"{skills}/synced/*/*/SKILL.md")):
            d._add(d.skills, "anthropic-skills:" + Path(skill).parent.name, _meta("Anthropic (sincronizada)", _frontmatter(skill)))
    for cmd in sorted(glob.glob(f"{c}/commands/**/*.md", recursive=True)):
        rel = os.path.relpath(cmd, c / "commands")[:-3].replace(os.sep, ":")
        d._add(d.skills, rel, _meta("comando (ECC/local)", _frontmatter(cmd)))

    for chave, linhas in sorted(((_json(c / "plugins" / "installed_plugins.json") or {}).get("plugins") or {}).items()):
        nome = chave.partition("@")[0]
        raiz = (linhas[0] or {}).get("installPath") if linhas else None
        ligado = ligados.get(chave) is not False
        d.plugins[nome] = {"ligado": ligado, "existe": bool(raiz and Path(raiz).is_dir())}
        if not ligado:
            continue
        if not d.plugins[nome]["existe"]:
            d.avisos.append(f"plugin sem pasta: {limpar_texto(nome, 60)}")
            continue
        n = _ler_plugin(d, nome, raiz)
        d.hooks["por_plugin"][nome] = n
        d.hooks["plugins"] += n
    for balde in sorted(glob.glob(f"{c}/plugins/synced/*/")):
        if os.path.basename(balde.rstrip("/")).startswith("."):
            continue
        for dn in sorted(os.listdir(balde)):
            cheio = Path(balde) / dn
            pj = cheio / ".claude-plugin" / "plugin.json"
            if not (cheio.is_dir() and pj.exists()) or dn == "design":  # igual a inventory.py de 2026-11-05
                continue
            meta = _json(pj) or {}
            nome = meta.get("name") or dn
            ligado = ligados.get(f"{nome}@synced") is not False
            d.plugins.setdefault(nome, {"ligado": ligado, "existe": True})
            if not ligado:
                continue
            n = _ler_plugin(d, nome, cheio)
            d.hooks["por_plugin"][nome] = n
            d.hooks["plugins"] += n

    for ag in sorted(glob.glob(f"{c}/agents/**/*.md", recursive=True)):
        if os.path.basename(ag) == "README.md":
            continue
        fm = _frontmatter(ag)
        nome = fm.get("name") or Path(ag).stem
        pasta = os.path.dirname(os.path.relpath(ag, c / "agents"))
        origem = "Coordenador PT" if nome in PT else "GSD" if nome.startswith("gsd-") else f"Agency/{pasta}" if pasta else "ECC/local"
        d._add(d.agentes, nome, _meta(origem, fm))

    cj = _json(Path(home) / ".claude.json") or {}
    user = cj.get("mcpServers") if isinstance(cj.get("mcpServers"), dict) else {}
    for nome in sorted(user):  # só os nomes
        d._add(d.mcp, nome, {"origem": "Config do utilizador"})
    projetos = cj.get("projects") if isinstance(cj.get("projects"), dict) else {}
    for caminho, cfg in sorted(projetos.items()):
        servidores = cfg.get("mcpServers") if isinstance(cfg, dict) and isinstance(cfg.get("mcpServers"), dict) else {}
        d.mcp_projetos += [f"{nome} ({Path(caminho).name})" for nome in sorted(servidores)]
    return d


# ---------------------------------------------------------------- junção
@dataclass
class Diferencas:
    novos: list = field(default_factory=list)
    removidos: list = field(default_factory=list)
    verificados: int = 0
    declarados: int = 0


def _presente(it, disco):
    """True/False se o disco decide; None se o item não está em disco (embutido, conector, app)."""
    if it.tipo == "Skill":
        return None if it.origem in ORIGENS_EMBUTIDAS else it.id in disco.skills
    if it.tipo == "Agente":
        return None if it.origem in ORIGENS_EMBUTIDAS else it.id in disco.agentes
    if it.origem in ("Config do utilizador", "Plugin"):
        return it.id in disco.mcp
    return None


def juntar(snapshot, disco, classificar):
    """Snapshot de 2026-11-05 + disco de agora. Devolve (itens vivos, Diferencas)."""
    vivos, dif = [], Diferencas()
    for it in snapshot:
        presente = _presente(it, disco)
        if presente is None:
            dif.declarados += 1
            vivos.append(it)
        elif presente:
            dif.verificados += 1
            vivos.append(replace(it, fonte="disco"))
        else:
            dif.removidos.append(it)
    conhecidos = {(i.tipo, i.id) for i in snapshot}
    for tipo, prefixo, mapa, estado in (("Skill", "skill", disco.skills, "ativa"), ("Agente", "agent", disco.agentes, "ativo"),
                                        ("MCP", "mcp", disco.mcp, "desconhecido")):
        for ident, meta in sorted(mapa.items()):
            if (tipo, ident) in conhecidos or (tipo == "Skill" and not meta.get("padrao", True)):
                continue
            dif.novos.append(Item(key=f"{prefixo}/{ident}", tipo=tipo, id=ident, funcao=classificar(tipo, ident),
                                  desc=meta.get("desc", ""), origem=meta["origem"], estado=estado, usos=0, auto=0,
                                  vitalicio=None, d30=0, ultimo="", interno=False, fonte="disco"))
    return vivos + dif.novos, dif
