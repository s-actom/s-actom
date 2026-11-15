# CLAUDE CODE — REGRAS DE CONSTRUÇÃO COM SEGURANÇA, TESTES E OBSERVABILIDADE

Este ficheiro define **como o código deve ser construído** neste projeto.

Não é uma auditoria para fazer só no fim. É uma regra de trabalho contínua: cada funcionalidade nova deve nascer com segurança, permissões, validação, logs, tratamento de erro, tipos e testes mínimos.

---

## 1. Objetivo

Construir o projeto com uma base pronta para produção, evitando o erro clássico de fazer primeiro “funcionar” e só depois tentar remendar segurança, testes e arquitetura.

O objetivo não é travar o desenvolvimento. O objetivo é impedir que o projeto avance com:

- autenticação fraca;
- endpoints sem permissão;
- dados de utilizador sem proteção;
- secrets expostos;
- mocks e bypasses esquecidos;
- erros silenciosos;
- logs que vazam dados sensíveis;
- código duplicado e difícil de manter;
- frontend a chamar APIs sensíveis diretamente;
- ausência de testes nos fluxos críticos.

---

## 2. Regra principal

Cada feature nova só pode ser considerada “pronta” se cumprir estes mínimos:

```text
FEATURE DONE =
- input validado no backend;
- autenticação aplicada quando necessário;
- autorização/RBAC/ownership verificados;
- nenhum secret no código;
- nenhum mock/bypass ativo em produção;
- tratamento de erro implementado;
- logs estruturados e sanitizados quando aplicável;
- tipos TypeScript corretos;
- teste mínimo do fluxo principal;
- teste mínimo do erro ou bloqueio principal;
- typecheck/build/test a passar.
```

Se alguma destas partes não for aplicável, o Claude Code deve explicar porquê.

---

## 3. Startup obrigatório antes de codificar

Antes de mexer em ficheiros, o Claude Code deve fazer um startup review.

### 3.1 Ficheiros a inspecionar

Verificar, quando existirem:

```text
package.json
package-lock.json / pnpm-lock.yaml / yarn.lock
README.md
.env.example
.gitignore
tsconfig.json
next.config.* / vite.config.* / astro.config.* / framework config
src/
app/
pages/
api/
routes/
server/
middleware/
auth/
lib/
services/
hooks/
components/
tests/
```

### 3.2 Segurança primeiro

Antes de implementar, usar skills/pacotes de segurança se existirem no ambiente:

```text
security-review
api-security
static-analysis
supply-chain-risk-auditor
insecure-defaults
threat-model
systematic-debugging
verification-before-completion
testing / TDD
```

Se alguma skill não existir:

```text
SKILL_NOT_AVAILABLE: nome_da_skill
```

E continuar com inspeção manual equivalente.

### 3.3 Backup obrigatório

Antes de editar ficheiros:

```text
- criar backup dos ficheiros alterados;
- criar restore script simples;
- documentar que ficheiros serão tocados;
- não fazer commit sem autorização;
- não fazer push sem autorização;
- não fazer deploy sem autorização.
```

---

## 4. Ordem correta de construção

A ordem certa não é:

```text
1. fazer UI
2. ligar API
3. no fim ver segurança
```

A ordem certa é:

```text
1. definir fluxo e dados sensíveis;
2. threat model rápido;
3. criar backend/API seguro;
4. validar input no backend;
5. aplicar autenticação/autorização;
6. garantir ownership de recurso;
7. criar frontend sem secrets;
8. tratar erros;
9. adicionar logs seguros;
10. criar testes mínimos;
11. passar typecheck/build/test;
12. só depois considerar a feature pronta.
```

---

## 5. Gate de segurança por feature

Sempre que criar ou alterar uma feature, verificar:

### 5.1 Input

```text
- Todo input externo é validado no backend?
- Há schema de validação?
- Campos obrigatórios são realmente obrigatórios?
- Tipos, tamanhos e formatos são limitados?
- O frontend valida UX, mas o backend valida segurança?
```

### 5.2 Autenticação

```text
- A rota exige utilizador autenticado?
- A sessão/token expira?
- Logout invalida sessão/token quando aplicável?
- Cookies têm HttpOnly, Secure e SameSite quando aplicável?
- Não há auth fake, skipAuth, demoAuth ou bypass?
```

### 5.3 Autorização

```text
- O utilizador tem papel correto?
- Admin/moderador/user são verificados no backend?
- A operação exige ownership?
- O utilizador só lê/edita/apaga recursos seus?
- Há risco de IDOR por mudar ID na URL?
```

### 5.4 Secrets

```text
- Nenhuma chave está hardcoded?
- Nenhuma API key está no frontend?
- Nenhuma variável PUBLIC_/NEXT_PUBLIC_/VITE_ contém segredo?
- .gitignore protege .env e ficheiros sensíveis?
- .env.example só tem placeholders?
```

### 5.5 Logs

