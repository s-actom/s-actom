# Privacidade do repositório público

`s-actom/s-actom` é **público**. Este documento regista o que expõe, o que foi reduzido e o
que fica por decisão do proprietário.

## Resultado

| Verificação | Resultado |
|---|---|
| gitleaks no **histórico completo** (15 commits, 5,37 MB) | **0 leaks** |
| gitleaks na árvore atual | **0 leaks** |
| Credenciais, tokens, sessões, históricos de conversa | **nenhum** no repositório (ver `docs/AUDITORIA.md` para a lista de exclusões) |
| Caminhos absolutos `/Users/goncaloferro` | **36 ocorrências em 3 ficheiros** (era 48 em 9) |

## Onde ficam os 36

| Ficheiro | Ocorrências | Decisão |
|---|---|---|
| `settings.json` | 31 | **Mantido.** É a configuração ativa; os comandos de hook exigem caminho absoluto. É resolvido na instalação (ver abaixo). |
| `instalar.sh` | 4 | Necessário: é o prefixo que o instalador reescreve. |
| `teste-instalacao.sh` | 1 | Verifica que o prefixo foi reescrito. |

Sanitizados nesta revisão: `CLAUDE_CODE_CAPABILITIES_INVENTORY.md`, `launch.json`,
`hooks/livro-flora-roadmap-step.sh` (agora `$HOME`), e 5 relatórios em `scripts/`
(`claude-md-global-REPORT`, `expose-ecc-REPORT`, `midia-nano-banana-REPORT`,
`nano-banana-fix-REPORT`, `rtk-caveman-estado-REPORT`).

## Porque `settings.json` mantém o caminho

Três razões, por ordem de peso:

1. **Funcional** — os hooks em `settings.json` são comandos de shell com caminho absoluto.
   Relativizar quebraria o carregamento sem um mecanismo de substituição.
2. **Rasto** — o ficheiro tem de continuar a ser uma cópia fiel da configuração ativa para
   que o `diff` entre repo e Mac (ver `PLANO-APLICACAO.md`) signifique algo.
3. **Resolvido na instalação** — `instalar.sh` reescreve o prefixo para `--destino` (e o
   `node` do nvm para o do sistema). Provado por `teste-instalacao.sh`:
   `5) nenhum caminho absoluto da máquina de origem`.

O que fica exposto é o **nome de utilizador local** (`goncaloferro`), não uma credencial, e já
não aparece fora dos ficheiros onde é tecnicamente necessário.

## Se o proprietário quiser exposição zero

Opções, por ordem de custo:

1. **Aceitar** o estado atual (nome de utilizador em 3 ficheiros, sem segredos). Recomendado:
   o ganho de removê-lo é cosmético e o custo é perder a fidelidade do snapshot.
2. **Placeholder + geração** — trocar `settings.json` por `settings.template.json` com
   `__CLAUDE_HOME__` e gerar o real só na instalação. Custo: o `diff` com o Mac deixa de ser
   direto e o ficheiro do repo deixa de ser o que está ativo.
3. **Histórico** — se no futuro entrar algo sensível, o histórico tem de ser reescrito
   (`git filter-repo`) **e** as credenciais revogadas. Não é o caso hoje: gitleaks deu zero
   em todos os 15 commits.

## Regras mantidas

- Nenhum segredo real foi publicado (verificado, não assumido).
- Nada de sessões, históricos de conversa, `projects/`, `tasks/`, `file-history/`, caches
  ou credenciais — a lista de exclusões está em `docs/AUDITORIA.md` e é aplicada na exportação.
- Variáveis específicas de cada máquina: o `settings.json` tem `env` sem chaves (as chaves
  vivem no Keychain via `helpers/with-openrouter-key.sh`, fail-closed).
