# Plano de aplicação ao Mac

> **Nada neste documento foi executado.** O ambiente ativo `~/.claude` está intacto
> (1332 alterações pendentes, 1 commit, 0 remotes — verificado).
> Este plano requer **autorização expressa do proprietário** antes de qualquer passo.

## 1. O que difere entre o repositório (corrigido) e o Mac (ativo)

Comparação feita ficheiro a ficheiro (`cmp`), em 2026-11-14. **13 ficheiros diferem** — ou seja,
os bugs corrigidos no GitHub **existem também localmente**:

| # | Ficheiro no Mac | Linhas de diff | Bug presente localmente |
|---|---|---|---|
| 1 | `equipas/hooks/portao.mjs` | 36 | **Crítico** — em modo `escuras` o JEV revela equipa e recurso |
| 2 | `equipas/hooks/atualizar.py` | 12 | Publicação pode pisar gravação do dono; registo desatualizado a meio |
| 3 | `equipas/reverter/reverter-fase-1.sh` | 39 | Backup corrompido substitui o ficheiro; symlink apaga ficheiro de fora; skill do dono bloqueia reversão |
| 4 | `hooks/claude-security-stop-hook.mjs` | 25 | Recusa de outra tarefa encerra o gate; caminho com espaço escapa ao gate |
| 5 | `scripts/coderabbit-review.sh` | 65 | Credencial em linha removida não é vista; `[a].txt` escapa; `--help` como opção; loop em opção sem valor |
| 6 | `scripts/coderabbit-review.test.sh` | 64 | Teste depende do HOME real |
| 7 | `agents/auditoria.md` | 28 | Afirma garantia de allowlist que não existe como subagente |
| 8 | `agents/workspace-automation-auditor.md` | 2 | Auditor read-only instruído a alterar ficheiros |
| 9 | `agents/conteudo.md` | 7 | Delegações para agentes inexistentes, sem nota |
| 10 | `agents/security/blockchain-security-auditor.md` | 5 | **`decimals()` em vez de `10 ** decimals()`** |
| 11 | `agents/security/penetration-tester.md` | 19 | **Sondagem sem filtro de âmbito** |
| 12 | `agents/engineering/incident-response-commander.md` | 27 | `kubectl -n production` fixo |
| 13 | `agents/engineering/multi-agent-systems-architect.md` | 2 | Audit log sem redação |

Ficheiros novos que não existem no Mac (aditivos, não substituem nada): `validar.sh`,
`validar.test.sh`, `instalar.sh`, `desinstalar.sh`, `teste-instalacao.sh`, `testes-agentes.sh`,
e `docs/{DEPENDENCIAS,AMBITO-CATALOGO,PATCHES-TERCEIROS,PRIVACIDADE}.md`.

## 2. Pré-condições

- [ ] Fechar todas as sessões do Claude Code (nada a escrever em `~/.claude`).
- [ ] Parar refrescamento em segundo plano: `rmdir ~/.claude/equipas/estado/atualizar.lock.d` (se existir).
- [ ] Confirmar que não há alterações locais **nestes 13 ficheiros** que ainda não estejam no repo:
      `cd ~/.claude && git diff -- <ficheiro>` para cada um.
- [ ] Autorização do proprietário (regra: nada se aplica sem ela).

## 3. Backup (obrigatório, com hashes)

