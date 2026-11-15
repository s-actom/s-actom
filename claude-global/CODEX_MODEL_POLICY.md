# Política Global — Codex Model para Second Opinion

## Problema

O plugin Trail of Bits Second Opinion hardcoda `gpt-5.3-codex` em ficheiros internos.
Este modelo é antigo. A OpenAI tem migration rules que o convertem para `gpt-5.4`,
mas **não** para `gpt-5.5` ou modelos mais recentes.

Não editar os ficheiros do plugin. Em vez disso, fazer override no comando.

## Regra Principal

**Quando invocar Second Opinion com Codex, SEMPRE fazer override do modelo.**

Nunca usar o modelo que a skill sugere por defeito.

## Como Determinar o Modelo Correto

**Fonte de verdade:** `~/.codex/config.toml`, campo `model`.

```bash
grep '^model' ~/.codex/config.toml
```

Usar o valor encontrado como override no `codex exec`.

**Fallback documentado (última verificação conhecida):**
- 2026-06-20: `gpt-5.5` verificado e confirmado funcional
- Este valor PODE estar desatualizado — verificar `config.toml` primeiro

## Override no Comando

```bash
# O override de modelo é explícito e nunca se omite (sem ele o router interno decide).
codex exec \
  -c model='"MODELO_ATUAL"' \
  -c model_reasoning_effort='"xhigh"' \
  --sandbox read-only \
  --ephemeral \
  -o "$output_file" \
  - < "$prompt_file"
```

Substituir `MODELO_ATUAL` pelo valor de `~/.codex/config.toml` ou por `gpt-5.5`
se a verificação falhar.

## Regras Operacionais

### Modelo
- Nunca usar `gpt-5.3-codex` diretamente — está desatualizado
- Nunca omitir `-c model=` — o default da skill é antigo
- Verificar `~/.codex/config.toml` antes de cada sessão de review importante

### Tool por defeito
- Usar **Codex only** salvo pedido explícito para Gemini
- Gemini requer `--yolo` (auto-aprova tool calls sem confirmação) — só quando solicitado

### Durante review
- Operar `--sandbox read-only` sempre
- Não editar ficheiros durante Second Opinion
- Não fazer commit, push, reset durante Second Opinion

### Smoke test
- Não ler ficheiros do repositório
- Não analisar código
- Não usar `--output-schema` (schema desnecessário para smoke test)
- Não usar Gemini
- Pedir resposta exacta de confirmação

## Modelos Obsoletos — Bloquear

| Modelo | Estado | Substituir por |
|--------|--------|----------------|
| `gpt-5.3-codex` | Obsoleto — migration para `gpt-5.4` | Default atual de `~/.codex/config.toml` |
| `gpt-5.2-codex` | Obsoleto | Default atual de `~/.codex/config.toml` |

## Atualizar Esta Política

Quando um novo modelo Codex for lançado e verificado:
1. Atualizar o campo `model` em `~/.codex/config.toml`
2. Atualizar a secção "Fallback documentado" acima com data + modelo verificado
3. Adicionar modelo antigo à tabela de obsoletos
