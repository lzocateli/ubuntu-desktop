# Instruções do Copilot - ubuntu-desktop

## Escopo

O documento principal do projeto e `README.md` na raiz. `.github/README-copilot.md` e
auxiliar e serve somente como mapa de instrucoes do Copilot; nao o trate como
README principal nem duplique nele a documentacao operacional do projeto.

Regras obrigatórias para criar, alterar e revisar automações neste repositório.
Responda e documente em português brasileiro. Leia implementação e testes próximos
antes de editar; preserve alterações do usuário. Não faça commit ou push sem pedido.
O alvo é Ubuntu Desktop; declare versões, arquitetura e requisitos de sessão gráfica
por automação, sem presumir que o terminal do desenvolvedor usa o mesmo SO do alvo.

## Organização

- `scripts/bash/`: executáveis e bibliotecas Bash.
- `scripts/powershell/`: scripts e módulos PowerShell.
- `ansible/`: playbooks, roles, inventários e configuração.
- `tests/`: testes por tecnologia; reutilize suítes e helpers existentes.
- `docs/`: documentação operacional; planos persistidos em `docs/plan/`.
- `artifacts/`: logs, relatórios e temporários locais ignorados pelo Git.
- Crie apenas pastas e arquivos necessários; remova auxiliares de geração ao concluir.

## Contrato Obrigatório

- Bash: `--help`, `-help`, `-h`; `--dry-run`, `-dryrun`; `--verbose`.
- PowerShell: `-Help`, `Get-Help`, `-DryRun`, `-WhatIf`, `-Confirm`, `-Verbose`.
- Ansible: `--check --diff`. Entrypoints operacionais oferecem wrapper fino Bash ou
  PowerShell com ajuda específica e tradução dos aliases de simulação.
- Bibliotecas importadas não executam CLI nem mutações ao carregar; documente funções públicas.
- Ajuda funciona sem privilégios, rede, dependências operacionais ou parâmetros
  obrigatórios; retorna zero e não cria logs ou arquivos.
- Simulação valida entradas e apresenta o plano, mas não altera configurações,
  pacotes, serviços, permissões, usuários, recursos remotos ou credenciais.
  A única escrita permitida é o log local de auditoria em `artifacts/`.
- Propague simulação a subprocessos e hosts remotos. Nunca execute uma mutação
  para descobrir o que aconteceria. Se não houver simulação segura, informe a
  limitação e não execute; não anuncie simulação completa de operações puladas.
- Logs no console e em arquivo, com timestamp UTC, nível, identificador único e
  modo real/simulado; erros em stderr/error stream, resultados estruturados separados.
- Nunca registre secrets, tokens ou dados sensíveis, nem em modo verboso/diff.
  Falha de logging deve impedir mutações sem auditoria.
- Valide dependências, versões, SO, entradas e privilégios antes de mutações.
  Não instale dependências durante ajuda ou simulação; não autoeleve privilégios.
- Busque idempotência: segunda execução não altera estado já convergido.
- Operações destrutivas exigem escopo, confirmação explícita e recuperação documentada.
  Não desabilite TLS, SSH host-key checking ou políticas de segurança para facilitar execução.
- Falhas retornam não zero, inclusive de comandos nativos/pipelines. Não esconda
  erros com `|| true`, `SilentlyContinue` ou sucesso incondicional.
- Resolva caminhos pelo script/repositório, não pelo diretório atual. Temporários
  únicos em `artifacts/`; cleanup restrito aos recursos desta execução.
- Não versionar credenciais, inventários privados, logs ou artefatos de execução.

## Documentação e Validação

- Cada automação tem ajuda embutida e README operacional com objetivo, dependências,
  parâmetros, exemplos, simulação, logs, riscos e recuperação. Veja o guia de documentação.
- Todo README técnico inclui sumário com âncoras. Atualize ajuda, documentação e
  testes junto das mudanças de comportamento.
- Antes de concluir, valide sintaxe/lint e testes focados; execute ajuda e simulação
  em ambiente isolado. Comprove zero chamadas mutantes no dry-run e idempotência.
- Nunca teste mutações no desktop do usuário ou em hosts reais sem autorização.
- Informe comandos executados, resultados e checks indisponíveis. Instruções Markdown
  orientam o Copilot, mas não substituem testes, revisão humana ou controles de CI.
- Mudanças grandes exigem plano aprovado. Planos em `docs/plan/` incluem `Status do Plano`,
  data, progresso, evidências e próximo passo. Estados: `Pendente`, `Em andamento`,
  `Bloqueado`, `Concluído`, `Cancelado`; concluir apenas depois de registrar validação.

## Guias Especializados

- [Bash](instructions/bash.instructions.md)
- [PowerShell](instructions/powershell.instructions.md)
- [Ansible](instructions/ansible.instructions.md)
- [Documentação operacional](instructions/documentation.instructions.md)
- [Índice e checklist](README-copilot.md)
