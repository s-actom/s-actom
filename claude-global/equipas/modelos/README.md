# Modelos autorizados (Adaptive Model Intelligence)

Este diretório é a **fonte única** de autorização de modelos. O código não conhece nenhum
identificador: lê `autorizacao.json`.

## Contrato

- `politica.fornecedores_permitidos` — portão duro. Um modelo de outro fornecedor é ignorado
  mesmo que esteja listado (`autorizado:true` não chega).
- Cada entrada precisa de `id`, `fornecedor`, `runtime`, `acesso` e das duas flags:
  - `autorizado` — decisão explícita do proprietário;
  - `ativo` — está em uso agora (uma entrada `ativo:false` fica documentada mas não é escolhida).
- `origem` é a prova (ficheiro:linha da configuração local). Sem prova, é uma suposição.
- `preco` (opcional, USD por milhão de tokens) só entra no cálculo se for declarado; em falta,
  o custo é neutro — não se estima.

## Adicionar um modelo (sem tocar em código)

1. Descobrir candidatos locais (sem rede):

   ```bash
   python3 equipas/modelos/descobrir.py
   ```

2. Acrescentar a entrada com `autorizado:true` e `ativo:true` (ou correr `--escrever` e depois
   mudar as flags — `--escrever` cria sempre como pendente).

3. Confirmar que não há divergências:

   ```bash
   python3 equipas/modelos/descobrir.py --verificar   # exit 1 = configurado sem autorização
   ```

## Remover um modelo

`ativo:false` (suspenso, mantém histórico) ou apagar a entrada. O histórico em
`estado/modelos.jsonl` nunca é reescrito.

## O que este módulo não faz

- Não procura modelos na Internet nem pergunta catálogos a APIs.
- Não autoriza por família: `openai`/`anthropic`/`deepseek`/`glm` são o âmbito, não a aprovação.
- Não escolhe fora da lista nem usa um modelo não autorizado como fallback.
- Não decide delegação: propõe à Direção Geral, que continua a ser o único decisor.
