#!/usr/bin/env bash
# expose-ecc-skills.sh
# Expõe skills relevantes de ~/.claude/skills/ecc/ para o path escaneado pelo
# harness (~/.claude/skills/<nome>/) via symlink relativo "ecc/<nome>".
#
# Porquê: o harness só escaneia filhos DIRETOS de ~/.claude/skills/ e SEGUE
# symlinks (provado: os symlinks ../../.agents/skills/* já são lidos no listing).
# A subpasta ecc/ é invisível ao scan. Este script cria root/<nome> -> ecc/<nome>.
#
# Propriedades:
#   - Idempotente: correr N vezes => mesmo estado, sem duplicar.
#   - Nunca apaga nada. Nunca escreve/move/apaga dentro de ecc/ (só LÊ SKILL.md).
#   - Colisão (nome já existe em root e NÃO foi criado por esta camada) => salta + log.
#   - Disparado por hook SessionStart (corre DEPOIS do ECC; repõe após repair/update).
#   - Exit 0 SEMPRE (uma falha nunca pode bloquear o arranque da sessão).
#   - DRY_RUN=1 => não cria symlinks, só reporta o que faria (validação read-only).
#
# NÃO instala deps. NÃO imprime secrets/envs.

set -uo pipefail

SKILLS_DIR="${HOME}/.claude/skills"
ECC_DIR="${SKILLS_DIR}/ecc"
LOG="${HOME}/.claude/scripts/expose-ecc.log"

# --- Lista de exposição (Tier 1, núcleo ~88) — agrupada por agente -----------
EXPOSE=(
  # construcao (19)
  python-patterns python-testing golang-patterns golang-testing rust-patterns
  rust-testing java-coding-standards kotlin-patterns kotlin-testing
  swift-concurrency-6-2 swiftui-patterns cpp-coding-standards cpp-testing
  coding-standards error-handling tdd-workflow verification-loop e2e-testing
  ai-regression-testing
  # sistema (23)
  backend-patterns api-design api-connector-builder database-migrations
  postgres-patterns mysql-patterns prisma-patterns jpa-patterns docker-patterns
  clickhouse-io latency-critical-systems data-throughput-accelerator
  dashboard-builder github-ops django-patterns django-security springboot-patterns
  springboot-security nestjs-patterns laravel-patterns laravel-security
  quarkus-patterns quarkus-security
  # site (11)
  react-patterns react-performance react-testing frontend-patterns
  frontend-design-direction motion-ui make-interfaces-feel-better
  liquid-glass-design angular-developer dart-flutter-patterns ui-to-vue
  # gestor-de-agentes (14)
  mcp-server-patterns agent-harness-construction agent-architecture-audit
  agentic-engineering ai-first-engineering eval-harness
  parallel-execution-optimizer prompt-optimizer cost-aware-llm-pipeline
  hookify-rules skill-scout autonomous-loops team-builder token-budget-advisor
  # crypto (4)
  defi-amm-security evm-token-decimals nodejs-keccak256 llm-trading-agent-security
  # lancamento (2)
  deployment-patterns production-audit
  # conteudo (4)
  article-writing brand-voice content-engine market-research
  # midia (4)
  fal-ai-media remotion-video-creation video-editing manim-video
  # pesquisa (4)
  exa-search research-ops knowledge-ops search-first
  # auditoria (3)
  security-bounty-hunter automation-audit-ops workspace-surface-audit
)

ts() { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "$1" >> "$LOG" 2>/dev/null; }

n_exposed=0; n_already=0; n_collision=0; n_missing=0
dry="${DRY_RUN:-0}"

log "=== expose-ecc-skills run @ $(ts) (DRY_RUN=${dry}) ==="

# Pré-condição: ecc/ existe. Se não, sai limpo (não bloqueia a sessão).
if [ ! -d "$ECC_DIR" ]; then
  log "[skip] ecc dir ausente: $ECC_DIR"
  echo "expose-ecc: ecc dir ausente, nada a fazer."
  exit 0
fi

for name in "${EXPOSE[@]}"; do
  src="${ECC_DIR}/${name}"
  link="${SKILLS_DIR}/${name}"

  # Fonte tem de existir (com SKILL.md) para expor.
  if [ ! -f "${src}/SKILL.md" ]; then
    log "[missing] ${name} — sem ecc/${name}/SKILL.md, salto"
    n_missing=$((n_missing + 1))
    continue
  fi

  if [ -L "$link" ]; then
    tgt="$(readlink "$link" 2>/dev/null || echo '')"
    if [ "$tgt" = "ecc/${name}" ]; then
      # Já exposto por esta camada => idempotente, nada a fazer.
      n_already=$((n_already + 1))
      continue
    fi
    # Symlink existente mas NÃO desta camada (ex.: ../../.agents/skills/*) => colisão.
    log "[collision] ${name} — symlink existente -> ${tgt}, salto (não sobreponho)"
    n_collision=$((n_collision + 1))
    continue
  elif [ -e "$link" ]; then
    # Dir/ficheiro real em root => skill nativa => colisão, salta.
    log "[collision] ${name} — entrada real em root, salto (não sobreponho)"
    n_collision=$((n_collision + 1))
    continue
  fi

  # Ausente em root => expor.
  if [ "$dry" = "1" ]; then
    log "[dry] exporia ${name} -> ecc/${name}"
    n_exposed=$((n_exposed + 1))
    continue
  fi

  if ln -s "ecc/${name}" "$link" 2>/dev/null; then
    log "[exposed] ${name} -> ecc/${name}"
    n_exposed=$((n_exposed + 1))
  else
    log "[error] ${name} — falhou ln -s, salto"
  fi
done

summary="expose-ecc: exposed=${n_exposed} already=${n_already} collision=${n_collision} missing=${n_missing} total=${#EXPOSE[@]} dry=${dry}"
log "$summary"
echo "$summary"
exit 0
