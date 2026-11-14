# Validação

## `validar.sh` (raiz da pasta)

Corre local e no CI. Verifica:

1. **JSON válido** — `settings.json`, `launch.json`, `mcp-configs/mcp-servers.json`, `hooks/package.json`
2. **Estrutura mínima de `equipas/equipas.yaml`** — chaves `versao:`, `camadas:`, `direcao_geral:`
3. **Frontmatter das 16 skills** — todas `skills/*/SKILL.md` com `name:` e `description:` (mínimo 16)
4. **Segredos** — grep de padrões reais (ghp_/gho_/github_pat_/sk-…/AKIA/PEM) excluindo linhas anotadas `// gitleaks:allow`; e gitleaks completo se instalado
5. **Higiene** — zero `.bak*`, `__pycache__`, `.DS_Store`, `*.log`, `.env`
6. **Limites de tamanho** — nenhum ficheiro >1,5 MB

```bash
bash claude-global/validar.sh   # exit 0 = tudo PASS
```

## Suites de testes executadas (snapshot 2026-11-14, todas verdes)

| Suite | Comando | Resultado |
|---|---|---|
| Hooks da Direção Geral (CI) | idem, com `skip` documentado do teste interativo `fase-2.sh` (pty do runner ≠ terminal do dono) | **53/53 + 1 skip** |
| Hooks da Direção Geral (local) | `node --test tests/hooks.test.mjs tests/fase2.test.mjs tests/recurso.test.mjs` | **54/54 pass** |
| context-handoff | `node --test hooks/context-handoff.test.js` | **29/29 pass** |
| Gerador de equipas | `PYTHONPATH=. python3 -m unittest discover -s tests` | **117 OK** |
| Guarda de equipas | `bash tests/test-guarda-equipa.sh` | **189 verificações OK** |
| Guarda de sessão | `bash tests/test-guarda-sessao.sh` | **52 verificações OK** |
| Rede VibeSec | `bash tests/test-rede-vibesec.sh` | **OK** |
| Integração de hooks | `bash tests/test-integracao.sh` | **OK** |
| Reversão Fase 1 | `bash reverter/testes/test-fase-1.sh` | **OK local** (constrói HOME a partir do `~/.claude` real; no CI não corre — o runner não tem sistema local) |
| Fase 0 (A/B) | `bash testes-fase-0/teste-ab.sh` | **PASS** |
| Wrapper CodeRabbit | `bash scripts/coderabbit-review.test.sh` | **PASS** (CLI falsa, sem rede; em CI o ficheiro global é copiado/criado em `$HOME`) |
| gitleaks 8.30.0 | `gitleaks detect --no-git` | **0 leaks** (6 fixtures anotadas) |

## CI (`.github/workflows/validacao.yml`)

Em cada PR/push: `validar.sh` + suites node/python + gitleaks-action.
O CodeRabbit revê o PR segundo `.coderabbit.yaml` (na raiz do repo).

## Falsos positivos anotados

As linhas com `// gitleaks:allow` em `equipas/hooks/tests/*.test.mjs` contêm
**fixtures sintéticas** (ex.: `ghp_AbCd…`, JWT de exemplo do jwt.io) usadas
pelos testes que verificam que o sistema **redige** segredos do registo.
Nenhum valor real.
