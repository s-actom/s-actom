# Equipas da Direção Geral

## Fase 1: às escuras

O que liga: as skills `direcao-geral` e 15 `equipa-*` em `~/.claude/skills/`; o `CLAUDE.md` com a Direção Geral como único decisor; 6 hooks em `settings.json` (código em `hooks/`): portão do pedido e JEV em silêncio (`UserPromptSubmit`), registo das equipas escolhidas (`PostToolUse[Skill]` e `UserPromptExpansion`), arranque com avisos e listas atualizadas em segundo plano (`SessionStart`), guarda das equipas (`PreToolUse`, ver abaixo), rede VibeSec junto ao portão do CodeRabbit (`Stop`).

```bash
bash ~/.claude/equipas/reverter/ativar-fase-1.sh             # ensaio: diz o que mudaria
bash ~/.claude/equipas/reverter/ativar-fase-1.sh --aplicar   # backup por cópia e ativação
bash ~/.claude/equipas/reverter/reverter-fase-1.sh --aplicar # desfaz (ensaio sem --aplicar)
```

- Registo local: `registo.jsonl` (modo 600). Guarda sessão, turno (`prompt_id`), portão, envelope de etiquetas, proposta do JEV e equipas finais com a razão. **Nunca o texto do pedido.** Nada sai da máquina, exceto o envelope de etiquetas e o catálogo das equipas, que vão ao JEV.
- JEV: só em objetivos novos, sem segredos; teto de 60 chamadas por dia; disjuntor em 429/529 até ao dia seguinte; prazo de 2 s. A chave vem só de `TYPESAFE_API_KEY` no ambiente.
- Sai quando houver 30 objetivos novos reais comparados: o arranque de sessão avisa numa linha.
- Testes: `node --test hooks/tests/*.test.mjs`, `bash hooks/tests/test-guarda-equipa.sh`, `bash hooks/tests/test-guarda-sessao.sh`, `bash hooks/tests/test-rede-vibesec.sh`, `bash reverter/testes/test-fase-1.sh` e `bash reverter/testes/test-ligar-guarda-sessao.sh` (HOME temporário, `settings.json` copiado sem o bloco `env`), e `bash hooks/tests/test-integracao.sh [--jev]` (usa `claude -p`, ~0,10 USD).
- A reversão da Fase 0 recusa-se enquanto a Fase 1 estiver ativa.

### Guarda das equipas

Um só mecanismo: o hook `PreToolUse` do `settings.json` (matcher `Bash|Monitor|mcp__.*`, comando `bash "…/hooks/guarda-sessao.sh" || true`, timeout 30 s). `hooks/guarda-sessao.sh` lê no `registo.jsonl` as equipas com guarda chamadas nesta sessão (Blockchain, Infraestrutura, Marketing, Multimédia, Cibersegurança) e passa a entrada, em série, a `hooks/guarda-equipa.sh <equipa>`, que tem as regras e pede confirmação ao dono ("ask"). Vigia a thread principal, os subagentes e as sessões retomadas. Nenhuma skill leva hooks no frontmatter: esse hook não corre em subagentes nem depois de `claude -p --resume` (CLI 2.1.319), e o refresco das listas (`hooks/atualizar.py`) recusa publicar um frontmatter com hooks.

```bash
bash ~/.claude/equipas/reverter/ligar-guarda-sessao.sh             # põe só este hook (backup do settings.json; nunca o imprime)
bash ~/.claude/equipas/reverter/ligar-guarda-sessao.sh --desligar  # tira só este hook
rm ~/.claude/equipas/estado/guardas-revistas                       # deixa o guarda inerte, sem mexer no settings.json
```

A ativação da Fase 1 já põe o hook. Ligado quer dizer o grupo exato acima, com o caminho de `hooks/` resolvido (`pwd -P`). `ligar-guarda-sessao.sh` troca qualquer variante (outro timeout, caminho, matcher ou type) pelo grupo exato; `--desligar` tira só os nossos comandos (saem os grupos que eles deixam vazios, e a chave `PreToolUse` e o `hooks` se ficarem vazios); recusa se `hooks/` for ligação simbólica; o temporário e os backups ficam em `backups/` (700, a pasta no `.gitignore` de `~/.claude`) e ficam os 5 backups `settings-m1-*` mais recentes.

Se o guarda devia vigiar e não pode (falta `jq` no PATH; `hooks/guarda-sessao.sh`, `hooks/guarda-equipa.sh` ou `hooks/registo-equipa.mjs` falta, é ligação simbólica ou não se lê; a lista das equipas com guarda (o `for e in …` de `guarda-sessao.sh`) não se lê; uma equipa com guarda falta no catálogo `hooks/lib/equipas.json`; o `registo.jsonl` existe mas não é um ficheiro normal que se leia e grave; faltam no `settings.json` os hooks do registo das equipas (`PostToolUse` `Skill` e `UserPromptExpansion` com `registo-equipa.mjs`) ou o grupo exato do guarda; ou o arranque não conseguiu verificar), o arranque de sessão avisa o dono numa linha, com os comandos. O modelo recebe só uma nota, sem comandos: pedir confirmação ao dono antes de push, deploy, publicação, transações ou gastos de créditos. O guarda em si cala, porque corre em todas as chamadas.

