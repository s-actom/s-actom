# Agentes arquivados (2026-10-29)

167 subagentes tirados de `~/.claude/agents/` para baixar o custo fixo de contexto
(aviso do Claude Code: descrições acima do limite de 15k tokens).

- **157**: divisões Agency inativas no `agency-commander` (academic, finance, game-development,
  gis, healthcare, marketing, paid-media, project-management, sales, spatial-computing,
  specialized, support), nunca chamados entre 2026-07-09 e 2026-10-29.
- **10**: soltos na raiz, órfãos ou sobrepostos aos coordenadores: agent-evaluator,
  chief-of-staff, opensource-forker, opensource-packager, opensource-sanitizer,
  research-discovery-coordinator, seo-audit-coordinator, skill-portfolio-manager,
  engineering-quality-lead, visual-style-director.

Estrutura de pastas igual à original. `MANIFEST.sha256` lista todos com checksum.
Backup integral da pasta antes da mudança: `~/.claude/backups/20261029T101837Z-archive-unused-agents/`.

## Repor

```bash
bash ~/.claude/agents-archive/RESTORE.sh --dry-run
bash ~/.claude/agents-archive/RESTORE.sh growth-hacker
bash ~/.claude/agents-archive/RESTORE.sh
```

Sem nomes repõe todos. Nunca sobrescreve. Depois de repor, regenera o catálogo do commander.
Auto-teste do script (pasta temporária, não toca em `~/.claude`): `bash test_restore.sh`.
Os 157 Agency também voltam se ativares a divisão em `skills/agency-commander/divisions.yaml`
(o commander injeta-os a partir de `~/tools/agency-agents`), exceto `executive-chief-of-staff`,
que só existe aqui.
