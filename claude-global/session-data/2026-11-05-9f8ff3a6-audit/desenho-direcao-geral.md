# Direção Geral e equipas: desenho para aprovação

**Estado:** aprovado pelo dono em 2026-11-07, sem escolhas riscadas ("aprovo o desenho e agenda para começares a fazer isso hoje as 22:01"). Cada fase continua a pedir aprovação própria. Em 2026-11-07, cerca das 22:40, com a Fase 0 a correr, o dono acrescentou: "Podes fazer tudo até estar finalizado". Até esta data, nada foi alterado em skills, agentes, MCP, hooks ou settings.

## Resumo

1. O pedido entra e o código filtra segredos, pedidos triviais e continuações.
2. Num objetivo novo, o JEV propõe equipas.
3. A Direção Geral (o orquestrador) confirma ou corrige, e diz porquê quando corrige.
4. Cada equipa chamada traz a lista do que tem e os seus hooks. O texto de cada skill só carrega quando é usado.
5. A segurança entra sempre que há código ou arquitetura.
6. Nenhum ficheiro muda de sítio.

## 1. Porquê

Palavras do dono:
- "o nosso sistema tem várias skills e agentes e mcp espalhados por todo lado e muitas vezes nem eu sei nem tu"
- "vamos começar um projeto de site, ao chamares as equipas já vem tudo lá, ou vamos fazer uma auditoria de segurança, já vem tudo lá dentro"
- "a segurança tem de andar sempre junta com tudo o que fazemos de código ou arquitetura"
- "agentes especialistas e skills de segurança também têm de ser usados"

Causa confirmada na documentação: Claude vê os nomes de todas as skills, mas as descrições têm um limite de 1% do contexto, e as das menos usadas são cortadas. Na lista recebida numa sessão anterior, só 35 de 728 skills tinham descrição.

Números de 2026-11-05: 1144 itens (736 skills, 285 agentes, 123 servidores MCP), 321 usados desde julho. Cada sessão lista 1182 ferramentas MCP e 285 agentes.

## 2. Objetivos

**Objetivos**
- O dono pede em linguagem normal e nunca precisa de nomear skills, agentes ou MCP.
- Claude sabe o que existe, porque a lista é gerada do disco e não depende da memória.
- Um só decisor escolhe quem trabalha.
- A segurança entra por regra, não por alguém se lembrar.
- O custo fixo de cada sessão desce, e isso é medido.

**Não-objetivos**
- Não remover nem arquivar itens agora.
- Não reescrever skills ou agentes de terceiros.
- Não fazer scans completos automáticos.

**Anti-objetivos: o projeto falhou se**
- Ficar mais uma camada ao lado das que já existem, em vez de um só decisor.
- Quebrar nomes de skills, por exemplo os 83 agentes que pré-carregam `coding-standards`.
- Parar o dono em cada pedido.
- O catálogo precisar de manutenção à mão.
- Dizer "seguro" sem relatório atual do `/claude-security`.

## 3. Restrições

- Backup antes de editar settings, hooks e agentes. Cada fase tem reversão num passo.
- Cada fase pede aprovação própria. Aprovações não passam entre sessões.
- `/claude-security` só a pedido do dono, sem contornar a confirmação do plugin.
- Skills de plugin não se escondem uma a uma: o plugin liga ou desliga inteiro.
- Agentes de plugin ignoram `hooks`, `mcpServers`, `permissionMode` e `initialPrompt`.
- Não alterar nem interromper o `~/.codex/jev-router`, que está em uso no Codex.
- Nunca imprimir chaves. `TYPESAFE_API_KEY` vem do ambiente.

## 4. Decisões

**Do dono**
- Direção Geral e 14 equipas, com skills, agentes e MCP dentro de cada equipa.
- Chamar equipa traz tudo, sem o dono saber nomes.
- O JEV escolhe equipas no início. Se o orquestrador discordar, escolhe ele, diz porquê, e afina-se o JEV.
- Segurança sempre junta com código e arquitetura, com especialistas da Agency e skills de segurança a serem mesmo usados.
- Nada muda antes de um desenho aprovado.

**Escolhas minhas: risca as que não queres**

