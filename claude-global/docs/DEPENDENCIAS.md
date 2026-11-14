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
git clone --depth 1 https://github.com/agamm/claude-code-owasp \
  "$HOME/.claude/skills/owasp-security"
```

Não está declarada em `settings.json` (`enabledPlugins`/`extraKnownMarketplaces`), por isso
não é instalada por essa via. Sem a skill, `auditoria` corre sem ela e o harness só avisa
com `--debug`.

## Reinstalação declarativa

Os plugins e marketplaces estão declarados em `settings.json`
(`enabledPlugins` + `extraKnownMarketplaces`). Reinstalar num ambiente novo é
aplicar essas declarações; não se copia conteúdo de terceiros para o repositório.
