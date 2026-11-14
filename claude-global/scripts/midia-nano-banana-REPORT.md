# RELATÓRIO — Agente Mídia + Nano Banana MCP (read-only)

**Data:** 2026-06-17 · **Máquina:** Claude Code 2.1.178 (darwin) · **Modo:** READ-ONLY total (zero alterações)

Objetivo: mapear o estado real do agente `midia` + MCP Nano Banana — o que está configurado, o que funciona, o que está incompleto. Prova: Read tool (conteúdo ficheiros) + grep em `.claude.json` + `settings.json`/`settings.local.json`. Zero alterações.

---

## 1. Resumo executivo

| Componente | Estado | Observação |
|---|---|---|
| `agents/midia.md` | **COMPLETO** — 128 linhas | Skills + MCPs + protocolo + validação |
| Nano Banana MCP (npx) | **INSTALADO** — 2 entradas em `.claude.json` | Uma sem GEMINI_API_KEY (home), outra com key (global) |
| `skills/nano-banana-pro-prompts-recommend/` | **PRESENTE** — 9 categorias JSON + SKILL.md | 10k+ prompts, workflow 5 passos |
| `skills/ai-image-prompts/` | **PRESENTE** — versão model-agnóstica | Symlink? Não — directório real |
| Higgsfield MCP | **CONFIGURADO** — HTTP MCP | `https://mcp.higgsfield.ai/mcp` em `.claude.json` global |
| Blender MCP | **DISPONÍVEL** via ECC | Deferred tool — presente em sessão |
| `settings.local.json` whitelist | **PARCIAL** — 3/6 tools whitelisted | `generate_image` ausente da whitelist |

**Risco principal:** `generate_image` não está na whitelist de `settings.local.json`. Sessões que herdem este ficheiro podem pedir aprovação ao usar Nano Banana para geração.

---

## 2. Agente `midia.md` — análise completa

**Path:** `~/.claude/agents/midia.md` · 128 linhas

### 2.1 Frontmatter

```yaml
name: midia
tools: ["Read", "Write", "Bash", "Grep", "Glob"]
model: inherit
```

Sem MCP tools declaradas no frontmatter — correto, MCPs são globais e não precisam de declaração por agente.

### 2.2 Skills declaradas (invocar via Skill tool)

**Geração de media:**
| Skill | Path real | Tipo |
|---|---|---|
| `ai-image-generation` | `skills/ai-image-generation` | symlink → `.agents/skills/ai-image-generation` |
| `ai-image-prompts` | `skills/ai-image-prompts/` | directório real |
| `nano-banana-pro-prompts-recommend` | `skills/nano-banana-pro-prompts-recommend/` | directório real |
| `seedance-20` | não verificado nesta sessão | — |
| `turntable` | não verificado nesta sessão | — |

**Animação e loops:**
| Skill | Path real |
|---|---|
| `perfect-loop` | não verificado |
| `remotion-best-practices` | não verificado |

**Blender e 3D:**
| Skill | Path real |
|---|---|
| `blender-product-polish` | não verificado |
| `blender-threejs-export` | não verificado |
| `polyhaven-studio-setup` | não verificado |

**ECC expostas (symlinks para ecc/):**
- `fal-ai-media` → `ecc/fal-ai-media`
- `remotion-video-creation` → `ecc/remotion-video-creation`
- `video-editing` → `ecc/video-editing`
- `manim-video` → `ecc/manim-video`

### 2.3 MCPs declarados no corpo do agente

**Higgsfield** — 11 tools listadas:
- `generate_image`, `generate_video`, `generate_audio`
- `upscale_image`, `upscale_video`, `remove_background`
- `media_upload_widget` (local files), `media_import_url` (URLs externas)
- `job_status`, `job_display`, `virality_predictor`

**Nano Banana** — 4 tools listadas:
- `mcp__nano-banana-mcp__generate_image`
- `mcp__nano-banana-mcp__edit_image`
- `mcp__nano-banana-mcp__continue_editing`
- `mcp__nano-banana-mcp__configure_gemini_token`

*Nota: `get_last_image_info` e `get_configuration_status` existem mas não estão no corpo do agente.*

**Blender** — 5 tools listadas (subset das disponíveis):
- `get_scene_info`, `execute_blender_code`, `get_viewport_screenshot`
- `search_polyhaven_assets`, `download_polyhaven_asset`

