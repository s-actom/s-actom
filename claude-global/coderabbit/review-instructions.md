# Global review instructions

These apply to every repository reviewed through the shared wrapper (Claude Code and Codex).
Repositories with their own CodeRabbit config file use that config instead of this file.

## Report first
- Bugs, regressions and incorrect behavior.
- Data loss or corruption.
- Authentication and authorization (IDOR/BOLA), privacy and secrets exposure.
- Race conditions and concurrency, resource exhaustion, broken integrations.
- Missing or wrong error handling, serious performance problems.
- Missing tests for critical behavior.

## Security uncertainty
Flag plausible security risks even without full proof, and say what evidence would confirm them.

## Specific areas
- API routes and handlers: check authn/authz on every route, input validation, data leakage and error responses. Describe a concrete failure scenario.
- On-chain, wallet and transaction code: check signer and account ownership checks, mainnet vs devnet targeting, secret handling and transaction safety.

## Avoid
Style nitpicks, preference-only architecture changes and speculative refactors. Be concise.
