# Patches a agentes de terceiros

Os agentes em `agents/**` vêm do catálogo **`agency-agents`** (terceiros). A regra geral é
**não reescrever prompts alheios** (ver [AMBITO-CATALOGO.md](AMBITO-CATALOGO.md)). Abre-se
uma exceção para problemas **materiais**: instruções que podem produzir operações destrutivas,
sondagem não autorizada, decisões de segurança erradas ou exposição de credenciais.

Cada patch abaixo é mínimo, rastreável e coberto por `testes-agentes.sh`.

## Porque estes e não os outros

O CodeRabbit levantou ~85 observações nos PRs #3–#5. A maioria é documental (fórmulas de
exemplo, acessibilidade de snippets, formatação CSV). Estes quatro atravessam a fronteira do
risco operacional **e** os agentes em causa estão **ativos** — os quatro estão em
`agents/security/` ou `agents/engineering/`, referidos por `equipas.yaml` / `equipas/seguranca.md`,
portanto delegáveis pela Direção Geral. Nenhum deles está em `agents-archive/`.

## Patches

| # | Ficheiro | Problema | Correção |
|---|---|---|---|
| 1 | `agents/security/blockchain-security-auditor.md` | `(amount * price) / priceFeed.decimals()` — `decimals()` é a **contagem de casas** (ex.: 8), não o fator. Com 8 casas o valor sai 10^8 vezes errado; um protocolo que siga o exemplo pode aceitar garantia insuficiente. | `scale = 10 ** decimals()` e divisão por `scale`, com comentário a explicar a diferença. |
| 2 | `agents/security/penetration-tester.md` | O recon enumera subdomínios e **sonda tudo** (`dnsx`, `httpx`, `naabu`) sem filtrar pelo âmbito autorizado. Subdomínios fora do contrato seriam sondados. | Âmbito obrigatório (`SCOPE_FILE`), paragem se vazio, separação `in-scope.txt` / `out-of-scope.txt`, sondagem só do que está no âmbito. |
| 3 | `agents/engineering/incident-response-commander.md` | `kubectl ... -n production` fixo: com o serviço noutro namespace, reverte o deployment **errado**. | `NS` e `CTX` confirmados no runbook; verificação prévia de que o deployment existe nesse namespace/contexto antes do `rollout undo`. |
| 4 | `agents/engineering/multi-agent-systems-architect.md` | "Audit log: ... inputs, outputs" sem redação: tokens e dados pessoais iriam para o registo. | Redação **antes** de registar; controlo de acesso e retenção no armazém de logs; só os campos necessários. |

## O que NÃO foi feito

- Não se reescreveram os restantes ~80 findings (documentais).
- Não se suspendeu nenhum agente: os patches resolvem o risco sem quebrar a delegação.
- Não se alterou o `skills:` nem o `model:` de nenhum agente.

## Manutenção

Ao atualizar o catálogo `agency-agents` na origem, estes quatro patches podem ser
substituídos por versões upstream corrigidas. `testes-agentes.sh` falha se os padrões
perigosos voltarem, o que assinala a regressão.
