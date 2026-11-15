# Adaptive Model Intelligence

> **Implementado em 2026-11-15** com a restrição de modelos do proprietário: só modelos
> **explicitamente autorizados** nos quatro fornecedores permitidos (OpenAI, Anthropic,
> DeepSeek, GLM/Z.ai), descobertos nas configurações locais — **nunca pela Internet**.
> O documento mantém o registo do desenho; a secção 6 é a implementação real.

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

---

## 6. Implementação (2026-11-15)

### 6.1 Registo de autorização — a única fonte

`equipas/modelos/autorizacao.json`. Cada entrada tem o **identificador exato**, `fornecedor`
(openai | anthropic | deepseek | glm), `runtime`, `acesso`, `origem` (ficheiro:linha que a
sustenta), `ativo`, `autorizado` e, opcionalmente, `preco`.

Regras que o código aplica:

- **Fornecedor não autoriza.** `autorizado:true` **e** `ativo:true` **e** fornecedor em
  `politica.fornecedores_permitidos` — as três, senão não é candidato.
- **Adicionar/remover = editar o ficheiro.** Não se altera código para autorizar um modelo.
- **Sem fallback não autorizado.** Sem candidato elegível devolve-se uma limitação
  (`sem_modelo_autorizado`), nunca um modelo de fora.
- **Desativado no registo** (`ativo:false`) continua documentado mas nunca é escolhido.
- **Aliases não entram** (`haiku`, `jev-latest`, `inherit`): não são identificadores e não
  permitem atribuir desempenho.

### 6.2 Descoberta local (sem rede)

`equipas/modelos/descobrir.py` lê `~/.claude/settings.json`, `~/.codex/config.toml`,
`~/.codex/AGENTS.md`, `~/.zcode/v2/provider_config.json` e `~/.deepseek-agent/server.py`.

```bash
python3 equipas/modelos/descobrir.py            # candidatos e diferenças
python3 equipas/modelos/descobrir.py --verificar # exit 1 se há configurado sem autorização
python3 equipas/modelos/descobrir.py --escrever  # junta NOVOS como ativo:false/autorizado:false
```

`--escrever` nunca autoriza: só cria entradas pendentes para o proprietário decidir.
O fornecedor vem da **estrutura** da configuração (provider/template), não do nome do modelo.

### 6.3 Execução observada

`equipas/hooks/modelo-executado.mjs` lê a **cauda** do transcript (256 KiB), extrai o último
`message.model`, os tokens de `usage` e a categoria de trabalho (`work=` do envelope do último
objetivo) e grava uma linha em `equipas/estado/modelos.jsonl` (append-only, 0600, < `PIPE_BUF`).

O mesmo valor aparece na linha de delegação (`tipo:"equipa"`), em `modelo`,
`modelo_autorizado` e `categoria_tarefa`. Um modelo fora do registo é registado com
`autorizado:false` — é **observação de drift**, não uso.

### 6.4 Escolha

`equipas/hooks/lib/modelos.mjs#escolher(registo, historico, categoria)` pontua os candidatos:

`0,50·qualidade + 0,20·fiabilidade + 0,15·velocidade + 0,15·custo`
(pesos em `politica.pesos`; normalizados em tempo de execução).

- qualidade = (ok+1)/(ok+falhas+2); fiabilidade = 1 − (sem_resultado+falhas)/n;
  velocidade = 1/(1+ms/1000); custo = 1/(1+custo) (ou neutro, se o preço for desconhecido).
- Menos de `politica.min_amostras` execuções naquela categoria → valor neutro e
  `sem_dados:true` (não se inventa aprendizagem).
- Desempate determinístico: pontuação, amostras, id. **Nenhum nome de modelo no código.**

### 6.5 Subordinação mantida

`escolher()` **propõe**; não delega. A Direção Geral continua a ser o único decisor, o modo
`escuras` continua o default e nenhum gate de segurança foi alterado. O módulo não escreve em
`registo.jsonl` além dos campos novos e nunca guarda texto do pedido.

### 6.6 Limitações assumidas

- `acesso` e `preco` são declarados no registo; quando `preco` é `null` o custo entra como
  neutro em vez de ser estimado.
- `gpt-6-astra` é um lock de delegação em `~/.codex/AGENTS.md`, não o modelo por omissão do
  Codex; fica registado como autorizado e a escolha aprende com o histórico real.
- Sem dados suficientes a escolha é neutra e ordenada por id — não é uma recomendação.
