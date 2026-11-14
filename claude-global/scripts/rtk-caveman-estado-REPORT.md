# RELATÓRIO — Estado de instalação: RTK + Caveman (read-only)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Modo:** READ-ONLY total (zero alterações)

Pergunta a fechar: **se NÃO mencionar RTK/Caveman num prompt, funcionam na mesma?**
Resposta: **SIM — ambos. RTK = hook automático. Caveman = auto-ativo por sessão.**

Prova: Read tool (settings.json, sem filtro RTK) + Bash (`which`/`ls`/`rtk init --show`). Nada instalado, reconfigurado ou tocado.

---

## 1. Tabela-resumo

| Ferramenta | Instalada? | Modo | Mencionar no prompt? |
|---|---|---|---|
| **RTK** | sim (`/opt/homebrew/bin/rtk` v0.39.0) | **hook automático** (PreToolUse Bash) | **não** |
| **Caveman** | sim (plugin `caveman@caveman`) | **auto-ativo cada sessão** (SessionStart + UserPromptSubmit) | **não** |
| **CodeGraph** | não | — | — |
| **Context-Mode** | não | — | — |

---

## 2. RTK — AUTOMÁTICO

### 2.1 Binário
```
which rtk      → /opt/homebrew/bin/rtk
rtk --version  → rtk 0.39.0
```

### 2.2 Hook de rewrite (a peça que o torna automático)
`~/.claude/settings.json` (linhas 88-96):
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "/Users/goncaloferro/.claude/hooks/rtk-rewrite.sh"
    }
  ]
}
```
- Sob `PreToolUse` → **todo comando Bash** passa por `rtk-rewrite.sh` antes de executar.
- Ficheiro existe: `~/.claude/hooks/rtk-rewrite.sh` (3.1K).

### 2.3 Estado confirmado por `rtk init --show` (só leitura)
```
rtk Configuration:

