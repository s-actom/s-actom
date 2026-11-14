# Preparação para o Adaptive Model Intelligence

> **Nada disto está implementado.** Este documento só confirma onde o sistema futuro se liga
> e o que falta observar. Não fixa nenhum modelo (DeepSeek, GLM, Fable, GPT ou outro).

## 1. Pontos de integração que já existem

| Ponto | Onde | Estado | Serve para |
|---|---|---|---|
| **Direção Geral** | `skills/direcao-geral/SKILL.md`, `equipas/equipas.yaml` | ativo | único decisor de delegação; o router futuro fica **subordinado** a ela |
| **Portão do pedido** | `equipas/hooks/portao.mjs` (`textoDoObjetivo`) | ativo, com teste | classifica o objetivo e decide o que mostrar (modo `escuras`/`falar`) |
| **Router JEV** | `equipas/hooks/lib/jev.mjs` (`proporEquipas`), `lib/capacidade.mjs` (`detetar`/`decidir`/`selecionar`) | ativo | ponto natural para trocar a heurística por decisão aprendida |
| **Catálogo de equipas** | `equipas/hooks/lib/equipas.json`, `equipas/equipas.yaml` | ativo | `proporEquipas` já recebe o catálogo por parâmetro: pode vir de descoberta dinâmica |
| **Registo de decisões** | `equipas/registo.jsonl` (0600) | ativo | histórico de objetivos, equipas e recursos escolhidos |
| **Recibos de execução** | `equipas/hooks/recibo-{tentativa,recurso,permissao,fecho}.mjs` | ativo | resultado verificado por chamada (ok / falhou / sem_resultado / recusado) |
| **Revisão** | `equipas/hooks/rever.mjs` | ativo | agrega o turno para arbitragem |
| **Refresco de listas** | `equipas/hooks/atualizar.py`, `gerador/gerar.py` | ativo | publicação idempotente do rascunho para `skills/` |
| **Chave** | `helpers/with-openrouter-key.sh` (Keychain, fail-closed) | ativo | o segredo nunca entra em ficheiros nem no repo |

## 2. O que **não** existe ainda (pré-requisitos da aprendizagem)

1. **Identificação do modelo executor por tarefa.** Nem o `registo.jsonl` nem os recibos
   guardam qual modelo correu a subtarefa. Sem isto não há atribuição de desempenho.
   → Adicionar um campo `modelo` (id devolvido pelo runtime, não uma constante) ao registo de
   cada delegação; `settings.json` tem hoje `CLAUDE_CODE_SUBAGENT_MODEL: haiku` e
   `model: claude-sonnet-5-5` fixos — a fase futura deve deixar de os fixar.
2. **Métricas objetivas.** Os recibos dizem sucesso/falha, mas não guardam **tempo** e **custo**
   por execução. → acrescentar `ms` (já existe no JEV) e tokens/custo quando o runtime os expõe.
3. **Avaliador de resultado.** Existe verificação (recibos, `rever.mjs`), mas não uma nota de
   qualidade comparável entre execuções. → definir um critério reproduzível por tipo de tarefa.
4. **Memória de desempenho persistente.** O `registo.jsonl` é um log append-only; não há índice
   consultável por (tarefa, modelo). → derivar um agregado a partir do log, sem reescrever o log.
5. **Descoberta de modelos.** `proporEquipas` usa `MODELO = "jev-latest"` (alias) e o catálogo é
   estático. → a lista de modelos/fornecedores deve ser descoberta, não codificada.

## 3. Mapa dos cinco módulos futuros sobre estes pontos

| Módulo | Liga-se a | Não pode violar |
|---|---|---|
| **Model Discovery** | `proporEquipas(catalogo)` + `settings.json` | não fixar nomes; não escolher fora das equipas da DG |
| **Performance Memory** | `registo.jsonl` + recibos (novo campo `modelo`) | nunca guardar texto do pedido (regra atual do registo) |
| **Evaluator** | `rever.mjs` + recibos | não substituir os gates de segurança existentes |
| **Adaptive Router** | `lib/capacidade.mjs#decidir` | continua subordinado à Direção Geral e ao modo `escuras` |
| **Continuous Learning** | `atualizar.py` + `entradas/` congeladas | não reescrever o histórico nem os dados congelados |

## 4. Restrições que a arquitetura já impõe (e que se mantêm)

- **A Direção Geral decide quem trabalha.** O router propõe; não delega por conta própria.
- **Modo `escuras` é o default** e o JEV não aparece nesse modo (corrigido no PR #1, com teste).
- **Segredos ficam fora do registo.** O envelope de etiquetas é fechado e o texto do pedido
  nunca é gravado.
- **Sem modelo fixado.** O `MODELO` do JEV é um alias; a config atual fixa modelos por ser a
  configuração ativa, o que a fase futura deve substituir por decisão dinâmica.
- **Teto e disjuntor** (60 chamadas/dia, 429/529) aplicam-se também ao router futuro.

## 5. Primeiro passo recomendado (não nesta tarefa)

Adicionar o campo `modelo` ao registo de delegação e medir durante uma semana **sem decidir
nada** — só observar. Só depois faz sentido comparar desempenho.
