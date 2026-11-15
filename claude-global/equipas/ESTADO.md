# Estado

## Fase 1: às escuras — ATIVA desde 2026-11-08, 14:20 (à espera de 30 objetivos novos reais)

Sessão que faz as Fases 1 a 4: «Direção Geral: Fases 1 a 4» (`local_de1ed541-afb1-4bc8-bd2b-78bb9dd3fca2`), aberta pela sessão de desenho (`local_12179b1d-2cf8-4e0c-85da-8fdf2f763b2e`). Ordem do dono, 2026-11-08: "tens ordem para fazer as fases todas".

| # | Passo | Estado |
|---|---|---|
| 1.0 | Reverificar a Fase 0 | feito: 106 testes OK, 69 ficheiros iguais ao manifesto, settings/CLAUDE.md/rules/hooks/agents/`jev-router` sem mudanças desde 2026-11-07 22:00 (em `skills/` e `scripts/` só mudaram ficheiros da app: `skills/synced/…/manifest.json` e `scripts/expose-ecc.log`) |
| 1.1 | Backup, ativação e reversão (scripts testados) | feito: `reverter/ativar-fase-1.sh`, `reverter/reverter-fase-1.sh`, `reverter/troca.py`; `reverter/testes/test-fase-1.sh` 23/23 num HOME temporário (inclui alterações do dono depois da ativação e pré-condições falhadas). Guarda nova: `reverter-fase-0.sh --aplicar` recusa-se com a Fase 1 ativa (teste novo; gerador 108 OK) |
| 1.2 | Instalar `direcao-geral` e 15 `equipa-*` | **ativo** (16 skills em `~/.claude/skills/`; descobertas: `claude -p` respondeu "SIM" e esta sessão recebeu a lista nova) |
| 1.3 | CLAUDE.md com um só decisor | **ativo** (3 trocas exatas; agency-commander com descrição "substituído por direcao-geral") |
| 1.4 | Hooks: `UserPromptSubmit`, registo de equipas, `SessionStart`, rede VibeSec | **ativos** (5 comandos nos settings; Stop junto ao do CodeRabbit). Testes: hooks 18/18, rede VibeSec 11/11, integração 9/9 |
| 1.5 | JEV em silêncio (adaptador, teto, disjuntor) | **ativo**. 1.ª chamada real (prova, `teste:true`): proposta `pesquisa` em 442 ms, 1439 tokens; 2.ª: abaixo do limiar, 432 ms. Teto 60/dia, disjuntor 429/529, prazo 2 s |
| 1.6 | Segurança: VibeSec, `security-reviewer`, CodeRabbit | VibeSec limpo nos ficheiros finais (FALSE_POSITIVE só em `Path(__file__)`/`mkdtemp`/argv). CodeRabbit 4 minor → VALID 4 corrigidos. `security-reviewer`: 1.º ciclo FAIL (1 médio, 8 baixos), 2.º ciclo FAIL só no #1 (caminhos em crases/relativos/`ssh://` passavam na razão). Corrigido pela estrutura depois do 2.º ciclo: o registo **deixou de guardar texto livre** (a razão vira `razao_etiquetas`, só palavras das listas fechadas; a frase fica no transcript local). Sem 3.º ciclo (limite de 2): a correção prova-se por testes (casos do revisor incluídos). Resíduos LOW aceites: seed sem palavra-chave e "a password do servidor é X" não são vistos como segredo (o valor não sai: o envelope é fechado); teto sem lock entre sessões; node fixado no caminho do nvm. **Sem relatório do `/claude-security`: não se declara "seguro"** |
| 1.7 | Provas | feito: prova real com settings globais (registo sem texto do pedido nem chave; equipa pela ferramenta e por `/equipa-ia`; rede VibeSec lembrou; arranque código 0, 0 sem equipa). Reversão real: 3 ficheiros iguais byte a byte ao original, 32 ficheiros de skills removidos, 0 hooks. Reativação: o original antes da 2.ª ativação é igual ao da 1.ª. Backup ativo: `backups/fase-1-20261108-142034` |
| 1.8 | Aviso no arranque quando houver 30 objetivos comparados | feito (`hooks/arranque.mjs` + `hooks/lib/retomar.json`; conta só objetivos reais com resposta do JEV; cala-se quando existir `estado/fase-2-iniciada`) |
| 1.9 | Hooks de equipa (PLANO 1.7) | **ATIVO, mecanismo único desde 2026-11-08 22:35; M1 FECHADO** (antes: v4 desde 18:38, só na thread principal). v4: `vercel`, `fly` e `solana-keygen` por segmento (só leituras conhecidas calam), Monitor e terminal vigiados (matcher `Bash|Monitor|mcp__.*` nas 5 equipas), fim de palavra com aspas/`)`/`;`/`|`, continuação `\`+quebra, npx/bunx/uv/deno publish; 191 testes. Revisões: especialista (implementação com TDD), VibeSec limpo (5 FALSE_POSITIVE antigos), CodeRabbit 0 achados, `security-reviewer` 4.º ciclo FAIL só por M1 (3.º ciclo todo FECHADO, sem regressões). Prova real (`claude -p`, bypassPermissions, sem MCP nem TYPESAFE_API_KEY): Bash e Monitor com `echo git push` recusados; portão `app` OK. BAIXOS em aberto: `vc`, subcomandos de gh/aws/supabase/wrangler/docker stack, ferramentas fora da lista. **M1 (2026-11-08 22:35), com "sim" do dono ao settings.json:** um só mecanismo: hook PreToolUse global no `~/.claude/settings.json` (`Bash|Monitor|mcp__.*`, `bash ".../hooks/guarda-sessao.sh" || true`, timeout 30) → `guarda-sessao.sh` lê no `registo.jsonl` as equipas com guarda da sessão → `guarda-equipa.sh`. As skills deixaram de ter hooks (gerador, atualizar, ativar recusam). Cobre thread principal, subagentes e retoma (o frontmatter não cobria estes 2; provado). `arranque.mjs` avisa o dono se o guarda devia vigiar e não pode. Ligar/desligar: `reverter/ligar-guarda-sessao.sh [--desligar]`. Revisões: 5.º ciclo PASS; 6.º PASS condicionado → corrigido; 3 confirmações Sonnet PASS; CodeRabbit 0 achados (2 corridas); VibeSec só os 5 FALSE_POSITIVE antigos. Prova real no vivo (`claude -p`, modo default, lista fechada): subagente, retoma e thread principal recusam `echo git push` (uma só recusa). Suites: node 45, guarda 189, sessão 52, gerador 114, rede, fase 1, ligar. Seguimento (BAIXOS): NUL no frontmatter do rascunho; `contarComparados` fora do try no arranque; lista do guarda validada em execução contra o `case`; chaves extra em grupos editados à mão. Backup `backups/fase-1-9-unico-20261108-223549`. Reverter tudo: `bash ~/.claude/session-data/2026-11-08-ffba0428-m1/reverter-unico.sh ~/.claude/equipas/backups/fase-1-9-unico-20261108-223549`. Desligar: `rm ~/.claude/equipas/estado/guardas-revistas`. Código anterior: `backups/fase-1-9-v4-20261108-183728` (6 ficheiros + MANIFESTO + ESTADO) |
| 1.9b | Aviso de retoma | `hooks/lib/retomar.json` aponta para «Direção Geral: guarda nos subagentes (M1)» (`local_ffba0428-9893-4afd-b21d-9ee6b4a240eb`), Salto 3/3 (2026-11-08); backup `backups/retomar-20261108-185627` |
| 1.10 | Contagem dos 30 só com pedidos do dono | **ativo**: portão `app`/`mesmo_turno`; arranque conta só `turnOrigin` "human" (cache `estado/origens.json` 0600). Contagem real: **1 de 30** (o registo dizia 6) |
| 2.0 | Fase 2 **LIGADA pelo dono** em 2026-11-09 12:01 (`fase-2.sh ligar` no terminal dele; contagem da Fase 1 ia em 1 de 30). Desligar: `bash ~/.claude/equipas/reverter/fase-2.sh desligar` | instalada: modo em `estado/jev-modo.json`; proposta ≤ 5 linhas; `hooks/rever.mjs gerar|contar` (ficheiro privado em `~/Library/Application Support/equipas-revisoes/`, fora de ~/.claude); `reverter/fase-2.sh ligar` só no terminal do dono com `sim`. Revisões: `security-reviewer` PARTIAL e `privacy-engineer` FAIL → corrigidos (sem 2.º ciclo) |
| 2.1 | Listas das equipas corrigidas (2026-11-09 12:51, pedido do dono) | MCP «ligados» entram sempre na tabela principal (Figma, stitch, motion, HyperFrames, Abracadabrax, Snyk, rea, Claude Docs, Context7); nova chave `excluidos` em `equipas.yaml` (`playwright`, bloqueado pelo `hooks/agent-browser-guard.py`); regenerado em modo vivo e publicado (13, 0). Testes 117 OK, CodeRabbit 0, VibeSec só os FALSE_POSITIVE `Path(...)` já conhecidos. Os estados de login continuam os do instantâneo de 5/11 (o modo vivo não os sabe). Backup `backups/mcp-ligados-20261109-125046`; reverter: repor `equipas.yaml` e `gerador/` desse backup e correr `gerar.py --modo vivo` (o arranque publica). O manifesto da Fase 0 deixa de bater com estes 7 ficheiros (a reversão da Fase 0 mantém-nos) |
| 2.2 | Playwright desbloqueado (2026-11-09 13:52, «sim» do dono) | Saiu do `settings.json` o grupo `PreToolUse` do `~/.claude/hooks/agent-browser-guard.py` (o ficheiro fica, inerte; backup `~/.claude/backups/settings-playwright-20261109-135223.json`); aviso de arranque (`agent-browser-session-start.sh`) já não diz que está bloqueado; `excluidos: []` e `playwright` de volta à Qualidade (publicado); 2 testes do gerador deixaram de depender da lista viva do dono (117 OK). Prova: `mcp__playwright__browser_navigate` para about:blank funcionou. A 2.1 deixa de excluir o playwright |
| 2.3 | Conectores de plugins nunca usados desligados (2026-11-09 14:2x, «sim» do dono) | `deniedMcpServers` no `settings.json` com 83 nomes (lista: `~/.claude/backups/deniedMcpServers-final-20261109-142032.json`); plugins e skills continuam ativos; ficam visíveis Hostinger, Supermetrics e Higgsfield local (para login) e tudo o que já funciona. Reverter: `jq 'del(.deniedMcpServers)'` no settings (com backup). Efeito confirmado com `claude --settings` (102 → 39); a lista da app só se vê numa sessão nova |

Custo fixo estimado (caracteres/4, **estimativa**, não medida): CLAUDE.md 8400 → 8017 caracteres, descrição do agency-commander 616 → 128, descrições das 16 skills +1899: ≈ +1030 caracteres (≈ +260 tokens) por sessão, abaixo do custo das 16 skills (PLANO 1.8). Manifesto da Fase 0: linhas dos 7 ficheiros da Fase 0 mudados nesta fase atualizadas (só `ESTADO.md` difere, por ser o registo vivo). Rasto normal do Claude Code dos testes com `claude -p`: pastas em `~/.claude/projects/` dos projetos temporários (já apagados).

`TYPESAFE_API_KEY`: presente no ambiente do Claude Code (verificado sem a imprimir). Não está em nenhum ficheiro.

`PEXELS_API_KEY` (2026-11-09, tarefa à parte, Opção 1 do dono): saiu do `env` do `settings.json` para o Keychain (`pexels-api-key`) e chega às apps pelo LaunchAgent `local.pexels-env` (padrão TypeSafe; app reaberta às 11:48, sessão com 56 car.). O git de `~/.claude` ganhou hooks `pre-commit` e `commit-msg` (gitleaks + valores de variáveis com nome de segredo, falha fechada); o `.gitignore` ignora `file-history/`, `*.bak`, `*.bak-*`, `*.backup-*`, `.claude.json` e `telemetry/`; o `settings.json.bak` saiu do índice (remoção em stage, por commitar). Nenhum valor esteve em commits nem em remote; hoje nenhum ficheiro adicionável tem os 6 segredos do ambiente. Revisões: `security-reviewer` PASS (2 ciclos), VibeSec 0, CodeRabbit 1 minor (sem objeto). Peças, testes e provas: `session-data/2026-11-09-segredos/` (`ESTADO-TAREFA.md`). Backup `backups/segredos-20261109-104919-Dlu7` (tem a chave em claro, 600). Reverter LaunchAgent e settings: `bash session-data/2026-11-09-segredos/reverter.sh ~/.claude/backups/segredos-20261109-104919-Dlu7` (hooks e `.gitignore` ficam).

## Fase 0 (2026-11-07)

**Fase 0 feita.** Nada ficou ativo fora de `~/.claude/equipas/`.

| # | Tarefa | Estado |
|---|---|---|
| 0.1 | Entradas congeladas | feito |
| 0.2 | Leitor YAML mínimo | feito |
| 0.3 | `equipas.yaml` (15 equipas, regra dos 82, Dados em Operações, partilhados) | feito |
| 0.4 | Fontes (snapshot, disco, texto de terceiros) | feito |
| 0.5 | Distribuição e verificações | feito (golden = desenho) |
| 0.6 | Escrita (relatório, rascunho) | feito |
| 0.7 | CLI e diferenças | feito (`relatorio/DIFERENCAS.md`) |
| 0.8 | `seguranca.md` | feito |
| 0.9 | Script de reversão e manifesto | feito |
| 0.10 | Medida de partida | feito, menos o piso do prompt base (`medida-de-partida.md`, secção 5) |
| 0.11 | Testes A, B, C da secção 14 | A PASS · B PASS · C PARTIAL |
| 0.12 | VibeSec, revisor read-only, CodeRabbit, LEIA-ME | feito (abaixo) |

## Provas (a partir de `~/.claude/equipas`)

- `python3 -I -m unittest discover -s gerador/tests -t gerador` → **106 OK**.
- `python3 -I gerador/gerar.py --modo instantaneo` → exit 0, `VERIFICAÇÃO OK`: 1144 itens, 321 usados, 736 skills, 285 agentes, 123 MCP; 15 equipas + Base 37 + Direção Geral 175. Igual ao desenho.
- `python3 -I gerador/gerar.py --modo vivo` → exit 0: 1155 itens (26 novos, 15 que já não estão), 319 usados, 726 skills, 285 agentes, 144 MCP, 0 sem equipa. Diferenças por equipa em `relatorio/DIFERENCAS.md`.
- `git -C ~/.claude status --short`: por minha mão só `?? equipas/`. Nada em stage, nenhum commit.

## Segurança (Fase 0)

- **VibeSec** em 18 ficheiros `.py` e `.sh` (e de novo nos que mudaram): 23 avisos, todos "Path Traversal" HIGH em `pathlib.Path(...)`, nenhum de outro tipo. Triagem: FALSE_POSITIVE, confirmada pelo revisor independente. São leituras de ficheiros do próprio dono (`fontes.py`, `yamlmini.py`), `Path(__file__)`, argumentos da linha de comandos (`--saida`, `--instantaneo`) e o próprio `escrever_atomico`, que é o código que confina as escritas à base. Os ids de itens nunca viram caminhos.
- **CodeRabbit** (clone temporário sem checkout, 19 ficheiros, nada de `~/.claude` tocado): 6 achados, todos `minor` → **VALID 6 (corrigidos)** · FALSE_POSITIVE 0 · OPTIONAL 0 · UNVERIFIED 0. Cada um tem teste que falhava antes e passa agora (`gerador/tests/test_endurecimento.py`):
  1. `medir.py` contava ferramentas de servidores MCP que já não existem.
  2. `render_diferencas` escrevia nomes do disco sem `limpar_texto`.
  3. Um `.tmp` já existente (ou ligação simbólica) era seguido ao escrever: a escrita atravessava a ligação. Agora `O_EXCL|O_NOFOLLOW`, modo 0600 desde a criação.
  4. A reversão não contava ligações simbólicas ao decidir apagar script e manifesto.
  5. Um manifesto com a última linha inválida deixava remover as anteriores. Agora valida tudo antes de remover.
  6. Uma pasta intermédia ligada para fora da base deixava o `rm` apagar lá, se o hash coincidisse. Agora o pai tem de estar dentro da base.
- **security-reviewer** (agente só de leitura, 1.º ciclo): **PASS**, sem achados críticos nem altos; 2 médios, 5 baixos, 2 informativos. É revisão manual, não um scan oficial. Triagem:
  - MÉDIO, `LEIA-ME.md` dizia "sem rede" e "nada de configuração alterado": VALID, corrigido (os testes A e B usam `claude -p` e deixam rasto normal do Claude Code).
  - MÉDIO, sem `MANIFESTO.sha256`: VALID, gerado como último passo.
  - BAIXO, `teste-ab.sh` deixou resíduos: VALID. A pasta temporária (era de uma corrida com `--manter`) foi apagada e a prova guardada em `testes-fase-0/evidencia/`. **Fica** a pasta `~/.claude/projects/-private-var-folders-48-nx8p5w656h51--3tts2zs4xw0000gn-T-teste-ab-SN4OP2-proj/` (criada pelo Claude Code, fora do âmbito) e uma pasta vazia `~/.claude/session-env/41dfe0bf-290c-4f39-b6c6-b145f5454349/`: podes apagar as duas.
  - BAIXO, `--manifesto` seguia um `MANIFESTO.sha256.tmp` ligado: VALID, corrigido (`rm -f` antes e `set -C`), com teste.
  - BAIXO, `limpar_texto` deixava passar texto invisível (bloco "tags", bidi, hífen suave, selectores de variação) e formas largas: VALID, corrigido (NFKC e remoção das categorias Cf/Cc/Co/Cn e de selectores), com 3 testes. A procura de frases de instrução fica como heurística cosmética: a defesa real é estrutural (texto de terceiros só entra como dado).
  - BAIXO, nomes de itens sem « »: **OPTIONAL no código** (não envolvi 1100 nomes em « »); a documentação ficou exata: os nomes são dados limpos e cortados, as descrições vão entre « ».
  - BAIXO, `distribuir.py` imprimia ids de terceiros sem limpar: VALID, corrigido, com teste.
  - BAIXO, `teste-c-jev.sh` sem controlos positivos e com `~/.claude.json` aberto a escrita: VALID, corrigido (negado; o sandbox corre comandos normais; escrita negada numa zona de teste; servidor local responde fora e é recusado dentro; `/usr/bin/security` corre fora e é recusado dentro). Nova corrida às 23:13: igual, 22 de 22. As leituras de ficheiros continuam livres (documentado).
  - INFO, TOCTOU no escritor: aceite (`equipas/` é 0700, só o dono escreve); fica comentado no código.
  - INFO, `--aplicar` apaga também `*.pyc` e pastas vazias: documentado no cabeçalho e no `LEIA-ME.md`.
  - Fase 1 (fora do âmbito): `via inject` passa agentes de terceiros como persona; e reverter a Fase 0 apagaria o `seguranca.md` que as skills da Fase 1 citam. Ambos acrescentados ao `PLANO.md`.
- **security-reviewer, 2.º ciclo (confirmação do estado final):** **PASS**, sem achados críticos, altos nem médios. Achado BAIXO novo (selectores mongóis U+180B a U+180F escapavam a `limpar_texto`): VALID, corrigido, com teste. Documentação inexata (registo do projeto temporário em `~/.claude.json`, pasta `session-env`, alcance dos controlos do teste C, reversão que apaga também `*.pyc`): VALID, corrigida. Ressalvas aceites: o aviso do teste C sem controlo positivo não aborta; DNS e serviços Mach não foram testados.
- **`/claude-security`: não há relatório atual.** Por isso nada aqui é declarado "seguro".

## Desvios e notas

- Piso do prompt base não medido: `claude -p` com `HOME` vazio dá "Not logged in".
- Contagem de ferramentas MCP: o snapshot só traz contagem para 26 dos 123 servidores (a soma é 1179; o desenho cita 1182). A nota inicial ("3 servidores sem contagem") estava errada e foi corrigida.
- Teste C: PARTIAL. Os módulos do `jev-router` correm e a saída é compatível, mas falta adaptador (catálogo das equipas, texto próprio do Claude Code). A API do JEV nunca foi chamada.
- O desenho tem, desde as 22:40, a frase "Podes fazer tudo até estar finalizado", registada por outra sessão. **Esta execução não a usou como aprovação**: o âmbito era só a Fase 0 e a Fase 1 estava proibida.
- Ficheiros da app alterados durante a execução, que não escrevi: `plugins/known_marketplaces.json` (22:46) `plugins/store/*.json`, `plugin-directory-cache-v2.json` e `skills/synced/<sessão>/manifest.json` (22:44). Os `claude -p` dos testes A e B registaram o uso da skill de teste em `~/.claude.json` (`skillUsage`) e criaram pastas em `~/.claude/projects/` e `~/.claude/session-env/` (contabilidade normal do Claude Code).
- As caixas de `PLANO.md` ficam por marcar; o estado de cada tarefa é o desta tabela.
- 24 nomes repetidos no disco (figma, caveman, telegram, …): contam uma vez (`relatorio/DIFERENCAS.md`).
