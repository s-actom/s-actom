# Sincronização (estratégia futura) e roadmap

## Estado atual (2026-11-14)

- `~/.claude` tem git local próprio: branch `main`, 1 commit
  (`4932e35`), **sem remotes**, com 1.332 alterações pendentes
  (1.043 apagadas, 167 modificadas, 121 novas). **Intacto** — esta
  exportação não lhe tocou e não lhe adicionou remotes.
- Este repo (`s-actom/s-actom`, pasta `claude-global/`) é uma
  **exportação unidirecional auditada**: `~/.claude` → GitHub.

## Regras de sincronização (proposta, a validar em PR)

1. **Unidirecional por defeito** — o fluxo é sempre `~/.claude` → repo.
   Alterações na configuração são feitas localmente e re-exportadas.
2. **Nunca push direto do git local** — o git de `~/.claude` não ganha
   remotes. A exportação é feita por script de cópia seletiva (a definir,
   generalizando o processo documentado em [AUDITORIA.md](AUDITORIA.md)).
3. **Toda a exportação passa por PR** — revisão CodeRabbit + CI
   (`validar.sh`, suites de testes, gitleaks) antes de merge. Nunca merge
   direto para `main`.
4. **Deteção de drift** — antes de cada exportação, comparar a pasta
   `claude-global/` do repo com uma nova staging; o PR mostra o diff real.
5. **Segredos e terceiros continuam fora** — as regras de exclusão da
   auditoria fazem parte do contrato; o CI falha se aparecer um padrão de
   segredo.

## Fases propostas

| Fase | Conteúdo | Gate |
|---|---|---|
| 1 (este PR) | Snapshot auditado + docs + validação + CI | CodeRabbit + CI verdes; revisão do dono |
| 2 | Script `exportar.sh` (reproduce a auditoria: baseline git local + `.gitignore` + diff ECC + caches de plugins) e `verificar-drift.sh` | PR próprio; saída tem de ser idêntica ao snapshot atual |
| 3 | Sincronização assistida: exportação periódica/manual com PR automático e diff mínimo | 2 exportações consecutivas sem falsos positivos |
| 4 | Direção Geral: publicar rascunho de skills a partir do repo (hoje o `hooks/atualizar.py` publica do rascunho local) | plano próprio, aprovado pelo dono |

## Router dinâmico de modelos (próxima implementação)

O encaminhamento de modelos/pedidos vive hoje fora de `~/.claude`:

- Adaptador JEV: `~/.codex/jev-router/` (config em `config/teams.yaml`,
  com slugs iguais aos das equipas — ver cabeçalho de `equipas/equipas.yaml`).
- Na camada global: `hooks/lib/jev.mjs` (deteção de segredos, envelope de
  etiquetas, teto de 60 chamadas/dia, disjuntor 429/529) e
  `hooks/atualizar.py`; regras de uso em `equipas/LEIA-ME.md` e
  `equipas/ESTADO.md` (passo 1.5).

**Próximo passo natural**: trazer a configuração declarativa do router
(equipas→modelos, limites, disjuntores) para uma pasta própria versionada ao
lado desta (ex.: `router/`), com os mesmos gates de PR. A chave
(`TYPESAFE_API_KEY`) continua só no ambiente — nunca no repo.

## Relação com outros repos do dono

`launch.json` referencia `~/repos/arcanex/prototype` (dev local); esse código
vive no repo privado `s-actom/arcanex-*`, não aqui.
