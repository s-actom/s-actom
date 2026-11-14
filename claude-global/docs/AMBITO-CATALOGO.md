# Âmbito dos PRs #3, #4 e #5 — catálogo de terceiros

## O que são esses PRs

| PR | Conteúdo | Proveniência |
|---|---|---|
| #3 | `agents/{design,engineering,marketing,paid-media,product,sales,security,testing}/*.md` (97) | catálogo `agency-agents` (terceiros), instalado localmente com `skills:` acrescentado |
| #4, #5 | `agents-archive/**` (166) | arquivo histórico do mesmo catálogo |

Não é código deste projeto: são **prompts de agentes** de um catálogo externo. A prova:
os nomes resolvem para os tipos `agency-*` do ambiente (`agency-ux-architect`,
`agency-data-engineer`, `agency-penetration-tester`, …) e o conteúdo é markdown de
instruções, sem nada executável.

## Porque são versionados mesmo assim

Fazem parte da **configuração ativa**: são os agentes que as equipas da Direção Geral
podem delegar. Versioná-los torna o sistema reproduzível. A regra de exclusão aplicada
na auditoria (não copiar terceiros) vale para o que é **reinstalável de forma
declarativa** (ECC, superpowers/GSD, caveman, skills de marketplace) — não para ficheiros
locais cujo conteúdo foi alterado (o `skills:` de cada agente é uma alteração local).

## Política de revisão

O CodeRabbit apontou ~85 observações Major nestes PRs. São sobre **a qualidade do
conteúdo dos prompts** (ex.: `aria-checked` desatualizado num exemplo de UI, `kubectl
rollout undo` sem namespace, fórmula de CPA invertida, JSONL em várias linhas).

Decisão: **não reescrever prompts de terceiros neste repositório.**

Razões:

1. **Reprodutibilidade** — alterações locais perdem-se na próxima atualização do
   catálogo e criam divergência silenciosa entre o repositório e o upstream.
2. **Rasto** — um PR de configuração não deve tornar-se um fork de um catálogo alheio.
3. **Âmbito** — nada aqui é executável; o risco material é o agente seguir uma instrução
   imperfeita, e a mitigação correta é reportar ao upstream, não corrigir à mão 85 pontos.

## O que foi feito em vez disso

- Os findings ficam registados nos PRs #3/#4/#5 como **conhecidos e aceites**.
- Correções **foram** aplicadas nos PRs #1 e #2, onde os ficheiros são deste projeto e o
  comportamento é executável (hooks, scripts, validação, rollback).
- Dois casos de **segurança material** no catálogo merecem correção antes de uso ativo em
  auditoria/pentest (`penetration-tester` sem filtro de âmbito, `blockchain-security-auditor`
  com normalização de decimais errada). Ficam como item de acompanhamento, não como
  bloqueio: são prompts, não código em execução, e o âmbito destes agentes é sempre dado
  pelo dono na delegação.

## Recomendação

Merge dos #3/#4/#5 como **snapshot de configuração** (estado atual, reproduzível), com os
findings do catálogo tratados a montante. Se quiseres o catálogo limpo, o caminho é
atualizar o `agency-agents` na origem e re-exportar — não corrigir cópia a cópia.
