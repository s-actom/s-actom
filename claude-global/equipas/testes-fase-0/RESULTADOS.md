# Resultados dos testes da secção 14 (Fase 0)

2026-11-07. Scripts: `teste-ab.sh` e `teste-c-jev.sh`. Cada um corre numa pasta temporária que se apaga no fim (`teste-ab.sh --manter` deixa-a). Para repetir: `bash ~/.claude/equipas/testes-fase-0/teste-ab.sh` (usa `claude -p`, ou seja, a API da Anthropic, ~0,06 USD) e `bash ~/.claude/equipas/testes-fase-0/teste-c-jev.sh` (sem Internet; só um servidor local em 127.0.0.1 durante alguns segundos, para o controlo positivo da rede).

Prova do A/B (linhas de log dos hooks, 653 bytes): `evidencia/`. Rasto que o `teste-ab.sh` deixa **fora** desta pasta, porque é o Claude Code a escrevê-lo: contabilidade em `~/.claude.json` (só o uso da skill de teste, `skillUsage["teste-hook"]`; o projeto temporário não ficou lá registado), uma pasta vazia em `~/.claude/session-env/41dfe0bf-290c-4f39-b6c6-b145f5454349/` (22:40) e a pasta `~/.claude/projects/-private-var-folders-48-nx8p5w656h51--3tts2zs4xw0000gn-T-teste-ab-SN4OP2-proj/` (só tem um `memory/` vazio). Podes apagar as duas pastas; não as apaguei porque estão fora do âmbito da Fase 0.

| Teste | Veredito | Em uma linha |
|---|---|---|
| A. Hook no frontmatter persiste? | **PASS** | Disparou nos 2 `Bash` seguintes à skill |
| B. O payload traz os argumentos da skill? | **PASS** | `tool_input = {"skill":"teste-hook","args":"alfa beta"}` |
| C. Os módulos do `jev-router` correm no Claude Code? | **PARTIAL** | Correm e a saída é compatível; falta adaptador (catálogo, texto, JEV real) |

## A. Hook no frontmatter de uma skill

Skill de teste com um hook `PreToolUse` (matcher `Bash`) que só regista uma linha. `claude -p` invocou-a pela ferramenta `Skill` e depois correu `echo passo2` e `echo passo3`.
Resultado: o hook disparou para **os dois** `Bash` que vieram depois da skill. Confirma a documentação ("até ao fim da sessão") e liberta os hooks de equipa do desenho (Blockchain, Infraestrutura, Multimédia, Marketing, Cibersegurança).
Não testado: o que acontece após `/clear`, compactação ou reinvocação; a opção `once: true`; eventos que não `PreToolUse`.

## B. Payload do hook

`PreToolUse` e `PostToolUse` com matcher `Skill` (nos settings do projeto) dispararam quando a skill foi invocada pela ferramenta:
- `tool_input = {"skill": "teste-hook", "args": "alfa beta"}` (a documentação não traz este esquema; agora está medido).
- `tool_response` tem as chaves `commandName` e `success`.

**Escrita à mão (`/teste-hook alfa beta`):** disparou só `UserPromptSubmit`. **Não** disparou `PreToolUse` nem `PostToolUse` de `Skill`. Consequência para o desenho: o registo "equipas finais" por `PostToolUse` perde as chamadas feitas à mão; a Fase 1 tem de registar também por `UserPromptExpansion` (a documentação diz que cobre este caso; **não testado**).

## C. Módulos do `jev-router` fora do Codex

Método: cópia do router em `$CODEX_HOME/jev-router` temporário (o router deriva `state`, `logs` e `config` de `$CODEX_HOME`), `env -i`, `HOME` temporário, `CODEX_JEV_TEST_MODE=1`, e `sandbox-exec` a negar rede, `/usr/bin/security` e escrita em `~/.codex`, `~/.claude` e `~/.claude.json`. Controlos positivos (revisão de segurança, 2.ª corrida às 23:13; provam só o que se segue): o sandbox corre comandos normais; a escrita é permitida em `$T` e negada numa zona de teste (com o caminho real: o sandbox compara com o caminho resolvido e `/var` é ligação para `/private/var`, o que numa 1.ª tentativa fez a regra falhar e o controlo apanhou-o); um servidor local em 127.0.0.1 responde fora do sandbox e é recusado dentro; `/usr/bin/security` corre fora e é recusado dentro (é o único acesso ao keychain do router). DNS e serviços Mach não foram testados. O router cai para o keychain `typesafe-api-key` quando não há `TYPESAFE_API_KEY`: foi essa a razão do bloqueio. **A API do JEV não foi chamada.**

