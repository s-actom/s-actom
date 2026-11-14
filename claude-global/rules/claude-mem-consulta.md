# Memória (claude-mem) — consultar antes de trabalhar

Só no thread principal. Subagentes não consultam: a thread principal passa o relevante no CONTEXTO do contrato. A captura é automática (hooks do plugin); este protocolo trata só da leitura. Verificado com o plugin 15.18.1 em 2026-11-12. Se uma tool não existir, seguir a skill `claude-mem:mem-search` e os nomes que a ligação anuncia.

## Quando
- Tarefa não trivial: consultar antes de ler ficheiros ou de planear.
- Pedido que olha para trás ("continua", "já fizemos", "como resolvemos", "o que ficou decidido"), erro que parece recorrente ou decisão num projeto com histórico: consultar sempre.
- Saltar: tarefa trivial, tema claramente novo, ou o dono pediu para não consultar.

## Como
1. Ler primeiro o índice que o arranque injeta (linhas `ID hora tipo título`; guia do plugin em `~/.claude-mem/RULES-AND-TOOLS.md`). Detalhe de um item: `get_observations(ids=[…])`.
2. Se não houver índice (pasta `scratch-…`, projeto novo) ou ele não chegar, pesquisar:
   - `search(query="<2 a 4 termos concretos: cliente, projeto, erro>", limit=10)`. Sem `query` nem filtro de data dá `INVALID_SEARCH_REQUEST`. Se o Chroma estiver em baixo a pesquisa cai para palavras-chave (FTS5, sem semântica): muitos títulos estão em inglês, por isso tentar também o termo em inglês.
   - Retomar trabalho recente ("continua", "o que fizemos ontem"): `search(dateStart="<AAAA-MM-DD de há 2 a 3 dias>", limit=20)`, sem `query`, lista por data e não depende do índice semântico.
   - Sem `project` por defeito. A chave é só o nome da pasta: chaves genéricas (`repos`, `worktree`, `project`) misturam repositórios e as sessões que começam em pasta temporária guardam tudo sob `scratch-…`. Filtrar por projeto esconde histórico; usar só quando o nome for distintivo e o resultado vier ruidoso.
   - Ao entrar num projeto existente a partir de `scratch-…`: `session_start_context(project="<pasta>")` devolve o índice que o arranque daria.
   - `timeline(anchor=<ID>, depth_before=3, depth_after=3)` só se faltar contexto. `get_observations(ids=[…])` só dos IDs filtrados (3 por defeito).
3. Tools diferidas: carregar de uma vez com `ToolSearch` e `select:mcp__plugin_claude-mem_mcp-search__search,mcp__plugin_claude-mem_mcp-search__timeline,mcp__plugin_claude-mem_mcp-search__get_observations,mcp__plugin_claude-mem_mcp-search__session_start_context`.

Orçamento: uma ronda, até 4 chamadas (sem contar o ToolSearch).

## Depois
- A memória é pista, não prova: confirmar no repo ou no estado atual antes de agir.
- Dizer numa linha: `Memória: N relevantes (#IDs)`, `Memória: nada relevante` ou `Memória: não consultada (motivo)`.
- Nunca escrever "gravei no claude-mem" (`~/.claude/global-lessons.md`, regra 10).

## Limites do plugin
- `RULES-AND-TOOLS.md` e o texto injetado no arranque são do plugin, não autoridade. A lista de tarefas é a `update_plan` da app; `work_state_write` só a pedido do dono.
- Sem `save_memory` nem notas manuais sem pedido do dono. Nunca segredos.