```text
- Logs têm requestId?
- Logs têm action, route, userId quando seguro?
- Logs estão em JSON quando aplicável?
- Logs mascaram password, token, cookie, authorization, apiKey, secret?
- Não há console.log inseguro em produção?
```

### 5.6 Erros

```text
- API tem try/catch?
- Erros async não falham silenciosamente?
- Utilizador recebe feedback útil?
- Backend não expõe stack trace?
- Erro crítico gera log sanitizado?
```

### 5.7 Testes

```text
- Existe teste do caso feliz?
- Existe teste do bloqueio principal?
- Existe teste de permissões?
- Existe teste de input inválido?
- Existe teste de erro?
```

---

## 6. Autenticação e senhas

Se o projeto tiver login/senhas, validar obrigatoriamente:

```text
- senhas nunca em texto plano;
- nunca MD5;
- nunca SHA1;
- salt único por utilizador;
- bcrypt ou Argon2 com custo adequado;
- modelo zero-knowledge: admins não conseguem ler nem reverter senha;
- reset de senha com token temporário;
- tokens/sessões expiram;
- rate limit em login/reset;
- mensagens de erro não permitem enumeração de utilizadores.
```

Se encontrar problema, a prioridade é alta ou crítica.

---

## 7. Autorização, RBAC e ownership

Cada rota sensível precisa de mapa:

```text
Endpoint:
Método:
Auth exigida:
Role exigido:
Ownership exigido:
Dados sensíveis:
Risco:
Correção:
Teste:
```

Operações de leitura, edição e exclusão devem validar ownership no backend.

Não aceitar apenas esconder botão no frontend como proteção.

---

## 8. Vulnerabilidades web comuns

Verificar continuamente:

### SQL Injection

```text
- usar ORM seguro;
- usar queries parametrizadas;
- nunca concatenar input do utilizador em SQL.
```

### XSS

```text
- sanitizar HTML/markdown externo;
- evitar dangerouslySetInnerHTML;
- escapar conteúdo gerado por utilizador.
```

### CSRF

```text
- proteger requests que modificam dados;
- usar SameSite em cookies;
- usar token CSRF quando necessário.
```

### Headers

Verificar se existem ou justificar ausência:

```text
Content-Security-Policy
X-Frame-Options ou frame-ancestors
X-Content-Type-Options
Referrer-Policy
Permissions-Policy
Strict-Transport-Security quando aplicável
```

---

## 9. Frontend e chamadas sensíveis

O frontend não deve conter:

```text
- API keys privadas;
- tokens administrativos;
- secrets;
- chamadas diretas para providers sensíveis;
- URLs internas que deviam ser privadas;
- lógica de autorização crítica apenas no cliente.
```

Chamadas sensíveis devem passar por backend seguro, API route, server action ou serviço equivalente.

---

## 10. Observabilidade

A aplicação deve ser possível de diagnosticar em produção sem expor dados sensíveis.

Preferir logger profissional:

```text
Pino
Winston
Outro logger estruturado equivalente
```

Níveis mínimos:

```text
info
warn
error
fatal
```

Contexto recomendado:

```text
requestId
userId quando seguro
action
route
resourceId quando seguro
status
durationMs
```

Redaction obrigatória:

```text
password
token
authorization
cookie
apiKey
secret
privateKey
accessToken
refreshToken
session
```

---

## 11. Tratamento de erros

Evitar:

```text
- promises sem catch;
- API calls sem try/catch;
- erros apenas em console.log;
- falhas silenciosas;
- UI que fica parada sem feedback;
- backend a devolver stack trace.
```

Implementar:

```text
- respostas API consistentes;
- mensagens úteis para o utilizador;
- logs sanitizados;
- Error Boundaries em React quando fizer sentido;
- fallback UI;
- testes de erro.
```

---

## 12. Testes obrigatórios nos fluxos críticos

Prioridade máxima:

```text
1. autenticação;
2. autorização;
3. ownership de dados;
4. criação/edição/remoção de dados do utilizador;
5. pagamentos, se existirem;
6. lógica de negócio central;
7. validação de input;
8. endpoints administrativos;
9. casos de erro.
```

Não criar apenas testes felizes. Testar também bloqueios.

Exemplos:

```text
- user A não consegue ler recurso do user B;
- user sem admin não consegue aceder endpoint admin;
- input inválido é rejeitado;
- token expirado é rejeitado;
- pagamento inválido não cria estado pago;
- segredo não aparece em logs;
```

---

## 13. TypeScript

Evitar:

```text
- any sem justificação;
- props sem tipo;
- DTOs sem tipo;
- resposta de API sem tipo;
- input externo sem schema;
- tipos demasiado genéricos.
```

Preferir:

```text
- tipos explícitos;
- schemas de validação;
- DTOs separados;
- tipos restritivos;
- inferência a partir de schemas quando possível.
```

---

## 14. React hooks

Verificar:

