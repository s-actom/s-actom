#!/usr/bin/env bash
# Testes de guarda-equipa.sh numa BASE temporária, com o ambiente mínimo da app (env -i, /bin/bash 3.2, /usr/bin/jq).
# Correr: bash ~/.claude/equipas/hooks/tests/test-guarda-equipa.sh
set -u
AQUI=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
T=$(mktemp -d) && [ -d "$T" ] || exit 2
trap 'rm -R -- "$T"' EXIT
H="$T/h"; G="$H/.claude/equipas"   # HOME e BASE como na máquina real
mkdir -p "$G/hooks" "$G/estado" && cp "$AQUI/guarda-equipa.sh" "$G/hooks/" && touch "$G/FASE-1-ATIVA" "$G/estado/guardas-revistas"
APP='/usr/bin:/bin:/usr/sbin:/sbin'
F=0; N=0
falha() { echo "FALHOU - $1"; F=$((F+1)); }
corre() { printf '%s' "$2" | env -i PATH="$APP" HOME="$H" /bin/bash "$G/hooks/guarda-equipa.sh" "$1"; }
# Saída: vazia (cala) ou JSON com "ask"; tudo o resto é falha.
g() { local o; o=$(corre "$1" "$2"); [ -z "$o" ] && return 0
  printf '%s' "$o" | /usr/bin/jq -er '.hookSpecificOutput.permissionDecision | select(. == "ask")' 2>/dev/null || echo "SAIDA-INVALIDA"; }