| # | Escolha | Razão |
|---:|---|---|
| 1 | 15.ª equipa, Sistema, com os 45 itens para mexer no próprio Claude Code | Mantém a Direção Geral curta. Se riscares, os 45 ficam na Direção Geral e o JEV escolhe entre 14 |
| 2 | Formas de trabalhar (175) ficam na Direção Geral | Servem todas as equipas |
| 3 | Superpowers fica inteiro e sempre ligado, como método | O plugin não se divide |
| 4 | ECC deixa de ser chamado como bloco e as peças entram nas equipas | É uma caixa de peças, não um método |
| 5 | Dados e analytics (20) entram em Operações & Documentos | 0 usos; "relatórios" já lá está |
| 6 | Depois de escolher, arranca logo e diz numa linha o que chamou. Só para em ações irreversíveis ou externas, ou se faltar um login necessário | Não te parar em cada pedido |
| 7 | Itens sem uso ficam nas listas, em segundo plano. Nada se arquiva agora | "Dentro das equipas fica tudo" |
| 8 | Um item pode estar em mais de uma equipa (Context7, browser) | Evita cópias |
| 9 | Strix fica de fora até pedires a instalação | Não existe no sistema |
| 10 | Primeiros 30 objetivos novos com o JEV às escuras | Sem isso, a medida de acerto fica enganadora |
| 11 | Listas de todas as equipas de uma vez, sem piloto numa só. A redução do que carrega é feita por partes | As listas não mudam ficheiros; esconder é que tem risco |
| 12 | Não usar um plugin por equipa | Ver secção 7 |
| 13 | A regra de segurança segue o que é editado, não uma lista de equipas | "Sempre" não pode falhar só porque a equipa era Design ou Multimédia |
| 14 | O registo guarda a referência do turno e o pedido é mostrado a partir do transcript local, só na revisão | Sem isso não consegues julgar quem tinha razão |
| 15 | Os hooks de equipa são guardas a mais. Nenhum guarda global passa para lá | Uma sessão sem a equipa não perde nada |
| 16 | A mesma chave TypeSafe do Codex, com teto diário e disjuntor | Uso previsto pequeno. Se preferires chave própria, crias tu |
| 17 | Os 7 hooks do GSD passam para uma skill nossa, `modo-gsd`. Se não se garantir que ela corre antes do GSD, ficam globais | Skills de terceiros não se editam |

## 5. Como funciona no dia a dia

**"vamos começar um projeto de site"**
1. O hook vê objetivo novo e o JEV propõe Desenvolvimento, Design & UX, Qualidade & Testes e Infraestrutura.
2. Como há código, aplica-se a regra de segurança da secção 9.
3. A Direção Geral escreve: `Equipas: Desenvolvimento, Design & UX, Qualidade, Infraestrutura + regra de segurança.`
4. Avisa o que falta: por exemplo, login em falta no Figma.
5. Superpowers dá o método: brainstorming, plano, TDD, verificação.
6. `security-architect` entra no plano. Os especialistas entram conforme o que o site toca, por exemplo `identity-access-engineer` se houver login.
7. No fecho: testes, VibeSec, CodeRabbit e `security-reviewer`.

**"vamos fazer uma auditoria de segurança"**
1. O JEV propõe Cibersegurança.
2. A equipa traz agentes, skills, Snyk e VibeSec, e entram os que servem o alvo.
3. Se o dono chamar `/claude-security`, o scan corre como hoje.

**Quando discordam**

`JEV: Design. Eu: Design + Infraestrutura. Porquê: o site precisa de deploy.`

## 6. Camadas e equipas

```
BASE, sempre ligada (37)
  app, memória, estilo, hooks gerais e de segurança
        │
DIREÇÃO GERAL (175)
  recebe pedidos, escolhe equipas · método: superpowers
        │
EQUIPAS, só quando chamadas (932)
```

| Equipa | Itens | Usados desde julho | Traz |
|---|---:|---:|---|
| Marketing & Growth | 129 | 75 | SEO, GEO, anúncios, CRO, copy, social |
| Cibersegurança | 63 | 28 | auditorias, pentest, análise |
| Desenvolvimento | 106 | 37 | frontend, backend, APIs, bases de dados |
| Design & UX | 122 | 13 | Figma, Stitch, interfaces, animações |
| Qualidade & Testes | 100 | 39 | QA, TDD, E2E, CodeRabbit, revisões de código |
| IA & Agentes | 26 | 10 | LLM, RAG, evals, agentes |
| Multimédia | 76 | 16 | vídeo, imagem, Higgsfield, Remotion |
| E-commerce | 12 | 3 | Shopify, catálogo, checkout, pagamentos |
| Vendas & CRM | 60 | 4 | leads, prospeção, CRM, outreach |
| Infraestrutura | 45 | 16 | GitHub, Vercel, Docker, deploy |
| Pesquisa | 21 | 15 | research, Context7, browser, Apify |
| Blockchain | 31 | 13 | Solana, Helius, contratos, DeFi |
| Engenharia reversa | 3 | 2 | Ghidra, REA, análise de apps |
| Operações & Documentos | 93 | 4 | documentos, produtividade, relatórios, dados |
| Sistema (proposta) | 45 | 14 | hooks, skills, agentes, plugins, configuração |

