# Padrões Copilot - ubuntu-desktop

## Sumário

- [Objetivo](#objetivo)
- [Mapa de instruções](#mapa-de-instruções)
- [Contrato de execução](#contrato-de-execução)
- [Documentação obrigatória](#documentação-obrigatória)
- [Checklist de entrega](#checklist-de-entrega)
- [Limites](#limites)

## Objetivo

Este e um guia auxiliar do Copilot. O documento principal do projeto e o
[`README.md` da raiz](../README.md).

Orientar automações Ubuntu Desktop seguras, idempotentes e rastreáveis. Base copiada
do SecuritFilesMaster e adaptada usando padrões de ajuda, logs e exemplos observados
em `run-terraform-local.sh`, `common-config.sh` e `export-iis-sites-inventory.ps1`
na pasta `scripts/` da origem. Esses exemplos não são templates completos de conformidade.

Foram removidas regras de Terraform, Python e a skill Hangfire/Service Bus, fora do
escopo atual. O caminho de artefatos foi substituído por `artifacts/`.

## Mapa de Instruções

| Guia | Aplicação |
| --- | --- |
| [copilot-instructions.md](copilot-instructions.md) | Todas as tarefas |
| [Bash](instructions/bash.instructions.md) | `.sh`, `.bash`, `.bats` |
| [PowerShell](instructions/powershell.instructions.md) | `.ps1`, `.psm1`, `.psd1` |
| [Ansible](instructions/ansible.instructions.md) | `ansible/`, arquivos `*.ansible.yml`/`*.ansible.yaml` |
| [Documentação](instructions/documentation.instructions.md) | READMEs e `docs/` |

Guias específicos possuem `description` e `applyTo`. Novos playbooks ficam em
`ansible/`; YAML genérico fora desses caminhos não ativa regras Ansible automaticamente.
Para executáveis sem extensão, carregue o guia manualmente e ajuste globs se necessário.

## Contrato de Execução

| Tecnologia | Ajuda | Simulação | Verbosidade |
| --- | --- | --- | --- |
| Bash | `-h`, `--help`, `-help` | `--dry-run`, `-dryrun` | `--verbose` |
| PowerShell | `-Help`, `Get-Help` | `-DryRun`, `-WhatIf` | `-Verbose` |
| Ansible | Ajuda específica no wrapper | Wrapper traduz para `--check --diff` | Wrapper traduz para `-v` |

Ajuda não exige root/dependências operacionais nem grava arquivos. Simulação não
altera estado local/remoto; só log local de auditoria é permitido. Check mode não
é sandbox: tarefas/plugins sem suporte exigem tratamento e limitações explícitas.

Modelos para futuros scripts, não arquivos existentes. Substitua `<script>` pelo
nome real e inclua os parâmetros operacionais necessários no README da automação:

```bash
bash scripts/bash/<script>.sh --help
bash scripts/bash/<script>.sh --dry-run --verbose
bash scripts/bash/<script>.sh
```

```powershell
pwsh -File scripts/powershell/<script>.ps1 -Help
pwsh -File scripts/powershell/<script>.ps1 -DryRun -Verbose
pwsh -File scripts/powershell/<script>.ps1 -WhatIf
pwsh -File scripts/powershell/<script>.ps1
```

Wrappers Ansible documentam inventário, `--limit`, tags e privilégios. Não invente
aliases `-help`/`-dryrun` para `ansible-playbook`; use o contrato no wrapper.

## Documentação Obrigatória

Use o [roteiro operacional](instructions/documentation.instructions.md): objetivo,
dependências/versões, parâmetros/defaults, exemplos de ajuda/simulação/uso real,
logs/saídas, segurança, recuperação, validação e troubleshooting.
Cada README técnico contém sumário com âncoras e caminhos relativos ao repositório.
Ajuda e README devem corresponder à implementação e aos testes reais.

## Checklist de Entrega

- [ ] Dependências, versões, escopo e privilégios validados antes de mutação.
- [ ] Ajuda/aliases funcionam sem efeitos colaterais ou entradas obrigatórias.
- [ ] Entradas inválidas falham; exit codes e streams são coerentes.
- [ ] Dry-run/WhatIf propagados e testados com zero chamadas mutantes.
- [ ] Logs únicos em console e `artifacts/`, sem secrets.
- [ ] Caminhos com espaços e execução fora da raiz testados.
- [ ] Sintaxe e lint aprovados nas ferramentas da tecnologia.
- [ ] Testes Bats/Pester/Molecule ou VM isolada, conforme risco e alvo.
- [ ] Segunda execução sem mudanças; exceções justificadas.
- [ ] README/ajuda atualizados; impacto, recuperação e limites explícitos.
- [ ] Evidências e verificações indisponíveis registradas.

## Limites

Esta base contém instruções e documentação, ainda sem scripts operacionais,
playbooks, testes ou CI. Comandos nos guias são critérios para futuras automações,
não resultados de execução. Markdown orienta o Copilot; testes e revisão continuam
necessários. Planos persistidos em `docs/plan/` registram status e evidências.
