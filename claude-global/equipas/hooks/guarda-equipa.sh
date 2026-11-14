#!/usr/bin/env bash
# guarda-equipa.sh — guarda a mais das equipas (Fase 1, passo 1.9): as regras. Não é hook por si: chama-o
# guarda-sessao.sh, a partir do hook PreToolUse global do settings.json, uma vez por equipa com guarda chamada na sessão.
# Uso: guarda-equipa.sh <blockchain|infraestrutura|multimedia|marketing|seguranca>, com a entrada PreToolUse no stdin.
# Pede confirmação ao dono ("ask") antes de ações irreversíveis, externas, que gastam créditos ou de uso duplo.
# Nunca recusa sozinho numa sessão interativa; em `claude -p` um "ask" equivale a recusar. Vale em bypassPermissions.
# Falha aberto: guarda-sessao.sh sai sempre 0 e o `|| true` está no comando do settings.json, por isso nem um erro de
# sintaxe aqui bloqueia as ferramentas.
# Vigia o comando de shell do Bash, do Monitor e do terminal (mcp__terminal__run_in_terminal); o resto do MCP, pelos
# verbos do nome. O Monitor com `ws` (sem shell) fica de fora.
# Apanha ações acidentais ou induzidas do agente; não resiste a ofuscação deliberada (n""map, $(echo …)).
# Falsos positivos aceites: `which vercel`, `grep -r vercel .` e mensagens de commit com vercel, fly ou solana pedem.
# Sem errexit nem pipefail, de propósito: um grep -q que sai cedo dá SIGPIPE a montante e o guarda calava (N4).
# Inerte até existir estado/guardas-revistas (criado depois da revisão de segurança).
unset TYPESAFE_API_KEY
BASE=$(cd "${BASH_SOURCE[0]%/*}/.." 2>/dev/null && pwd -P) || exit 0   # sem dirname: não depende do PATH
[ -f "$BASE/FASE-1-ATIVA" ] && [ -f "$BASE/estado/guardas-revistas" ] || exit 0
# Chamado por guarda-sessao.sh nunca chega aqui sem jq (ele cala antes, e o arranque da sessão avisa).
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '{"systemMessage":"Guarda de equipa sem jq: não está a vigiar esta sessão."}'; exit 0
fi
IN=$(cat)
TOOL=$(printf '%s' "$IN" | jq -r '.tool_name // empty' 2>/dev/null)
# Um comando por linha: o original e, se mudar, a variante com as continuações \+quebra unidas. Verificam-se as duas
# (nunca menos pedidos): \\+quebra é uma quebra real e a junção sozinha esconderia o comando seguinte.
# A junção é em awk, linear: o gsub do jq 1.7.1 é quadrático e, com muitas continuações, passava o timeout do hook.
RAW=$(printf '%s' "$IN" | jq -r '.tool_input.command // empty | tostring' 2>/dev/null)
JUN=$(printf '%s\n' "$RAW" | awk '{ if (sub(/\\\r?$/, "")) { printf "%s", $0; n = 1 } else print } END { exit !n }') || JUN=''
CMDL=$(printf '%s\n%s' "$RAW" "$JUN" | tr '\r\t' '\n ')
CMD=$(printf '%s' "$CMDL" | tr '\n' ' ')
ACAO=$(printf '%s' "$IN" | jq -r '.tool_input.action // empty | strings' 2>/dev/null | head -c 200)
P='(^|[^[:alnum:]_.-])'          # início de palavra
A='([^;&|]*[[:space:]])?'        # argumentos no mesmo comando (sem passar ; & |)
F='([[:space:]"'\''`)<>;&|]|$)'  # fim de palavra: espaço, aspas, backtick, ) < > ; & | ou fim
V='(@[^[:space:]]*)?'            # npx pacote@versão
# MCP: cada palavra do nome da ferramenta e do `action` (partidos em _ - e camelCase). Escrita pede; sem verbo de leitura, pede.
W='create|generate|publish|unpublish|post|upload|boost|activate|send|update|edit|editing|delete|remove|pause|upscale|outpaint|reframe|dubbing|deploy|promote|rollback|merge|apply|execute|buy|purchase|put|transfer|swap|stake|withdraw|mint|burn|write|render|export|import|add|assign|cancel|approve|complete|start|stop|restore|replace|invalidate|kill|revoke|issue|accept|authorize|connect|disconnect|participate|register|build|sync|change|extend|patch|move|rename|copy|archive|unarchive|attach|upsert|retry|rerequest|request|stage|run|call|record|set|enable|disable|configure|reconnect|submit|reply|comment|confirm|reset|rebase|control|sign|broadcast|pay|invite|share|schedule|launch|signup|upgrade|subscribe'
L='get|list|search|read|fetch|show|query|count|aggregate|describe|view|preview|check|status|wait|explore|inspect|find|lookup|resolve|history|overview|metrics|stats|info|balance|quote|price|availability|docs|doc|help|guide|insights|report|display|logs|schema|parse|analyze|compare|trace|validate'
# Programas que escrevem por omissão: pedem sempre, salvo leituras conhecidas (segmento a segmento). O: opções globais.
O='((-u[[:space:]=]*[^[:space:]]+|--url[[:space:]=]+[^[:space:]]+|(-C|--config|--output|--commitment)[[:space:]=]+[^[:space:]]+|-v|--verbose)[[:space:]]+)*'
RS='balance|address|account|config[[:space:]]+get|cluster-version|block|block-height|block-time|blocks|slot|epoch|epoch-info|confirm|validators|supply|inflation|logs|rent|catchup|gossip|genesis-hash|leader-schedule|largest-accounts|transaction-count|transaction-history|feature[[:space:]]+status|vote-account|stake-account|stake-history|stakes|program[[:space:]]+(show|dump)|decode-transaction|--version|-V|help|--help|-h'
RT='accounts|balance|supply|display|address|account-info|--version|-V|help|--help|-h'
OKG='((-C|--config)[[:space:]=]+[^[:space:]]+[[:space:]]+)*'
RKG='pubkey|verify|--version|-V|help|--help|-h'
OV='(((-t|--token|--cwd|-S|--scope|--team|-T|-A|--local-config|-Q|--global-config)([[:space:]]+|=)[^[:space:]]+|-d|--debug|--no-color|--non-interactive)[[:space:]]+)*'
RV='ls|list|inspect|logs|env[[:space:]]+(ls|pull)|pull|whoami|help|--help|-h|--version|-v'
OF='(((-a|--app|-c|--config|-o|--org|-r|--region|-t|--access-token)([[:space:]]+|=)[^[:space:]]+|--verbose|--debug|--json|-j)[[:space:]]+)*'
RF='status|logs|version|--version|help|--help|-h|apps[[:space:]]+list|auth[[:space:]]+whoami|releases|machine[[:space:]]+(list|status)|secrets[[:space:]]+list|config[[:space:]]+show'
# escrita <programas> <opções globais> <leituras>: pede se um segmento usa o programa (palavra ou programa@versão) e não
# começa (após espaços e sudo, npx ou bunx) por programa[@versão] + opções globais + leitura conhecida + fim de palavra.
escrita() {
  printf '%s\n' "$SEGS" | grep -iE "${P}($1)(@|${F})" \
    | grep -vE "^[[:space:]]*((sudo|npx|bunx)[[:space:]]+)?($1)${V}[[:space:]]+$2($3)${F}" | grep -q .
}
B=''; MCP=1; ESC=''
case "${1:-}" in
  blockchain) ESC=sol; B="(mainnet|(^|[[:space:]])(-u[[:space:]=]*|--url[[:space:]=]+)m([[:space:]]|$)|--keypair|id\.json|private[_ -]?key|mnemonic|seed[ _-]?phrase|keystore|--broadcast|send(raw)?transaction|sendbundle|${P}anchor[[:space:]]+(deploy|upgrade|migrate)$F|${P}cast[[:space:]]+(send|publish|mktx|wallet)$F|${P}forge[[:space:]]+create$F)"
    R='Blockchain: possível transação, chave ou mainnet' ;;
  infraestrutura) ESC=infra; B="(${P}git[[:space:]]$A(push)$F|${P}gh[[:space:]]+(pr[[:space:]]+merge|release[[:space:]]+create|repo[[:space:]]+(delete|archive)|workflow[[:space:]]+run)$F|${P}(npm|pnpm|yarn|bun|cargo|poetry|npx|bunx|uv|deno)[[:space:]]$A(publish|unpublish|deprecate)$F|${P}(npm|pnpm|yarn|bun)[[:space:]]+run[[:space:]]+[^[:space:];&|]*(deploy|release|publish)|${P}make[[:space:]]$A[^[:space:];&|]*(deploy|release|publish)|(^|[[:space:];&|(])(\./|(bash|sh|zsh|node|python3?|npx|tsx|bun)[[:space:]]+)[^[:space:];&|]*(deploy|release|publish)|${P}twine[[:space:]]+upload$F|${P}gem[[:space:]]+push$F|${P}docker[[:space:]]$A(push|--push)$F|${P}terraform[[:space:]]$A(apply|destroy|import)$F|${P}(kubectl|oc)[[:space:]]$A(apply|delete|scale|rollout|patch|replace|create|edit|set|drain)$F|${P}helm[[:space:]]$A(install|upgrade|uninstall|rollback|delete)$F|${P}(gcloud|az|aws|heroku|netlify|netlify-cli|wrangler|firebase|firebase-tools|railway|supabase|doctl|pulumi|serverless|sls|cdk|sam|eb|amplify)$V[[:space:]]$A(deploy|publish|up|apply|destroy|delete|rm|update-function-code|promote|release|push)$F|${P}s3[[:space:]]+(cp|sync|mv|rm)$F|${P}(rsync|scp)[[:space:]][^;&|]*[[:alnum:]_.-]+:)"
    R='Infraestrutura: push, deploy ou publicação' ;;
  multimedia) R='Multimédia: pode gastar créditos ou publicar' ;;
  marketing) R='Marketing: pode gastar créditos ou publicar' ;;
  seguranca) MCP=0; B="(^|[[:space:];|&/(\"'\`])(nmap|masscan|zmap|rustscan|sqlmap|hydra|medusa|nikto|gobuster|ffuf|wfuzz|dirb|dirsearch|feroxbuster|hashcat|john|msfconsole|msfvenom|aircrack-ng|airodump-ng|aireplay-ng|crackmapexec|netexec|nxc|responder|nuclei|subfinder|amass|naabu|wpscan|enum4linux|kerbrute|evil-winrm|bettercap|ettercap|tcpdump|tshark|impacket-[a-z0-9]+|secretsdump(\.py)?|psexec(\.py)?|mimikatz|chisel|socat|nc|ncat|netcat)$F"
    R='Cibersegurança: ferramenta de uso duplo' ;;
  *) exit 0 ;;
esac
HIT=0
case "$TOOL" in
  Bash | Monitor | mcp__terminal__run_in_terminal)   # comandos de shell
    [ -n "$B" ] && printf '%s' "$CMD" | grep -qiE "$B" && HIT=1
    if [ "$HIT" = 0 ] && [ -n "$ESC" ]; then
      SEGS=$(printf '%s\n' "$CMDL" | awk '{gsub(/&&|\|\||[;&|()`]|\$\(|<\(/, "\n"); print}')
      if [ "$ESC" = sol ]; then
        escrita solana "$O" "$RS" || escrita spl-token "$O" "$RT" || escrita solana-keygen "$OKG" "$RKG"
      else
        escrita vercel "$OV" "$RV" || escrita 'fly|flyctl' "$OF" "$RF"
      fi && HIT=1
    fi ;;
esac
case "$TOOL" in
  mcp__ccd_* | mcp__vibesec__* | mcp__context7__* | mcp__plugin_claude-mem_* | mcp__Claude_Browser__* | mcp__claude-in-chrome__* | mcp__computer-use__* | mcp__visualize__*) ;;  # internos, leitura ou regras de browser próprias
  mcp__*) if [ "$MCP" = 1 ]; then
      TOK=$(printf '%s %s' "${TOOL##*__}" "$ACAO" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '\n')
      if printf '%s\n' "$TOK" | grep -qxE "($W)"; then HIT=1
      elif ! printf '%s\n' "$TOK" | grep -qxE "($L)"; then HIT=1; fi   # sem verbo de leitura conhecido: na dúvida, pede
    fi ;;
esac
[ "$HIT" = 1 ] || exit 0
jq -n --arg r "$R. Confirma com o dono antes de continuar (guarda a mais da equipa; os guardas globais continuam)." \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
exit 0
