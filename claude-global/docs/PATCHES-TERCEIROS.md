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
| 4 | `agents/engineering/multi-agent-systems-architect.md` | "Audit log: ... inputs, outputs" sem redação. O log de chamada de agente expunha `output` e fixava `"model": "claude-opus-4-6"`. | Redação **antes** de registar; controlo de acesso e retenção; `output_redacted`; `model_id` vem do runtime, nunca fixado. |
| 5 | `agents/security/blockchain-security-auditor.md` | Normalizava o feed mas não as **unidades** do token vs dívida (18 vs 6 casas = razão 10^12 errada). O script de ferramentas seguia para a seguinte depois de uma falha de execução, e podia reportar "limpo". | Nota explícita de unidades + falha explícita (`ANÁLISE INCOMPLETA`, exit 2) quando uma ferramenta não conclui. |
| 6 | `agents/security/penetration-tester.md` | `-follow-redirects` seguia um redirect para fora do âmbito **antes** de qualquer verificação; o WhatWeb recebia linhas com colunas em vez de URLs. | `-no-follow-redirects` (destinos 3xx validados à mão) + lista de URLs extraída para o fingerprinting. |
| 7 | `agents/engineering/incident-response-commander.md` | `rollout history` usava `-n production`; HPA com `--max=20` podia reduzir abaixo do que foi escalado; a SLI de correção comparava proporção de **erro** com objetivo de **sucesso**. | `$CTX`/`$NS` em todos os comandos; `--max` da capacidade confirmada; SLI corrigida (`1 - erros/total`). |

### Guardas (`testes-agentes.sh`)

Cada padrão perigoso tem uma verificação que **falha** se ele voltar; todas foram provadas por
mutação (repôs-se o padrão errado e confirmou-se a falha). Cobre: divisão por `decimals()` com
e sem cast, `in-scope.txt` produzido pelo filtro (não por cópia), `-no-follow-redirects`,
namespace fixo mesmo com opções globais, e `unredacted` no log.

## Riscos conhecidos e deliberadamente NÃO corrigidos

| Ficheiro | Finding | Porque não se corrige aqui |
|---|---|---|
| `equipas/gerador/classify.py` | O fallback `'niche'` faz um item sem regra cair na equipa `desenvolvimento` (via `Nichos específicos` no `equipas.yaml`). | Alterar o fallback muda a **distribuição de equipas** — é decisão do dono, não de uma revisão. Fica registado para a fase de ajuste do gerador, com a opção de introduzir uma categoria `sem-equipa` e um aviso no relatório do gerador. |
| `agents-archive/**` (166 ficheiros) | ~50 observações documentais (fórmulas de exemplo, CSV, JSONL, números de emergência). | Arquivados e inacessíveis à delegação: não estão em `agents/**` nem referidos por `equipas.yaml`. Corrigir prompt arquivado não reduz risco e perde-se na próxima importação. |

## O que NÃO foi feito

- Não se reescreveram os restantes ~80 findings (documentais).
- Não se suspendeu nenhum agente: os patches resolvem o risco sem quebrar a delegação.
- Não se alterou o `skills:` nem o `model:` de nenhum agente.

## Manutenção

Ao atualizar o catálogo `agency-agents` na origem, estes quatro patches podem ser
substituídos por versões upstream corrigidas. `testes-agentes.sh` falha se os padrões
perigosos voltarem, o que assinala a regressão.