Total: Base 37 + Direção Geral 175 + Equipas 932 = 1144. Lista item a item em `equipas-distribuicao.md`, ainda sem aplicar Sistema, Base e Dados em Operações.

**Regra para dividir os 82 de manutenção**
- **Base (37):** origem `App (embutido)`, `artifact-*`, caveman, ponytail, i-have-adhd, claude-mem, `memory`, `using-superpowers`, `full-output-enforcement`.
- **Sistema (45):** todos os restantes.

## 7. Montagem

**Forma escolhida: registo gerado por script, sem mover ficheiros.**

Porque não um plugin por equipa:
- Mover skills para plugin muda o nome para `plugin:skill` e parte `skills:` em agentes, o CLAUDE.md e hooks.
- Agentes de plugin perdem `hooks`, `mcpServers` e `permissionMode`.
- Plugins de terceiros não se dividem sem fork.
- Ligar um plugin a meio da sessão pede `/reload-plugins`, portanto não acontece só por chamar a equipa.

**Peças**

1. **Registo:** `~/.claude/equipas/equipas.yaml`, com as 15 equipas, a descrição de cada uma e as regras. Parte das regras de `distribuir_equipas.py` e de `agency-commander/divisions.yaml`.
2. **Gerador:** lê disco, plugins, configuração MCP e uso. Escreve as listas. Nunca há edição à mão. Parte de `inventory.py`, `classify.py`, `distribuir_equipas.py` e `build_catalog.py`.
3. **Skill de equipa:** `equipa-<slug>`, gerada.
   - Descrição nossa, numa linha.
   - Corpo com os itens usados primeiro: nome, função, estado do MCP.
   - Os sem uso ficam num ficheiro ao lado, lido só se nada do resto servir.
   - Primeira linha, gerada: quando houver código ou arquitetura, segue `~/.claude/equipas/seguranca.md` (secção 9).
   - `hooks:` no frontmatter quando a equipa tem hooks próprios.
4. **Direção Geral:** skill `direcao-geral`, evolução do `agency-commander`, com menos de 120 linhas.
   - Mantém do commander: classes de tarefa, limites de equipa, contrato de delegação, `via installed` e `via inject`, revisores read-only.
   - Acrescenta: proposta do JEV, escolha de equipas, linha de desacordo, `seguranca.md`.
5. **Aviso de novidades:** item novo sem equipa aparece no arranque da sessão.

**Como se reduz o que carrega**

| Peso | Mecanismo | Limite |
|---|---|---|
| Skills locais (407) | `skillOverrides: name-only` | Usar `name-only`, nunca `off`: em `off` a invocação dá erro |
| Skills de plugin (329) | `enabledPlugins` por projeto | Plugin inteiro. Desligado continua legível por caminho, sem os hooks dele |
| Conectores claude.ai (710 ferramentas) | Ligar por equipa com `set_session_connector_enabled` | Vale no turno seguinte, fica como default das sessões novas e pode pedir aprovação por chamada. A testar |
| MCP do utilizador (374 ferramentas) | Passar `rea` e `meta-ads` para os projetos que os usam | Deixam de estar disponíveis noutras pastas |
| Duplicados | Retirar cópias: Shopify, Context7, Higgsfield. Rever `playwright`, bloqueado por hook | Confirmar qual fica |
| Agentes (285) | Sem uso passam a `via inject`, como em 2026-10-29 (20,9k para 12,3k tokens) | Revisores read-only ficam instalados, porque precisam dos limites de tools |

## 8. JEV

**O que é:** modelo da TypeSafe que devolve probabilidades e escolhas tipadas, sem texto nem raciocínio. Por isso a razão de um desacordo só pode vir do orquestrador.

**O que já existe:** `~/.codex/jev-router`, só no Codex. Desde 2026-09-21: 3031 pedidos e 5126 chamadas, com 270 ms de mediana e 1,5 s no p95, em 608 medidas recentes. Não encontrei medida de acerto nos registos.