[ok] Hook: rtk hook claude (native binary command)
[ok] RTK.md: /Users/goncaloferro/.claude/RTK.md (slim mode)
[ok] Global (~/.claude/CLAUDE.md): @RTK.md reference
[--] Local (./CLAUDE.md): exists but rtk not configured
[ok] settings.json: RTK hook configured
[--] OpenCode: plugin not found
[--] Cursor hook: not found
```
4 de 4 peças do modo recomendado presentes: hook + RTK.md + @RTK.md no CLAUDE.md global + hook no settings.json.

### 2.4 Veredicto RTK
**Hook automático.** Cada Bash é reescrito sozinho (`git status` → `rtk git status`, etc.). Zero menção necessária.

> Ressalva operacional (memória `rtk-diff-unreliable`): RTK comprime/filtra output e pode reportar diffs errados ("files identical"). Para prova de diff, usar `rtk proxy <cmd>` raw ou o Read tool — não Bash filtrado.

---

## 3. Caveman — AUTO-ATIVO

### 3.1 Não é binário — é plugin
```
which caveman → not found
```
Plugin habilitado em `~/.claude/settings.json` (linha 171):
```json
"caveman@caveman": true
```
Marketplace (linhas 222-227): `github: JuliusBrussee/caveman`.
Dirs do plugin presentes: `~/.claude/plugins/cache/caveman`, `~/.claude/plugins/marketplaces/caveman`.

### 3.2 Hook de ativação por sessão
`~/.claude/settings.json` (linhas 24-33) — sob `SessionStart`:
```json
{
  "type": "command",
  "command": "node \"/Users/goncaloferro/.claude/hooks/caveman-activate.js\"",
  "timeout": 5,
  "statusMessage": "Loading caveman mode..."
}
```
Ficheiro existe: `~/.claude/hooks/caveman-activate.js` (6.1K).

### 3.3 Hook de reforço por prompt
`~/.claude/settings.json` (linhas 128-138) — sob `UserPromptSubmit`:
```json
{
  "type": "command",
  "command": "node \"/Users/goncaloferro/.claude/hooks/caveman-mode-tracker.js\"",
  "timeout": 5,
  "statusMessage": "Tracking caveman mode..."
}
```
Ficheiro existe: `~/.claude/hooks/caveman-mode-tracker.js` (5.6K).

### 3.4 Lógica do activate (prova de auto-on)
`caveman-activate.js` (excertos):
- L2-7: "Runs on every session start: writes flag file `.caveman-active`, emits caveman ruleset as hidden SessionStart context."
- L18-25: `const mode = getDefaultMode();` — só salta ativação se `mode === 'off'`. Default ≠ off → ativa.
- L28: `safeWriteFlag(flagPath, mode)` — escreve o flag que a statusline lê.
- L91: emite `CAVEMAN MODE ACTIVE — level: <mode>` + ruleset filtrado ao nível.

### 3.5 Prova VIVA (empírica, esta sessão)
Os system reminders desta própria conversa, sem eu mencionar caveman:
- SessionStart: `CAVEMAN MODE ACTIVE — level: full`
- UserPromptSubmit (cada prompt): `CAVEMAN MODE ACTIVE (full)`

→ confirma auto-ativação em runtime, não só em config.

### 3.6 `/caveman` NÃO é o interruptor
```
ls ~/.claude/commands/ | grep -i caveman → nenhum
```
Não existe slash-command `/caveman`. Logo `/caveman lite|full|ultra` **não liga** (já liga sozinho) — só **muda o nível**, interpretado pelo `caveman-mode-tracker.js` no UserPromptSubmit.

### 3.7 Veredicto Caveman
**Auto-ativo cada sessão.** Default level `full`. Zero menção necessária para usar.

---

## 4. CodeGraph / Context-Mode — AUSENTES
```
which codegraph     → not found
which context-mode  → not found
ls ~/.claude/skills/*codegraph*    → no matches
ls ~/.claude/skills/*context-mode* → no matches
```
Mesmo ecossistema tokless, mas **não instalados**. Nada a configurar.

---

## 5. Resposta à pergunta (com prova)

**"Se NÃO mencionar RTK/Caveman, funcionam na mesma?" → SIM.**

| Ferramenta | Porquê funciona sem menção | Ficheiro/prova |
|---|---|---|
| RTK | hook `PreToolUse:Bash` reescreve todo comando sozinho | `settings.json:88-96` + `rtk-rewrite.sh` + `rtk init --show` |
| Caveman | hooks `SessionStart` + `UserPromptSubmit` injetam o ruleset | `settings.json:24-33,128-138` + `caveman-activate.js` + system reminders ao vivo |

Prova viva irrefutável: **este próprio prompt** — não mencionei nenhum, e ambos agiram (Bash reescrito + estilo caveman ativo).

---

## 6. Controlo manual (só se quiseres mexer)

Nenhum precisa de ser ligado. Para **alterar**:

| Ação | Comando | Quando |
|---|---|---|
| Mudar nível caveman | `/caveman lite` · `/caveman full` · `/caveman ultra` | qualquer prompt |
| Desligar caveman (esta sessão) | `stop caveman` ou `normal mode` | qualquer prompt |
| Ver estado RTK | `rtk init --show` | qualquer altura (só leitura) |
| Analytics RTK | `rtk gain` · `rtk gain --history` | qualquer altura |
| Desinstalar RTK | `rtk init -g --uninstall` | **destrutivo — não correr sem intenção** |

---

## 7. Artefactos / paths inspecionados (read-only)

- `~/.claude/settings.json` (hooks RTK + Caveman) — lido, não alterado
- `~/.claude/settings.local.json` (14.9K) — existe; hooks rtk/caveman NÃO vivem aqui (estão no settings.json)
- `~/.claude/hooks/rtk-rewrite.sh` (3.1K) · `caveman-activate.js` (6.1K) · `caveman-mode-tracker.js` (5.6K)
- `~/.claude/RTK.md` (slim mode, via `@RTK.md` em CLAUDE.md global)
- `~/.claude/commands/` — sem `/caveman`
- `~/.claude/plugins/{cache,marketplaces}/caveman`
- Binário: `/opt/homebrew/bin/rtk` v0.39.0

---

**Critérios do veredicto (todos provados):** RTK binário presente · hook RTK em settings.json + ficheiro existe · `rtk init --show` 4/4 ok · Caveman plugin habilitado · 2 hooks Caveman em settings.json + ficheiros existem · activate.js auto-on salvo modo off · prova viva nos system reminders · sem `/caveman` command (ativação não-manual) · CodeGraph/Context-Mode ausentes · **zero alterações (read-only respeitado).**
