#!/bin/bash
# zcode-glm: corre a CLI do ZCode (GLM) fora da app, com o mesmo runtime e a mesma
# configuração de fornecedores que a app passa aos seus processos zcode-cli.
# Correção de 2026-10-18: a CLI 0.16.9 não encontra sozinha a configuração do
# fornecedor (caminho relativo errado) e, no modo -p, só vê o plano depois de um
# "login zai" feito pela própria CLI. Uso: zcode-glm.sh [argumentos da CLI zcode]
set -euo pipefail
APP="/Applications/ZCode.app"
CLI="$APP/Contents/Resources/glm/zcode.cjs"
HELPER="$APP/Contents/Frameworks/ZCode Helper.app/Contents/MacOS/ZCode Helper"
[ -f "$CLI" ] || { echo "zcode-glm: CLI não encontrada em $CLI" >&2; exit 2; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(uname -m)"; [ "$ARCH" = "arm64" ] && ARCH="aarch64"
RUNTIME_DIR="$HOME/.zcode/v2/runtime/provider/darwin-$ARCH/$VERSION"
BUILTIN="$(ls -t "$RUNTIME_DIR"/*/zcode-builtin.json 2>/dev/null | head -1 || true)"
[ -n "$BUILTIN" ] || BUILTIN="$APP/Contents/Resources/config/provider/zcode-builtin.json"
export ZCODE_BUILTIN_PROVIDER_CONFIG_FILE="$BUILTIN"
export ZCODE_PERSONAL_PROVIDER_CONFIG_FILE="$HOME/.zcode/v2/provider_config.json"
export ZCODE_APP_VERSION="$VERSION"
export ELECTRON_RUN_AS_NODE=1
exec "$HELPER" "$CLI" "$@"
