# RELATÓRIO — Fix dos 2 gaps Nano Banana (whitelist + dedup)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Modo:** edição com rede de segurança · **VEREDICTO: PASS**

Fechados os 2 gaps do diagnóstico anterior ([midia-nano-banana-REPORT.md](midia-nano-banana-REPORT.md)): whitelist incompleta + duplicação do MCP. Zero secrets impressos.

---

## Rede de segurança (Phase 0)

| Item | Estado |
|---|---|
| `/tmp/claude-json-backup-20260617-152427.json` | 148423 B (>0) |
| `/tmp/settings-local-backup-20260617-152427.json` | 15241 B (>0) |
| git init `~/.claude` + `.gitignore` + commit | `4932e35 "estado antes de fix nano-banana (whitelist + dedup)"` |

**`.gitignore`** estendido além do SPEC: além de `settings.local.json`, `.credentials*`, `backups/`, `_staging/`, `sessions/`, `projects/`, `*.bak.*`, também exclui volumes pesados/reinstaláveis (`plugins/`, `skills/`, `security/`, `gsd-user-files-backup/`, `design-md/`, etc.). Razão: `~/.claude` = 4.3G com 19 embedded `.git`. Sem isto, `git add -A` faria commit de ~1.5G com gitlinks partidos. Net capta a camada de config humana (agents/commands/hooks/rules/scripts/mcp-configs + .md + settings.json) = 1544 ficheiros, sem embedded repos. Scan confirmou **0 valores de secret** staged (só nome da variável em 2 ficheiros).

---

## GAP 2 — whitelist (Phase 1)

Adicionadas a `settings.local.json` (formato MCP existente `mcp__nano-banana-mcp__<tool>`), após `edit_image`:

```
mcp__nano-banana-mcp__generate_image
mcp__nano-banana-mcp__continue_editing
mcp__nano-banana-mcp__get_last_image_info
```

**Prova (grep):** 6 tools nano-banana agora na whitelist (3 originais + 3 novas). Diff vs backup = exatamente +3 linhas. JSON válido (exit 0).

---

## GAP 1 — duplicação (Phase 2)

**Investigação (python, key só como booleano):**

| | Entrada A — `projects['/Users/goncaloferro'].mcpServers` | Entrada B — top-level global `mcpServers` |
|---|---|---|
| GEMINI_API_KEY | ausente | **presente** |
| outros servers | nenhum (nano = único) | helius, stitch, motion, higgsfield, playwright, blender |
| scope | só cwd `~` | todos os projetos (incl. `~`) |
| precedência em `~` | **ganha** (project > global p/ mesmo nome) | perde |

**Decisão: OPÇÃO A — remover entrada A.** Porquê: A (keyless) é shadow partido — em `~` tem precedência sobre B e força `generate_image` a falhar sem `configure_gemini_token`. B (global, com key) já cobre `~` e todo o lado. Remover A → B vira fonte única que funciona, **sem tocar no secret**. Opção B (copiar key) duplicaria o secret; Opção C (runtime token) manteria o shadow partido — ambas piores.

**Ação:** A = único server → `mcpServers` ficou `{}`. Edição textual atómica via python (Edit tool perdia a race contra o ficheiro vivo que o CC reescreve), com verificação de contagem (1 ocorrência) e validação JSON pré-escrita.

**Prova:** project `mcpServers: {}` (nano removido), global nano com key=True, **1 só** definição `"nano-banana-mcp": {` no ficheiro. JSON válido (exit 0). Key: **0 ocorrências no diff** (linha global intacta).

---

## Verificação (Phase 3)

| Check | Resultado |
|---|---|
| JSON válido `settings.local.json` | ✅ exit 0 |
| JSON válido `~/.claude.json` | ✅ exit 0 |
| 3 tools na whitelist | ✅ grep confirma |
| 1 config coerente nano (sem duplicação) | ✅ 1 definição, global com key |
| Nada além do necessário alterado | ✅ git status `~/.claude` limpo; diff `.claude.json` = minha mudança nano (11 L) + churn `tengu_*` do CC (582/876 L, runtime, não meu) |
| Secrets impressos | ✅ zero (key sempre redacted/booleano) |

---

## Rollback (se preciso)

```bash
cp /tmp/claude-json-backup-20260617-152427.json ~/.claude.json
cp /tmp/settings-local-backup-20260617-152427.json ~/.claude/settings.local.json
# ou, para a árvore de config: cd ~/.claude && git reset --hard 4932e35
```

**VEREDICTO: PASS.** Ambos os gaps fechados, JSON válido nos 2 ficheiros, rede de segurança intacta, zero secrets impressos.