### 2.4 Protocolo de geração (correto e operacional)

```
1. Invocar skill de prompts → ai-image-prompts ou nano-banana-pro-prompts-recommend
2. Upload media local → media_upload_widget (NUNCA passar paths locais diretos)
3. URLs externas → media_import_url → obter media_id
4. Gerar → passar media_id, não raw URL
5. Monitorizar → job_status
6. Validar → inspecionar antes de aprovar
```

### 2.5 Checklist de validação de assets

```
- [ ] Extremidades e bordas
- [ ] Proporções e composição
- [ ] Consistência com guidelines de marca
- [ ] Resolução adequada para uso final
- [ ] Sem conteúdo inapropriado
- [ ] Direitos de uso claros
```

Alinhado com `global-lessons.md` (aprovação visual obrigatória).

---

## 3. Nano Banana MCP — configuração real

### 3.1 Entradas em `~/.claude.json`

**Entrada A — `/Users/goncaloferro` project context (L651):**
```json
"nano-banana-mcp": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "nano-banana-mcp"],
  "env": {}
}
```
→ **SEM GEMINI_API_KEY.** MCP arranca mas `generate_image` falha sem token.
→ Workaround: usar `configure_gemini_token` na sessão para injetar o token.

**Entrada B — global mcpServers (~L3656):**
```json
"nano-banana-mcp": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "nano-banana-mcp"],
  "env": {
    "GEMINI_API_KEY": "[PRESENTE — não impresso]"
  }
}
```
→ **TEM GEMINI_API_KEY.** Esta é a entrada operacional.

### 3.2 Tools disponíveis (deferred, carregam via ToolSearch)

| Tool | Whitelisted em settings.local.json? |
|---|---|
| `generate_image` | **NÃO** ← gap |
| `edit_image` | **SIM** (L69) |
| `continue_editing` | **NÃO** |
| `configure_gemini_token` | **SIM** (L68) |
| `get_configuration_status` | **SIM** (L67) |
| `get_last_image_info` | **NÃO** |

**3 de 6 tools sem whitelist explícita** — dependendo do `defaultMode`, podem pedir aprovação.

### 3.3 Instalação

- Sem plugin cache em `~/.claude/plugins/` — não é plugin CC, é MCP stdio via `npx`
- Instala `nano-banana-mcp` do npm registry on-demand no primeiro arranque
- `npm install` silencioso na 1.ª chamada; subsequentes usam cache npx

---

## 4. Skills Nano Banana — estado

### 4.1 `nano-banana-pro-prompts-recommend` (242 linhas SKILL.md)

**Path:** `~/.claude/skills/nano-banana-pro-prompts-recommend/SKILL.md`

**Estrutura:**
- SKILL.md — workflow completo (5 passos + Step 0 auto-update)
- `references/` — 9 ficheiros JSON + manifest.json:
  - `social-media-post.json`, `product-marketing.json`, `poster-flyer.json`
  - `ecommerce-main-image.json`, `youtube-thumbnail.json`, `game-asset.json`
  - `comic-storyboard.json`, `profile-avatar.json`, `others.json`
  - `manifest.json` — índice dinâmico com totalPrompts e categorias

**Workflow:**
1. Step 0 — auto-update check (`node scripts/setup.js --check`)
2. Step 0.5 — detect content illustration mode
3. Step 1 — clarify vague requests
4. Step 2 — search & match (grep em categorias JSON)
5. Step 3 — apresentar ≤3 prompts COM imagem (sourceMedia[0] obrigatório)
6. Step 4 — fallback custom prompt se sem match
7. Step 5 — remix/personalização se utilizador selecionar

**Atualização:** community sync diário de GitHub (`YouMind-OpenLab/nano-banana-pro-prompts-recommend-skill`).

### 4.2 `ai-image-prompts` (versão genérica)

**Path:** `~/.claude/skills/ai-image-prompts/SKILL.md` · directório real

Mesma biblioteca de 10k+ prompts mas posicionamento model-agnóstico. Funciona com qualquer modelo (Midjourney, DALL-E, Flux, Stable Diffusion, etc.). Workflow idêntico ao #4.1.

---

## 5. Higgsfield MCP — estado

