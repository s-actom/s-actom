# Dependências externas

Esta pasta versiona **configuração própria**. Skills, agentes e plugins de terceiros
não são copiados para o repositório — são reinstalados de forma declarativa. Este
documento lista o que uma instalação de destino precisa de ter para que os agentes e
hooks desta exportação funcionem como declarado.

## Regra geral

Uma dependência em falta **não dá erro visível**: o harness ignora a skill em silêncio
(só aviso com `--debug`) e a delegação para um agente inexistente falha. Confirmar
sempre com `claude --debug` numa instalação nova.

## Skills declaradas por agentes desta exportação

| Skill | Usada por | Origem | Versionada aqui? |
|---|---|---|---|
| `agent-architecture-audit` | `agents/auditoria.md` | ECC (marketplace, MIT) | Não — reinstalar do marketplace |
| `owasp-security` | `agents/auditoria.md` | clone manual de `github.com/agamm/claude-code-owasp` (MIT) para `~/.claude/skills/owasp-security/` | Não |
| `verification-loop` | `agents/auditoria.md` | ECC | Não |
| `superpowers:verification-before-completion` | `agents/auditoria.md` | plugin `superpowers@superpowers-dev` | Não |
| `automation-audit-ops`, `workspace-surface-audit` | `agents/workspace-automation-auditor.md` | ECC | Não |
| `copywriting`, `content-strategy`, `seo`, `page-cro` | `agents/conteudo.md` | `~/.agents/skills/` (ligações externas, fora de `~/.claude`) | Não — ligar/instalar no destino |

> As skills ECC não ficam em `~/.claude/skills/<nome>/` mas em `~/.claude/skills/ecc/<nome>/`.
> O harness só varre os filhos diretos de `~/.claude/skills/`, por isso uma reinstalação do ECC
> deixa-as invisíveis até correr `scripts/expose-ecc-skills.sh` (cria `skills/<nome> -> ecc/<nome>`).

## Revisores delegados por `agents/auditoria.md`

A allowlist `Agent(...)` nomeia **29 revisores**. Só **7 têm definição local** neste repositório;
os outros **22 vêm do catálogo `agency-agents`** instalado no ambiente. Sem ele, a delegação
falha em silêncio (regra geral acima). Confirmar com `claude --debug` quais resolvem.

**Definidos aqui (7):** `application-security-auditor`, `crypto-protocol-auditor`,
`database-platform-reviewer`, `node-backend-reviewer`, `jvm-enterprise-reviewer`,
`quarkus-reviewer`, `web-design-reviewer`.

**Externos (22):** `code-reviewer`, `security-reviewer`, `silent-failure-hunter`,
`fastapi-reviewer`, `django-reviewer`, `react-reviewer`, `typescript-reviewer`,
`python-reviewer`, `go-reviewer`, `java-reviewer`, `rust-reviewer`, `cpp-reviewer`,
`csharp-reviewer`, `kotlin-reviewer`, `swift-reviewer`, `php-reviewer`, `fsharp-reviewer`,
`flutter-reviewer`, `mle-reviewer`, `healthcare-reviewer`, `network-config-reviewer`,
`network-troubleshooter`.

> Nota: `agents/security-reviewer-fable52.md` existe, mas o nome **não** é `security-reviewer`,
> por isso não resolve a delegação `security-reviewer` da allowlist.

## Agentes referenciados mas não definidos aqui

`agents/conteudo.md` permite delegar para `marketing-agent` e `seo-specialist`; nenhum
dos dois existe em `agents/`. Vêm do catálogo `agency-agents` instalado no ambiente.
Sem esse catálogo, essas duas delegações falham (as restantes continuam a resolver).

## Programas exigidos em runtime

| Programa | Usado por |
|---|---|
| `jq`, `python3`, `shasum` | `equipas/reverter/*.sh`, `equipas/hooks/*` |
| `node` (≥ 20) | hooks `.mjs`/`.js`, gerador de skills |
| `git` | guardas, wrapper CodeRabbit |

### Reinstalar `owasp-security` (não vem de plugin/marketplace)

```bash
# O repositório pode trazer a skill na raiz ou em .claude/skills/<nome>/.
# Clonar para uma pasta temporária e copiar o que existir evita o SKILL.md ficar num
# caminho aninhado (ex.: skills/owasp-security/.claude/skills/owasp-security/SKILL.md).
_tmp=$(mktemp -d) || exit 1
git clone --depth 1 https://github.com/agamm/claude-code-owasp "$_tmp/owasp" || exit 1
mkdir -p "$HOME/.claude/skills"
if [ -f "$_tmp/owasp/.claude/skills/owasp-security/SKILL.md" ]; then
  cp -R "$_tmp/owasp/.claude/skills/owasp-security" "$HOME/.claude/skills/"
else
  cp -R "$_tmp/owasp" "$HOME/.claude/skills/owasp-security"
fi
rm -rf -- "$_tmp"
[ -f "$HOME/.claude/skills/owasp-security/SKILL.md" ] || echo "aviso: SKILL.md não ficou no destino" >&2
```

Não está declarada em `settings.json` (`enabledPlugins`/`extraKnownMarketplaces`), por isso
não é instalada por essa via. Sem a skill, `auditoria` corre sem ela e o harness só avisa
com `--debug`.

## Reinstalação declarativa

Os plugins e marketplaces estão declarados em `settings.json`
(`enabledPlugins` + `extraKnownMarketplaces`). Reinstalar num ambiente novo é
aplicar essas declarações; não se copia conteúdo de terceiros para o repositório.
