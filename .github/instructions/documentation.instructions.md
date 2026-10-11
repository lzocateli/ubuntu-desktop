---
description: "Documentar Bash, PowerShell e Ansible: objetivo, dependencias, parametros, exemplos, dry-run, logs, riscos e recuperacao."
applyTo: "**/README.md,docs/**/*.md"
---

# Documentacao Operacional

## Regras

- Portugues brasileiro, direto e verificavel. Todo README tecnico tem sumario
  com ancoras, links relativos validos e comandos coerentes com a implementacao.
- Cada automacao tem ajuda embutida quando possivel e README dedicado ou secao
  identificavel num README existente. Nao duplique documentos extensos.
- Atualize ajuda, documento e testes junto do comportamento. Exemplos usam valores
  ficticios seguros, nunca senhas, tokens ou alvos privados reais.
- Identifique modelos/placeholders; nao anuncie scripts ou ferramentas como
  implementados antes de cria-los. READMEs operacionais usam comandos reais.
- Planos persistidos em `docs/plan/` seguem `Status do Plano` das regras globais.

## Roteiro Obrigatorio

1. **Objetivo e escopo:** problema, SO/versoes, estado desejado e limites.
2. **Dependencias:** ferramentas/versoes, modulos/collections, instalacao confiavel
   separada, rede e privilegios minimos. Distinguir dependencias de execucao/teste.
3. **Uso rapido:** comando desde a raiz e pre-condicoes verificaveis.
4. **Parametros:** nome, tipo, obrigatoriedade, default, valores aceitos, aliases
   e origem de secrets; Ansible inclui variaveis, inventario, tags, limite e become.
5. **Exemplos:** ajuda, simulacao, execucao real, verbosidade e erro. Exemplos
   destrutivos explicam confirmacao e impacto antes do comando.
6. **Simulacao:** consultas, plano, log local permitido, tasks nao simulaveis e
   como comprovar ausencia de mutacoes locais/remotas.
7. **Logs e saidas:** caminhos `artifacts/`, formato, streams, codigos de saida,
   permissoes, retencao/descarte e protecao de dados.
8. **Seguranca e impacto:** arquivos, pacotes, servicos, usuarios e rede afetados;
   idempotencia, backup, confirmacao e interrupcoes possiveis.
9. **Validacao:** sintaxe/lint/testes, ambiente, resultados esperados, segunda
   execucao sem mudancas e evidencias reais; checks nao executados explicitados.
10. **Troubleshooting e recuperacao:** sintomas, causas, diagnostico sem secrets,
    rollback passo a passo e limites de reversibilidade. Sem bypass de seguranca.

## Revisao

- Ajuda funciona sem dependencias operacionais ou entradas obrigatorias?
- Exemplos e defaults correspondem ao parser implementado?
- Simulacao protege efeitos indiretos, comandos nativos e redirecionamentos?
- Dependencias sao instaladas separadamente, nunca na ajuda/dry-run?
- Ha testes de erros, zero mutacoes e idempotencia com lacunas registradas?
- Recuperacao e praticavel, sem prometer rollback impossivel?