```bash
# Um diretório por execução; nunca sobrescreve backups anteriores.
B=$(mktemp -d "$HOME/.claude/backups/aplicacao-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
echo "backup: $B"

# Ficheiros que vão ser tocados (13) — copiar e registar hashes.
ARQ="equipas/hooks/portao.mjs equipas/hooks/atualizar.py equipas/reverter/reverter-fase-1.sh \
hooks/claude-security-stop-hook.mjs scripts/coderabbit-review.sh scripts/coderabbit-review.test.sh \
agents/auditoria.md agents/workspace-automation-auditor.md agents/conteudo.md \
agents/security/blockchain-security-auditor.md agents/security/penetration-tester.md \
agents/engineering/incident-response-commander.md agents/engineering/multi-agent-systems-architect.md"

for f in $ARQ; do
  mkdir -p "$B/$(dirname "$f")"
  cp -p "$HOME/.claude/$f" "$B/$f"
done
( cd "$HOME/.claude" && for f in $ARQ; do shasum -a 256 "$f"; done ) > "$B/ANTES.sha256"
shasum -a 256 "$B/ANTES.sha256"   # registar este hash no relatório
```

## 4. Aplicação (por ficheiro, mínimo e rastreável)

**Não** copiar a pasta inteira. Aplicar só os 13, um a um:

```bash
REPO=/caminho/para/s-actom/claude-global
for f in $ARQ; do
  echo "== $f"
  diff -u "$HOME/.claude/$f" "$REPO/$f" | head -40      # rever antes de escrever
  cp -p "$REPO/$f" "$HOME/.claude/$f"
done
```

Alternativa automatizada, com ensaio e recusa sem `--forcar`:

```bash
bash "$REPO/instalar.sh" --destino "$HOME/.claude" --ensaio   # mostra o plano
# SÓ depois da revisão: --destino "$HOME/.claude" --forcar
```

> `instalar.sh` faz backup do que é pré-existente, aplica a reescrita de prefixo (não altera
> nada nesta máquina, porque o prefixo já é o correto) e remove hooks cujos ficheiros não
> existem — nesta máquina **não remove nenhum**, porque os `gsd-*` existem.

## 5. Testes de regressão após a instalação

```bash
cd ~/.claude
bash equipas/hooks/tests/hooks.test.mjs 2>/dev/null || node --test equipas/hooks/tests/hooks.test.mjs
node --test equipas/hooks/tests/portao-modo.test.mjs                 # modo escuras
node --test hooks/claude-security-stop-hook.test.mjs                 # gate
bash equipas/reverter/testes/test-reverter-integridade.sh            # rollback
PYTHONPATH=equipas/gerador python3 -m unittest discover -s equipas/gerador/tests
bash scripts/coderabbit-review.test.sh                               # wrapper
bash testes-agentes.sh                                               # agentes
```

Esperado: todos verdes (é o que se verifica no repo e na composição).

## 6. Rollback

```bash
# Repor só os 13 ficheiros a partir do backup, e confirmar hashes.
( cd "$HOME/.claude" && for f in $ARQ; do cp -p "$B/$f" "$f"; done )
( cd "$HOME/.claude" && shasum -a 256 -c "$B/ANTES.sha256" )   # tem de dar OK em todos
```

Se alguém alterou um destes ficheiros **depois** da aplicação, o `shasum -c` falha — nesse caso
o ficheiro alterado fica como está e revê-se à mão (o `ANTES.sha256` indica o que era).

## 7. Restrições respeitadas neste plano

- Não se usa `git reset --hard`, `git clean`, force-push, nem merge direto.
- Não se copia a pasta inteira sobre a configuração local.
- Preserva-se: Direção Geral como único decisor, hooks/guardas, delegação, memória
  operacional (`equipas/registo.jsonl`), Codex/JEV (`~/.codex/jev-router` intacto),
  alterações locais não integradas, credenciais e sessões.
- `settings.json` **não** é tocado: já está correto nesta máquina e a reescrita de prefixo é
  uma no-op aqui.

## 8. O que falta decidir (proprietário)

1. Autorizar a aplicação dos 13 ficheiros (passos 3–6).
2. Confirmar se quer os ficheiros novos (`validar.sh`, `instalar.sh`, `testes-agentes.sh`,
   `docs/*`) também em `~/.claude` — são aditivos e não alteram comportamento.
3. Decidir sobre a exposição do nome de utilizador em `settings.json` (ver `PRIVACIDADE.md` §3).
