# Validação

## `validar.sh` (raiz da pasta)

Corre local e no CI. Verifica:

1. **JSON válido** — `settings.json`, `launch.json`, `mcp-configs/mcp-servers.json`, `hooks/package.json`
2. **Estrutura mínima de `equipas/equipas.yaml`** — `versao:`, `camadas:`, `direcao_geral:`
3. **Frontmatter das 16 skills** — todas `skills/*/SKILL.md` com `name:` e `description:`
4. **Segredos** — padrões reais (ghp_/gho_/PAT/sk-/AKIA/PEM), excluindo linhas `gitleaks:allow`.
   O relatório é privado (`mktemp` 0600, apagado no fim) e **nunca imprime o valor**
   encontrado — só ficheiro, linha e contagem. Mais gitleaks completo, se instalado.
5. **Higiene** — zero `.bak*`, `__pycache__`, `.DS_Store`, `*.log`, `.env`
6. **Limites de tamanho** — nenhum ficheiro >1,5 MB

```bash
bash claude-global/validar.sh   # exit 0 = tudo PASS
```

## Cobertura real do CI

| Suite | No CI | Notas |
|---|---|---|
| `validar.sh` | ✅ | |
| `equipas/hooks/tests/{hooks,fase2,recurso}.test.mjs` | ✅ | 54 testes |
| `equipas/hooks/tests/portao-modo.test.mjs` | ✅ | 7 testes — contrato do modo do JEV |
| `hooks/context-handoff.test.js` | ✅ | 29 testes |
| `hooks/claude-security-stop-hook.test.mjs` | ✅ | 3 testes — recusa delimitada ao turno |
| `equipas/gerador/tests` (unittest) | ✅ | 117 testes |
| `test-guarda-equipa.sh` | ✅ | 189 verificações |
| `test-guarda-sessao.sh` | ✅ | 52 verificações |
| `test-rede-vibesec.sh` | ✅ | |
| `equipas/reverter/testes/test-reverter-integridade.sh` | ✅ | 8 verificações — integridade do rollback |
| `scripts/coderabbit-review.test.sh` | ✅ | HOME isolado; já não depende da máquina |
| `test-integracao.sh` | ❌ | exige `claude -p` real (~0,10 USD) e HOME autenticado |
| `testes-fase-0/teste-ab.sh` | ❌ | exige `claude -p` real e HOME autenticado |
| `testes-fase-0/teste-c-jev.sh` | ❌ | exige `sandbox-exec` (macOS) e o router em `~/.codex` |
| `reverter/testes/test-fase-1.sh` | ❌ | constrói um HOME a partir do `~/.claude` real da máquina |
| `reverter/testes/test-ligar-guarda-sessao.sh` | ❌ | idem: precisa do `~/.claude` real |

As quatro excluídas são **testes de integração com o ambiente real**: não são
executáveis num runner limpo sem custo/credenciais. Correm à mão, na máquina do dono:

```bash
bash equipas/hooks/tests/test-integracao.sh        # ~0,10 USD
bash equipas/testes-fase-0/teste-ab.sh
bash equipas/testes-fase-0/teste-c-jev.sh
bash equipas/reverter/testes/test-fase-1.sh
```

## Resultados (2026-11-14, máquina do dono)

| Suite | Resultado |
|---|---|
| hooks da Direção Geral | **54/54 pass** |
| contrato do modo do JEV | **7/7 pass** (verificado por mutação) |
| context-handoff | **29/29 pass** |
| hook Claude Security | **3/3 pass** (verificado por mutação) |
| gerador de equipas | **117 OK** |
| guarda de equipas / sessão / VibeSec | **189 / 52 / OK** |
| integridade do rollback | **8/8 OK** (verificado por mutação) |
| wrapper CodeRabbit | **PASS** |
| `validar.sh` | **PASS — 489 ficheiros, 0 falhas** |
| gitleaks 8.30.0 | **0 leaks** |

## Verificação por mutação

Cada correção de bug foi provada em dois sentidos: o teste passa com a correção e
**falha** quando o comportamento antigo é reintroduzido. Feito para:
modo do JEV (`portao.mjs`), integridade do rollback (`reverter-fase-1.sh`, 2 casos)
e delimitação da recusa ao turno (`claude-security-stop-hook.mjs`).

## Falsos positivos anotados

Linhas com `// gitleaks:allow` em `equipas/hooks/tests/*.test.mjs` contêm **fixtures
sintéticas** (`ghp_AbCd…`, JWT de exemplo do jwt.io) usadas pelos testes que verificam
que o sistema **redige** segredos. Os headers PEM em
`agents/security/senior-secops-engineer.md` são **documentação de padrões** a detetar,
sem corpo de chave. Nenhum valor real.
