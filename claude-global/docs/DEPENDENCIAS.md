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
| `owasp-security` | `agents/auditoria.md` | instalação local (`~/.claude/skills/owasp-security/`) | Não |
| `verification-loop` | `agents/auditoria.md` | ECC | Não |
| `superpowers:verification-before-completion` | `agents/auditoria.md` | plugin `superpowers@superpowers-dev` | Não |
| `automation-audit-ops`, `workspace-surface-audit` | `agents/workspace-automation-auditor.md` | ECC | Não |

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

## Reinstalação declarativa

Os plugins e marketplaces estão declarados em `settings.json`
(`enabledPlugins` + `extraKnownMarketplaces`). Reinstalar num ambiente novo é
aplicar essas declarações; não se copia conteúdo de terceiros para o repositório.