**Autoridade:** código > orquestrador com razão > JEV. Hoje, no Codex, é código > JEV > LLM.

**Fluxo**
1. Hook `UserPromptSubmit` no thread principal.
2. Portão de código: segredos, pedidos triviais, continuação. Regra inicial para objetivo novo: primeiro pedido da sessão, ou nenhuma equipa ativa.
3. O JEV recebe etiquetas de trabalho e as 15 equipas, e devolve uma probabilidade por equipa. Limite inicial 0,5, no máximo 5 equipas.
4. Se falhar ou passar de 2 s, não há proposta e escolhe o orquestrador.

**Privacidade:** segue a regra do router. Pedidos normais de projeto levam só etiquetas permitidas. Sensíveis e secretos não chamam o JEV. Enviar o texto do pedido exige nova decisão do dono.

**Registo:** `~/.claude/equipas/registo.jsonl`, local. Guarda a referência da sessão e do turno, proposta, equipas finais e razão, nunca o texto do pedido. As equipas finais vêm de um hook `PostToolUse` nas skills `equipa-*`. Na revisão, o pedido é mostrado a partir do transcript local, só ao dono. Nada sai da máquina.

**Chave e custo:** a mesma `TYPESAFE_API_KEY` do router. Teto diário de chamadas e disjuntor: se o JEV devolver erro de limite, fica desligado até ao dia seguinte, para não prejudicar o Codex. Preços e quotas confirmam-se nas docs da TypeSafe na Fase 0. O custo real mede-se na fase às escuras.

**Fases do JEV**
- **Às escuras:** nos primeiros 30 objetivos novos, o JEV regista em silêncio e o orquestrador escolhe sem ver.
- **A falar:** o JEV propõe primeiro e o orquestrador pode corrigir.

**Afinar, a cada 30 casos**
1. Lista dos desacordos e de 5 acordos ao acaso.
2. O dono decide quem tinha razão. O orquestrador não é árbitro, senão o JEV copia os erros dele.
3. Ajustam-se descrições das equipas, etiquetas, perguntas e limites. Pelo que li, o modelo não é treinado com os nossos casos.
4. Um ajuste só fica se acertar mais na lista de casos.

**Saída honesta:** se o JEV não acertar mais do que o orquestrador sozinho, ou não poupar nada, sai. O resto do desenho funciona sem ele.

## 9. Segurança

**Regra de código.** A regra segue o que é feito, não uma lista de equipas. Qualquer equipa que escreva código ou mexa em arquitetura fica coberta, incluindo Design & UX, Qualidade e Multimédia.
- **Fonte única:** `~/.claude/equipas/seguranca.md`, com as tabelas desta secção.
- **Ligação:** `direcao-geral` e as 15 skills de equipa apontam para ela numa linha gerada. Nem o JEV nem o orquestrador a podem tirar.
- **Rede:** a lembrança do VibeSec (secção 10) apanha edições de código mesmo sem equipa chamada.
- **"+ regra de segurança" não é a equipa inteira.** A lista completa de Cibersegurança só é chamada quando o alvo é segurança ou quando as tabelas não chegam.

**Quanto entra, conforme a dimensão**

| Classe | Segurança |
|---|---|
| Trivial (1 a 2 linhas de código) | VibeSec no fecho |
| Simples | 1 skill de segurança da área e VibeSec |
| Várias áreas ou arquitetura | `security-architect` no plano, especialista conforme o que toca, `security-reviewer` no fecho |
| Crítica (login, pagamentos, dados pessoais, segredos, produção) | Especialista e revisor independente, ambos obrigatórios |

**Quem entra, conforme o que o trabalho toca**

| Toca em | Especialista | Skills |
|---|---|---|
| Arquitetura, fronteiras de confiança | `security-architect` | `owasp-security`, `insecure-defaults` |
| Login, sessões, permissões | `identity-access-engineer` | `api-security-best-practices` |
| Dados pessoais | `privacy-engineer` | `owasp-security` |
| Segredos e chaves | `secrets-credential-hygiene-engineer` | `insecure-defaults` |
| APIs e apps web | `application-security-engineer` | `api-security-best-practices`, `cc-skill-security-review`, `VibeSec-Skill` |
| Cloud e infraestrutura | `cloud-security-architect` | `insecure-defaults` |
| Dependências | `senior-secops-engineer` | `supply-chain-risk-auditor`, Snyk |
| Agentes, hooks, GitHub Actions | `ai-generated-code-security-auditor` | `agentic-actions-auditor`, `security-scan` |
| Muito código gerado por IA | `ai-generated-code-security-auditor` | `VibeSec-Skill` |
| Contratos, DeFi, wallets | `blockchain-security-auditor`, `crypto-protocol-auditor` | `building-secure-contracts:*`, `defi-amm-security` |
| Framework específico | Conforme o caso | `django-security`, `laravel-security`, `springboot-security`, `quarkus-security` |