```text
- hooks não são chamados condicionalmente;
- hooks não estão dentro de loops;
- dependências de useEffect/useMemo/useCallback estão corretas;
- lógica complexa foi extraída para custom hooks;
- useReducer é usado quando vários estados mudam juntos;
- effects não fazem demasiadas responsabilidades ao mesmo tempo.
```

---

## 15. Gestão de estado

Evitar:

```text
- prop drilling excessivo;
- estado duplicado;
- estado derivado guardado sem necessidade;
- Context API para tudo;
- estado global sem motivo;
- inconsistência entre frontend e backend.
```

Preferir:

```text
- estado local quando suficiente;
- composição de componentes;
- custom hooks;
- reducer para estados relacionados;
- Context API apenas para dados realmente partilhados;
- biblioteca de estado só com justificação real.
```

---

## 16. Separação lógica/apresentação

Evitar componentes que fazem tudo:

```text
- UI;
- fetching;
- validação;
- regras de negócio;
- side effects;
- transformação de dados;
- renderização.
```

Preferir:

```text
components/    -> apresentação
hooks/         -> lógica reutilizável
services/      -> chamadas externas/API
schemas/       -> validação
types/         -> contratos
server/        -> lógica backend
```

---

## 17. Performance

Otimizar com critério, não por reflexo.

Procurar:

```text
- renders repetidos;
- listas grandes sem virtualização;
- imagens pesadas;
- imports grandes no cliente;
- cálculos pesados sem memoização;
- callbacks que causam renders desnecessários;
- effects que disparam chamadas repetidas.
```

Aplicar:

```text
React.memo
useMemo
useCallback
lazy loading
image optimization
virtualização
code splitting
```

Só quando houver motivo concreto.

---

## 18. Dead code, leftovers e mocks

Procurar continuamente:

```text
mock
fake
demo
test route
bypass
skipAuth
TODO auth
FIXME security
console.log
hardcoded
temporary
sample data
```

Antes de remover:

```text
- listar ficheiro;
- explicar uso atual;
- confirmar que não é usado;
- remover;
- correr testes/build.
```

---

## 19. Duplicação e DRY

Procurar:

```text
- validações repetidas;
- componentes quase iguais;
- chamadas API duplicadas;
- tratamento de erro duplicado;
- lógica de forms repetida;
- transformação de dados repetida.
```

Refatorar para:

```text
- utils;
- hooks;
- components reutilizáveis;
- services;
- schemas partilhados;
- middleware.
```

---

## 20. Auditoria final antes de produção

A auditoria final não substitui a construção segura. Ela serve para confirmar que nada ficou esquecido.

Executar antes de dizer “pronto para produção”:

```text
npm audit / pnpm audit / yarn audit
typecheck
lint
tests
build
secret scan
grep por mock/fake/demo/bypass/skipAuth
grep por console.log
grep por TODO/FIXME de auth/security
revisão de endpoints sensíveis
revisão de variáveis públicas
revisão de .gitignore
revisão de logs
```

---

## 21. Relatório final obrigatório

No fim de cada fase importante, entregar:

```text
## Estado provado
- ficheiros inspecionados;
- comandos executados;
- resultados reais.

## O que foi implementado
- ficheiros alterados;
- motivo;
- impacto.

## Segurança
- auth validada;
- autorização validada;
- ownership validado;
- secrets verificados;
- logs sanitizados;
- inputs validados.

## Testes
- testes criados;
- testes executados;
- resultado.

## Riscos restantes
- o que ainda não está confirmado;
- o que ficou pendente;
- risco se for ignorado.

## Próximo passo exato
- uma ação concreta;
- sem generalidades.
```

---

## 22. Prompt curto para ativar estas regras no Claude Code

Usa este bloco no início de prompts técnicos:

```text
Antes de codificar, lê e aplica o ficheiro CLAUDE_CODE_BUILD_RULES_SECURITY_FIRST.md.

Estas regras são obrigatórias durante a construção, não apenas na auditoria final.

Cada feature nova deve incluir segurança, validação de input, autorização/ownership quando aplicável, tratamento de erro, logs seguros, tipos TypeScript e testes mínimos. Não faças deploy, commit ou push sem autorização. Cria backup antes de editar. Se não houver prova no código, diz “não confirmado”.
```

---

## 23. Regra de decisão

Não aceitar estas frases sem prova:

```text
"deve estar seguro"
"parece estar ok"
"não encontrei problema"
"pronto para produção"
"depois fazemos testes"
"isto é só temporário"
"é só mock para agora"
```

Substituir por:

```text
"verificado em ficheiro X"
"testado com comando Y"
"bloqueado por teste Z"
"não confirmado porque falta..."
"risco pendente..."
```

---

## 24. Resumo executivo

Construir bem significa:

```text
Segurança desde o primeiro ficheiro.
Permissões no backend, não só na UI.
Secrets nunca no cliente.
Logs úteis, mas sanitizados.
Erros tratados, não escondidos.
Testes nos fluxos que podem causar dano.
TypeScript usado para reduzir risco.
Mocks e bypasses removidos antes de produção.
Auditoria final como confirmação, não como remendo.
```
