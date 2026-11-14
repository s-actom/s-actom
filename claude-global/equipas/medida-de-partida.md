# Medida de partida (2026-11-07)

Referência para comparar na Fase 3 (reduzir). **Medido** = lido de uma ferramenta. **Estimativa** = caracteres/4 ou contagem × tokens por nome (aproximação, só serve para comparar com a mesma fórmula).

## 1. Tokens fixos no arranque da sessão principal

Origem: `get_usage` da app (sessão desta execução), 2026-11-07 entre 22:15 e 23:10. A app só mostra as 6 maiores categorias.

| Parte | Tokens | Tipo |
|---|---:|---|
| Ferramentas do sistema | 27 039 | medido |
| Ferramentas MCP carregadas | 24 299 | medido |
| Agentes (285) | 19 268 | medido |
| Ficheiros de memória (CLAUDE.md, rules, MEMORY.md) | 14 371 | medido |
| Instruções dos servidores MCP | 10 292 | medido |
| **Soma das 5 categorias fixas listadas** | **95 269** | medido |
| Skills (726) + prompt base: tudo o que não aparece nas 6 maiores | ≤ 15 461 | medido (resíduo: 189 676 − 174 215) |
| Skills (726), só nomes | ~4 100 | estimativa |
| Skills (726), nomes e descrições (máximo, descrições cortadas a 120 caracteres) | ~23 900 | estimativa; a app corta as descrições ao orçamento de 1%, por isso o real é menor |
| Lista das ferramentas MCP adiadas (1179 nomes × 9; só os 26 servidores com contagem no snapshot) | ~10 600 | estimativa |
| Agentes (285), estimativa pelo mesmo método | ~15 900 | estimativa (o medido é 19 268: a fórmula fica 18% abaixo) |

Total da primeira leitura: 189 676 tokens, dos quais 78 946 são mensagens (o desenho lido, saídas de ferramentas e contextos injetados por hooks). **Não é o arranque limpo de uma sessão nova**: serve de teto, não de valor exato.

**Separado por origem (os três pedidos do dono):** skills ≤ 15,5 mil (resíduo medido) · agentes 19,3 mil (medido) · ferramentas MCP 24,3 mil carregadas + ~10,6 mil de nomes adiados (estimativa) + 10,3 mil de instruções dos servidores (medido).

## 2. Custo de arranque de um subagente

Subagente trivial ("responde OK", modelo haiku, sem ferramentas). Valor = `subagent_tokens` devolvido pela app. Uma medição por tipo.

| Tipo | Tokens | Porquê |
|---|---:|---|
| `general-purpose` | 111 694 | traz todas as ferramentas, incluindo as MCP |
| `Explore` | 77 332 | quase todas as ferramentas |
| `security-reviewer` | 37 881 | só 4 ferramentas (Read, Bash, Grep, Glob) |

Referência de 2026-11-05: **208 mil tokens** num subagente com 2 chamadas (a revisão). Leitura: o arranque pesa 38 mil a 112 mil conforme as ferramentas que o tipo traz; o resto daquela revisão foi trabalho. Para a Fase 3, o alvo é o tipo com ferramentas restritas.

## 3. Hooks

| Origem | Hooks |
|---|---:|
| Settings | 19 (SessionStart 6, PreToolUse 6, PostToolUse 4, Stop 1, SubagentStart 1, UserPromptSubmit 1) |
| Plugins | 23 (claude-mem 8, security-guidance 7, claude-security 6, superpowers 1, i-have-adhd 1) |
| **Total** | **42** (igual ao desenho: 19 + pelo menos 23) |

## 4. Contagens (gerador, modo vivo)

| | Desenho (2026-11-05) | Agora |
|---|---:|---:|
| Skills | 736 | 726 |
| Agentes | 285 | 285 |
| Servidores MCP | 123 | 144 |
| Ferramentas MCP listadas por sessão | 1182 | 1179 (soma das contagens do snapshot; só 26 dos 144 servidores têm contagem, os 22 novos não; a diferença de 3 não se explica com estes dados) |
| Plugins instalados / em `enabledPlugins` | 37 / 38 | 37 / 38 (o 38.º é `cc-plugin-you-should-know@builtin`) |

Detalhe item a item: `relatorio/DIFERENCAS.md`.

## 5. O que não se mediu

- O piso do prompt base, sem a configuração do utilizador: `claude -p` com HOME vazio falha ("Not logged in"), por isso não há valor.
- Skills: só estimativa e um teto (a app não mostra a categoria).
- Ferramentas MCP: a contagem vem do snapshot e cobre 26 servidores; os outros 118 (dos 144 de agora) não têm contagem e não entram na estimativa. Não se verificou quantos deles carregam ferramentas na sessão.
- Variação entre corridas (1 medição por tipo de subagente).
- Arranque de uma sessão nova real: esta já tinha mensagens quando se mediu.

## 6. Como repetir na Fase 3

1. `python3 -I ~/.claude/equipas/gerador/medir.py` (contagens e estimativas, com a mesma fórmula).
2. Numa sessão nova, antes de qualquer pedido: `get_usage` e copiar as categorias.
3. Três subagentes triviais (`general-purpose`, `Explore`, `security-reviewer`, haiku, "responde OK") e copiar `subagent_tokens`.
4. Preencher as mesmas tabelas, antes e depois de cada mecanismo da Fase 3.