**Rever o que foi feito, com tools só de leitura:** `security-reviewer`, `application-security-auditor`, `differential-review`.

**Só quando pedido ou quando acontece:** `penetration-tester`, `compliance-auditor`, `incident-responder`, `threat-detection-engineer`, `threat-intelligence-analyst`, `security-bounty-hunter`, `semgrep`, `codeql`, `burpsuite-project-parser`, `/claude-security`. A biblioteca `~/.claude/security-skill-library` continua a ser lida por caminho, e o grupo de uso duplo continua só manual.

**Prova do problema:** dos 12 agentes de segurança da Agency, 6 têm 0 usos desde julho. Skills e revisores gerais têm muito uso (`owasp-security`, `security-reviewer`). As tabelas servem para os especialistas serem de facto chamados.

**Três momentos**
- **Ao desenhar:** plano e arquitetura levam uma parte de segurança: o que pode correr mal, quem acede a quê, segredos, dados.
- **Ao escrever:** hooks ativos e especialista quando a tabela o indicar.
- **Ao fechar:** testes, VibeSec, CodeRabbit, e revisor quando a classe o pede.

**Triagem:** VibeSec tem falsos positivos. Em 2026-11-05 marcou `Path(__file__)` como Path Traversal HIGH. Os achados seguem as classes VALID, FALSE_POSITIVE, OPTIONAL e UNVERIFIED, e o VibeSec não bloqueia sozinho.

**Segurança do próprio desenho**
- Texto de terceiros no catálogo é dado, nunca instrução. Cortar e limpar descrições na geração.
- Só skills geradas por nós levam hooks no frontmatter das equipas.
- Conectores que escrevem (Vercel, Supabase, Shopify, meta-ads) continuam a pedir confirmação.
- `gsd-prompt-guard` e `gsd-read-injection-scanner` parecem guardas de segurança. Ler antes de mexer no GSD. Não se podem perder.

## 10. Hooks

Hoje: 19 nos settings (9 do GSD) e pelo menos 23 em plugins.

**Novos gerais (só 3)**

| Evento | Faz | Falha |
|---|---|---|
| `UserPromptSubmit` | Portão de código, JEV, lembrete de invocar `direcao-geral`, no máximo 5 linhas | Sem proposta, nunca bloqueia |
| `PostToolUse` nas skills `equipa-*` | Regista equipas e razão | Ignora |
| `SessionStart` | Atualiza listas se o disco mudou e avisa de itens sem equipa | Usa a última lista |

**Alargar 1:** a rede do `coderabbit-stop-gate.sh` lembra uma vez se houve código editado sem VibeSec. Funciona mesmo sem equipa chamada.

**Novos de equipa** (frontmatter; ficam ativos até ao fim da sessão). São guardas a mais: nenhum guarda global passa para aqui, por isso uma sessão sem a equipa não perde nada. Nos settings e nos hooks de plugins que li não há guard de crypto; hoje é regra no CLAUDE.md.

| Equipa | Hook |
|---|---|
| Blockchain | Guards obrigatórios: mainnet, wallet, secret, transaction |
| Infraestrutura | Confirmação de push e deploy |
| Multimédia, Marketing | Confirmação antes de gastar créditos ou publicar |
| Cibersegurança | Autorização antes de ferramentas de uso duplo |

**Mudar de sítio**
- 7 hooks do GSD passam para uma skill nossa, `modo-gsd`, sem editar as `gsd-*` de terceiros. Só depois de confirmar que nenhum projeto ativo depende de `.planning/`. Se não se garantir que ela corre antes do GSD, ficam globais. Os 2 que parecem guardas ficam globais.
- `livro-flora-roadmap-step.sh` passa para as settings desse projeto.

**Ficam como estão:** RTK, `agent-browser-guard`, `context-handoff`, `skill-policy-hook`, `security-guidance`, claude-mem, `expose-ecc-skills`, CodeRabbit, caveman, ponytail, ADHD, superpowers.

## 11. O que acontece às peças que já existem