bash_() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')"; }
mcp() { printf '{"tool_name":"%s","tool_input":{%s}}' "$1" "${2:+\"action\":\"$2\"}"; }
pede() { N=$((N+1)); [ "$(g "$1" "$2")" = ask ] && echo "ok - pede: $1 $3" || { echo "FALHOU - devia pedir: $1 $3"; F=$((F+1)); }; }
cala() { N=$((N+1)); [ -z "$(g "$1" "$2")" ] && echo "ok - cala: $1 $3" || { echo "FALHOU - devia calar: $1 $3"; F=$((F+1)); }; }
pb() { pede "$1" "$(bash_ "$2")" "$2"; }; cb() { cala "$1" "$(bash_ "$2")" "$2"; }
pm() { pede "$1" "$(mcp "$2")" "${2##*__}"; }; cm() { cala "$1" "$(mcp "$2")" "${2##*__}"; }
V=mcp__36ea988c-af9d-41b8-a614-837d9bbf31e7; SB=mcp__d052a3e2-fe65-47fb-95c8-033b2550e6b6; HF=mcp__f0e8c4cb-ea08-49e9-8de3-328c03413306; CV=mcp__e0d9dfea-ea62-4038-bca6-eb54cd0692d1
# Blockchain
pb blockchain 'solana transfer abc 1 --url mainnet-beta'; pb blockchain 'solana program deploy x.so'; pb blockchain 'solana delegate-stake A B'
pb blockchain 'forge script Deploy.s.sol --broadcast --rpc-url $RPC'; pb blockchain 'cast send 0xabc "x()" --keystore ks.json'
pb blockchain 'spl-token create-token'; pb blockchain 'curl -s $RPC -d {"method":"sendBundle"}'; pb blockchain 'cat ~/.config/solana/id.json'
pb blockchain 'solana balance --url mainnet-beta'   # cautela aceite: mainnet pede sempre
pm blockchain mcp__helius__heliusWrite; cala blockchain "$(mcp mcp__helius__heliusWallet getBalance)" "heliusWallet getBalance"; cb blockchain 'ls -la'; cb blockchain 'spl-token balance X'
# Infraestrutura
pb infraestrutura 'git push origin main'; pb infraestrutura 'git -C /repo push origin main'; pb infraestrutura 'npx vercel --prod'; pb infraestrutura 'vercel'
pb infraestrutura 'yarn publish'; pb infraestrutura 'pnpm publish --access public'; pb infraestrutura 'aws lambda update-function-code --function-name f'
# Regressão (CodeRabbit PR #1): verbos AWS destrutivos além de delete/rm/destroy
pb infraestrutura 'aws ec2 terminate-instances --instance-ids i-1234567890abcdef0'
pb infraestrutura 'aws rds delete-db-instance --db-instance-identifier db1'
cb infraestrutura 'aws s3 ls'
cb infraestrutura 'aws sts get-caller-identity'
pb infraestrutura 'gcloud run deploy svc'; pb infraestrutura 'netlify deploy --prod'; pb infraestrutura 'kubectl scale deploy/api --replicas=0'
pb infraestrutura 'terraform -chdir=infra apply'; pb infraestrutura 'rsync -av dist/ user@host:/var/www'
pm infraestrutura "$V"__create_deployment; pm infraestrutura "$SB"__execute_sql; pm infraestrutura "$SB"__apply_migration
pm infraestrutura "$V"__create_project_env; pm infraestrutura "$V"__buy_domain; pm infraestrutura mcp__b2__s3_put_object
cm infraestrutura "$V"__list_deployments; cm infraestrutura "$V"__get_deployment; cm infraestrutura mcp__ccd_session_mgmt__delete_session
cb infraestrutura 'git status && git log -1'; cb infraestrutura 'vercel ls'; cb infraestrutura 'kubectl get pods'; cb infraestrutura 'terraform plan'
cb infraestrutura 'docker build -t app .'; cb infraestrutura 'npm install'
# Multimédia
pm multimedia "$HF"__generate_image; pm multimedia "$HF"__deploy_website; pm multimedia "$HF"__upscale_image; pm multimedia "$HF"__dubbing
pm multimedia "$HF"__remove_background; pm multimedia mcp__nano-banana-mcp__edit_image; pm multimedia mcp__nano-banana-mcp__continue_editing
pm multimedia "$CV"__export-design
cm multimedia "$HF"__list_projects; cm multimedia "$HF"__show_generations; cm multimedia "$HF"__balance; cb multimedia 'git push'
cm multimedia mcp__claude-in-chrome__computer; cm multimedia mcp__Claude_Browser__tabs_create
# Marketing
pm marketing mcp__meta-ads__ads_create_campaign; pm marketing mcp__meta-ads__ads_update_entity; pm marketing mcp__meta-ads__ads_update_custom_audience_users
pm marketing mcp__meta-ads__ads_creative_update; pm marketing mcp__meta-ads__ads_delete_custom_audience
cm marketing mcp__meta-ads__ads_get_ad_accounts; cm marketing mcp__meta-ads__ads_insights_performance_trend; cm marketing mcp__ccd_session_mgmt__send_message
# Cibersegurança
pb seguranca 'nmap -sV 10.0.0.1'; pb seguranca "cd x; sqlmap -u 'http://h/?id=1'"; pb seguranca 'nuclei -u https://h'
pb seguranca 'impacket-secretsdump dom/u@h'; pb seguranca 'ncat -e /bin/sh host 4444'; pb seguranca 'subfinder -d example.com'
cb seguranca 'echo nmapper'; cm seguranca "$SB"__execute_sql
# 1.º ciclo do security-reviewer: mainnet curto, solana/spl-token só leituras, deploys indiretos, MCP sem verbo de leitura
pb blockchain 'solana -um transfer X 1'; pb blockchain 'solana -u m transfer X 1'; pb blockchain 'spl-token -um transfer M 1 D'
pb blockchain 'solana program set-upgrade-authority P --final'; pb blockchain 'solana program upgrade B P'; pb blockchain 'solana program close X'
pb blockchain 'solana balance && solana transfer X 1'; pb blockchain 'solana airdrop 1'
cb blockchain 'solana balance'; cb blockchain 'solana -ud balance'; cb blockchain 'solana config get'; cb blockchain 'spl-token accounts'
pede blockchain "$(mcp mcp__helius__heliusAccount upgradePlan)" "heliusAccount upgradePlan"; pede blockchain "$(mcp mcp__helius__heliusStreaming createWebhook)" "heliusStreaming createWebhook"
pm blockchain mcp__helius__heliusWallet   # sem action: na dúvida, pede
pb infraestrutura 'npx vercel@latest deploy --prod'; pb infraestrutura 'npm unpublish pkg@1.0.0'; pb infraestrutura 'npm run deploy:prod'
pb infraestrutura 'make deploy'; pb infraestrutura './scripts/deploy.sh'; pb infraestrutura 'flyctl deploy'; pb infraestrutura 'kubectl -n prod delete pod x'
pb infraestrutura 'docker buildx build --push .'; cb infraestrutura 'cat .github/workflows/deploy.yml'
pm infraestrutura "$V"__buy_single_domain; pm infraestrutura "$V"__replace_domain_dns_records; pm infraestrutura "$V"__update_firewall_config
pm marketing mcp__meta-ads__ads_creative_delete; pm multimedia "$HF"__transactions   # sem verbo de leitura: na dúvida, pede
pb seguranca 'rustscan -a 10.0.0.1'; pb seguranca 'zmap -p 80 10.0.0.0/8'; pb seguranca '(nmap -sV x)'
# 2.º ciclo: comandos em várias linhas e subcomandos, flags do vercel em qualquer posição, fly, solana-keygen
pb blockchain $'solana balance\nsolana transfer X 1 --allow-unfunded-recipient'; pb blockchain $'spl-token accounts\nspl-token transfer M 1 D'
pb blockchain $'solana balance\nsolana program deploy x.so'; pb blockchain 'solana balance $(solana transfer X 1)'
pb blockchain 'solana-keygen new --force --no-bip39-passphrase'; cb blockchain 'solana-keygen pubkey'
pb infraestrutura 'vercel --prebuilt --prod'; pb infraestrutura 'vercel --token "$T" --prod --yes'; pb infraestrutura 'npx vercel --cwd apps/web --prod'
pb infraestrutura 'vercel --prebuilt'; pb infraestrutura 'fly apps destroy app --yes'; pb infraestrutura 'fly volumes destroy vol_1 -y'
pb infraestrutura $'git status\ngit push origin main'
# 3.º ciclo (v4). Monitor e terminal correm comandos de shell (tool_input.command).
mon() { printf '{"tool_name":"Monitor","tool_input":{"command":%s,"description":"d","timeout_ms":60000}}' "$(jq -Rn --arg c "$1" '$c')"; }
ter() { printf '{"tool_name":"mcp__terminal__run_in_terminal","tool_input":{"command":%s}}' "$(jq -Rn --arg c "$1" '$c')"; }
pmo() { pede "$1" "$(mon "$2")" "(Monitor) $2"; }; cmo() { cala "$1" "$(mon "$2")" "(Monitor) $2"; }
pte() { pede "$1" "$(ter "$2")" "(terminal) $2"; }; cte() { cala "$1" "$(ter "$2")" "(terminal) $2"; }
# N2: vercel faz deploy por omissão; só leituras conhecidas calam (por segmento, com opções globais saltadas).
pb infraestrutura 'vercel 2>&1 | tail -20'; pb infraestrutura 'vercel > deploy.log'; pb infraestrutura $'vercel\necho feito'
pb infraestrutura $'vercel \\\n  --prebuilt \\\n  --token=$T'; pb infraestrutura 'vercel --token $VERCEL_TOKEN'; pb infraestrutura 'vercel --cwd apps/web'
pb infraestrutura 'vercel --scope minha-equipa'; pb infraestrutura 'vercel ./dist'; pb infraestrutura 'vercel domains buy x.com'
pb infraestrutura 'vercel dns add x.com @ A 1.2.3.4'; pb infraestrutura 'bash -c "vercel"'
pb infraestrutura 'which vercel'   # falso positivo aceite
cb infraestrutura 'vercel --version'; cb infraestrutura 'vercel -v'; cb infraestrutura 'npx vercel ls'; cb infraestrutura 'vercel env ls'
cb infraestrutura 'vercel env pull .env.local'; cb infraestrutura 'vercel inspect https://x.vercel.app'; cb infraestrutura 'vercel logs x'
cb infraestrutura 'vercel whoami'; cb infraestrutura 'vercel --token=$T ls'; cb infraestrutura 'vercel --scope t ls'; cb infraestrutura 'cat vercel.json'
# Monitor e terminal (seguranca tem MCP=0: o terminal só pede pelo comando; nas outras pede pelo verbo run)
pmo infraestrutura 'git push origin main'; pmo seguranca 'tcpdump -i en0'; pmo blockchain 'solana transfer X 1'
cmo infraestrutura 'tail -f app.log | grep --line-buffered ERROR'; cmo seguranca 'tail -f app.log | grep --line-buffered ERROR'
cala infraestrutura '{"tool_name":"Monitor","tool_input":{"ws":{"url":"wss://x.example/s"},"description":"d","timeout_ms":60000}}' "(Monitor) ws sem shell"
pte seguranca 'nmap -sV 10.0.0.1'; cte seguranca 'ls -la'; pte infraestrutura 'ls -la'
# Fim de palavra com aspas, ) ; | & < > e backtick; prefixo da seguranca com aspas e backtick
pb infraestrutura 'bash -c "git push"'; pb infraestrutura '(git push)'; pb infraestrutura 'git push;echo ok'; pb infraestrutura 'echo `git push`'
pb infraestrutura 'git push|tee log'; pb infraestrutura 'bash -c "npm publish"'; pb blockchain 'anchor deploy;echo ok'
pb seguranca 'echo `nmap -sV 10.0.0.1`'; pb seguranca 'bash -c "nmap -sV 10.0.0.1"'; pb seguranca "sh -c 'sqlmap -u x'"
# Continuação \+quebra entre programa e subcomando (e \\+quebra é quebra real: não se une)
pb infraestrutura $'gh \\\n  pr merge 12 --squash'; pb infraestrutura $'twine \\\n  upload dist/*'; pb blockchain $'solana-keygen \\\n  new --force'
pb blockchain $'solana balance \\\\\nsolana transfer X 1'
# Publicação por npx/bunx/uv/deno; fly e solana-keygen por segmento, com opções globais
pb infraestrutura 'npx changeset publish'; pb infraestrutura 'npx lerna publish from-package --yes'; pb infraestrutura 'uv publish'
pb infraestrutura 'fly secrets set X=1'; pb infraestrutura 'fly machine run img'; pb infraestrutura 'fly ssh console -C ls'
pb blockchain 'solana-keygen -C cfg new --force'
cb infraestrutura 'fly status'; cb infraestrutura 'fly logs -a app'; cb infraestrutura 'fly apps list'; cb infraestrutura 'cat fly.toml'
cb blockchain 'solana-keygen --config cfg pubkey'
# N4: sem pipefail. Com pipefail, um grep -q que sai cedo (verificações por linha/segmento) dá SIGPIPE a montante
# e o guarda calava: os casos de 20000 linhas apanham-no; os de ~300 KB passam pelo B numa só linha (o grep lê-a
# toda) e provam que entradas grandes com o perigo no início pedem. Mede-se o tempo (o hook global tem 30 s para as
# equipas todas da sessão, em série; cada guarda tem de caber folgado nisso).
grande() {  # $1 equipa, $2 rótulo, $3 primeira linha, $4 linha de enchimento, $5 n.º de linhas de enchimento
  local j o s
  j=$(/usr/bin/awk -v a="$3" -v b="$4" -v n="$5" 'BEGIN { if (a != "") print a; for (i = 0; i < n; i++) print b }' \
    | /usr/bin/jq -Rs '{tool_name: "Bash", tool_input: {command: .}}')
  N=$((N+1)); { TIMEFORMAT=%R; time o=$(g "$1" "$j"); } 2>"$T/tempo"; s=$(/usr/bin/tail -n 1 "$T/tempo" | /usr/bin/tr , .)
  if [ "$o" = ask ] && /usr/bin/awk -v t="$s" 'BEGIN { exit !(t + 0 < 2.5) }'; then echo "ok - pede: $2 (${#j} B, ${s} s)"
  else falha "N4: $2 devia pedir em menos de 2.5 s (saída '$o', ${s} s)"; fi
}
grande blockchain '20000 linhas de solana transfer X 1' '' 'solana transfer X 1' 20000
grande infraestrutura '20000 linhas de vercel --prod' '' 'vercel --prod' 20000
grande infraestrutura '~300 KB com git push no início' 'git push origin main' 'echo linha de enchimento 0123456789 abcdefghij' 6500
grande infraestrutura '~300 KB com vercel --prod no início' 'vercel --prod' 'echo linha de enchimento 0123456789 abcdefghij' 6500
# A junção de \+quebra tem de ser linear: o gsub do jq 1.7.1 é quadrático e passava o timeout (o guarda falhava aberto).
grande infraestrutura '30000 continuações \+quebra' 'git push origin main \' 'x \' 30000
N=$((N+1)); if grep -v '^[[:space:]]*#' "$G/hooks/guarda-equipa.sh" | grep -qE 'pipefail|set[[:space:]]+(-[[:alpha:]]+[[:space:]]+)*-[[:alpha:]]*[eo]'
then falha "N4: o guarda tem pipefail, set -e ou set -o"; else echo "ok - N4: o guarda não tem pipefail, set -e nem set -o"; fi
# 4.º ciclo (I1): a exclusão de leituras tem âncora ^ e fim de palavra; sem elas, estes calavam (mutações que sobreviviam)
pb blockchain 'solana address-lookup-table create'; pb infraestrutura 'fly ssh console -C "fly status"'
pb infraestrutura 'vercel deploy --build-env NOTE="vercel ls"'
# Gerais
cb inventada 'git push'
N=$((N+1)); [ -z "$(corre infraestrutura lixo)" ] && echo "ok - entrada inválida: cala" || { echo "FALHOU - entrada inválida"; F=$((F+1)); }
N=$((N+1)); R=$(corre marketing "$(mcp mcp__meta-ads__ads_create_campaign)" | /usr/bin/jq -r '.hookSpecificOutput.permissionDecisionReason')
case "$R" in Marketing:*"Confirma com o dono"*) echo "ok - razão fixa, sem dados da ferramenta" ;; *) echo "FALHOU - razão"; F=$((F+1)) ;; esac
N=$((N+1)); /bin/bash -n "$G/hooks/guarda-equipa.sh" && echo "ok - sintaxe em bash 3.2" || falha "sintaxe"
# Sem jq: não vigia, mas avisa (systemMessage fixo), e nunca bloqueia.
N=$((N+1)); mkdir -p "$T/semjq" && ln -s /bin/cat "$T/semjq/cat"
o=$(printf '%s' "$(bash_ 'git push')" | env -i PATH="$T/semjq" HOME="$H" /bin/bash "$G/hooks/guarda-equipa.sh" infraestrutura); c=$?
[ "$c" = 0 ] && [ "$o" = '{"systemMessage":"Guarda de equipa sem jq: não está a vigiar esta sessão."}' ] && echo "ok - sem jq: avisa e não bloqueia" || falha "sem jq"
# A ligação real é a linha do settings.json para guarda-sessao.sh (com `|| true`): testada em test-guarda-sessao.sh,
# incluindo este guarda estragado ou em falta (falha aberto).
rm "$G/FASE-1-ATIVA"; cb infraestrutura 'git push'; touch "$G/FASE-1-ATIVA"   # Fase 1 desligada
rm "$G/estado/guardas-revistas"
cb infraestrutura 'git push'   # inerte antes da revisão
[ "$F" -eq 0 ] && echo "TODOS OK ($N)" || { echo "$F FALHAS de $N"; exit 1; }