- `user-prompt-hook.mjs` com payload do Claude Code **e** com payload do Codex: exit 0 nos dois, ~120 ms, JSON `{"hookSpecificOutput": {"hookEventName", "additionalContext"}}`, a mesma forma que o Claude Code aceita no `UserPromptSubmit`.
- 22 de 22 testes de contrato offline do router passam em Node 24 na cópia (`private-data`, `action-gate`, `task-state`, `context-gate`).
- Router real intocado: 0 ficheiros novos; o que o teste escreveu ficou na cópia.

**Porque PARTIAL:** a rota devolvida é do Codex ("Direção Geral Codex: o catálogo de equipas está indisponível"), porque a cópia não tem o catálogo; o modo de teste usa um backend simulado, por isso o comportamento com o JEV real não foi visto; o Claude Code não traz `turn_id` nem `model`, e o formato do `transcript_path` é outro. Reutilizar os módulos é viável (portão de segredos, estado, deteção de continuação), mas a Fase 1 precisa de um **adaptador pequeno** com o catálogo das 15 equipas e sem leitura do keychain (só `TYPESAFE_API_KEY` do ambiente).

## TypeSafe: preços e quotas

Lidos nas páginas públicas de `docs.typesafe.ai` e `typesafe.ai` em 2026-11-07 (subagente de leitura; nenhum endpoint chamado). Números tal como estão escritos:
- **Preço:** `jev-1.14.0` e `jev-1.13.0`: US$ 42 por mil milhões de tokens de input (US$ 0,042 por milhão). **Output grátis.** A moeda só aparece como "$".
- **Exemplo (ilustrativo, não é tarifário):** 1000 pedidos por dia × 2000 tokens de input = 2 milhões de tokens = cerca de US$ 0,08 por dia.
- **Plano gratuito ou créditos:** não consta. O Jev está em acesso antecipado.
- **Limites:** "por organização", em tokens por segundo e pedidos por segundo. Os valores só aparecem na consola (`console.typesafe.ai/rate-limits`). Não há limite por minuto ou dia publicado.
- **Contexto:** 64k por pedido e 32k por pergunta (262k com o cabeçalho `TypeSafe-Danger-Zone-Long-Context`, mais lento e menos exato). Corpo HTTP até 32 MiB.
- **Erro de limite:** HTTP 429 ("You have exceeded your rate limit") e 529 (sobrecarga); recomendam backoff exponencial; o SDK Python respeita `Retry-After`. Os campos do corpo do 429 não constam.
- **Latência:** "70 ms a 500 ms" de ponta a ponta (afirmação da própria empresa).
- Não consta: preço de outros modelos, SLA, valores de quota da conta.

Efeito no desenho: o disjuntor por erro 429 e o teto diário de chamadas (escolha 16) continuam necessários, porque a quota real só se vê na consola; o custo previsto é pequeno, mas mede-se na fase às escuras.

## O que muda no desenho

1. **Hooks de equipa:** podem depender-se do frontmatter (A). Passo 7 da Fase 1 fica liberto.
2. **Registo de equipas:** `PostToolUse` com matcher `Skill` serve (B), mais `UserPromptExpansion` para a escrita à mão (por testar na Fase 1).
3. **JEV:** reutilizar módulos com adaptador (C); a chave só do ambiente.

## O que não se verificou

- O perfil do sandbox nega rede e escritas; **as leituras de ficheiros continuam livres**. Por isso o teste C prova "o router não usa a rede (loopback incluído), não executa o `/usr/bin/security` e não escreve em `~/.codex`, `~/.claude` e `~/.claude.json`", não "não lê segredos". As escritas só estão negadas nessas 3 zonas e no canário.
- Comportamento com o JEV real (nada chamado, por regra).
- `UserPromptExpansion`, `once: true`, compactação e `/clear` com hooks de frontmatter.
- Os testes A e B correram com o modelo sonnet em `claude -p`, não numa sessão interativa. O `claude -p` registou o uso da skill em `~/.claude.json` (`skillUsage`) e criou pastas de sessão em `~/.claude/projects` e `~/.claude/session-env` (contabilidade normal do Claude Code; não toca em settings).
- O teste `permissions.deny` de agentes (marcado para a Fase 3, não para esta).