| Peça | Fica assim |
|---|---|
| `agency-commander` | Evolui para `direcao-geral`. Só um dos dois decide em cada momento |
| Tabela de routing do CLAUDE.md | Substituída pela Direção Geral |
| 10 coordenadores PT | Ficam como itens das equipas, sem recomendação no CLAUDE.md. Rever depois (9 sem uso em 30 dias) |
| `skill-router` | Retirado da decisão (sem chamadas Skill; último registo em setembro) |
| Superpowers | Sempre ligado. Regra no CLAUDE.md: a escolha é da Direção Geral, e a regra do 1% não se aplica. O próprio texto diz que o CLAUDE.md manda |
| ECC | Ficheiros onde estão. `rules/ecc/common/agents.md` deixa de mandar usar agentes por iniciativa e deixa de citar o plugin `ecc@ecc`, que não está ligado |
| GSD | 100 itens na Direção Geral, com 1 uso. Sem arquivar agora |
| CLAUDE.md "auditorias só a pedido" | Mantém-se para Daybreak e `/claude-security`. Revisores de código passam a entrar por regra |

## 12. Fases

Cada fase: backup, prova com comandos, VibeSec e CodeRabbit nos scripts, e aprovação do dono.

| Fase | O que muda | Sai quando |
|---|---|---|
| 0. Preparar | Registo, gerador, listas em rascunho, script de reversão, medida de partida. Nada ativo | O dono viu as listas |
| 1. Às escuras | `direcao-geral`, 15 skills de equipa, `seguranca.md`, rede VibeSec, JEV em silêncio. CLAUDE.md passa a ter um só decisor | 30 objetivos novos comparados |
| 2. JEV a falar | O JEV propõe e o orquestrador corrige. Registo e afinação | Acerto aprovado pelo dono |
| 3. Reduzir | Um mecanismo de cada vez, medido antes e depois. Hooks do GSD | Custo fixo medido e sem quebras |
| 4. Limpar | Retirar routers antigos e rever coordenadores. Arquivo só do que o dono aprovar | Um só decisor no sistema |

## 13. Como medimos

- Tokens fixos no arranque da sessão, antes e depois.
- Acerto do JEV e do orquestrador, com o dono como árbitro nos desacordos.
- Vezes em que o dono teve de nomear um recurso, em 30 pedidos.
- Alterações de código com a segurança completa para a sua classe: objetivo 100%.
- Sem quebras: os `skills:` dos agentes resolvem e a delegação funciona.

## 14. Riscos e o que testar

| Risco | Como se testa ou limita |
|---|---|
| O hook do Codex pode não correr no Claude Code | Testar na Fase 0. Reutilizar módulos, sem mexer no Codex |
| O JEV pode acertar pouco em português só com etiquetas | Fase às escuras. Se falhar, decisão do dono |
| A regra no CLAUDE.md pode não travar o texto dos superpowers | Ver na Fase 1 se aparecem invocações a mais |
| `permissions.deny` pode não tirar agentes da lista | Testar antes de usar. A documentação só garante que impede o uso |
| O payload do hook pode não trazer os argumentos da skill | Testar na Fase 0. Alternativa: comando local de registo |
| Hook no frontmatter pode não persistir como a documentação diz | Testar na Fase 0 com um hook inofensivo, antes de depender dele |
| Mais latência e dependência externa | Só em objetivo novo, limite de 2 s, sem bloquear |
| Mais tokens com especialistas | Quanto entra depende da classe da secção 9 |
| Hooks de equipa ficam ativos até ao fim da sessão | Aceite: pecam por excesso de cautela |

## 15. Fica ao critério de quem construir

- Estrutura de ficheiros dentro de `~/.claude/equipas/`.
- Reutilizar módulos do `jev-router` ou escrever um adaptador pequeno, depois de ler as docs atuais da TypeSafe.
- Formato exato das listas e escolha do tipo de pergunta ao JEV.
- Lista final de itens partilhados.
- Linguagem dos hooks.

## 16. Fontes

- Documentação: code.claude.com/docs, páginas `sub-agents`, `plugins/components`, `skills`, `settings-reference`, `hooks`, lidas via Context7 em 2026-11-05.
- Dados: `ds/auditoria-itens.json`, `equipas-distribuicao.md`, `~/.codex/jev-router/README.md`, `logs/router.jsonl`, `agency-commander/catalog.md`.
- Estado da app: `session_connectors_status`, 2026-11-05.