O `registo.jsonl` também é estado do guarda: com a Fase 1 ativa, não o apagues nem o rodes, senão o guarda deixa de ver as equipas já chamadas nas sessões abertas.

## Fase 0 (preparação)

**Estado: preparado, nada ativo.** Esta pasta só tem texto, scripts e testes. Nenhuma skill, agente, hook, MCP, plugin, regra, `settings.json` nem `CLAUDE.md` foi alterado, e o `~/.codex/jev-router` não foi tocado. Único rasto fora desta pasta: os testes A e B correm `claude -p`, e o próprio Claude Code regista isso (detalhe em `testes-fase-0/RESULTADOS.md`). A Fase 1 **não** começou e espera a tua aprovação.

Desenho aprovado: `~/.claude/session-data/2026-11-05-9f8ff3a6-audit/desenho-direcao-geral.md`.

## O que está aqui

| Onde | Para quê |
|---|---|
| `PLANO.md` | Plano de todas as fases (Fase 0 em detalhe; as outras com passos e provas) |
| `equipas.yaml` | Registo: 15 equipas, camadas (Base, Direção Geral), regras e itens partilhados |
| `seguranca.md` | Tabelas de segurança da secção 9 do desenho |
| `gerador/` | Script (só biblioteca padrão do Python) que lê o disco e gera `relatorio/` e `rascunho/` |
| `relatorio/` | `RESUMO.md` (totais), `DIFERENCAS.md` (desenho vs disco de hoje), `atribuicao.tsv` (item a item) |
| `rascunho/` | `direcao-geral` e 15 skills `equipa-*`. Fora de `~/.claude/skills/`, por isso **não** são descobertas |
| `medida-de-partida.md` | Tokens fixos no arranque, custo de arranque de subagentes, hooks |
| `testes-fase-0/` | Testes A, B e C da secção 14, `RESULTADOS.md` (inclui preços e quotas da TypeSafe) e `evidencia/` (prova do A/B) |
| `reverter/` | `reverter-fase-0.sh` e `MANIFESTO.sha256` |
| `entradas/` | Cópia congelada do snapshot de 2026-11-05 (sem novo scan de transcripts) |
| `ESTADO.md` | Estado da execução |

## Comandos (a partir de `~/.claude/equipas`)

Testes do gerador:

```bash
python3 -I -m unittest discover -s gerador/tests -t gerador
```

Verificar que as regras reproduzem o desenho (só lê, nunca escreve):

```bash
python3 -I gerador/gerar.py --modo instantaneo
```

Regenerar `relatorio/` e `rascunho/` com o disco de hoje (escreve só dentro desta pasta):

```bash
python3 -I gerador/gerar.py --modo vivo
```

Repetir a medida de partida:

```bash
python3 -I gerador/medir.py
```

Ver o que a reversão removeria (não remove nada):

```bash
bash reverter/reverter-fase-0.sh
```

Desfazer a Fase 0 (remove só ficheiros do manifesto que não mudaram, mais `*.pyc` e pastas vazias; ficheiros editados por ti ficam):

```bash
bash reverter/reverter-fase-0.sh --aplicar
```

**Se a Fase 1 estiver ativa, reverte-a primeiro:** as skills da Fase 1 citam `seguranca.md` e `equipas.yaml`, que esta reversão apaga.

## Regras que esta pasta cumpre

- Texto de terceiros é **dado**, nunca instrução: as descrições de skills, agentes e MCP aparecem entre « »; os nomes de itens vão limpos de marcação e de caracteres invisíveis, e cortados.
- Da configuração MCP só saem **nomes** de servidores. Nunca env, headers, args nem URLs.
- O gerador só escreve dentro da pasta `--saida` (por omissão, esta). Recusa `..`, caminhos absolutos e ligações simbólicas.
- O gerador não usa rede. Os testes A e B usam `claude -p` (API da Anthropic); o teste C corre sem Internet. A API do JEV nunca foi chamada.

## Segurança: o que foi e o que não foi feito

Feito: VibeSec em todos os `.py` e `.sh`; revisor `security-reviewer` só de leitura; CodeRabbit conforme a regra global. Os achados e a triagem estão em `ESTADO.md`.

**Não existe relatório atual do `/claude-security` para esta pasta**, por isso nada aqui é declarado "seguro". Só se pode dizer que o scan não foi feito.