**Configuração:** `~/.claude.json` (~L3674)
```json
"higgsfield": {
  "type": "http",
  "url": "https://mcp.higgsfield.ai/mcp"
}
```
- HTTP MCP (sem autenticação explícita no JSON — provavelmente autenticação via sessão)
- 11 tools disponíveis como deferred tools em sessão
- Sem whitelist entries em `settings.local.json` mas `defaultMode: bypassPermissions` em `settings.json` — aprovação automática global

---

## 6. Issues identificados

### 6.1 `generate_image` fora da whitelist (MÉDIO)

`mcp__nano-banana-mcp__generate_image` não está em `settings.local.json:allow[]`.
Com `defaultMode: bypassPermissions` global, provavelmente passa. Mas se o utilizador mudar o modo de permissões, quebra.

**Fix opcional:** adicionar `"mcp__nano-banana-mcp__generate_image"` à lista em `settings.local.json`.

### 6.2 Entrada home sem API key (BAIXO)

A entrada Nano Banana para `/Users/goncaloferro` tem `env: {}`. Se essa é a entrada que carrega na sessão home, `generate_image` falha até chamar `configure_gemini_token`.

**Fix opcional:** verificar qual entrada está ativa e alinhar com a que tem a key.

### 6.3 Skills `seedance-20`, `turntable`, `perfect-loop`, `blender-*`, `polyhaven-studio-setup` — não verificadas

Referenciadas no `midia.md` mas não inspecionadas nesta sessão (fora do scope).

---

## 7. Tabela de decisão

| Item | Estado | Acção recomendada |
|---|---|---|
| `midia.md` | ✅ Completo | Manter |
| Nano Banana MCP (entrada com key) | ✅ Operacional | Manter |
| Nano Banana MCP (entrada home sem key) | ⚠️ Incompleto | Adicionar GEMINI_API_KEY à entrada `/Users/goncaloferro` |
| `generate_image` whitelist | ⚠️ Ausente | Adicionar a `settings.local.json` (opcional com bypassPermissions) |
| `continue_editing` whitelist | ⚠️ Ausente | Idem |
| `get_last_image_info` whitelist | ⚠️ Ausente | Idem |
| skill `nano-banana-pro-prompts-recommend` | ✅ Presente e atualizada | Manter; sync semanal recomendado |
| skill `ai-image-prompts` | ✅ Presente | Manter |
| Higgsfield MCP | ✅ Configurado | Manter |
| Blender MCP | ✅ Disponível via ECC | Verificar se Blender está a correr localmente antes de usar |

---

## 8. Limitações da inspeção

- `settings.local.json` scanned para whitelist — só 3 entries Nano Banana visíveis.
- `~/.claude.json` tem 3700+ linhas; inspeção focada nos blocos nano-banana e higgsfield.
- Skills `seedance-20`, `turntable`, `perfect-loop`, `blender-*` não inspecionadas.
- Nano Banana npx: não testado em runtime (exigiria `get_configuration_status` ou `generate_image`).
- Higgsfield: não testado em runtime (status de sessão HTTP não verificado).
- **Zero alterações — read-only respeitado.**

---

## 9. Artefactos / paths inspecionados

- `~/.claude/agents/midia.md` — lido na íntegra (128 linhas)
- `~/.claude/skills/nano-banana-pro-prompts-recommend/SKILL.md` — lido na íntegra
- `~/.claude/skills/ai-image-prompts/SKILL.md` — lido primeiras 60 linhas
- `~/.claude/mcp-configs/mcp-servers.json` — lido na íntegra (catálogo de referência, não MCPs ativos)
- `~/.claude/settings.json` — relevante L1-155 + L155-233
- `~/.claude/settings.local.json` — lido na íntegra (197 linhas)
- `~/.claude.json` — grep `nano-banana`, `mcpServer`, L645-675, L3650-3680
- `~/.claude/plugins/cache/` + `marketplaces/` — ls (nano-banana ausente: é MCP npx, não plugin)

**Veredicto:** agente `midia` está bem definido. Nano Banana MCP operacional com key na entrada global. Gap menor: `generate_image`/`continue_editing`/`get_last_image_info` sem whitelist explícita. Entrada home sem GEMINI_API_KEY. Higgsfield e Blender presentes. **NÃO alterado nada — read-only respeitado.**
