#!/usr/bin/env bash
# SessionStart (global): lembrete de que a automação de browser usa agent-browser.
# O stdout do SessionStart entra no contexto da sessão (frases factuais, não imperativas).
printf '%s\n' 'Automação de browser neste setup: agent-browser, sempre com --session <nome> (fluxo: open <url> -> snapshot -i -> refs @eN). Playwright também pode ser usado (MCP e CLI); o Chrome real do utilizador (logins) só via Claude in Chrome, quando pedido.'
