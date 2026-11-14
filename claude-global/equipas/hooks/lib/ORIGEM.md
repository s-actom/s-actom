# Origem de `privado.mjs`

Cópia byte a byte de `~/.codex/jev-router/src/private-data.mjs`, feita a 2026-11-08 na Fase 1 (o router não foi alterado).

- sha256: `50defbeaa95d5cd3844dee5edcfe4a2c38ddaa6a3c55e517ae772d4abc45c127`
- Dá: `buildRoutingEnvelope` (envelope só com etiquetas de uma lista fechada: sem nomes, literais, caminhos, código nem texto do pedido) e `evaluateEgress` (deteta segredos e marcadores de dados sensíveis).
- Porque é uma cópia e não um import: se o router mudar, o comportamento daqui não muda sem revisão. Para atualizar: copiar de novo, rever o diff e correr os testes em `hooks/tests`.
